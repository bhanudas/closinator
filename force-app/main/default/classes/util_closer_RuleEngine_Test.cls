/**
 * @description Test class for util_closer_RuleEngine.
 * Tests rule retrieval, query building, and case evaluation.
 * Uses dependency injection via mockRules for deterministic testing.
 */
@isTest
private class util_closer_RuleEngine_Test {

    @TestSetup
    static void setup() {
        // Setup mock settings to enable debug mode for logging
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
    }

    /**
     * @description Helper method to create a mock rule with common defaults.
     */
    private static util_closer_Case_Status_Rule__mdt createMockRule(
        String developerName,
        String sourceStatus,
        String targetStatus,
        Integer executionOrder
    ) {
        return new util_closer_Case_Status_Rule__mdt(
            DeveloperName = developerName,
            MasterLabel = developerName,
            Is_Active__c = true,
            Source_Status__c = sourceStatus,
            Target_Status__c = targetStatus,
            Execution_Order__c = executionOrder
        );
    }

    /**
     * @description Reset mockRules after each test to avoid interference.
     */
    private static void resetMockRules() {
        util_closer_RuleEngine.mockRules = null;
    }

    @isTest
    static void testGetActiveRules_ReturnsMockRules() {
        // Setup - set mock rules
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Rule_1', 'New', 'Closed', 1),
            createMockRule('Rule_2', 'Open', 'Closed', 2)
        };

        // Execute
        Test.startTest();
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
        Test.stopTest();

        // Verify
        System.assertEquals(2, rules.size(), 'Should return 2 mock rules');
        System.assertEquals('Rule_1', rules[0].DeveloperName, 'First rule should be Rule_1');
        System.assertEquals('Rule_2', rules[1].DeveloperName, 'Second rule should be Rule_2');

