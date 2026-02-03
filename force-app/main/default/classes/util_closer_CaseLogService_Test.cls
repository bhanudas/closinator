/**
 * @description Test class for util_closer_CaseLogService.
 * Tests case log creation, buffering, and flush operations.
 */
@isTest
private class util_closer_CaseLogService_Test {

    @TestSetup
    static void setup() {
        // Create settings
        util_closer_Settings__c settings = util_closer_TestDataFactory.createSettingsWithLogging(true, 90, true);
        util_closer_TestDataFactory.insertOrgDefaultSettings(settings);
    }

    @isTest
    static void testLogCaseEvaluation_Matched() {
        // Setup
        util_closer_Batch_Log__c batchLog = util_closer_TestDataFactory.createBatchLog('Running', false);
        insert batchLog;

        Case testCase = util_closer_TestDataFactory.createCase('New');
        insert testCase;

        util_closer_CaseLogService service = new util_closer_CaseLogService(batchLog.Id, 1);

        util_closer_CaseLogService.CaseEvaluationResult result = new util_closer_CaseLogService.CaseEvaluationResult();
        result.caseId = testCase.Id;
        result.caseNumber = '00001';
        result.originalStatus = 'New';
        result.targetStatus = 'Closed';
        result.matchedRuleDeveloperName = 'Test_Rule';
        result.matchedRuleMasterLabel = 'Test Rule';
        result.processingResult = 'Matched';
        result.rulesEvaluatedCount = 3;
        result.processingTimeMs = 50;

        // Execute
        Test.startTest();
        service.logCaseEvaluation(result);
        service.flushLogs();
        Test.stopTest();

        // Verify
        List<util_closer_Case_Log__c> logs = [
            SELECT Case__c, Processing_Result__c, Original_Status__c, Target_Status__c,
                   Matched_Rule__c, Rules_Evaluated_Count__c
            FROM util_closer_Case_Log__c
            WHERE Batch_Log__c = :batchLog.Id
        ];

        System.assertEquals(1, logs.size(), 'Should have 1 case log');
        System.assertEquals(testCase.Id, logs[0].Case__c, 'Case should be linked');
        System.assertEquals('Matched', logs[0].Processing_Result__c, 'Result should be Matched');
        System.assertEquals('New', logs[0].Original_Status__c, 'Original status should be New');
        System.assertEquals('Closed', logs[0].Target_Status__c, 'Target status should be Closed');
        System.assertEquals('Test_Rule', logs[0].Matched_Rule__c, 'Rule should be set');
    }

    @isTest
    static void testLogCaseEvaluation_NotMatched() {
        // Setup
        util_closer_Batch_Log__c batchLog = util_closer_TestDataFactory.createBatchLog('Running', false);
        insert batchLog;

        Case testCase = util_closer_TestDataFactory.createCase('New');
        insert testCase;

        util_closer_CaseLogService service = new util_closer_CaseLogService(batchLog.Id, 1);

        util_closer_CaseLogService.CaseEvaluationResult result = new util_closer_CaseLogService.CaseEvaluationResult();
        result.caseId = testCase.Id;
        result.caseNumber = '00001';
        result.originalStatus = 'New';
        result.processingResult = 'Not Matched';
        result.rulesEvaluatedCount = 5;

        // Execute
        Test.startTest();
        service.logCaseEvaluation(result);
        service.flushLogs();
        Test.stopTest();

        // Verify
        List<util_closer_Case_Log__c> logs = [
            SELECT Processing_Result__c, Target_Status__c, Matched_Rule__c
            FROM util_closer_Case_Log__c
            WHERE Batch_Log__c = :batchLog.Id
        ];

        System.assertEquals(1, logs.size(), 'Should have 1 case log');
        System.assertEquals('Not Matched', logs[0].Processing_Result__c, 'Result should be Not Matched');
        System.assertEquals(null, logs[0].Target_Status__c, 'Target status should be null');
        System.assertEquals(null, logs[0].Matched_Rule__c, 'Matched rule should be null');
    }

