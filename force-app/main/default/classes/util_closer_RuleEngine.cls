/**
 * @description Evaluates Custom Metadata rules and builds dynamic SOQL queries.
 * Core rule processing engine for the Case Auto-Closer system.
 */
public with sharing class util_closer_RuleEngine {

    /**
     * @description Mock rules for testing. When set, getActiveRules() returns these instead of querying.
     */
    @TestVisible
    private static List<util_closer_Case_Status_Rule__mdt> mockRules;

    /**
     * @description Wrapper class to hold status and reason changes for a Case.
     */
    public virtual class CaseChange {
        public String newStatus;
        public String reason;

        public CaseChange(String newStatus, String reason) {
            this.newStatus = newStatus;
            this.reason = reason;
        }
    }

    /**
     * @description Extended wrapper class with detailed evaluation information.
     */
    public class DetailedCaseChange extends CaseChange {
        public String matchedRuleDeveloperName;
        public String matchedRuleMasterLabel;
        public Integer rulesEvaluatedCount;
        public List<RuleEvaluationDetail> ruleEvaluations;
        public Boolean childRecordsChecked;
        public Integer childRecordsFound;

        public DetailedCaseChange(String newStatus, String reason) {
            super(newStatus, reason);
            this.rulesEvaluatedCount = 0;
            this.ruleEvaluations = new List<RuleEvaluationDetail>();
            this.childRecordsChecked = false;
            this.childRecordsFound = 0;
        }
    }

    /**
     * @description Wrapper class for individual rule evaluation details.
     */
    public class RuleEvaluationDetail {
        public String ruleDeveloperName;
        public String ruleMasterLabel;
        public Boolean matched;
        public String failureReason;

        public RuleEvaluationDetail(String developerName, String masterLabel, Boolean matched, String failureReason) {
            this.ruleDeveloperName = developerName;
            this.ruleMasterLabel = masterLabel;
            this.matched = matched;
            this.failureReason = failureReason;
        }
    }

    /**
     * @description Returns active rules ordered by Execution_Order__c.
     * Uses mockRules if set (for testing), otherwise queries custom metadata.
     * @return List of active rules.
     */
    public static List<util_closer_Case_Status_Rule__mdt> getActiveRules() {
        if (mockRules != null) {
            return mockRules;
        }
        return [
            SELECT Id, DeveloperName, MasterLabel,
                   Is_Active__c, Execution_Order__c,
                   Source_Status__c, Target_Status__c, Target_Reason__c,
                   Days_Since_Last_Modified__c, Days_Since_Created__c,
                   Days_Since_Last_Activity__c, Record_Type_Developer_Names__c,
                   Exclude_Record_Type_Developer_Names__c, Additional_Filter_Logic__c,
                   Description__c, Stop_Processing__c,
                   Child_Object_API_Name__c, Child_Lookup_Field__c,
                   Child_Filter_Field__c, Child_Filter_Value__c,
                   Child_Filter_Operator__c, Require_Child_Record__c,
                   Origins__c, Owner_Name_Like__c, Last_Modified_By_Name_Like__c
            FROM util_closer_Case_Status_Rule__mdt
            WHERE Is_Active__c = true
            ORDER BY Execution_Order__c ASC
        ];
    }

    /**
     * @description Checks if any rules have child criteria configured.
     * @param rules List of rules to check.
     * @return True if at least one rule has child criteria.
     */
    @TestVisible
    public static Boolean rulesHaveChildCriteria(List<util_closer_Case_Status_Rule__mdt> rules) {
        return util_closer_ChildRecordService.rulesHaveChildCriteria(rules);
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
        
        String query = 'SELECT Id, CaseNumber, Status, LastModifiedDate, CreatedDate ' +
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
     * @return Map of CaseId to CaseChange containing new status and optional reason.
     */
    public static Map<Id, CaseChange> evaluateCases(List<Case> cases, List<util_closer_Case_Status_Rule__mdt> rules) {
        return evaluateCases(cases, rules, null);
    }

    /**
     * @description Evaluates cases against rules and returns status changes with child data support.
     * @param cases List of cases to evaluate.
     * @param rules List of rules to apply.
     * @param childDataMap Map of Case ID to list of child records (null if no child criteria).
     * @return Map of CaseId to CaseChange containing new status and optional reason.
     */
    public static Map<Id, CaseChange> evaluateCases(
        List<Case> cases,
        List<util_closer_Case_Status_Rule__mdt> rules,
        Map<Id, List<SObject>> childDataMap
    ) {
        Map<Id, CaseChange> caseChanges = new Map<Id, CaseChange>();

        for (Case c : cases) {
            List<SObject> childRecords = (childDataMap != null && childDataMap.containsKey(c.Id))
                ? childDataMap.get(c.Id)
                : new List<SObject>();
            CaseChange change = evaluateCaseAgainstRules(c, rules, childRecords);
            if (change != null) {
                caseChanges.put(c.Id, change);
            }
        }

        util_closer_Logger.debug('RuleEngine', 'Evaluated ' + cases.size() + ' cases, ' + caseChanges.size() + ' require updates');

        return caseChanges;
    }

    /**
     * @description Evaluates cases against rules with detailed evaluation information.
     * Returns DetailedCaseChange objects that include per-rule evaluation details.
     * @param cases List of cases to evaluate.
     * @param rules List of rules to apply.
     * @param childDataMap Map of Case ID to list of child records (null if no child criteria).
     * @param logRuleEvaluations Whether to include detailed per-rule evaluation results.
     * @return Map of CaseId to DetailedCaseChange containing evaluation details.
     */
    public static Map<Id, DetailedCaseChange> evaluateCasesWithDetails(
        List<Case> cases,
        List<util_closer_Case_Status_Rule__mdt> rules,
        Map<Id, List<SObject>> childDataMap,
        Boolean logRuleEvaluations
    ) {
        Map<Id, DetailedCaseChange> caseChanges = new Map<Id, DetailedCaseChange>();

        for (Case c : cases) {
            List<SObject> childRecords = (childDataMap != null && childDataMap.containsKey(c.Id))
                ? childDataMap.get(c.Id)
                : new List<SObject>();
            DetailedCaseChange change = evaluateCaseAgainstRulesWithDetails(c, rules, childRecords, logRuleEvaluations);
            if (change != null) {
                caseChanges.put(c.Id, change);
            }
        }

        util_closer_Logger.debug('RuleEngine', 'Evaluated (detailed) ' + cases.size() + ' cases, ' + caseChanges.size() + ' require updates');

        return caseChanges;
    }

    /**
     * @description Evaluates a single case against all rules with detailed tracking.
     * @param c The case to evaluate.
     * @param rules The rules to apply.
     * @param childRecords List of child records for this case.
     * @param logRuleEvaluations Whether to track per-rule evaluation details.
     * @return DetailedCaseChange with evaluation details if a rule matches, null otherwise.
     */
    private static DetailedCaseChange evaluateCaseAgainstRulesWithDetails(
        Case c,
        List<util_closer_Case_Status_Rule__mdt> rules,
        List<SObject> childRecords,
        Boolean logRuleEvaluations
    ) {
        DetailedCaseChange result = new DetailedCaseChange(null, null);
        result.childRecordsChecked = !childRecords.isEmpty() || rulesHaveChildCriteria(rules);
        result.childRecordsFound = childRecords.size();

        for (util_closer_Case_Status_Rule__mdt rule : rules) {
            result.rulesEvaluatedCount++;
            String failureReason = getRuleFailureReason(c, rule, childRecords);

            if (logRuleEvaluations) {
                result.ruleEvaluations.add(new RuleEvaluationDetail(
                    rule.DeveloperName,
                    rule.MasterLabel,
                    failureReason == null,
                    failureReason
                ));
            }

            if (failureReason == null) {
                // Rule matched
                util_closer_Logger.debug('RuleEngine', 'Case ' + c.Id + ' matches rule ' + rule.DeveloperName);
                result.newStatus = rule.Target_Status__c;
                result.reason = rule.Target_Reason__c;
                result.matchedRuleDeveloperName = rule.DeveloperName;
                result.matchedRuleMasterLabel = rule.MasterLabel;
                return result;
            }
        }

        // No rule matched - return null to indicate no change needed
        return null;
    }

    /**
     * @description Gets the reason why a rule didn't match for a case.
     * @param c The case to check.
     * @param rule The rule to match against.
     * @param childRecords List of child records for this case.
     * @return Null if rule matches, otherwise a string describing why it didn't match.
     */
    @TestVisible
    private static String getRuleFailureReason(Case c, util_closer_Case_Status_Rule__mdt rule, List<SObject> childRecords) {
        // Check source status
        Set<String> sourceStatuses = parseStatusList(rule.Source_Status__c);
        if (!sourceStatuses.contains(c.Status)) {
            return 'Status mismatch: Case status "' + c.Status + '" not in rule source statuses';
        }

        // Check days since last modified
        if (rule.Days_Since_Last_Modified__c != null) {
            Integer daysSinceModified = getDaysSince(c.LastModifiedDate);
            if (daysSinceModified < rule.Days_Since_Last_Modified__c) {
                return 'Days since modified: ' + daysSinceModified + ' < required ' + rule.Days_Since_Last_Modified__c;
            }
        }

        // Check days since created
        if (rule.Days_Since_Created__c != null) {
            Integer daysSinceCreated = getDaysSince(c.CreatedDate);
            if (daysSinceCreated < rule.Days_Since_Created__c) {
                return 'Days since created: ' + daysSinceCreated + ' < required ' + rule.Days_Since_Created__c;
            }
        }

        // Check days since last activity
        if (rule.Days_Since_Last_Activity__c != null) {
            try {
                Object lastActivityObj = c.get('LastActivityDate');
                if (lastActivityObj != null) {
                    Date lastActivity = (Date)lastActivityObj;
                    Integer daysSinceActivity = lastActivity.daysBetween(Date.today());
                    if (daysSinceActivity < rule.Days_Since_Last_Activity__c) {
                        return 'Days since activity: ' + daysSinceActivity + ' < required ' + rule.Days_Since_Last_Activity__c;
                    }
                }
            } catch (SObjectException e) {
                // Field not available, skip this check
            }
        }

        // Check record type inclusion
        if (String.isNotBlank(rule.Record_Type_Developer_Names__c)) {
            Set<String> includedRecordTypes = parseList(rule.Record_Type_Developer_Names__c);
            try {
                SObject recordType = c.getSObject('RecordType');
                String caseRecordType = recordType != null ? (String)recordType.get('DeveloperName') : null;
                if (caseRecordType == null || !includedRecordTypes.contains(caseRecordType)) {
                    return 'Record type "' + caseRecordType + '" not in included types';
                }
            } catch (SObjectException e) {
                // RecordType not available
            }
        }

        // Check record type exclusion
        if (String.isNotBlank(rule.Exclude_Record_Type_Developer_Names__c)) {
            Set<String> excludedRecordTypes = parseList(rule.Exclude_Record_Type_Developer_Names__c);
            try {
                SObject recordType = c.getSObject('RecordType');
                String caseRecordType = recordType != null ? (String)recordType.get('DeveloperName') : null;
                if (caseRecordType != null && excludedRecordTypes.contains(caseRecordType)) {
                    return 'Record type "' + caseRecordType + '" is in excluded types';
                }
            } catch (SObjectException e) {
                // RecordType not available
            }
        }

        // Check child record criteria
        if (!util_closer_ChildRecordService.caseMatchesChildCriteria(c.Id, rule, childRecords)) {
            return 'Child record criteria not satisfied';
        }

        // Check Origin filter
        if (String.isNotBlank(rule.Origins__c)) {
            Set<String> allowedOrigins = parseList(rule.Origins__c);
            try {
                String caseOrigin = (String)c.get('Origin');
                if (caseOrigin == null || !allowedOrigins.contains(caseOrigin)) {
                    return 'Origin "' + caseOrigin + '" not in allowed origins';
                }
            } catch (SObjectException e) {
                // Origin field not available
            }
        }

        // Check Owner Name Like filter
        if (String.isNotBlank(rule.Owner_Name_Like__c)) {
            try {
                String ownerName = getRelatedFieldValue(c, 'Owner', 'Name');
                if (ownerName == null || !matchesLikePattern(ownerName, rule.Owner_Name_Like__c)) {
                    return 'Owner name "' + ownerName + '" does not match pattern "' + rule.Owner_Name_Like__c + '"';
                }
            } catch (Exception e) {
                // Owner not available
            }
        }

        // Check Last Modified By Name Like filter
        if (String.isNotBlank(rule.Last_Modified_By_Name_Like__c)) {
            try {
                String lastModifiedByName = getRelatedFieldValue(c, 'LastModifiedBy', 'Name');
                if (lastModifiedByName == null || !matchesLikePattern(lastModifiedByName, rule.Last_Modified_By_Name_Like__c)) {
                    return 'Last modified by "' + lastModifiedByName + '" does not match pattern "' + rule.Last_Modified_By_Name_Like__c + '"';
                }
            } catch (Exception e) {
                // LastModifiedBy not available
            }
        }

        // All checks passed - rule matches
        return null;
    }

    /**
     * @description Evaluates a single case against all rules.
     * @param c The case to evaluate.
     * @param rules The rules to apply.
     * @param childRecords List of child records for this case.
     * @return CaseChange with new status and reason if a rule matches, null otherwise.
     */
    private static CaseChange evaluateCaseAgainstRules(
        Case c,
        List<util_closer_Case_Status_Rule__mdt> rules,
        List<SObject> childRecords
    ) {
        for (util_closer_Case_Status_Rule__mdt rule : rules) {
            if (caseMatchesRule(c, rule, childRecords)) {
                util_closer_Logger.debug('RuleEngine', 'Case ' + c.Id + ' matches rule ' + rule.DeveloperName);

                if (rule.Stop_Processing__c == true) {
                    return new CaseChange(rule.Target_Status__c, rule.Target_Reason__c);
                }
                return new CaseChange(rule.Target_Status__c, rule.Target_Reason__c);
            }
        }
        return null;
    }
    
    /**
     * @description Checks if a case matches a specific rule (without child records).
     * @param c The case to check.
     * @param rule The rule to match against.
     * @return True if the case matches the rule.
     */
    @TestVisible
    private static Boolean caseMatchesRule(Case c, util_closer_Case_Status_Rule__mdt rule) {
        return caseMatchesRule(c, rule, new List<SObject>());
    }

    /**
     * @description Checks if a case matches a specific rule including child criteria.
     * @param c The case to check.
     * @param rule The rule to match against.
     * @param childRecords List of child records for this case.
     * @return True if the case matches the rule.
     */
    @TestVisible
    private static Boolean caseMatchesRule(Case c, util_closer_Case_Status_Rule__mdt rule, List<SObject> childRecords) {
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

        // Check child record criteria
        if (!util_closer_ChildRecordService.caseMatchesChildCriteria(c.Id, rule, childRecords)) {
            return false;
        }

        // Check Origin filter
        if (String.isNotBlank(rule.Origins__c)) {
            Set<String> allowedOrigins = parseList(rule.Origins__c);
            try {
                String caseOrigin = (String)c.get('Origin');
                if (caseOrigin == null || !allowedOrigins.contains(caseOrigin)) {
                    return false;
                }
            } catch (SObjectException e) {
                // Origin field not available, skip this check
            }
        }

        // Check Owner Name Like filter
        if (String.isNotBlank(rule.Owner_Name_Like__c)) {
            try {
                // Access Owner.Name using relationship path for polymorphic field
                String ownerName = getRelatedFieldValue(c, 'Owner', 'Name');
                if (ownerName == null || !matchesLikePattern(ownerName, rule.Owner_Name_Like__c)) {
                    return false;
                }
            } catch (Exception e) {
                // Owner not available, skip this check
            }
        }

        // Check Last Modified By Name Like filter
        if (String.isNotBlank(rule.Last_Modified_By_Name_Like__c)) {
            try {
                String lastModifiedByName = getRelatedFieldValue(c, 'LastModifiedBy', 'Name');
                if (lastModifiedByName == null || !matchesLikePattern(lastModifiedByName, rule.Last_Modified_By_Name_Like__c)) {
                    return false;
                }
            } catch (Exception e) {
                // LastModifiedBy not available, skip this check
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
    @TestVisible
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
    @TestVisible
    private static Integer getDaysSince(DateTime dt) {
        if (dt == null) {
            return 0;
        }
        return dt.date().daysBetween(Date.today());
    }

    /**
     * @description Safely gets a field value from a related object.
     * Handles cases where the relationship might not be queried.
     * @param record The parent SObject.
     * @param relationshipName The relationship name (e.g., 'Owner', 'LastModifiedBy').
     * @param fieldName The field name on the related object (e.g., 'Name').
     * @return The field value as String, or null if not available.
     */
    @TestVisible
    private static String getRelatedFieldValue(SObject record, String relationshipName, String fieldName) {
        if (record == null) {
            return null;
        }
        try {
            SObject relatedRecord = record.getSObject(relationshipName);
            if (relatedRecord == null) {
                return null;
            }
            return (String)relatedRecord.get(fieldName);
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * @description Checks if a value matches a SQL LIKE pattern.
     * Supports % as wildcard (matches any characters) and _ as single character wildcard.
     * @param value The value to check.
     * @param likePattern The LIKE pattern to match against.
     * @return True if the value matches the pattern.
     */
    @TestVisible
    private static Boolean matchesLikePattern(String value, String likePattern) {
        if (value == null || likePattern == null) {
            return false;
        }

        // Convert SQL LIKE pattern to regex
        // Escape regex special characters except % and _
        String regex = '';
        for (Integer i = 0; i < likePattern.length(); i++) {
            String ch = likePattern.substring(i, i + 1);
            if (ch == '%') {
                regex += '.*';
            } else if (ch == '_') {
                regex += '.';
            } else if ('\\[](){}^$.|*+?'.contains(ch)) {
                regex += '\\' + ch;
            } else {
                regex += ch;
            }
        }

        // Case-insensitive match
        Pattern regexPattern = Pattern.compile('(?i)^' + regex + '$');
        Matcher m = regexPattern.matcher(value);
        return m.matches();
    }
}

