/**
 * @description Test class for util_closer_ChildRecordService.
 * Tests child criteria extraction, child record queries, and criteria matching.
 */
@isTest
private class util_closer_ChildRecordService_Test {

    @TestSetup
    static void setup() {
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        // Create test cases
        List<Case> testCases = new List<Case>();
        testCases.add(new Case(Subject = 'Test Case 1', Status = 'New', Origin = 'Web'));
        testCases.add(new Case(Subject = 'Test Case 2', Status = 'New', Origin = 'Web'));
        insert testCases;
    }

    @isTest
    static void testChildCriteria_Constructor() {
        // Setup - create a mock rule with child criteria
        util_closer_Case_Status_Rule__mdt rule = createMockRuleWithChildCriteria();

        // Execute
        Test.startTest();
        util_closer_ChildRecordService.ChildCriteria criteria =
            new util_closer_ChildRecordService.ChildCriteria(rule);
        Test.stopTest();

        // Verify
        System.assertEquals('CaseComment', criteria.childObjectApiName, 'Child object should be set');
        System.assertEquals('ParentId', criteria.childLookupField, 'Lookup field should be set');
        System.assertEquals('CommentBody', criteria.childFilterField, 'Filter field should be set');
        System.assert(criteria.childFilterValues.contains('TestValue'), 'Filter values should be parsed');
        System.assertEquals('Equals', criteria.childFilterOperator, 'Operator should be set');
        System.assertEquals(true, criteria.requireChildRecord, 'Require flag should be set');
    }

    @isTest
    static void testChildCriteria_IsValid() {
        // Setup - valid criteria
        util_closer_Case_Status_Rule__mdt validRule = createMockRuleWithChildCriteria();

        // Execute
        Test.startTest();
        util_closer_ChildRecordService.ChildCriteria validCriteria =
            new util_closer_ChildRecordService.ChildCriteria(validRule);
        Test.stopTest();

        // Verify
        System.assertEquals(true, validCriteria.isValid(), 'Valid criteria should return true');
    }

    @isTest
    static void testChildCriteria_IsValid_Missing() {
        // Setup - invalid criteria (missing fields)
        util_closer_Case_Status_Rule__mdt invalidRule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Test_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed'
        );

        // Execute
        Test.startTest();
        util_closer_ChildRecordService.ChildCriteria invalidCriteria =
            new util_closer_ChildRecordService.ChildCriteria(invalidRule);
        Test.stopTest();