    @isTest
    static void testLogCaseEvaluation_Failed() {
        // Setup
        util_closer_Batch_Log__c batchLog = util_closer_TestDataFactory.createBatchLog('Running', false);
        insert batchLog;

        Case testCase = util_closer_TestDataFactory.createCase('New');
        insert testCase;

        util_closer_CaseLogService service = new util_closer_CaseLogService(batchLog.Id, 1);

        util_closer_CaseLogService.CaseEvaluationResult result = new util_closer_CaseLogService.CaseEvaluationResult();
        result.caseId = testCase.Id;
        result.caseNumber = '00001';
        result.originalStatus = 'New';
        result.targetStatus = 'Closed';
        result.processingResult = 'Failed';
        result.errorMessage = 'Validation error: Status cannot be changed';

        // Execute
        Test.startTest();
        service.logCaseEvaluation(result);
        service.flushLogs();
        Test.stopTest();

        // Verify
        List<util_closer_Case_Log__c> logs = [
            SELECT Processing_Result__c, Error_Message__c
            FROM util_closer_Case_Log__c
            WHERE Batch_Log__c = :batchLog.Id
        ];

        System.assertEquals(1, logs.size(), 'Should have 1 case log');
        System.assertEquals('Failed', logs[0].Processing_Result__c, 'Result should be Failed');
        System.assert(logs[0].Error_Message__c.contains('Validation error'), 'Error message should be set');
    }

    @isTest
    static void testLogCaseEvaluation_Simulated() {
        // Setup
        util_closer_Batch_Log__c batchLog = util_closer_TestDataFactory.createBatchLog('Running', true);
        insert batchLog;

        Case testCase = util_closer_TestDataFactory.createCase('New');
        insert testCase;

        util_closer_CaseLogService service = new util_closer_CaseLogService(batchLog.Id, 1);

        util_closer_CaseLogService.CaseEvaluationResult result = new util_closer_CaseLogService.CaseEvaluationResult();
        result.caseId = testCase.Id;
        result.caseNumber = '00001';
        result.originalStatus = 'New';
        result.targetStatus = 'Closed';
        result.processingResult = 'Simulated';

        // Execute
        Test.startTest();
        service.logCaseEvaluation(result);
        service.flushLogs();
        Test.stopTest();

        // Verify
        List<util_closer_Case_Log__c> logs = [
            SELECT Processing_Result__c
            FROM util_closer_Case_Log__c
            WHERE Batch_Log__c = :batchLog.Id
        ];

        System.assertEquals(1, logs.size(), 'Should have 1 case log');
        System.assertEquals('Simulated', logs[0].Processing_Result__c, 'Result should be Simulated');
    }

    @isTest
    static void testBulkFlush() {
        // Setup
        util_closer_Batch_Log__c batchLog = util_closer_TestDataFactory.createBatchLog('Running', false);
        insert batchLog;

        util_closer_CaseLogService service = new util_closer_CaseLogService(batchLog.Id, 1);

        // Create multiple results
        for (Integer i = 0; i < 50; i++) {
            util_closer_CaseLogService.CaseEvaluationResult result = new util_closer_CaseLogService.CaseEvaluationResult();
            result.caseNumber = '0000' + i;
            result.originalStatus = 'New';
            result.processingResult = 'Not Matched';
            result.rulesEvaluatedCount = 3;
            service.logCaseEvaluation(result);
        }

        // Execute
        Test.startTest();
        service.flushLogs();
        Test.stopTest();

        // Verify
        Integer count = [SELECT COUNT() FROM util_closer_Case_Log__c WHERE Batch_Log__c = :batchLog.Id];
        System.assertEquals(50, count, 'Should have 50 case logs');
    }

    @isTest
    static void testAutoFlush_BufferOverflow() {
        // Setup
        util_closer_Batch_Log__c batchLog = util_closer_TestDataFactory.createBatchLog('Running', false);
        insert batchLog;

        util_closer_CaseLogService service = new util_closer_CaseLogService(batchLog.Id, 1);

        // Execute - add more than buffer size (200)
        Test.startTest();
        for (Integer i = 0; i < 210; i++) {
            util_closer_CaseLogService.CaseEvaluationResult result = new util_closer_CaseLogService.CaseEvaluationResult();
            result.caseNumber = '0000' + i;
            result.originalStatus = 'New';
            result.processingResult = 'Not Matched';
            service.logCaseEvaluation(result);
        }
        service.flushLogs(); // Flush remaining
        Test.stopTest();

        // Verify - should have auto-flushed at 200 and then final flush
        Integer count = [SELECT COUNT() FROM util_closer_Case_Log__c WHERE Batch_Log__c = :batchLog.Id];
        System.assertEquals(210, count, 'Should have 210 case logs');
    }

