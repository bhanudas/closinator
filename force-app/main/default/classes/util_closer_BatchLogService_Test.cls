/**
 * @description Test class for util_closer_BatchLogService.
 * Tests batch log creation, updates, finalization, and JSON serialization.
 */
@isTest
private class util_closer_BatchLogService_Test {

    @isTest
    static void testCreateBatchLog_FullMode() {
        // Setup
        List<util_closer_Case_Status_Rule__mdt> mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            new util_closer_Case_Status_Rule__mdt(
                DeveloperName = 'Test_Rule_1',
                MasterLabel = 'Test Rule 1',
                Is_Active__c = true
            ),
            new util_closer_Case_Status_Rule__mdt(
                DeveloperName = 'Test_Rule_2',
                MasterLabel = 'Test Rule 2',
                Is_Active__c = true
            )
        };

        // Execute
        Test.startTest();
        util_closer_Batch_Log__c result = util_closer_BatchLogService.createBatchLog(
            '707000000000001AAA',
            mockRules,
            false
        );
        Test.stopTest();

        // Verify
        System.assertNotEquals(null, result.Id, 'Batch log should be created');
        System.assertEquals('Running', result.Status__c, 'Status should be Running');
        System.assertEquals('Full', result.Execution_Mode__c, 'Mode should be Full');
        System.assertEquals(2, result.Active_Rules_Count__c, 'Should have 2 active rules');
        System.assert(result.Active_Rules_JSON__c.contains('Test_Rule_1'), 'JSON should contain rule names');
        System.assertEquals(UserInfo.getUserId(), result.Running_User__c, 'Running user should be current user');
    }

    @isTest
    static void testCreateBatchLog_SimulationMode() {
        // Setup
        List<util_closer_Case_Status_Rule__mdt> mockRules = new List<util_closer_Case_Status_Rule__mdt>();

        // Execute
        Test.startTest();
        util_closer_Batch_Log__c result = util_closer_BatchLogService.createBatchLog(
            '707000000000002AAA',
            mockRules,
            true
        );
        Test.stopTest();

        // Verify
        System.assertEquals('Simulation', result.Execution_Mode__c, 'Mode should be Simulation');
        System.assertEquals(0, result.Active_Rules_Count__c, 'Should have 0 active rules');
        System.assertEquals('[]', result.Active_Rules_JSON__c, 'JSON should be empty array');
    }

    @isTest
    static void testUpdateBatchProgress() {
        // Setup
        util_closer_Batch_Log__c batchLog = util_closer_TestDataFactory.createBatchLog('Running', false);
        insert batchLog;

        util_closer_BatchMetrics metrics = new util_closer_BatchMetrics();
        metrics.totalRecordsProcessed = 100;
        metrics.totalRecordsUpdated = 80;
        metrics.totalRecordsFailed = 5;
        metrics.totalBatchesExecuted = 2;
        metrics.statusTransitionCounts.put('New -> Closed', 80);
        metrics.errors.add('Error 1');

        // Execute
        Test.startTest();
        util_closer_BatchLogService.updateBatchProgress(batchLog, metrics);
        Test.stopTest();

        // Verify
        util_closer_Batch_Log__c updated = [
            SELECT Total_Records_Processed__c, Total_Records_Updated__c, Total_Records_Failed__c,
                   Total_Batches_Executed__c, Status_Transitions_JSON__c, Error_Summary__c
            FROM util_closer_Batch_Log__c
            WHERE Id = :batchLog.Id
        ];

        System.assertEquals(100, updated.Total_Records_Processed__c, 'Processed count should be 100');
        System.assertEquals(80, updated.Total_Records_Updated__c, 'Updated count should be 80');
        System.assertEquals(5, updated.Total_Records_Failed__c, 'Failed count should be 5');
        System.assertEquals(2, updated.Total_Batches_Executed__c, 'Batch count should be 2');
        System.assert(updated.Status_Transitions_JSON__c.contains('New -> Closed'), 'Should contain transitions');
        System.assert(updated.Error_Summary__c.contains('Error 1'), 'Should contain errors');
    }

    @isTest
    static void testFinalizeBatchLog_Success() {
        // Setup
        util_closer_Batch_Log__c batchLog = util_closer_TestDataFactory.createBatchLog('Running', false);
        insert batchLog;

        util_closer_BatchMetrics metrics = new util_closer_BatchMetrics();
        metrics.totalRecordsProcessed = 50;
        metrics.totalRecordsUpdated = 50;
        metrics.totalRecordsFailed = 0;
        metrics.totalBatchesExecuted = 1;

        // Execute
        Test.startTest();
        util_closer_BatchLogService.finalizeBatchLog(batchLog, metrics);
        Test.stopTest();

        // Verify
        util_closer_Batch_Log__c updated = [
            SELECT Status__c, End_Time__c
            FROM util_closer_Batch_Log__c
            WHERE Id = :batchLog.Id
        ];

        System.assertEquals('Completed', updated.Status__c, 'Status should be Completed');
        System.assertNotEquals(null, updated.End_Time__c, 'End time should be set');
    }

    @isTest
    static void testFinalizeBatchLog_WithErrors() {
        // Setup
        util_closer_Batch_Log__c batchLog = util_closer_TestDataFactory.createBatchLog('Running', false);
        insert batchLog;

        util_closer_BatchMetrics metrics = new util_closer_BatchMetrics();
        metrics.totalRecordsProcessed = 50;
        metrics.totalRecordsUpdated = 45;
        metrics.totalRecordsFailed = 5;
        metrics.totalBatchesExecuted = 1;

        // Execute
        Test.startTest();
        util_closer_BatchLogService.finalizeBatchLog(batchLog, metrics);
        Test.stopTest();

        // Verify
        util_closer_Batch_Log__c updated = [
            SELECT Status__c
            FROM util_closer_Batch_Log__c
            WHERE Id = :batchLog.Id
        ];

        System.assertEquals('Completed with Errors', updated.Status__c, 'Status should be Completed with Errors');
    }

    @isTest
    static void testMarkBatchLogFailed() {
        // Setup
        util_closer_Batch_Log__c batchLog = util_closer_TestDataFactory.createBatchLog('Running', false);
        insert batchLog;

        // Execute
        Test.startTest();
        util_closer_BatchLogService.markBatchLogFailed(batchLog, 'Test error message');
        Test.stopTest();

        // Verify
        util_closer_Batch_Log__c updated = [
            SELECT Status__c, Error_Summary__c, End_Time__c
            FROM util_closer_Batch_Log__c
            WHERE Id = :batchLog.Id
        ];

        System.assertEquals('Failed', updated.Status__c, 'Status should be Failed');
        System.assertEquals('Test error message', updated.Error_Summary__c, 'Error summary should be set');
        System.assertNotEquals(null, updated.End_Time__c, 'End time should be set');
    }

    @isTest
    static void testRulesToJson_WithRules() {
        // Setup
        List<util_closer_Case_Status_Rule__mdt> rules = new List<util_closer_Case_Status_Rule__mdt>{
            new util_closer_Case_Status_Rule__mdt(
                DeveloperName = 'Rule_A',
                MasterLabel = 'Rule A'
            ),
            new util_closer_Case_Status_Rule__mdt(
                DeveloperName = 'Rule_B',
                MasterLabel = 'Rule B'
            )
        };

        // Execute
        Test.startTest();
        String json = util_closer_BatchLogService.rulesToJson(rules);
        Test.stopTest();

        // Verify
        System.assert(json.contains('Rule_A'), 'JSON should contain Rule_A');
        System.assert(json.contains('Rule_B'), 'JSON should contain Rule_B');
        System.assert(json.startsWith('['), 'JSON should be an array');
    }

    @isTest
    static void testRulesToJson_Empty() {
        // Execute
        Test.startTest();
        String json = util_closer_BatchLogService.rulesToJson(null);
        Test.stopTest();

        // Verify
        System.assertEquals('[]', json, 'Should return empty array for null');
    }

    @isTest
    static void testTransitionsToJson() {
        // Setup
        Map<String, Integer> transitions = new Map<String, Integer>{
            'New -> Closed' => 10,
            'Open -> Closed' => 5
        };

        // Execute
        Test.startTest();
        String json = util_closer_BatchLogService.transitionsToJson(transitions);
        Test.stopTest();

        // Verify
        System.assert(json.contains('New -> Closed'), 'JSON should contain transition');
        System.assert(json.contains('10'), 'JSON should contain count');
    }

    @isTest
    static void testTransitionsToJson_Empty() {
        // Execute
        Test.startTest();
        String json = util_closer_BatchLogService.transitionsToJson(null);
        Test.stopTest();

        // Verify
        System.assertEquals('{}', json, 'Should return empty object for null');
    }

    @isTest
    static void testTruncateText() {
        // Setup - create a string longer than the limit
        String longText = '';
        for (Integer i = 0; i < 4000; i++) {
            longText += 'x';
        }

        // Execute
        Test.startTest();
        String result = util_closer_BatchLogService.truncateText(longText, 100);
        Test.stopTest();

        // Verify
        System.assertEquals(100, result.length(), 'Should be truncated to 100 chars');
        System.assert(result.contains('... [truncated]'), 'Should contain truncation indicator');
    }

    @isTest
    static void testTruncateText_ShortText() {
        // Execute
        Test.startTest();
        String result = util_closer_BatchLogService.truncateText('short text', 100);
        Test.stopTest();

        // Verify
        System.assertEquals('short text', result, 'Should not be truncated');
    }

    @isTest
    static void testTruncateText_Null() {
        // Execute
        Test.startTest();
        String result = util_closer_BatchLogService.truncateText(null, 100);
        Test.stopTest();

        // Verify
        System.assertEquals(null, result, 'Should return null for null input');
    }

    @isTest
    static void testUpdateBatchProgress_NullBatchLog() {
        // Setup
        util_closer_BatchMetrics metrics = new util_closer_BatchMetrics();

        // Execute - should not throw exception
        Test.startTest();
        util_closer_BatchLogService.updateBatchProgress(null, metrics);
        Test.stopTest();

        // Verify - no exception thrown
        System.assert(true, 'Should handle null batch log gracefully');
    }

    @isTest
    static void testFinalizeBatchLog_NullBatchLog() {
        // Setup
        util_closer_BatchMetrics metrics = new util_closer_BatchMetrics();

        // Execute - should not throw exception
        Test.startTest();
        util_closer_BatchLogService.finalizeBatchLog(null, metrics);
        Test.stopTest();

        // Verify - no exception thrown
        System.assert(true, 'Should handle null batch log gracefully');
    }

    @isTest
    static void testMarkBatchLogFailed_NullBatchLog() {
        // Execute - should not throw exception
        Test.startTest();
        util_closer_BatchLogService.markBatchLogFailed(null, 'Error');
        Test.stopTest();

        // Verify - no exception thrown
        System.assert(true, 'Should handle null batch log gracefully');
    }

    @isTest
    static void testCreateBatchLog_NullRules() {
        // Execute
        Test.startTest();
        util_closer_Batch_Log__c result = util_closer_BatchLogService.createBatchLog(
            '707000000000003AAA',
            null,
            false
        );
        Test.stopTest();

        // Verify
        System.assertEquals(0, result.Active_Rules_Count__c, 'Should have 0 rules for null input');
    }
}
