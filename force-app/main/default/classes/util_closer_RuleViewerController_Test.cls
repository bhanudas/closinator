/**
 * @description Test class for util_closer_RuleViewerController.
 * Tests the getActiveRules Aura-enabled method with mock rule injection.
 */
@isTest
private class util_closer_RuleViewerController_Test {

    /**
     * @description Helper to create a mock rule with all fields populated.
     */
    private static util_closer_Case_Status_Rule__mdt createFullMockRule(
        String developerName,
        Integer executionOrder
    ) {
        return new util_closer_Case_Status_Rule__mdt(
            DeveloperName = developerName,
            MasterLabel = developerName.replace('_', ' '),
            Is_Active__c = true,
            Execution_Order__c = executionOrder,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Target_Reason__c = 'Auto-closed',
            Description__c = 'Test rule description',
            Stop_Processing__c = false,
            Days_Since_Last_Modified__c = 30,
            Days_Since_Created__c = 60,
            Days_Since_Last_Activity__c = 14,
            Record_Type_Developer_Names__c = 'Support',
            Exclude_Record_Type_Developer_Names__c = 'Internal',
            Origins__c = 'Web;Email',
            Owner_Name_Like__c = '%Support%',
            Last_Modified_By_Name_Like__c = '%Auto%',
            Additional_Filter_Logic__c = 'Status != Escalated',
            Child_Object_API_Name__c = 'UJET__UJET_Session__c',
            Child_Lookup_Field__c = 'Case__c',
            Child_Filter_Field__c = 'UJET__Status__c',
            Child_Filter_Value__c = 'Finished',
            Child_Filter_Operator__c = 'Equals',
            Require_Child_Record__c = true
        );
    }

    /**
     * @description Helper to create a minimal mock rule with only required fields.
     */
    private static util_closer_Case_Status_Rule__mdt createMinimalMockRule(
        String developerName,
        Integer executionOrder
    ) {
        return new util_closer_Case_Status_Rule__mdt(
            DeveloperName = developerName,
            MasterLabel = developerName,
            Is_Active__c = true,
            Execution_Order__c = executionOrder,
            Source_Status__c = 'Open',
            Target_Status__c = 'Closed'
        );
    }

    @isTest
    static void testGetActiveRules_ReturnsMappedData() {
        // Setup
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createFullMockRule('Stale_Cases', 1),
            createFullMockRule('Abandoned_Calls', 2)
        };

        // Execute
        Test.startTest();
        List<Map<String, Object>> result = util_closer_RuleViewerController.getActiveRules();
        Test.stopTest();

        // Verify
        System.assertEquals(2, result.size(), 'Should return 2 rules');

        Map<String, Object> first = result[0];
        System.assertEquals('Stale_Cases', first.get('developerName'), 'Developer name should match');
        System.assertEquals('Stale Cases', first.get('label'), 'Label should match');
        System.assertEquals(1, (Decimal) first.get('executionOrder'), 'Execution order should match');
        System.assertEquals('New', first.get('sourceStatus'), 'Source status should match');
        System.assertEquals('Closed', first.get('targetStatus'), 'Target status should match');
        System.assertEquals('Auto-closed', first.get('targetReason'), 'Target reason should match');

        // Cleanup
        util_closer_RuleEngine.mockRules = null;
    }

    @isTest
    static void testGetActiveRules_EmptyRules() {
        // Setup
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>();

        // Execute
        Test.startTest();
        List<Map<String, Object>> result = util_closer_RuleViewerController.getActiveRules();
        Test.stopTest();

        // Verify
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Should return empty list');

        // Cleanup
        util_closer_RuleEngine.mockRules = null;
    }

    @isTest
    static void testGetActiveRules_ForcedException() {
        // Setup
        util_closer_RuleViewerController.throwExceptionOnGetRules = true;

        // Execute
        Test.startTest();
        Boolean exceptionThrown = false;
        String exceptionMessage = '';
        try {
            util_closer_RuleViewerController.getActiveRules();
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
            exceptionMessage = ex.getMessage();
        }
        Test.stopTest();

        // Reset
        util_closer_RuleViewerController.throwExceptionOnGetRules = false;

        // Verify
        System.assertEquals(true, exceptionThrown, 'Should throw AuraHandledException');
        System.assert(exceptionMessage.containsIgnoreCase('Error loading rules'),
            'Should have proper error message. Got: ' + exceptionMessage);
    }

    @isTest
    static void testGetActiveRules_NullFields() {
        // Setup -- minimal rule with most fields null
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMinimalMockRule('Minimal_Rule', 1)
        };

        // Execute
        Test.startTest();
        List<Map<String, Object>> result = util_closer_RuleViewerController.getActiveRules();
        Test.stopTest();

        // Verify -- should not throw, null fields map to null values
        System.assertEquals(1, result.size(), 'Should return 1 rule');
        Map<String, Object> rule = result[0];
        System.assertEquals('Minimal_Rule', rule.get('developerName'), 'Developer name should match');
        System.assertEquals(null, rule.get('targetReason'), 'Null field should map to null');
        System.assertEquals(null, rule.get('description'), 'Null field should map to null');
        System.assertEquals(null, rule.get('daysSinceLastModified'), 'Null field should map to null');
        System.assertEquals(null, rule.get('childObjectApiName'), 'Null field should map to null');

        // Cleanup
        util_closer_RuleEngine.mockRules = null;
    }

    @isTest
    static void testGetActiveRules_VerifyAllFieldMapping() {
        // Setup -- full rule with every field populated
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createFullMockRule('Full_Rule', 5)
        };

        // Execute
        Test.startTest();
        List<Map<String, Object>> result = util_closer_RuleViewerController.getActiveRules();
        Test.stopTest();

        // Verify every mapped field
        System.assertEquals(1, result.size(), 'Should return 1 rule');
        Map<String, Object> r = result[0];

        // Core
        System.assertEquals('Full_Rule', r.get('developerName'));
        System.assertEquals('Full Rule', r.get('label'));
        System.assertEquals(5, (Decimal) r.get('executionOrder'));
        System.assertEquals('New', r.get('sourceStatus'));
        System.assertEquals('Closed', r.get('targetStatus'));
        System.assertEquals('Auto-closed', r.get('targetReason'));
        System.assertEquals('Test rule description', r.get('description'));
        System.assertEquals(false, r.get('stopProcessing'));

        // Timing
        System.assertEquals(30, (Decimal) r.get('daysSinceLastModified'));
        System.assertEquals(60, (Decimal) r.get('daysSinceCreated'));
        System.assertEquals(14, (Decimal) r.get('daysSinceLastActivity'));

        // Filtering
        System.assertEquals('Support', r.get('recordTypeDeveloperNames'));
        System.assertEquals('Internal', r.get('excludeRecordTypeDeveloperNames'));
        System.assertEquals('Web;Email', r.get('origins'));
        System.assertEquals('%Support%', r.get('ownerNameLike'));
        System.assertEquals('%Auto%', r.get('lastModifiedByNameLike'));
        System.assertEquals('Status != Escalated', r.get('additionalFilterLogic'));

        // Child Object
        System.assertEquals('UJET__UJET_Session__c', r.get('childObjectApiName'));
        System.assertEquals('Case__c', r.get('childLookupField'));
        System.assertEquals('UJET__Status__c', r.get('childFilterField'));
        System.assertEquals('Finished', r.get('childFilterValue'));
        System.assertEquals('Equals', r.get('childFilterOperator'));
        System.assertEquals(true, r.get('requireChildRecord'));

        // Cleanup
        util_closer_RuleEngine.mockRules = null;
    }
}
