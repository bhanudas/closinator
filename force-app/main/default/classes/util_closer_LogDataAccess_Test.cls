/**
 * @description Test class for util_closer_LogDataAccess.
 * Tests all CRUD operations for log data access.
 */
@isTest
private class util_closer_LogDataAccess_Test {

    @isTest
    static void testInsertBatchLog() {
        // Setup
        util_closer_Batch_Log__c batchLog = util_closer_TestDataFactory.createBatchLog('Running', false);

        // Execute
        Test.startTest();
        util_closer_Batch_Log__c result = util_closer_LogDataAccess.insertBatchLog(batchLog);
        Test.stopTest();

        // Verify
        System.assertNotEquals(null, result.Id, 'Batch log should be inserted with Id');
        System.assertEquals('Running', result.Status__c, 'Status should be Running');
    }

    @isTest
    static void testUpdateBatchLog() {
        // Setup
        util_closer_Batch_Log__c batchLog = util_closer_TestDataFactory.createBatchLog('Running', false);
        insert batchLog;

        // Execute
        Test.startTest();
        batchLog.Status__c = 'Completed';
        batchLog.End_Time__c = DateTime.now();
        util_closer_LogDataAccess.updateBatchLog(batchLog);
        Test.stopTest();

        // Verify
        util_closer_Batch_Log__c updated = [SELECT Status__c, End_Time__c FROM util_closer_Batch_Log__c WHERE Id = :batchLog.Id];
        System.assertEquals('Completed', updated.Status__c, 'Status should be Completed');
        System.assertNotEquals(null, updated.End_Time__c, 'End time should be set');
    }

    @isTest
    static void testInsertCaseLogs() {
        // Setup
        util_closer_Batch_Log__c batchLog = util_closer_TestDataFactory.createBatchLog('Running', false);
        insert batchLog;

        List<util_closer_Case_Log__c> caseLogs = util_closer_TestDataFactory.createCaseLogs(batchLog.Id, 5, 'Updated');

        // Execute
        Test.startTest();
        List<Database.SaveResult> results = util_closer_LogDataAccess.insertCaseLogs(caseLogs);
        Test.stopTest();

        // Verify
        System.assertEquals(5, results.size(), 'Should have 5 save results');
        for (Database.SaveResult sr : results) {
            System.assert(sr.isSuccess(), 'All inserts should succeed');
        }

        Integer count = [SELECT COUNT() FROM util_closer_Case_Log__c WHERE Batch_Log__c = :batchLog.Id];
        System.assertEquals(5, count, 'Should have 5 case logs');
    }

    @isTest
    static void testQueryBatchLogsOlderThan() {
        // Setup - create old and new batch logs
        util_closer_Batch_Log__c oldLog = util_closer_TestDataFactory.createBatchLog('Completed', false);
        oldLog.Start_Time__c = DateTime.now().addDays(-100);
        insert oldLog;

        util_closer_Batch_Log__c newLog = util_closer_TestDataFactory.createBatchLog('Completed', false);
        newLog.Start_Time__c = DateTime.now().addDays(-10);
        insert newLog;

        DateTime cutoff = DateTime.now().addDays(-50);

        // Execute
        Test.startTest();
        List<util_closer_Batch_Log__c> results = util_closer_LogDataAccess.queryBatchLogsOlderThan(cutoff);
        Test.stopTest();

        // Verify - only old log should be returned
        System.assertEquals(1, results.size(), 'Should find 1 old log');
        System.assertEquals(oldLog.Id, results[0].Id, 'Should be the old log');
    }

    @isTest
    static void testQueryStaleBatchLogs() {
        // Setup - create stale running log
        util_closer_Batch_Log__c staleLog = util_closer_TestDataFactory.createBatchLog('Running', false);
        staleLog.Start_Time__c = DateTime.now().addHours(-48);
        staleLog.End_Time__c = null;
        insert staleLog;

        util_closer_Batch_Log__c recentLog = util_closer_TestDataFactory.createBatchLog('Running', false);
        recentLog.Start_Time__c = DateTime.now().addMinutes(-30);
        recentLog.End_Time__c = null;
        insert recentLog;

        // Execute
        Test.startTest();
        List<util_closer_Batch_Log__c> results = util_closer_LogDataAccess.queryStaleBatchLogs(24);
        Test.stopTest();

        // Verify - only stale log should be returned
        System.assertEquals(1, results.size(), 'Should find 1 stale log');
        System.assertEquals(staleLog.Id, results[0].Id, 'Should be the stale log');
    }

    @isTest
    static void testDeleteBatchLogs() {
        // Setup
        util_closer_Batch_Log__c batchLog = util_closer_TestDataFactory.createBatchLog('Completed', false);
        insert batchLog;

        List<util_closer_Case_Log__c> caseLogs = util_closer_TestDataFactory.createCaseLogs(batchLog.Id, 3, 'Updated');
        insert caseLogs;

        // Execute
        Test.startTest();
        util_closer_LogDataAccess.deleteBatchLogs(new List<util_closer_Batch_Log__c>{ batchLog });
        Test.stopTest();

        // Verify - batch log and case logs should be deleted (cascade)
        Integer batchCount = [SELECT COUNT() FROM util_closer_Batch_Log__c WHERE Id = :batchLog.Id];
        Integer caseLogCount = [SELECT COUNT() FROM util_closer_Case_Log__c WHERE Batch_Log__c = :batchLog.Id];

        System.assertEquals(0, batchCount, 'Batch log should be deleted');
        System.assertEquals(0, caseLogCount, 'Case logs should be cascade deleted');
    }

    @isTest
    static void testQueryBatchLogByJobId() {
        // Setup
        util_closer_Batch_Log__c batchLog = util_closer_TestDataFactory.createBatchLog('Completed', false);
        String jobId = batchLog.Batch_Job_Id__c;
        insert batchLog;

        // Execute
        Test.startTest();
        util_closer_Batch_Log__c result = util_closer_LogDataAccess.queryBatchLogByJobId(jobId);
        Test.stopTest();

        // Verify
        System.assertNotEquals(null, result, 'Should find batch log');
        System.assertEquals(batchLog.Id, result.Id, 'Should be the correct batch log');
    }

    @isTest
    static void testQueryBatchLogByJobId_NotFound() {
        // Execute
        Test.startTest();
        util_closer_Batch_Log__c result = util_closer_LogDataAccess.queryBatchLogByJobId('707000000000000AAA');
        Test.stopTest();

        // Verify
        System.assertEquals(null, result, 'Should return null when not found');
    }

    @isTest
    static void testInsertCaseLogs_PartialSuccess() {
        // Setup
        util_closer_Batch_Log__c batchLog = util_closer_TestDataFactory.createBatchLog('Running', false);
        insert batchLog;

        List<util_closer_Case_Log__c> caseLogs = util_closer_TestDataFactory.createCaseLogs(batchLog.Id, 3, 'Updated');

        // Execute with allOrNone=false (partial success mode)
        Test.startTest();
        List<Database.SaveResult> results = util_closer_LogDataAccess.insertCaseLogs(caseLogs);
        Test.stopTest();

        // Verify
        System.assertEquals(3, results.size(), 'Should have 3 results');
    }
}
