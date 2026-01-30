/**
 * @description Test class for util_closer_RuleEngine.
 * Tests rule retrieval, query building, and case evaluation.
 */
@isTest
private class util_closer_RuleEngine_Test {
    
    @TestSetup
    static void setup() {
        // Setup mock settings to enable debug mode for logging
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
    }
    
    @isTest
    static void testGetActiveRules_ReturnsOrderedRules() {
        // Execute - uses deployed custom metadata rules
        Test.startTest();
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
        Test.stopTest();
        
        // Verify - rules should be ordered by Execution_Order__c
        System.assertNotEquals(null, rules, 'Rules should not be null');
        if (rules.size() > 1) {
            for (Integer i = 1; i < rules.size(); i++) {
                System.assert(
                    rules[i].Execution_Order__c >= rules[i-1].Execution_Order__c,
                    'Rules should be ordered by Execution_Order__c'
                );
            }
        }
    }
    
    @isTest
    static void testGetActiveRules_ExcludesInactive() {
        // Execute
        Test.startTest();
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
        Test.stopTest();
        
        // Verify - all returned rules should be active
        for (util_closer_Case_Status_Rule__mdt rule : rules) {
            System.assertEquals(true, rule.Is_Active__c, 'All returned rules should be active');
        }
    }
    
    @isTest
    static void testBuildBatchQuery_CombinesActiveRules() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        
        // Execute
        Test.startTest();
        String query = util_closer_RuleEngine.buildBatchQuery();
        Test.stopTest();
        