    @isTest
    static void testFlushLogs_EmptyBuffer() {
        // Setup
        util_closer_Batch_Log__c batchLog = util_closer_TestDataFactory.createBatchLog('Running', false);
        insert batchLog;

        util_closer_CaseLogService service = new util_closer_CaseLogService(batchLog.Id, 1);

        // Execute - flush empty buffer
        Test.startTest();
        service.flushLogs();
        Test.stopTest();

        // Verify - no exception, no logs created
        Integer count = [SELECT COUNT() FROM util_closer_Case_Log__c WHERE Batch_Log__c = :batchLog.Id];
        System.assertEquals(0, count, 'Should have 0 case logs');
    }

    @isTest
    static void testLogCaseEvaluation_NullResult() {
        // Setup
        util_closer_Batch_Log__c batchLog = util_closer_TestDataFactory.createBatchLog('Running', false);
        insert batchLog;

        util_closer_CaseLogService service = new util_closer_CaseLogService(batchLog.Id, 1);

        // Execute - log null result
        Test.startTest();
        service.logCaseEvaluation(null);
        service.flushLogs();
        Test.stopTest();

        // Verify - no exception, no logs created
        Integer count = [SELECT COUNT() FROM util_closer_Case_Log__c WHERE Batch_Log__c = :batchLog.Id];
        System.assertEquals(0, count, 'Should have 0 case logs');
    }

    @isTest
    static void testCreateResult_WithChange() {
        // Setup
        Case testCase = new Case(Id = '500000000000001AAA', Status = 'New', Subject = 'Test Case');
        util_closer_RuleEngine.CaseChange change = new util_closer_RuleEngine.CaseChange('Closed', 'Auto closed');

        // Execute
        Test.startTest();
        util_closer_CaseLogService.CaseEvaluationResult result =
            util_closer_CaseLogService.createResult(testCase, change, false);
        Test.stopTest();

        // Verify
        System.assertEquals(null, result.caseNumber, 'Case number should be null for mock case');
        System.assertEquals('New', result.originalStatus, 'Original status should be New');
        System.assertEquals('Closed', result.targetStatus, 'Target status should be Closed');
        System.assertEquals('Auto closed', result.targetReason, 'Target reason should be set');
        System.assertEquals('Matched', result.processingResult, 'Result should be Matched');
    }

    @isTest
    static void testCreateResult_WithoutChange() {
        // Setup
        Case testCase = new Case(Id = '500000000000001AAA', Status = 'New', Subject = 'Test Case');

        // Execute
        Test.startTest();
        util_closer_CaseLogService.CaseEvaluationResult result =
            util_closer_CaseLogService.createResult(testCase, null, false);
        Test.stopTest();

        // Verify
        System.assertEquals('Not Matched', result.processingResult, 'Result should be Not Matched');
        System.assertEquals(null, result.targetStatus, 'Target status should be null');
    }

    @isTest
    static void testCreateResult_Simulation() {
        // Setup
        Case testCase = new Case(Id = '500000000000001AAA', Status = 'New', Subject = 'Test Case');
        util_closer_RuleEngine.CaseChange change = new util_closer_RuleEngine.CaseChange('Closed', null);

        // Execute
        Test.startTest();
        util_closer_CaseLogService.CaseEvaluationResult result =
            util_closer_CaseLogService.createResult(testCase, change, true);
        Test.stopTest();

        // Verify
        System.assertEquals('Simulated', result.processingResult, 'Result should be Simulated');
    }

    @isTest
    static void testMarkAsUpdated() {
        // Setup
        util_closer_CaseLogService.CaseEvaluationResult result = new util_closer_CaseLogService.CaseEvaluationResult();
        result.processingResult = 'Matched';

        // Execute
        Test.startTest();
        util_closer_CaseLogService.markAsUpdated(result);
        Test.stopTest();

        // Verify
        System.assertEquals('Updated', result.processingResult, 'Result should be Updated');
    }

