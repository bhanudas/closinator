/**
 * @description Service class for handling child record criteria evaluation.
 * Provides methods to extract child criteria from rules, query child records,
 * and evaluate whether Cases match child record criteria.
 */
public with sharing class util_closer_ChildRecordService {

    /**
     * @description Wrapper class to hold child criteria configuration from a rule.
     */
    public class ChildCriteria {
        public String childObjectApiName;
        public String childLookupField;
        public String childFilterField;
        public Set<String> childFilterValues;
        public String childFilterOperator;
        public Boolean requireChildRecord;

        public ChildCriteria(util_closer_Case_Status_Rule__mdt rule) {
            this.childObjectApiName = rule.Child_Object_API_Name__c;
            this.childLookupField = rule.Child_Lookup_Field__c;
            this.childFilterField = rule.Child_Filter_Field__c;
            this.childFilterValues = parseValues(rule.Child_Filter_Value__c);
            this.childFilterOperator = rule.Child_Filter_Operator__c;
            this.requireChildRecord = rule.Require_Child_Record__c == true;
        }

        /**
         * @description Parses semicolon-separated values into a Set.
         */
        private Set<String> parseValues(String valueString) {
            Set<String> values = new Set<String>();
            if (String.isNotBlank(valueString)) {
                for (String value : valueString.split(';')) {
                    String trimmed = value.trim();
                    if (String.isNotBlank(trimmed)) {
                        values.add(trimmed);
                    }
                }
            }
            return values;
        }

        /**
         * @description Returns a unique key for this criteria configuration.
         */
        public String getKey() {
            return childObjectApiName + '|' + childLookupField + '|' + childFilterField;
        }

        /**
         * @description Checks if this criteria is valid and complete.
         */
        public Boolean isValid() {
            return String.isNotBlank(childObjectApiName) &&
                   String.isNotBlank(childLookupField);
        }
    }

    /**
     * @description Extracts unique child criteria configurations from a list of rules.
     * @param rules List of rules to extract child criteria from.
     * @return Map of criteria key to ChildCriteria object.
     */
    public static Map<String, ChildCriteria> getChildCriteriaFromRules(List<util_closer_Case_Status_Rule__mdt> rules) {
        Map<String, ChildCriteria> criteriaMap = new Map<String, ChildCriteria>();

        for (util_closer_Case_Status_Rule__mdt rule : rules) {
            if (ruleHasChildCriteria(rule)) {
                ChildCriteria criteria = new ChildCriteria(rule);
                if (criteria.isValid()) {
                    criteriaMap.put(criteria.getKey(), criteria);
                }
            }
        }

        util_closer_Logger.debug('ChildRecordService', 'Extracted ' + criteriaMap.size() + ' unique child criteria configurations');
        return criteriaMap;
    }

    /**
     * @description Checks if any rules in the list have child criteria configured.
     * @param rules List of rules to check.
     * @return True if at least one rule has child criteria.
     */
    public static Boolean rulesHaveChildCriteria(List<util_closer_Case_Status_Rule__mdt> rules) {
        for (util_closer_Case_Status_Rule__mdt rule : rules) {
            if (ruleHasChildCriteria(rule)) {
                return true;
            }
        }
        return false;
    }

    /**
     * @description Checks if a single rule has child criteria configured.
     * @param rule The rule to check.
     * @return True if the rule has child criteria.
     */
    public static Boolean ruleHasChildCriteria(util_closer_Case_Status_Rule__mdt rule) {
        return String.isNotBlank(rule.Child_Object_API_Name__c) &&
               String.isNotBlank(rule.Child_Lookup_Field__c);
    }

    /**
     * @description Queries child records for all Cases in the scope based on criteria.
     * Uses CaseDataAccess to perform the query without sharing restrictions.
     * @param caseIds Set of Case IDs to query children for.
     * @param criteriaMap Map of criteria configurations to query.
     * @return Map of Case ID to List of child SObjects.
     */
    public static Map<Id, List<SObject>> queryChildRecords(
        Set<Id> caseIds,
        Map<String, ChildCriteria> criteriaMap
    ) {
        Map<Id, List<SObject>> childDataMap = new Map<Id, List<SObject>>();

        if (caseIds == null || caseIds.isEmpty() || criteriaMap == null || criteriaMap.isEmpty()) {
            return childDataMap;
        }

        // Initialize map with empty lists for all Case IDs
        for (Id caseId : caseIds) {
            childDataMap.put(caseId, new List<SObject>());
        }

        // Query child records for each unique criteria configuration
        for (ChildCriteria criteria : criteriaMap.values()) {
            try {
                List<SObject> childRecords = util_closer_CaseDataAccess.queryChildRecords(
                    criteria.childObjectApiName,
                    criteria.childLookupField,
                    criteria.childFilterField,
                    caseIds
                );

                // Group child records by Case ID
                for (SObject child : childRecords) {
                    Id caseId = (Id)child.get(criteria.childLookupField);
                    if (caseId != null && childDataMap.containsKey(caseId)) {
                        childDataMap.get(caseId).add(child);
                    }
                }

                util_closer_Logger.debug('ChildRecordService',
                    'Queried ' + childRecords.size() + ' child records for ' + criteria.childObjectApiName);

            } catch (Exception e) {
                util_closer_Logger.error('ChildRecordService: Error querying child records for ' + criteria.childObjectApiName + ': ' + e.getMessage());
            }
        }

        return childDataMap;
    }

    /**
     * @description Checks if a Case matches the child criteria for a rule.
     * @param caseId The Case ID to evaluate.
     * @param rule The rule with child criteria.
     * @param childRecords List of child records for this Case.
     * @return True if the Case matches the child criteria.
     */
    public static Boolean caseMatchesChildCriteria(
        Id caseId,
        util_closer_Case_Status_Rule__mdt rule,
        List<SObject> childRecords
    ) {
        // If rule has no child criteria, it matches by default
        if (!ruleHasChildCriteria(rule)) {
            return true;
        }

        ChildCriteria criteria = new ChildCriteria(rule);

        // Filter to only child records from the correct object
        List<SObject> relevantChildren = filterChildRecordsByObject(childRecords, criteria.childObjectApiName);

        // If no relevant child records exist
        if (relevantChildren.isEmpty()) {
            // If child record is required, no match
            if (criteria.requireChildRecord) {
                util_closer_Logger.debug('ChildRecordService',
                    'Case ' + caseId + ' has no child records but Require_Child_Record is true');
                return false;
            }
            // If child record is not required and no children exist, match
            return true;
        }

        // Check if any child record matches the filter criteria
        for (SObject child : relevantChildren) {
            if (childRecordMatchesFilter(child, criteria)) {
                util_closer_Logger.debug('ChildRecordService',
                    'Case ' + caseId + ' has matching child record');
                return true;
            }
        }

        // No matching child records found
        util_closer_Logger.debug('ChildRecordService',
            'Case ' + caseId + ' has ' + relevantChildren.size() + ' child records but none match criteria');
        return false;
    }

    /**
     * @description Filters child records to only include those from the specified object.
     * @param childRecords List of all child records.
     * @param objectApiName The object API name to filter by.
     * @return List of child records from the specified object.
     */
    @TestVisible
    private static List<SObject> filterChildRecordsByObject(List<SObject> childRecords, String objectApiName) {
        List<SObject> filtered = new List<SObject>();
        if (childRecords == null || String.isBlank(objectApiName)) {
            return filtered;
        }

        for (SObject child : childRecords) {
            String childObjectName = child.getSObjectType().getDescribe().getName();
            if (childObjectName.equalsIgnoreCase(objectApiName)) {
                filtered.add(child);
            }
        }
        return filtered;
    }

    /**
     * @description Checks if a single child record matches the filter criteria.
     * @param child The child record to evaluate.
     * @param criteria The criteria to match against.
     * @return True if the child record matches.
     */
    @TestVisible
    private static Boolean childRecordMatchesFilter(SObject child, ChildCriteria criteria) {
        // If no filter field specified, any child record matches
        if (String.isBlank(criteria.childFilterField)) {
            return true;
        }

        Object fieldValue;
        try {
            fieldValue = child.get(criteria.childFilterField);
        } catch (SObjectException e) {
            util_closer_Logger.error('ChildRecordService: Field ' + criteria.childFilterField + ' not found on child record: ' + e.getMessage());
            return false;
        }

        String operator = String.isNotBlank(criteria.childFilterOperator) ? criteria.childFilterOperator : 'Equals';
        String fieldValueStr = fieldValue != null ? String.valueOf(fieldValue) : null;

        switch on operator {
            when 'Equals' {
                return fieldValueStr != null && criteria.childFilterValues.contains(fieldValueStr);
            }
            when 'Not Equals' {
                return fieldValueStr == null || !criteria.childFilterValues.contains(fieldValueStr);
            }
            when 'Contains' {
                if (fieldValueStr == null) {
                    return false;
                }
                for (String filterValue : criteria.childFilterValues) {
                    if (fieldValueStr.containsIgnoreCase(filterValue)) {
                        return true;
                    }
                }
                return false;
            }
            when 'Is Null' {
                return fieldValue == null;
            }
            when 'Is Not Null' {
                return fieldValue != null;
            }
            when else {
                // Default to Equals behavior
                return fieldValueStr != null && criteria.childFilterValues.contains(fieldValueStr);
            }
        }
    }
}
