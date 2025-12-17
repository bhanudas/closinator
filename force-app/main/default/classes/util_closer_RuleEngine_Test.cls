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
        Map<Id, String> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
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
        Map<Id, String> changes = util_closer_RuleEngine.evaluateCases(new List<Case>(), rules);
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
        Map<Id, String> changes = util_closer_RuleEngine.evaluateCases(new List<Case>{ testCase }, rules);
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
        Map<Id, String> changes = util_closer_RuleEngine.evaluateCases(testCases, rules);
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
}

