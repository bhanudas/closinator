/**
 * @description Evaluates Custom Metadata rules and builds dynamic SOQL queries.
 * Core rule processing engine for the Case Auto-Closer system.
 */
public with sharing class util_closer_RuleEngine {
    
    /**
     * @description Returns active rules ordered by Execution_Order__c.
     * @return List of active rules.
     */
    public static List<util_closer_Case_Status_Rule__mdt> getActiveRules() {
        return [
            SELECT Id, DeveloperName, MasterLabel,
                   Is_Active__c, Execution_Order__c,
                   Source_Status__c, Target_Status__c,
                   Days_Since_Last_Modified__c, Days_Since_Created__c,
                   Days_Since_Last_Activity__c, Record_Type_Developer_Names__c,
                   Exclude_Record_Type_Developer_Names__c, Additional_Filter_Logic__c,
                   Description__c, Stop_Processing__c
            FROM util_closer_Case_Status_Rule__mdt
            WHERE Is_Active__c = true
            ORDER BY Execution_Order__c ASC
        ];
    }
    
    /**
     * @description Builds complete SOQL query for batch start method.
     * @return Complete SOQL query string.
     */
    public static String buildBatchQuery() {
        List<util_closer_Case_Status_Rule__mdt> rules = getActiveRules();
        
        if (rules.isEmpty()) {
            util_closer_Logger.debug('RuleEngine', 'No active rules found. Returning empty query.');
            return 'SELECT Id FROM Case WHERE Id = null';
        }
        
        Set<String> allSourceStatuses = new Set<String>();
        for (util_closer_Case_Status_Rule__mdt rule : rules) {
            allSourceStatuses.addAll(parseStatusList(rule.Source_Status__c));
        }
        
        String query = 'SELECT Id, Status, LastModifiedDate, CreatedDate ' +
                       'FROM Case ' +
                       'WHERE IsClosed = false ' +
                       'AND Status IN :sourceStatuses';
        
        util_closer_Logger.debug('RuleEngine', 'Built batch query with ' + allSourceStatuses.size() + ' source statuses');
        
        return query;
    }
    
    /**
     * @description Gets all source statuses from active rules for query binding.
     * @return Set of source status values.
     */
    public static Set<String> getAllSourceStatuses() {
        Set<String> allSourceStatuses = new Set<String>();
        for (util_closer_Case_Status_Rule__mdt rule : getActiveRules()) {
            allSourceStatuses.addAll(parseStatusList(rule.Source_Status__c));
        }
        return allSourceStatuses;
    }
    
    /**
     * @description Evaluates cases against rules and returns status changes.
     * @param cases List of cases to evaluate.
     * @param rules List of rules to apply.
     * @return Map of CaseId to new Status value.
     */
    public static Map<Id, String> evaluateCases(List<Case> cases, List<util_closer_Case_Status_Rule__mdt> rules) {
        Map<Id, String> statusChanges = new Map<Id, String>();
        
        for (Case c : cases) {
            String newStatus = evaluateCaseAgainstRules(c, rules);
            if (newStatus != null) {
                statusChanges.put(c.Id, newStatus);
            }
        }
        
        util_closer_Logger.debug('RuleEngine', 'Evaluated ' + cases.size() + ' cases, ' + statusChanges.size() + ' require updates');
        
        return statusChanges;
    }
    
    /**
     * @description Evaluates a single case against all rules.
     * @param c The case to evaluate.
     * @param rules The rules to apply.
     * @return New status if a rule matches, null otherwise.
     */
    private static String evaluateCaseAgainstRules(Case c, List<util_closer_Case_Status_Rule__mdt> rules) {
        for (util_closer_Case_Status_Rule__mdt rule : rules) {
            if (caseMatchesRule(c, rule)) {
                util_closer_Logger.debug('RuleEngine', 'Case ' + c.Id + ' matches rule ' + rule.DeveloperName);
                
                if (rule.Stop_Processing__c == true) {
                    return rule.Target_Status__c;
                }
                return rule.Target_Status__c;
            }
        }
        return null;
    }
    
    /**
     * @description Checks if a case matches a specific rule.
     * @param c The case to check.
     * @param rule The rule to match against.
     * @return True if the case matches the rule.
     */
    private static Boolean caseMatchesRule(Case c, util_closer_Case_Status_Rule__mdt rule) {
        // Check source status
        Set<String> sourceStatuses = parseStatusList(rule.Source_Status__c);
        if (!sourceStatuses.contains(c.Status)) {
            return false;
        }
        
        // Check days since last modified
        if (rule.Days_Since_Last_Modified__c != null) {
            Integer daysSinceModified = getDaysSince(c.LastModifiedDate);
            if (daysSinceModified < rule.Days_Since_Last_Modified__c) {
                return false;
            }
        }
        
        // Check days since created
        if (rule.Days_Since_Created__c != null) {
            Integer daysSinceCreated = getDaysSince(c.CreatedDate);
            if (daysSinceCreated < rule.Days_Since_Created__c) {
                return false;
            }
        }
        
        // Check days since last activity - only if the field exists on the object
        if (rule.Days_Since_Last_Activity__c != null) {
            try {
                Object lastActivityObj = c.get('LastActivityDate');
                if (lastActivityObj != null) {
                    Date lastActivity = (Date)lastActivityObj;
                    Integer daysSinceActivity = lastActivity.daysBetween(Date.today());
                    if (daysSinceActivity < rule.Days_Since_Last_Activity__c) {
                        return false;
                    }
                }
            } catch (SObjectException e) {
                // Field not available, skip this check
            }
        }
        
        // Check record type inclusion - only if RecordType is available
        if (String.isNotBlank(rule.Record_Type_Developer_Names__c)) {
            Set<String> includedRecordTypes = parseList(rule.Record_Type_Developer_Names__c);
            try {
                SObject recordType = c.getSObject('RecordType');
                String caseRecordType = recordType != null ? (String)recordType.get('DeveloperName') : null;
                if (caseRecordType == null || !includedRecordTypes.contains(caseRecordType)) {
                    return false;
                }
            } catch (SObjectException e) {
                // RecordType not available, skip this check
            }
        }
        
        // Check record type exclusion - only if RecordType is available
        if (String.isNotBlank(rule.Exclude_Record_Type_Developer_Names__c)) {
            Set<String> excludedRecordTypes = parseList(rule.Exclude_Record_Type_Developer_Names__c);
            try {
                SObject recordType = c.getSObject('RecordType');
                String caseRecordType = recordType != null ? (String)recordType.get('DeveloperName') : null;
                if (caseRecordType != null && excludedRecordTypes.contains(caseRecordType)) {
                    return false;
                }
            } catch (SObjectException e) {
                // RecordType not available, skip this check
            }
        }
        
        return true;
    }
    
    /**
     * @description Parses semicolon-separated status list.
     * @param statusString The status string to parse.
     * @return Set of status values.
     */
    private static Set<String> parseStatusList(String statusString) {
        return parseList(statusString);
    }
    
    /**
     * @description Parses a semicolon-separated list into a set.
     * @param listString The string to parse.
     * @return Set of trimmed values.
     */
    private static Set<String> parseList(String listString) {
        Set<String> values = new Set<String>();
        if (String.isNotBlank(listString)) {
            for (String value : listString.split(';')) {
                String trimmed = value.trim();
                if (String.isNotBlank(trimmed)) {
                    values.add(trimmed);
                }
            }
        }
        return values;
    }
    
    /**
     * @description Calculates days since a datetime.
     * @param dt The datetime to compare.
     * @return Number of days since the datetime.
     */
    private static Integer getDaysSince(DateTime dt) {
        if (dt == null) {
            return 0;
        }
        return dt.date().daysBetween(Date.today());
    }
}