    @isTest
    static void testMarkAsFailed() {
        // Setup
        util_closer_CaseLogService.CaseEvaluationResult result = new util_closer_CaseLogService.CaseEvaluationResult();
        result.processingResult = 'Matched';

        // Execute
        Test.startTest();
        util_closer_CaseLogService.markAsFailed(result, 'Test error');
        Test.stopTest();

        // Verify
        System.assertEquals('Failed', result.processingResult, 'Result should be Failed');
        System.assertEquals('Test error', result.errorMessage, 'Error message should be set');
    }

    @isTest
    static void testRuleEvaluationDetails() {
        // Setup
        util_closer_Batch_Log__c batchLog = util_closer_TestDataFactory.createBatchLog('Running', false);
        insert batchLog;

        util_closer_CaseLogService service = new util_closer_CaseLogService(batchLog.Id, 1);

        util_closer_CaseLogService.CaseEvaluationResult result = new util_closer_CaseLogService.CaseEvaluationResult();
        result.caseNumber = '00001';
        result.originalStatus = 'New';
        result.processingResult = 'Matched';
        result.ruleEvaluations.add(new util_closer_CaseLogService.RuleEvaluation(
            'Rule_1', 'Rule 1', false, 'Status mismatch'
        ));
        result.ruleEvaluations.add(new util_closer_CaseLogService.RuleEvaluation(
            'Rule_2', 'Rule 2', true, null
        ));

        // Execute
        Test.startTest();
        service.logCaseEvaluation(result);
        service.flushLogs();
        Test.stopTest();

        // Verify
        List<util_closer_Case_Log__c> logs = [
            SELECT Rule_Evaluation_Details__c
            FROM util_closer_Case_Log__c
            WHERE Batch_Log__c = :batchLog.Id
        ];

        System.assertEquals(1, logs.size(), 'Should have 1 case log');
        System.assert(logs[0].Rule_Evaluation_Details__c.contains('Rule_1'), 'Should contain Rule_1');
        System.assert(logs[0].Rule_Evaluation_Details__c.contains('Rule_2'), 'Should contain Rule_2');
    }

    @isTest
    static void testCreateDetailedResult() {
        // Setup
        Case testCase = new Case(Id = '500000000000001AAA', Status = 'New', Subject = 'Test Case');
        util_closer_RuleEngine.DetailedCaseChange change = new util_closer_RuleEngine.DetailedCaseChange('Closed', 'Auto closed');
        change.matchedRuleDeveloperName = 'Test_Rule';
        change.matchedRuleMasterLabel = 'Test Rule';
        change.rulesEvaluatedCount = 3;
        change.childRecordsChecked = true;
        change.childRecordsFound = 2;
        change.ruleEvaluations.add(new util_closer_RuleEngine.RuleEvaluationDetail(
            'Test_Rule', 'Test Rule', true, null
        ));

        // Execute
        Test.startTest();
        util_closer_CaseLogService.CaseEvaluationResult result =
            util_closer_CaseLogService.createDetailedResult(testCase, change, false);
        Test.stopTest();

        // Verify
        System.assertEquals('Test_Rule', result.matchedRuleDeveloperName, 'Matched rule should be set');
        System.assertEquals(3, result.rulesEvaluatedCount, 'Rules evaluated count should be 3');
        System.assertEquals(true, result.childRecordsChecked, 'Child records checked should be true');
        System.assertEquals(2, result.childRecordsFound, 'Child records found should be 2');
        System.assertEquals(1, result.ruleEvaluations.size(), 'Should have 1 rule evaluation');
    }

    @isTest
    static void testMarkAsUpdated_NullResult() {
        // Execute - should not throw exception
        Test.startTest();
        util_closer_CaseLogService.markAsUpdated(null);
        Test.stopTest();

        // Verify - no exception thrown
        System.assert(true, 'Should handle null gracefully');
    }

    @isTest
    static void testMarkAsFailed_NullResult() {
        // Execute - should not throw exception
        Test.startTest();
        util_closer_CaseLogService.markAsFailed(null, 'Error');
        Test.stopTest();

        // Verify - no exception thrown
        System.assert(true, 'Should handle null gracefully');
    }
}