        resetMockRules();
    }

    @isTest
    static void testGetActiveRules_ReturnsOrderedRules() {
        // Setup - mock rules with specific execution order
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Rule_First', 'New', 'Closed', 1),
            createMockRule('Rule_Second', 'Open', 'Closed', 2),
            createMockRule('Rule_Third', 'Pending', 'Closed', 3)
        };

        // Execute
        Test.startTest();
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
        Test.stopTest();

        // Verify - rules should be ordered by Execution_Order__c
        System.assertEquals(3, rules.size(), 'Should return 3 rules');
        for (Integer i = 1; i < rules.size(); i++) {
            System.assert(
                rules[i].Execution_Order__c >= rules[i-1].Execution_Order__c,
                'Rules should be ordered by Execution_Order__c'
            );
        }

        resetMockRules();
    }

    @isTest
    static void testGetActiveRules_WithNullMockRules_QueriesMetadata() {
        // Setup - ensure mockRules is null
        util_closer_RuleEngine.mockRules = null;

        // Execute - should query actual metadata
        Test.startTest();
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
        Test.stopTest();

        // Verify - should not be null (may be empty if no metadata deployed)
        System.assertNotEquals(null, rules, 'Rules should not be null');
        // All returned rules should be active
        for (util_closer_Case_Status_Rule__mdt rule : rules) {
            System.assertEquals(true, rule.Is_Active__c, 'All returned rules should be active');
        }
    }

    @isTest
    static void testBuildBatchQuery_CombinesActiveRules() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Rule_1', 'New', 'Closed', 1),
            createMockRule('Rule_2', 'Open;Pending', 'Closed', 2)
        };

        // Execute
        Test.startTest();
        String query = util_closer_RuleEngine.buildBatchQuery();
        Test.stopTest();

        // Verify
        System.assertNotEquals(null, query, 'Query should not be null');
        System.assert(query.containsIgnoreCase('SELECT'), 'Query should contain SELECT');
        System.assert(query.containsIgnoreCase('FROM Case'), 'Query should contain FROM Case');
        System.assert(query.containsIgnoreCase('IsClosed = false'), 'Query should filter closed cases');

        resetMockRules();
    }

    @isTest
    static void testGetAllSourceStatuses_ReturnsStatusSet() {
        // Setup
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Rule_1', 'New;Open', 'Closed', 1),
            createMockRule('Rule_2', 'Pending', 'Closed', 2)
        };

        // Execute
        Test.startTest();
        Set<String> statuses = util_closer_RuleEngine.getAllSourceStatuses();
        Test.stopTest();

        // Verify
        System.assertEquals(3, statuses.size(), 'Should have 3 unique statuses');
        System.assert(statuses.contains('New'), 'Should contain New');
        System.assert(statuses.contains('Open'), 'Should contain Open');
        System.assert(statuses.contains('Pending'), 'Should contain Pending');

        resetMockRules();
    }

    @isTest
    static void testEvaluateCases_NoMatch() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Rule_1', 'New', 'Closed', 1)
        };

        // Create a case with a status that doesn't match any rules
        Case testCase = new Case(
            Subject = 'Test Case',
            Status = 'Working',
            Origin = 'Web'
        );
        insert testCase;

        // Reload with all fields
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
        Test.stopTest();

        // Verify - no changes expected for 'Working' status
        System.assertEquals(0, changes.size(), 'No changes expected for non-matching case');

        resetMockRules();
    }

    @isTest
    static void testEvaluateCases_WithEmptyList() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Rule_1', 'New', 'Closed', 1)
        };
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>(), rules);
        Test.stopTest();

        // Verify
        System.assertEquals(0, changes.size(), 'Empty case list should return empty map');

        resetMockRules();
    }

    @isTest
    static void testEvaluateCases_MatchingCase() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Rule_1', 'New', 'Closed', 1)
        };

        // Create a case with matching status
        Case testCase = new Case(
            Subject = 'Test Matching Case',
            Status = 'New',
            Origin = 'Web'
        );
        insert testCase;

        // Reload with all fields
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
        Test.stopTest();

        // Verify - case should match rule
        System.assertEquals(1, changes.size(), 'Should have 1 change');
        System.assertEquals('Closed', changes.get(testCase.Id).newStatus, 'Status should change to Closed');

        resetMockRules();
    }
    
    @isTest
    static void testEvaluateCases_MultipleRules() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Rule_1', 'New', 'Closed', 1),
            createMockRule('Rule_2', 'Escalated', 'Working', 2)
        };
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Create multiple test cases
        List<Case> testCases = new List<Case>();
        testCases.add(new Case(Subject = 'Case 1', Status = 'New', Origin = 'Web'));
        testCases.add(new Case(Subject = 'Case 2', Status = 'Working', Origin = 'Web'));
        testCases.add(new Case(Subject = 'Case 3', Status = 'Escalated', Origin = 'Web'));
        insert testCases;

        // Reload cases
        testCases = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id IN :testCases];

        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(testCases, rules);
        Test.stopTest();

        // Verify - 2 cases should match (New and Escalated)
        System.assertEquals(2, changes.size(), 'Should have 2 changes');

        resetMockRules();
    }

    @isTest
    static void testBuildBatchQuery_QueryIsExecutable() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Rule_1', 'New', 'Closed', 1)
        };

        // Create a test case
        Case testCase = new Case(Subject = 'Test', Status = 'New', Origin = 'Web');
        insert testCase;

        // Get source statuses for binding
        Set<String> sourceStatuses = util_closer_RuleEngine.getAllSourceStatuses();

        // Execute - verify the query can be executed
        Test.startTest();
        String query = util_closer_RuleEngine.buildBatchQuery();
        List<Case> results = Database.query(query);
        Test.stopTest();

        // Verify
        System.assertNotEquals(null, results, 'Query should execute without error');

        resetMockRules();
    }

    @isTest
    static void testBuildBatchQuery_NoActiveRules() {
        // Setup - empty rules list
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>();

        // Execute
        Test.startTest();
        String query = util_closer_RuleEngine.buildBatchQuery();
        Test.stopTest();

        // Verify - query should return empty result query
        System.assertNotEquals(null, query, 'Query should not be null');
        System.assert(query.contains('Id = null'), 'Should return empty query when no rules');

        resetMockRules();
    }

    @isTest
    static void testEvaluateCases_WithRecordTypeInclusion() {
        // Setup - rule requires specific record type
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        // Get record type if available
        List<RecordType> recordTypes = [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType = 'Case' LIMIT 1];

        if (recordTypes.isEmpty()) {
            // Skip if no record types available
            System.assert(true, 'Skipping - no Case record types');
            return;
        }

        // Create rule that requires specific record type
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'RecordType_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Execution_Order__c = 1,
            Record_Type_Developer_Names__c = recordTypes[0].DeveloperName
        );
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };

        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        testCase.put('RecordTypeId', recordTypes[0].Id);
        insert testCase;

        // Reload with RecordType
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate, RecordType.DeveloperName FROM Case WHERE Id = :testCase.Id];

        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
        Test.stopTest();

        // Verify - should match since record type is included
        System.assertEquals(1, changes.size(), 'Should have 1 change');

        resetMockRules();
    }

    @isTest
    static void testEvaluateCases_WithDaysSinceLastActivity() {
        // Setup - rule with Days_Since_Last_Activity requirement
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Activity_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Execution_Order__c = 1,
            Days_Since_Last_Activity__c = 5
        );
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };

        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert testCase;

        // Reload
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute - should handle LastActivityDate field gracefully
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
        Test.stopTest();

        // Verify - method should handle missing LastActivityDate field gracefully
        System.assertNotEquals(null, changes, 'Changes map should not be null');

        resetMockRules();
    }

    @isTest
    static void testEvaluateCases_WithDaysSinceCreated() {
        // Setup - rule with Days_Since_Created requirement
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Created_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Execution_Order__c = 1,
            Days_Since_Created__c = 30
        );
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };

        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert testCase;

        // Backdate to meet days since created requirement
        Test.setCreatedDate(testCase.Id, DateTime.now().addDays(-60));

        // Reload
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
        Test.stopTest();

        // Verify - should match since case is old enough
        System.assertEquals(1, changes.size(), 'Should have 1 change');

        resetMockRules();
    }

    @isTest
    static void testEvaluateCases_WithDaysSinceLastModified() {
        // Setup - rule with Days_Since_Last_Modified requirement
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Modified_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Execution_Order__c = 1,
            Days_Since_Last_Modified__c = 0
        );
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };

        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert testCase;

        // Reload
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
        Test.stopTest();

        // Verify - should match (0 days requirement)
        System.assertEquals(1, changes.size(), 'Should have 1 change');

        resetMockRules();
    }

    @isTest
    static void testEvaluateCases_WithStopProcessingFlag() {
        // Setup - rule with Stop_Processing enabled
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Stop_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Execution_Order__c = 1,
            Stop_Processing__c = true
        );
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };

        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert testCase;

        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
        Test.stopTest();

        // Verify - stop processing flag should be handled
        System.assertEquals(1, changes.size(), 'Should have 1 change');

        resetMockRules();
    }

    @isTest
    static void testBuildBatchQuery_EmptyRules_ReturnsEmptyQuery() {
        // Setup - empty rules list
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>();

        // Execute
        Test.startTest();
        String query = util_closer_RuleEngine.buildBatchQuery();
        Test.stopTest();

        // Verify - should return empty query when no rules
        System.assertNotEquals(null, query, 'Query should not be null');
        System.assert(query.contains('Id = null'), 'Should return empty query');

        resetMockRules();
    }

    @isTest
    static void testEvaluateCases_DaysSinceLastModified_FailsCheck() {
        // Setup - rule with high Days_Since_Last_Modified requirement
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Strict_Modified_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Execution_Order__c = 1,
            Days_Since_Last_Modified__c = 365
        );
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };

        // Create case with matching status but recent modification (should fail check)
        Case testCase = new Case(Subject = 'Recent Case', Status = 'New', Origin = 'Web');
        insert testCase;

        // Don't backdate - keep it recent so it fails days check
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
        Test.stopTest();

        // Verify - case should NOT match because it doesn't meet days requirement
        System.assertEquals(0, changes.size(), 'Should have 0 changes - case too recent');

        resetMockRules();
    }

    @isTest
    static void testEvaluateCases_DaysSinceCreated_FailsCheck() {
        // Setup - rule with high Days_Since_Created requirement
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Strict_Created_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Execution_Order__c = 1,
            Days_Since_Created__c = 365
        );
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };

        // Create case with matching status but recent creation (should fail check)
        Case testCase = new Case(Subject = 'Recent Case', Status = 'New', Origin = 'Web');
        insert testCase;

        // Don't backdate - keep it recent so it fails days check
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
        Test.stopTest();

        // Verify - case should NOT match because it doesn't meet days requirement
        System.assertEquals(0, changes.size(), 'Should have 0 changes - case too recent');

        resetMockRules();
    }

    @isTest
    static void testEvaluateCases_LastActivityDate_FieldNotQueried() {
        // Setup - rule with Days_Since_Last_Activity but field not in query
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Activity_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Execution_Order__c = 1,
            Days_Since_Last_Activity__c = 5
        );
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };

        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert testCase;

        // Reload WITHOUT LastActivityDate
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute - catch block should execute since LastActivityDate not queried
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
        Test.stopTest();

        // Verify - should handle missing field gracefully
        System.assertNotEquals(null, changes, 'Changes map should not be null');

        resetMockRules();
    }

    @isTest
    static void testEvaluateCases_RecordTypeInclusion_NotIncluded() {
        // Setup - rule requires specific record type that case doesn't have
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        // Get record types
        List<RecordType> recordTypes = [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType = 'Case' LIMIT 2];

        if (recordTypes.size() < 2) {
            // Need at least 2 record types to test inclusion/exclusion
            System.assert(true, 'Skipping - need 2 record types');
            return;
        }

        // Create rule that requires first record type
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'RecordType_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Execution_Order__c = 1,
            Record_Type_Developer_Names__c = recordTypes[0].DeveloperName
        );
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };

        // Create case with SECOND record type (won't be included)
        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        testCase.put('RecordTypeId', recordTypes[1].Id);
        insert testCase;

        // Reload with RecordType
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate, RecordType.DeveloperName FROM Case WHERE Id = :testCase.Id];

        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
        Test.stopTest();

        // Verify - should NOT match since record type is not in inclusion list
        System.assertEquals(0, changes.size(), 'Should have 0 changes - record type not included');

        resetMockRules();
    }

    @isTest
    static void testEvaluateCases_RecordTypeExclusion_Excluded() {
        // Setup - rule excludes specific record type
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        // Get record types
        List<RecordType> recordTypes = [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType = 'Case' LIMIT 1];

        if (recordTypes.isEmpty()) {
            System.assert(true, 'Skipping - no record types');
            return;
        }

        // Create rule that excludes this record type
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Exclude_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Execution_Order__c = 1,
            Exclude_Record_Type_Developer_Names__c = recordTypes[0].DeveloperName
        );
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };

        // Create case with excluded record type
        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        testCase.put('RecordTypeId', recordTypes[0].Id);
        insert testCase;

        // Reload with RecordType
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate, RecordType.DeveloperName FROM Case WHERE Id = :testCase.Id];

        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
        Test.stopTest();

        // Verify - should NOT match since record type is excluded
        System.assertEquals(0, changes.size(), 'Should have 0 changes - record type excluded');

        resetMockRules();
    }

    @isTest
    static void testEvaluateCases_RecordType_NotQueried() {
        // Setup - rule with record type filter but case doesn't have RecordType queried
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'RecordType_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Execution_Order__c = 1,
            Record_Type_Developer_Names__c = 'SomeRecordType'
        );
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };

        // Create case without record type
        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert testCase;

        // Reload WITHOUT RecordType relationship
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute - getSObject('RecordType') will fail, catch block should execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
        Test.stopTest();

        // Verify - should handle missing RecordType gracefully (skip the check)
        System.assertNotEquals(null, changes, 'Changes map should not be null');

        resetMockRules();
    }

    @isTest
    static void testCaseChange_WrapperClass() {
        // Test the CaseChange wrapper class
        Test.startTest();
        util_closer_RuleEngine.CaseChange change = new util_closer_RuleEngine.CaseChange('Closed', 'Auto-closed due to inactivity');
        Test.stopTest();

        // Verify
        System.assertEquals('Closed', change.newStatus, 'New status should be set');
        System.assertEquals('Auto-closed due to inactivity', change.reason, 'Reason should be set');
    }

    @isTest
    static void testCaseChange_WrapperClass_NullReason() {
        // Test the CaseChange wrapper class with null reason
        Test.startTest();
        util_closer_RuleEngine.CaseChange change = new util_closer_RuleEngine.CaseChange('Escalated', null);
        Test.stopTest();

        // Verify
        System.assertEquals('Escalated', change.newStatus, 'New status should be set');
        System.assertEquals(null, change.reason, 'Reason should be null');
    }

    @isTest
    static void testGetActiveRules_IncludesTargetReason() {
        // Setup - mock rule with Target_Reason__c
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Reason_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Target_Reason__c = 'Auto-closed',
            Execution_Order__c = 1
        );
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };

        // Execute
        Test.startTest();
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
        Test.stopTest();

        // Verify - Target_Reason__c field should be accessible
        System.assertEquals(1, rules.size(), 'Should have 1 rule');
        System.assertEquals('Auto-closed', rules[0].Target_Reason__c, 'Target reason should be set');

        resetMockRules();
    }

    // ==================== Child Record Criteria Tests ====================

    @isTest
    static void testGetActiveRules_IncludesChildCriteriaFields() {
        // Setup - mock rule with child criteria fields
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Child_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Execution_Order__c = 1,
            Child_Object_API_Name__c = 'CaseComment',
            Child_Lookup_Field__c = 'ParentId',
            Child_Filter_Field__c = 'CommentBody',
            Child_Filter_Value__c = 'Resolved',
            Child_Filter_Operator__c = 'Contains',
            Require_Child_Record__c = true
        );
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };

        // Execute
        Test.startTest();
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
        Test.stopTest();

        // Verify - child criteria fields should be accessible
        System.assertEquals(1, rules.size(), 'Should have 1 rule');
        System.assertEquals('CaseComment', rules[0].Child_Object_API_Name__c, 'Child object should be set');
        System.assertEquals('ParentId', rules[0].Child_Lookup_Field__c, 'Child lookup should be set');
        System.assertEquals('CommentBody', rules[0].Child_Filter_Field__c, 'Child filter field should be set');
        System.assertEquals('Resolved', rules[0].Child_Filter_Value__c, 'Child filter value should be set');
        System.assertEquals('Contains', rules[0].Child_Filter_Operator__c, 'Child filter operator should be set');
        System.assertEquals(true, rules[0].Require_Child_Record__c, 'Require child should be set');

        resetMockRules();
    }

    @isTest
    static void testRulesHaveChildCriteria_WithChildCriteria() {
        // Setup - rule WITH child criteria
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Child_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Execution_Order__c = 1,
            Child_Object_API_Name__c = 'CaseComment',
            Child_Lookup_Field__c = 'ParentId'
        );
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };

        // Execute
        Test.startTest();
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
        Boolean hasChildCriteria = util_closer_RuleEngine.rulesHaveChildCriteria(rules);
        Test.stopTest();

        // Verify - should return true
        System.assertEquals(true, hasChildCriteria, 'Should have child criteria');

        resetMockRules();
    }

    @isTest
    static void testRulesHaveChildCriteria_WithoutChildCriteria() {
        // Setup - rule WITHOUT child criteria
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Simple_Rule', 'New', 'Closed', 1)
        };

        // Execute
        Test.startTest();
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
        Boolean hasChildCriteria = util_closer_RuleEngine.rulesHaveChildCriteria(rules);
        Test.stopTest();

        // Verify - should return false
        System.assertEquals(false, hasChildCriteria, 'Should not have child criteria');

        resetMockRules();
    }

    @isTest
    static void testRulesHaveChildCriteria_EmptyRules() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        // Execute
        Test.startTest();
        Boolean hasChildCriteria = util_closer_RuleEngine.rulesHaveChildCriteria(new List<util_closer_Case_Status_Rule__mdt>());
        Test.stopTest();

        // Verify - empty rules should return false
        System.assertEquals(false, hasChildCriteria, 'Empty rules should return false');
    }

    @isTest
    static void testEvaluateCases_WithChildDataMap() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Rule_1', 'New', 'Closed', 1)
        };

        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert testCase;

        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        // Create empty child data map
        Map<Id, List<SObject>> childDataMap = new Map<Id, List<SObject>>();
        childDataMap.put(testCase.Id, new List<SObject>());

        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(
            new List<Case>{ testCase },
            rules,
            childDataMap
        );
        Test.stopTest();

        // Verify - should match since rule has no child criteria
        System.assertEquals(1, changes.size(), 'Should have 1 change');

        resetMockRules();
    }

    @isTest
    static void testEvaluateCases_WithNullChildDataMap() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Rule_1', 'New', 'Closed', 1)
        };

        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert testCase;

        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute with null child data map
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(
            new List<Case>{ testCase },
            rules,
            null
        );
        Test.stopTest();

        // Verify - should handle null child data map
        System.assertEquals(1, changes.size(), 'Should have 1 change');

        resetMockRules();
    }

    @isTest
    static void testCaseMatchesRule_WithChildRecords() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert testCase;

        // Add child comment
        CaseComment comment = new CaseComment(
            ParentId = testCase.Id,
            CommentBody = 'Test Comment'
        );
        insert comment;

        // Reload case
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];
        List<SObject> childRecords = [SELECT Id, ParentId, CommentBody FROM CaseComment WHERE ParentId = :testCase.Id];

        // Create a mock rule - rules without child criteria should match
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        // Execute
        Test.startTest();
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
        Map<Id, List<SObject>> childDataMap = new Map<Id, List<SObject>>();
        childDataMap.put(testCase.Id, childRecords);

        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(
            new List<Case>{ testCase },
            rules,
            childDataMap
        );
        Test.stopTest();

        // Verify - should match
        System.assertEquals(1, changes.size(), 'Should have 1 change');

        resetMockRules();
    }

    @isTest
    static void testEvaluateCases_WithStopProcessing_True() {
        // Test Stop_Processing__c = true path
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert testCase;
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        // Create rule with Stop_Processing = true
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Stop_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Target_Reason__c = 'Auto-closed',
            Execution_Order__c = 1,
            Stop_Processing__c = true
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(
            new List<Case>{ testCase },
            rules,
            null
        );
        Test.stopTest();

        // Verify - should match and return change
        System.assertEquals(1, changes.size(), 'Should have 1 change');
        System.assertEquals('Closed', changes.get(testCase.Id).newStatus, 'Should have Closed status');
        System.assertEquals('Auto-closed', changes.get(testCase.Id).reason, 'Should have reason set');

        resetMockRules();
    }

    @isTest
    static void testEvaluateCases_WithStopProcessing_False() {
        // Test Stop_Processing__c = false path
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert testCase;
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        // Create rule with Stop_Processing = false
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Continue_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Escalated',
            Target_Reason__c = 'Auto-escalated',
            Execution_Order__c = 1,
            Stop_Processing__c = false
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(
            new List<Case>{ testCase },
            rules,
            null
        );
        Test.stopTest();

        // Verify
        System.assertEquals(1, changes.size(), 'Should have 1 change');
        System.assertEquals('Escalated', changes.get(testCase.Id).newStatus, 'Should have Escalated status');

        resetMockRules();
    }

    @isTest
    static void testEvaluateCases_MultipleRulesFirstMatches() {
        // Test that first matching rule is applied
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert testCase;
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        // Create multiple rules - first one should match
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('First_Rule', 'New', 'Working', 1),
            createMockRule('Second_Rule', 'New', 'Closed', 2)
        };
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(
            new List<Case>{ testCase },
            rules,
            null
        );
        Test.stopTest();

        // Verify - first rule should match
        System.assertEquals(1, changes.size(), 'Should have 1 change');
        System.assertEquals('Working', changes.get(testCase.Id).newStatus, 'First rule should be applied');

        resetMockRules();
    }

    @isTest
    static void testEvaluateCases_NoRulesMatch() {
        // Test when no rules match
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        Case testCase = new Case(Subject = 'Test Case', Status = 'Working', Origin = 'Web');
        insert testCase;
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        // Create rule that won't match the case status
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('New_Only_Rule', 'New', 'Closed', 1)
        };
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(
            new List<Case>{ testCase },
            rules,
            null
        );
        Test.stopTest();

        // Verify - no match
        System.assertEquals(0, changes.size(), 'Should have 0 changes');

        resetMockRules();
    }

    @isTest
    static void testEvaluateCases_DaysSinceLastModified_Pass() {
        // Test Days_Since_Last_Modified passes check
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert testCase;

        // Backdate the case
        Test.setCreatedDate(testCase.Id, DateTime.now().addDays(-30));
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        // Create rule with days requirement
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Days_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Execution_Order__c = 1,
            Days_Since_Last_Modified__c = 0
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(
            new List<Case>{ testCase },
            rules,
            null
        );
        Test.stopTest();

        // Verify - should match (0 days is met)
        System.assertEquals(1, changes.size(), 'Should have 1 change');

        resetMockRules();
    }

    @isTest
    static void testEvaluateCases_DaysSinceCreated_Pass() {
        // Test Days_Since_Created passes check
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert testCase;

        // Backdate the case creation
        Test.setCreatedDate(testCase.Id, DateTime.now().addDays(-30));
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        // Create rule with days requirement
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Created_Days_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Execution_Order__c = 1,
            Days_Since_Created__c = 0
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(
            new List<Case>{ testCase },
            rules,
            null
        );
        Test.stopTest();

        // Verify
        System.assertEquals(1, changes.size(), 'Should have 1 change');

        resetMockRules();
    }

    @isTest
    static void testParseList_WithBlankValues() {
        // Test parseList handles blank values in semicolon list
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert testCase;
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        // Rule with semicolon-separated statuses including blanks
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Multi_Status_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New;  ;Working; ',
            Target_Status__c = 'Closed',
            Execution_Order__c = 1
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(
            new List<Case>{ testCase },
            rules,
            null
        );
        Test.stopTest();

        // Verify - should still match 'New'
        System.assertEquals(1, changes.size(), 'Should have 1 change');

        resetMockRules();
    }

    @isTest
    static void testParseList_EmptyString() {
        // Test parseList with empty string
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert testCase;
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        // Rule with empty source status
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Empty_Status_Rule',
            Is_Active__c = true,
            Source_Status__c = '',
            Target_Status__c = 'Closed',
            Execution_Order__c = 1
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(
            new List<Case>{ testCase },
            rules,
            null
        );
        Test.stopTest();

        // Verify - no match due to empty source status
        System.assertEquals(0, changes.size(), 'Should have 0 changes');

        resetMockRules();
    }

    @isTest
    static void testGetDaysSince_WithValidDatetime() {
        // Test getDaysSince with valid datetime
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        // Create a case
        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert testCase;
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        // Create rule with Days_Since_Last_Modified
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Test_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Execution_Order__c = 1,
            Days_Since_Last_Modified__c = 0
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(
            new List<Case>{ testCase },
            rules,
            null
        );
        Test.stopTest();

        // Verify - should match
        System.assertEquals(1, changes.size(), 'Should have 1 change');

        resetMockRules();
    }

    @isTest
    static void testEvaluateCases_ChildCriteriaFailsMatch() {
        // Test case fails child criteria check
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert testCase;
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        // Create rule with child criteria that requires child record
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Child_Required_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Execution_Order__c = 1,
            Child_Object_API_Name__c = 'CaseComment',
            Child_Lookup_Field__c = 'ParentId',
            Child_Filter_Field__c = 'CommentBody',
            Child_Filter_Value__c = 'Required Value',
            Child_Filter_Operator__c = 'Equals',
            Require_Child_Record__c = true
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute with empty child data
        Test.startTest();
        Map<Id, List<SObject>> childDataMap = new Map<Id, List<SObject>>();
        childDataMap.put(testCase.Id, new List<SObject>());

        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(
            new List<Case>{ testCase },
            rules,
            childDataMap
        );
        Test.stopTest();

        // Verify - should not match because child record is required but none exist
        System.assertEquals(0, changes.size(), 'Should have 0 changes - child required but missing');

        resetMockRules();
    }

    @isTest
    static void testCaseMatchesRule_TwoParamOverload() {
        // Test the 2-param evaluateCases which calls 3-param internally
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert testCase;
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Simple_Rule', 'New', 'Closed', 1)
        };
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute using the 2-param evaluateCases
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(
            new List<Case>{ testCase },
            rules
        );
        Test.stopTest();

        // Verify
        System.assertEquals(1, changes.size(), 'Should have 1 change');

        resetMockRules();
    }

    @isTest
    static void testEvaluateCases_WithDaysSinceLastActivity_RuleCheck() {
        // Test Days_Since_Last_Activity rule check
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert testCase;

        // Reload case without LastActivityDate
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        // Create rule with days since last activity requirement
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Activity_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Execution_Order__c = 1,
            Days_Since_Last_Activity__c = 0
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(
            new List<Case>{ testCase },
            rules,
            null
        );
        Test.stopTest();

        // Verify - method should handle missing LastActivityDate gracefully
        System.assertNotEquals(null, changes, 'Changes should not be null');

        resetMockRules();
    }

    @isTest
    static void testEvaluateCases_WithDaysSinceLastActivity_HighRequirement() {
        // Test Days_Since_Last_Activity with high requirement
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert testCase;
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        // Create rule with days since last activity - high requirement
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Activity_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Execution_Order__c = 1,
            Days_Since_Last_Activity__c = 30
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(
            new List<Case>{ testCase },
            rules,
            null
        );
        Test.stopTest();

        // Verify - should handle null LastActivityDate gracefully
        System.assertNotEquals(null, changes, 'Changes should not be null');

        resetMockRules();
    }

    @isTest
    static void testEvaluateCases_EmptyRulesList() {
        // Test with empty rules list
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert testCase;
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];

        // Execute with empty rules
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(
            new List<Case>{ testCase },
            new List<util_closer_Case_Status_Rule__mdt>(),
            null
        );
        Test.stopTest();

        // Verify - no changes because no rules
        System.assertEquals(0, changes.size(), 'Should have 0 changes with empty rules');
    }

    @isTest
    static void testEvaluateCases_ChildCriteriaWithMatchingChild() {
        // Test child criteria passes when matching child exists
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert testCase;

        // Create matching child comment
        CaseComment comment = new CaseComment(
            ParentId = testCase.Id,
            CommentBody = 'Resolved by customer'
        );
        insert comment;

        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];
        List<SObject> childRecords = [SELECT Id, ParentId, CommentBody FROM CaseComment WHERE ParentId = :testCase.Id];

        // Create rule with child criteria
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Child_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Execution_Order__c = 1,
            Child_Object_API_Name__c = 'CaseComment',
            Child_Lookup_Field__c = 'ParentId',
            Child_Filter_Field__c = 'CommentBody',
            Child_Filter_Value__c = 'Resolved',
            Child_Filter_Operator__c = 'Contains',
            Require_Child_Record__c = true
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();

        // Execute
        Test.startTest();
        Map<Id, List<SObject>> childDataMap = new Map<Id, List<SObject>>();
        childDataMap.put(testCase.Id, childRecords);

        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(
            new List<Case>{ testCase },
            rules,
            childDataMap
        );
        Test.stopTest();

        // Verify - should match because child record exists with matching value
        System.assertEquals(1, changes.size(), 'Should have 1 change');

        resetMockRules();
    }
}