        // Verify
        System.assertEquals(false, invalidCriteria.isValid(), 'Invalid criteria should return false');
    }

    @isTest
    static void testChildCriteria_GetKey() {
        // Setup
        util_closer_Case_Status_Rule__mdt rule = createMockRuleWithChildCriteria();

        // Execute
        Test.startTest();
        util_closer_ChildRecordService.ChildCriteria criteria =
            new util_closer_ChildRecordService.ChildCriteria(rule);
        String key = criteria.getKey();
        Test.stopTest();

        // Verify
        System.assertEquals('CaseComment|ParentId|CommentBody', key, 'Key should be formatted correctly');
    }

    @isTest
    static void testChildCriteria_ParseMultipleValues() {
        // Setup - rule with multiple filter values
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Test_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Child_Object_API_Name__c = 'CaseComment',
            Child_Lookup_Field__c = 'ParentId',
            Child_Filter_Field__c = 'CommentBody',
            Child_Filter_Value__c = 'Value1;Value2;Value3',
            Child_Filter_Operator__c = 'Equals'
        );

        // Execute
        Test.startTest();
        util_closer_ChildRecordService.ChildCriteria criteria =
            new util_closer_ChildRecordService.ChildCriteria(rule);
        Test.stopTest();

        // Verify
        System.assertEquals(3, criteria.childFilterValues.size(), 'Should parse 3 values');
        System.assert(criteria.childFilterValues.contains('Value1'), 'Should contain Value1');
        System.assert(criteria.childFilterValues.contains('Value2'), 'Should contain Value2');
        System.assert(criteria.childFilterValues.contains('Value3'), 'Should contain Value3');
    }

    @isTest
    static void testGetChildCriteriaFromRules_WithCriteria() {
        // Setup
        List<util_closer_Case_Status_Rule__mdt> rules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRuleWithChildCriteria()
        };

        // Execute
        Test.startTest();
        Map<String, util_closer_ChildRecordService.ChildCriteria> criteriaMap =
            util_closer_ChildRecordService.getChildCriteriaFromRules(rules);
        Test.stopTest();

        // Verify
        System.assertEquals(1, criteriaMap.size(), 'Should extract 1 criteria');
    }

    @isTest
    static void testGetChildCriteriaFromRules_NoCriteria() {
        // Setup - rules without child criteria
        List<util_closer_Case_Status_Rule__mdt> rules = new List<util_closer_Case_Status_Rule__mdt>{
            new util_closer_Case_Status_Rule__mdt(
                DeveloperName = 'Test_Rule',
                Is_Active__c = true,
                Source_Status__c = 'New',
                Target_Status__c = 'Closed'
            )
        };

        // Execute
        Test.startTest();
        Map<String, util_closer_ChildRecordService.ChildCriteria> criteriaMap =
            util_closer_ChildRecordService.getChildCriteriaFromRules(rules);
        Test.stopTest();

        // Verify
        System.assertEquals(0, criteriaMap.size(), 'Should extract 0 criteria');
    }

    @isTest
    static void testRulesHaveChildCriteria_True() {
        // Setup
        List<util_closer_Case_Status_Rule__mdt> rules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRuleWithChildCriteria()
        };

        // Execute
        Test.startTest();
        Boolean result = util_closer_ChildRecordService.rulesHaveChildCriteria(rules);
        Test.stopTest();

        // Verify
        System.assertEquals(true, result, 'Should return true when rules have child criteria');
    }

    @isTest
    static void testRulesHaveChildCriteria_False() {
        // Setup - rules without child criteria
        List<util_closer_Case_Status_Rule__mdt> rules = new List<util_closer_Case_Status_Rule__mdt>{
            new util_closer_Case_Status_Rule__mdt(
                DeveloperName = 'Test_Rule',
                Is_Active__c = true,
                Source_Status__c = 'New',
                Target_Status__c = 'Closed'
            )
        };

        // Execute
        Test.startTest();
        Boolean result = util_closer_ChildRecordService.rulesHaveChildCriteria(rules);
        Test.stopTest();

        // Verify
        System.assertEquals(false, result, 'Should return false when no rules have child criteria');
    }

    @isTest
    static void testRuleHasChildCriteria_True() {
        // Setup
        util_closer_Case_Status_Rule__mdt rule = createMockRuleWithChildCriteria();

        // Execute
        Test.startTest();
        Boolean result = util_closer_ChildRecordService.ruleHasChildCriteria(rule);
        Test.stopTest();

        // Verify
        System.assertEquals(true, result, 'Should return true for rule with child criteria');
    }

    @isTest
    static void testRuleHasChildCriteria_False() {
        // Setup
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Test_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed'
        );

        // Execute
        Test.startTest();
        Boolean result = util_closer_ChildRecordService.ruleHasChildCriteria(rule);
        Test.stopTest();

        // Verify
        System.assertEquals(false, result, 'Should return false for rule without child criteria');
    }

    @isTest
    static void testQueryChildRecords_WithValidData() {
        // Setup
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        CaseComment comment = new CaseComment(
            ParentId = testCase.Id,
            CommentBody = 'TestValue'
        );
        insert comment;

        Set<Id> caseIds = new Set<Id>{ testCase.Id };
        Map<String, util_closer_ChildRecordService.ChildCriteria> criteriaMap =
            new Map<String, util_closer_ChildRecordService.ChildCriteria>();

        util_closer_Case_Status_Rule__mdt rule = createMockRuleWithChildCriteria();
        util_closer_ChildRecordService.ChildCriteria criteria =
            new util_closer_ChildRecordService.ChildCriteria(rule);
        criteriaMap.put(criteria.getKey(), criteria);

        // Execute
        Test.startTest();
        Map<Id, List<SObject>> childDataMap =
            util_closer_ChildRecordService.queryChildRecords(caseIds, criteriaMap);
        Test.stopTest();

        // Verify
        System.assert(childDataMap.containsKey(testCase.Id), 'Should contain case ID');
        System.assertEquals(1, childDataMap.get(testCase.Id).size(), 'Should have 1 child record');
    }

    @isTest
    static void testQueryChildRecords_EmptyCaseIds() {
        // Setup
        Map<String, util_closer_ChildRecordService.ChildCriteria> criteriaMap =
            new Map<String, util_closer_ChildRecordService.ChildCriteria>();
        criteriaMap.put('test', new util_closer_ChildRecordService.ChildCriteria(createMockRuleWithChildCriteria()));

        // Execute
        Test.startTest();
        Map<Id, List<SObject>> childDataMap =
            util_closer_ChildRecordService.queryChildRecords(new Set<Id>(), criteriaMap);
        Test.stopTest();

        // Verify
        System.assertEquals(0, childDataMap.size(), 'Should return empty map for empty case IDs');
    }

    @isTest
    static void testQueryChildRecords_NullCriteriaMap() {
        // Setup
        Set<Id> caseIds = new Set<Id>{ '500000000000000AAA' };

        // Execute
        Test.startTest();
        Map<Id, List<SObject>> childDataMap =
            util_closer_ChildRecordService.queryChildRecords(caseIds, null);
        Test.stopTest();

        // Verify
        System.assertEquals(0, childDataMap.size(), 'Should return empty map for null criteria');
    }

    @isTest
    static void testCaseMatchesChildCriteria_NoChildCriteria() {
        // Setup - rule without child criteria
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Test_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed'
        );

        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Execute
        Test.startTest();
        Boolean result = util_closer_ChildRecordService.caseMatchesChildCriteria(
            testCase.Id, rule, new List<SObject>()
        );
        Test.stopTest();

        // Verify
        System.assertEquals(true, result, 'Should match when no child criteria defined');
    }

    @isTest
    static void testCaseMatchesChildCriteria_RequiredButNoChildren() {
        // Setup - rule requiring child record
        util_closer_Case_Status_Rule__mdt rule = createMockRuleWithChildCriteria();
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Execute - no child records
        Test.startTest();
        Boolean result = util_closer_ChildRecordService.caseMatchesChildCriteria(
            testCase.Id, rule, new List<SObject>()
        );
        Test.stopTest();

        // Verify
        System.assertEquals(false, result, 'Should not match when child required but none exist');
    }

    @isTest
    static void testCaseMatchesChildCriteria_NotRequiredNoChildren() {
        // Setup - rule not requiring child record
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Test_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Child_Object_API_Name__c = 'CaseComment',
            Child_Lookup_Field__c = 'ParentId',
            Child_Filter_Field__c = 'CommentBody',
            Child_Filter_Value__c = 'TestValue',
            Child_Filter_Operator__c = 'Equals',
            Require_Child_Record__c = false
        );

        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Execute
        Test.startTest();
        Boolean result = util_closer_ChildRecordService.caseMatchesChildCriteria(
            testCase.Id, rule, new List<SObject>()
        );
        Test.stopTest();

        // Verify
        System.assertEquals(true, result, 'Should match when child not required and none exist');
    }

    @isTest
    static void testCaseMatchesChildCriteria_MatchingChild() {
        // Setup
        util_closer_Case_Status_Rule__mdt rule = createMockRuleWithChildCriteria();
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        CaseComment comment = new CaseComment(
            ParentId = testCase.Id,
            CommentBody = 'TestValue'
        );
        insert comment;

        // Query the comment
        List<SObject> childRecords = [SELECT Id, ParentId, CommentBody FROM CaseComment WHERE ParentId = :testCase.Id];

        // Execute
        Test.startTest();
        Boolean result = util_closer_ChildRecordService.caseMatchesChildCriteria(
            testCase.Id, rule, childRecords
        );
        Test.stopTest();

        // Verify
        System.assertEquals(true, result, 'Should match when child meets criteria');
    }

    @isTest
    static void testCaseMatchesChildCriteria_NonMatchingChild() {
        // Setup
        util_closer_Case_Status_Rule__mdt rule = createMockRuleWithChildCriteria();
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        CaseComment comment = new CaseComment(
            ParentId = testCase.Id,
            CommentBody = 'DifferentValue'
        );
        insert comment;

        List<SObject> childRecords = [SELECT Id, ParentId, CommentBody FROM CaseComment WHERE ParentId = :testCase.Id];

        // Execute
        Test.startTest();
        Boolean result = util_closer_ChildRecordService.caseMatchesChildCriteria(
            testCase.Id, rule, childRecords
        );
        Test.stopTest();

        // Verify
        System.assertEquals(false, result, 'Should not match when child does not meet criteria');
    }

    @isTest
    static void testFilterChildRecordsByObject() {
        // Setup
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        CaseComment comment = new CaseComment(
            ParentId = testCase.Id,
            CommentBody = 'Test'
        );
        insert comment;

        List<SObject> childRecords = [SELECT Id, ParentId, CommentBody FROM CaseComment WHERE ParentId = :testCase.Id];

        // Execute
        Test.startTest();
        List<SObject> filtered = util_closer_ChildRecordService.filterChildRecordsByObject(childRecords, 'CaseComment');
        Test.stopTest();

        // Verify
        System.assertEquals(1, filtered.size(), 'Should return matching records');
    }

    @isTest
    static void testFilterChildRecordsByObject_NoMatch() {
        // Setup
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        CaseComment comment = new CaseComment(
            ParentId = testCase.Id,
            CommentBody = 'Test'
        );
        insert comment;

        List<SObject> childRecords = [SELECT Id, ParentId, CommentBody FROM CaseComment WHERE ParentId = :testCase.Id];

        // Execute
        Test.startTest();
        List<SObject> filtered = util_closer_ChildRecordService.filterChildRecordsByObject(childRecords, 'NonExistentObject');
        Test.stopTest();

        // Verify
        System.assertEquals(0, filtered.size(), 'Should return empty list for non-matching object');
    }

    @isTest
    static void testFilterChildRecordsByObject_NullInputs() {
        // Execute
        Test.startTest();
        List<SObject> filtered1 = util_closer_ChildRecordService.filterChildRecordsByObject(null, 'CaseComment');
        List<SObject> filtered2 = util_closer_ChildRecordService.filterChildRecordsByObject(new List<SObject>(), null);
        Test.stopTest();

        // Verify
        System.assertEquals(0, filtered1.size(), 'Should return empty list for null records');
        System.assertEquals(0, filtered2.size(), 'Should return empty list for null object name');
    }

    @isTest
    static void testChildRecordMatchesFilter_Equals() {
        // Setup
        util_closer_Case_Status_Rule__mdt rule = createMockRuleWithChildCriteria();
        util_closer_ChildRecordService.ChildCriteria criteria =
            new util_closer_ChildRecordService.ChildCriteria(rule);

        Case testCase = [SELECT Id FROM Case LIMIT 1];
        CaseComment comment = new CaseComment(
            ParentId = testCase.Id,
            CommentBody = 'TestValue'
        );
        insert comment;
        comment = [SELECT Id, ParentId, CommentBody FROM CaseComment WHERE Id = :comment.Id];

        // Execute
        Test.startTest();
        Boolean result = util_closer_ChildRecordService.childRecordMatchesFilter(comment, criteria);
        Test.stopTest();

        // Verify
        System.assertEquals(true, result, 'Should match with Equals operator');
    }

    @isTest
    static void testChildRecordMatchesFilter_NotEquals() {
        // Setup
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Test_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Child_Object_API_Name__c = 'CaseComment',
            Child_Lookup_Field__c = 'ParentId',
            Child_Filter_Field__c = 'CommentBody',
            Child_Filter_Value__c = 'TestValue',
            Child_Filter_Operator__c = 'Not Equals'
        );
        util_closer_ChildRecordService.ChildCriteria criteria =
            new util_closer_ChildRecordService.ChildCriteria(rule);

        Case testCase = [SELECT Id FROM Case LIMIT 1];
        CaseComment comment = new CaseComment(
            ParentId = testCase.Id,
            CommentBody = 'DifferentValue'
        );
        insert comment;
        comment = [SELECT Id, ParentId, CommentBody FROM CaseComment WHERE Id = :comment.Id];

        // Execute
        Test.startTest();
        Boolean result = util_closer_ChildRecordService.childRecordMatchesFilter(comment, criteria);
        Test.stopTest();

        // Verify
        System.assertEquals(true, result, 'Should match with Not Equals operator');
    }

    @isTest
    static void testChildRecordMatchesFilter_Contains() {
        // Setup
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Test_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Child_Object_API_Name__c = 'CaseComment',
            Child_Lookup_Field__c = 'ParentId',
            Child_Filter_Field__c = 'CommentBody',
            Child_Filter_Value__c = 'Test',
            Child_Filter_Operator__c = 'Contains'
        );
        util_closer_ChildRecordService.ChildCriteria criteria =
            new util_closer_ChildRecordService.ChildCriteria(rule);

        Case testCase = [SELECT Id FROM Case LIMIT 1];
        CaseComment comment = new CaseComment(
            ParentId = testCase.Id,
            CommentBody = 'This is a Test comment'
        );
        insert comment;
        comment = [SELECT Id, ParentId, CommentBody FROM CaseComment WHERE Id = :comment.Id];

        // Execute
        Test.startTest();
        Boolean result = util_closer_ChildRecordService.childRecordMatchesFilter(comment, criteria);
        Test.stopTest();

        // Verify
        System.assertEquals(true, result, 'Should match with Contains operator');
    }

    @isTest
    static void testChildRecordMatchesFilter_IsNull() {
        // Setup
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Test_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Child_Object_API_Name__c = 'CaseComment',
            Child_Lookup_Field__c = 'ParentId',
            Child_Filter_Field__c = 'CommentBody',
            Child_Filter_Operator__c = 'Is Null'
        );
        util_closer_ChildRecordService.ChildCriteria criteria =
            new util_closer_ChildRecordService.ChildCriteria(rule);

        // Create a mock SObject with null field
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        // Note: CaseComment requires CommentBody, so we use a different approach
        // We'll test the logic with a non-null value and verify it returns false
        CaseComment comment = new CaseComment(
            ParentId = testCase.Id,
            CommentBody = 'NotNull'
        );
        insert comment;
        comment = [SELECT Id, ParentId, CommentBody FROM CaseComment WHERE Id = :comment.Id];

        // Execute
        Test.startTest();
        Boolean result = util_closer_ChildRecordService.childRecordMatchesFilter(comment, criteria);
        Test.stopTest();

        // Verify - CommentBody is not null, so Is Null should return false
        System.assertEquals(false, result, 'Should not match with Is Null when field has value');
    }

    @isTest
    static void testChildRecordMatchesFilter_IsNotNull() {
        // Setup
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Test_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Child_Object_API_Name__c = 'CaseComment',
            Child_Lookup_Field__c = 'ParentId',
            Child_Filter_Field__c = 'CommentBody',
            Child_Filter_Operator__c = 'Is Not Null'
        );
        util_closer_ChildRecordService.ChildCriteria criteria =
            new util_closer_ChildRecordService.ChildCriteria(rule);

        Case testCase = [SELECT Id FROM Case LIMIT 1];
        CaseComment comment = new CaseComment(
            ParentId = testCase.Id,
            CommentBody = 'SomeValue'
        );
        insert comment;
        comment = [SELECT Id, ParentId, CommentBody FROM CaseComment WHERE Id = :comment.Id];

        // Execute
        Test.startTest();
        Boolean result = util_closer_ChildRecordService.childRecordMatchesFilter(comment, criteria);
        Test.stopTest();

        // Verify
        System.assertEquals(true, result, 'Should match with Is Not Null when field has value');
    }

    @isTest
    static void testChildRecordMatchesFilter_NoFilterField() {
        // Setup - no filter field means any child matches
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Test_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Child_Object_API_Name__c = 'CaseComment',
            Child_Lookup_Field__c = 'ParentId',
            Require_Child_Record__c = true
        );
        util_closer_ChildRecordService.ChildCriteria criteria =
            new util_closer_ChildRecordService.ChildCriteria(rule);

        Case testCase = [SELECT Id FROM Case LIMIT 1];
        CaseComment comment = new CaseComment(
            ParentId = testCase.Id,
            CommentBody = 'AnyValue'
        );
        insert comment;
        comment = [SELECT Id, ParentId, CommentBody FROM CaseComment WHERE Id = :comment.Id];

        // Execute
        Test.startTest();
        Boolean result = util_closer_ChildRecordService.childRecordMatchesFilter(comment, criteria);
        Test.stopTest();

        // Verify
        System.assertEquals(true, result, 'Should match when no filter field specified');
    }

    @isTest
    static void testChildRecordMatchesFilter_DefaultOperator() {
        // Setup - unknown operator should default to Equals
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Test_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Child_Object_API_Name__c = 'CaseComment',
            Child_Lookup_Field__c = 'ParentId',
            Child_Filter_Field__c = 'CommentBody',
            Child_Filter_Value__c = 'TestValue',
            Child_Filter_Operator__c = 'Unknown'
        );
        util_closer_ChildRecordService.ChildCriteria criteria =
            new util_closer_ChildRecordService.ChildCriteria(rule);

        Case testCase = [SELECT Id FROM Case LIMIT 1];
        CaseComment comment = new CaseComment(
            ParentId = testCase.Id,
            CommentBody = 'TestValue'
        );
        insert comment;
        comment = [SELECT Id, ParentId, CommentBody FROM CaseComment WHERE Id = :comment.Id];

        // Execute
        Test.startTest();
        Boolean result = util_closer_ChildRecordService.childRecordMatchesFilter(comment, criteria);
        Test.stopTest();

        // Verify
        System.assertEquals(true, result, 'Unknown operator should default to Equals');
    }

    // Helper method to create mock rule with child criteria
    private static util_closer_Case_Status_Rule__mdt createMockRuleWithChildCriteria() {
        return new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Test_Rule_With_Child',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Child_Object_API_Name__c = 'CaseComment',
            Child_Lookup_Field__c = 'ParentId',
            Child_Filter_Field__c = 'CommentBody',
            Child_Filter_Value__c = 'TestValue',
            Child_Filter_Operator__c = 'Equals',
            Require_Child_Record__c = true
        );
    }
}
