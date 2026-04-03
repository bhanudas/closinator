/**
 * @description Apex controller for the Rule Viewer LWC.
 * Provides read-only access to active Case Status Auto-Closer rules.
 */
public with sharing class util_closer_RuleViewerController {

    @TestVisible
    private static Boolean throwExceptionOnGetRules = false;

    /**
     * @description Returns all active rules as a list of maps with camelCase keys.
     * Wraps util_closer_RuleEngine.getActiveRules() and serializes into a
     * flat structure that avoids custom metadata serialization issues.
     * @return List of maps representing each active rule.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getActiveRules() {
        try {
            if (throwExceptionOnGetRules) {
                throw new CalloutException('Test exception for getActiveRules');
            }

            List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
            List<Map<String, Object>> result = new List<Map<String, Object>>();

            for (util_closer_Case_Status_Rule__mdt rule : rules) {
                Map<String, Object> m = new Map<String, Object>();
                // Core
                m.put('developerName', rule.DeveloperName);
                m.put('label', rule.MasterLabel);
                m.put('executionOrder', rule.Execution_Order__c);
                m.put('sourceStatus', rule.Source_Status__c);
                m.put('targetStatus', rule.Target_Status__c);
                m.put('targetReason', rule.Target_Reason__c);
                m.put('description', rule.Description__c);
                m.put('stopProcessing', rule.Stop_Processing__c);
                // Timing
                m.put('daysSinceLastModified', rule.Days_Since_Last_Modified__c);
                m.put('daysSinceCreated', rule.Days_Since_Created__c);
                m.put('daysSinceLastActivity', rule.Days_Since_Last_Activity__c);
                // Filtering
                m.put('recordTypeDeveloperNames', rule.Record_Type_Developer_Names__c);
                m.put('excludeRecordTypeDeveloperNames', rule.Exclude_Record_Type_Developer_Names__c);
                m.put('origins', rule.Origins__c);
                m.put('ownerNameLike', rule.Owner_Name_Like__c);
                m.put('lastModifiedByNameLike', rule.Last_Modified_By_Name_Like__c);
                m.put('additionalFilterLogic', rule.Additional_Filter_Logic__c);
                // Child Object
                m.put('childObjectApiName', rule.Child_Object_API_Name__c);
                m.put('childLookupField', rule.Child_Lookup_Field__c);
                m.put('childFilterField', rule.Child_Filter_Field__c);
                m.put('childFilterValue', rule.Child_Filter_Value__c);
                m.put('childFilterOperator', rule.Child_Filter_Operator__c);
                m.put('requireChildRecord', rule.Require_Child_Record__c);
                result.add(m);
            }

            return result;
        } catch (Exception ex) {
            String msg = 'Error loading rules: ' + ex.getMessage();
            AuraHandledException e = new AuraHandledException(msg);
            e.setMessage(msg);
            throw e;
        }
    }
}