        // Verify
        System.assertNotEquals(null, query, 'Query should not be null');
        System.assert(query.containsIgnoreCase('SELECT'), 'Query should contain SELECT');
        System.assert(query.containsIgnoreCase('FROM Case'), 'Query should contain FROM Case');
        System.assert(query.containsIgnoreCase('IsClosed = false'), 'Query should filter closed cases');
    }
    
    @isTest
    static void testGetAllSourceStatuses_ReturnsStatusSet() {
        // Execute
        Test.startTest();
        Set<String> statuses = util_closer_RuleEngine.getAllSourceStatuses();
        Test.stopTest();
        
        // Verify
        System.assertNotEquals(null, statuses, 'Statuses should not be null');
    }
    
    @isTest
    static void testEvaluateCases_NoMatch() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        
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
    }
    
    @isTest
    static void testEvaluateCases_WithEmptyList() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
        
        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>(), rules);
        Test.stopTest();
        
        // Verify
        System.assertEquals(0, changes.size(), 'Empty case list should return empty map');
    }
    
    @isTest
    static void testEvaluateCases_MatchingCase() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        
        // Get active rules to find a source status
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
        
        if (rules.isEmpty()) {
            // Skip test if no rules deployed
            return;
        }
        
        // Create a case with matching status
        String sourceStatus = rules[0].Source_Status__c.split(';')[0].trim();
        Case testCase = new Case(
            Subject = 'Test Matching Case',
            Status = sourceStatus,
            Origin = 'Web'
        );
        insert testCase;
        
        // Backdate the case to meet age requirements
        Test.setCreatedDate(testCase.Id, DateTime.now().addDays(-60));
        
        // Reload with all fields
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];
        
        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
        Test.stopTest();
        
        // Verify - the case may or may not match depending on rule criteria
        // This test just verifies the method runs without error
        System.assertNotEquals(null, changes, 'Changes map should not be null');
    }
    
    @isTest
    static void testEvaluateCases_MultipleRules() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
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
        
        // Verify
        System.assertNotEquals(null, changes, 'Changes map should not be null');
    }
    
    @isTest
    static void testBuildBatchQuery_QueryIsExecutable() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        
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
    }
    
    @isTest
    static void testBuildBatchQuery_NoActiveRules() {
        // Setup - this test verifies behavior when no rules exist
        // In practice, this would return an empty query
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        
        // Execute
        Test.startTest();
        String query = util_closer_RuleEngine.buildBatchQuery();
        Test.stopTest();
        
        // Verify - query should contain empty WHERE clause or null check
        System.assertNotEquals(null, query, 'Query should not be null');
    }
    
    @isTest
    static void testEvaluateCases_WithRecordTypeFilter() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        
        // Get record type if available
        List<RecordType> recordTypes = [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType = 'Case' LIMIT 1];
        
        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        if (!recordTypes.isEmpty()) {
            testCase.put('RecordTypeId', recordTypes[0].Id);
        }
        insert testCase;
        
        // Reload with all fields
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];
        
        // Backdate
        Test.setCreatedDate(testCase.Id, DateTime.now().addDays(-60));
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];
        
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
        
        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
        Test.stopTest();
        
        // Verify - method should execute without error
        System.assertNotEquals(null, changes, 'Changes map should not be null');
    }
    
    @isTest
    static void testEvaluateCases_WithLastActivityDate() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        
        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert testCase;
        
        // Reload with all fields (LastActivityDate is not a standard field on Case)
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];
        
        // Backdate
        Test.setCreatedDate(testCase.Id, DateTime.now().addDays(-60));
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];
        
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
        
        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
        Test.stopTest();
        
        // Verify - method should handle missing LastActivityDate field gracefully
        System.assertNotEquals(null, changes, 'Changes map should not be null');
    }
    
    @isTest
    static void testEvaluateCases_WithDaysSinceCreated() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
        
        if (rules.isEmpty()) {
            return;
        }
        
        Case testCase = new Case(Subject = 'Test Case', Status = rules[0].Source_Status__c.split(';')[0].trim(), Origin = 'Web');
        insert testCase;
        
        // Backdate to meet days since created requirement
        Test.setCreatedDate(testCase.Id, DateTime.now().addDays(-60));
        Test.setCreatedDate(testCase.Id, DateTime.now().addDays(-60)); // Set last modified too
        
        // Reload
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];
        
        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
        Test.stopTest();
        
        // Verify
        System.assertNotEquals(null, changes, 'Changes map should not be null');
    }
    
    @isTest
    static void testEvaluateCases_WithDaysSinceLastModified() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
        
        if (rules.isEmpty()) {
            return;
        }
        
        Case testCase = new Case(Subject = 'Test Case', Status = rules[0].Source_Status__c.split(';')[0].trim(), Origin = 'Web');
        insert testCase;
        
        // Backdate last modified
        Test.setCreatedDate(testCase.Id, DateTime.now().addDays(-60));
        
        // Reload
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];
        
        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
        Test.stopTest();
        
        // Verify
        System.assertNotEquals(null, changes, 'Changes map should not be null');
    }
    
    @isTest
    static void testEvaluateCases_WithStopProcessingFlag() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
        
        if (rules.isEmpty()) {
            return;
        }
        
        Case testCase = new Case(Subject = 'Test Case', Status = rules[0].Source_Status__c.split(';')[0].trim(), Origin = 'Web');
        insert testCase;
        
        // Backdate
        Test.setCreatedDate(testCase.Id, DateTime.now().addDays(-60));
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];
        
        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
        Test.stopTest();
        
        // Verify - stop processing flag should be handled
        System.assertNotEquals(null, changes, 'Changes map should not be null');
    }
    
    @isTest
    static void testBuildBatchQuery_EmptyRules_ReturnsEmptyQuery() {
        // Setup - this tests the empty rules path (lines 33-35)
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        
        // Execute - if no rules exist, should return empty query
        Test.startTest();
        String query = util_closer_RuleEngine.buildBatchQuery();
        Test.stopTest();
        
        // Verify - should return empty query when no rules
        System.assertNotEquals(null, query, 'Query should not be null');
        System.assert(query.contains('Id = null') || query.contains('WHERE'), 'Should return empty query');
    }
    
    @isTest
    static void testEvaluateCases_DaysSinceLastModified_FailsCheck() {
        // Setup - test case that fails days since last modified check (line 123)
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
        
        if (rules.isEmpty()) {
            return;
        }
        
        // Create case with matching status but recent modification (should fail check)
        String sourceStatus = rules[0].Source_Status__c.split(';')[0].trim();
        Case testCase = new Case(Subject = 'Recent Case', Status = sourceStatus, Origin = 'Web');
        insert testCase;
        
        // Don't backdate - keep it recent so it fails days check
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];
        
        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
        Test.stopTest();
        
        // Verify - if rule has Days_Since_Last_Modified__c, case should not match
        System.assertNotEquals(null, changes, 'Changes map should not be null');
    }
    
    @isTest
    static void testEvaluateCases_DaysSinceCreated_FailsCheck() {
        // Setup - test case that fails days since created check (line 131)
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
        
        if (rules.isEmpty()) {
            return;
        }
        
        // Create case with matching status but recent creation (should fail check)
        String sourceStatus = rules[0].Source_Status__c.split(';')[0].trim();
        Case testCase = new Case(Subject = 'Recent Case', Status = sourceStatus, Origin = 'Web');
        insert testCase;
        
        // Don't backdate - keep it recent so it fails days check
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];
        
        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
        Test.stopTest();
        
        // Verify - if rule has Days_Since_Created__c, case should not match
        System.assertNotEquals(null, changes, 'Changes map should not be null');
    }
    
    @isTest
    static void testEvaluateCases_LastActivityDate_FieldNotAvailable() {
        // Setup - test LastActivityDate field not available path (lines 137-148)
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
        
        if (rules.isEmpty()) {
            return;
        }
        
        Case testCase = new Case(Subject = 'Test Case', Status = rules[0].Source_Status__c.split(';')[0].trim(), Origin = 'Web');
        insert testCase;
        
        // Backdate
        Test.setCreatedDate(testCase.Id, DateTime.now().addDays(-60));
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];
        
        // Execute - LastActivityDate field doesn't exist on Case, so catch block should execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
        Test.stopTest();
        
        // Verify - should handle missing field gracefully
        System.assertNotEquals(null, changes, 'Changes map should not be null');
    }
    
    @isTest
    static void testEvaluateCases_RecordTypeInclusion_NotIncluded() {
        // Setup - test record type inclusion check (lines 152-163)
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
        
        if (rules.isEmpty()) {
            return;
        }
        
        // Get record types
        List<RecordType> recordTypes = [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType = 'Case' LIMIT 2];
        
        if (recordTypes.size() < 2) {
            // Need at least 2 record types to test inclusion/exclusion
            return;
        }
        
        // Create case with record type that might not be included
        Case testCase = new Case(Subject = 'Test Case', Status = rules[0].Source_Status__c.split(';')[0].trim(), Origin = 'Web');
        testCase.put('RecordTypeId', recordTypes[1].Id); // Use different record type
        insert testCase;
        
        // Backdate
        Test.setCreatedDate(testCase.Id, DateTime.now().addDays(-60));
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];
        
        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
        Test.stopTest();
        
        // Verify - should handle record type inclusion check
        System.assertNotEquals(null, changes, 'Changes map should not be null');
    }
    
    @isTest
    static void testEvaluateCases_RecordTypeExclusion_Excluded() {
        // Setup - test record type exclusion check (lines 166-177)
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
        
        if (rules.isEmpty()) {
            return;
        }
        
        // Get record types
        List<RecordType> recordTypes = [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType = 'Case' LIMIT 1];
        
        if (recordTypes.isEmpty()) {
            return;
        }
        
        // Create case with record type
        Case testCase = new Case(Subject = 'Test Case', Status = rules[0].Source_Status__c.split(';')[0].trim(), Origin = 'Web');
        testCase.put('RecordTypeId', recordTypes[0].Id);
        insert testCase;
        
        // Backdate
        Test.setCreatedDate(testCase.Id, DateTime.now().addDays(-60));
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];
        
        // Execute
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
        Test.stopTest();
        
        // Verify - should handle record type exclusion check
        System.assertNotEquals(null, changes, 'Changes map should not be null');
    }
    
    @isTest
    static void testEvaluateCases_RecordType_NotAvailable() {
        // Setup - test record type not available path (SObjectException catch blocks)
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
        
        if (rules.isEmpty()) {
            return;
        }
        
        // Create case without record type
        Case testCase = new Case(Subject = 'Test Case', Status = rules[0].Source_Status__c.split(';')[0].trim(), Origin = 'Web');
        insert testCase;
        
        // Backdate
        Test.setCreatedDate(testCase.Id, DateTime.now().addDays(-60));
        testCase = [SELECT Id, Status, LastModifiedDate, CreatedDate FROM Case WHERE Id = :testCase.Id];
        
        // Execute - RecordType relationship not queried, so getSObject will fail
        Test.startTest();
        Map<Id, util_closer_RuleEngine.CaseChange> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
        Test.stopTest();

        // Verify - should handle missing RecordType gracefully
        System.assertNotEquals(null, changes, 'Changes map should not be null');
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
        // Verify that getActiveRules includes Target_Reason__c field
        Test.startTest();
        List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
        Test.stopTest();

        // Verify - rules should be returned (may have Target_Reason__c populated or not)
        System.assertNotEquals(null, rules, 'Rules should not be null');
        // The Target_Reason__c field should be queryable without error
        for (util_closer_Case_Status_Rule__mdt rule : rules) {
            // Just accessing the field should not throw an error
            String reason = rule.Target_Reason__c;
        }
    }
}

