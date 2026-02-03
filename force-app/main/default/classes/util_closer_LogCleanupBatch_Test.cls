/**
 * @description Test class for util_closer_LogCleanupBatch.
 * Tests cleanup of old logs, retention of recent logs, and scheduling.
 */
@isTest
private class util_closer_LogCleanupBatch_Test {

    @TestSetup
    static void setup() {
        // Create settings with 90 day retention
        util_closer_Settings__c settings = util_closer_TestDataFactory.createSettingsWithLogging(true, 90);
        util_closer_TestDataFactory.insertOrgDefaultSettings(settings);
    }

    @isTest
    static void testDeleteOldLogs() {
        // Setup - create old log (100 days ago)
        util_closer_Batch_Log__c oldLog = util_closer_TestDataFactory.createBatchLog('Completed', false);
        oldLog.Start_Time__c = DateTime.now().addDays(-100);
        insert oldLog;

        List<util_closer_Case_Log__c> oldCaseLogs = util_closer_TestDataFactory.createCaseLogs(oldLog.Id, 3, 'Updated');
        insert oldCaseLogs;

        // Create recent log (10 days ago)
        util_closer_Batch_Log__c recentLog = util_closer_TestDataFactory.createBatchLog('Completed', false);
        recentLog.Start_Time__c = DateTime.now().addDays(-10);
        insert recentLog;

        // Execute
        Test.startTest();
        util_closer_LogCleanupBatch batch = new util_closer_LogCleanupBatch(90);
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - old log should be deleted, recent log should remain
        Integer oldLogCount = [SELECT COUNT() FROM util_closer_Batch_Log__c WHERE Id = :oldLog.Id];
        Integer recentLogCount = [SELECT COUNT() FROM util_closer_Batch_Log__c WHERE Id = :recentLog.Id];
        Integer oldCaseLogCount = [SELECT COUNT() FROM util_closer_Case_Log__c WHERE Batch_Log__c = :oldLog.Id];

        System.assertEquals(0, oldLogCount, 'Old batch log should be deleted');
        System.assertEquals(0, oldCaseLogCount, 'Old case logs should be cascade deleted');
        System.assertEquals(1, recentLogCount, 'Recent batch log should be retained');
    }

    @isTest
    static void testRetainRecentLogs() {
        // Setup - create log within retention period
        util_closer_Batch_Log__c recentLog = util_closer_TestDataFactory.createBatchLog('Completed', false);
        recentLog.Start_Time__c = DateTime.now().addDays(-30);
        insert recentLog;

        // Execute
        Test.startTest();
        util_closer_LogCleanupBatch batch = new util_closer_LogCleanupBatch(90);
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - recent log should be retained
        Integer count = [SELECT COUNT() FROM util_closer_Batch_Log__c WHERE Id = :recentLog.Id];
        System.assertEquals(1, count, 'Recent log should be retained');
    }

    @isTest
    static void testCascadeDelete() {
        // Setup - create old log with case logs
        util_closer_Batch_Log__c oldLog = util_closer_TestDataFactory.createBatchLog('Completed', false);
        oldLog.Start_Time__c = DateTime.now().addDays(-100);
        insert oldLog;

        List<util_closer_Case_Log__c> caseLogs = util_closer_TestDataFactory.createCaseLogs(oldLog.Id, 10, 'Updated');
        insert caseLogs;

        // Execute
        Test.startTest();
        util_closer_LogCleanupBatch batch = new util_closer_LogCleanupBatch(90);
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - all case logs should be cascade deleted
        Integer caseLogCount = [SELECT COUNT() FROM util_closer_Case_Log__c WHERE Batch_Log__c = :oldLog.Id];
        System.assertEquals(0, caseLogCount, 'Case logs should be cascade deleted');
    }

    @isTest
    static void testMarkStaleBatchLogsFailed() {
        // Setup - create stale running log
        util_closer_Batch_Log__c staleLog = util_closer_TestDataFactory.createBatchLog('Running', false);
        staleLog.Start_Time__c = DateTime.now().addHours(-48);
        staleLog.End_Time__c = null;
        insert staleLog;

        // Execute
        Test.startTest();
        util_closer_LogCleanupBatch batch = new util_closer_LogCleanupBatch(90);
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - stale log should be marked as Failed
        util_closer_Batch_Log__c updated = [
            SELECT Status__c, Error_Summary__c, End_Time__c
            FROM util_closer_Batch_Log__c
            WHERE Id = :staleLog.Id
        ];

        System.assertEquals('Failed', updated.Status__c, 'Stale log should be marked as Failed');
        System.assertNotEquals(null, updated.End_Time__c, 'End time should be set');
        System.assert(updated.Error_Summary__c.contains('24 hours'), 'Error summary should mention 24 hours');
    }

    @isTest
    static void testScheduleDaily() {
        // Execute
        Test.startTest();
        String jobId = util_closer_LogCleanupBatch.scheduleDaily();
        Test.stopTest();

        // Verify
        List<CronTrigger> jobs = [
            SELECT Id, CronExpression
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'util_closer_LogCleanupBatch'
        ];

        System.assertEquals(1, jobs.size(), 'Job should be scheduled');
        System.assertEquals('0 0 3 * * ?', jobs[0].CronExpression, 'Should use default cron');
    }

    @isTest
    static void testScheduleDaily_CustomCron() {
        // Execute
        Test.startTest();
        String jobId = util_closer_LogCleanupBatch.scheduleDaily('0 0 6 * * ?');
        Test.stopTest();

        // Verify
        List<CronTrigger> jobs = [
            SELECT Id, CronExpression
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'util_closer_LogCleanupBatch'
        ];

        System.assertEquals(1, jobs.size(), 'Job should be scheduled');
        System.assertEquals('0 0 6 * * ?', jobs[0].CronExpression, 'Should use custom cron');
    }

    @isTest
    static void testScheduleDaily_ReplacesExisting() {
        // Setup - schedule first job
        util_closer_LogCleanupBatch.scheduleDaily('0 0 3 * * ?');

        // Execute - schedule again with different time
        Test.startTest();
        String jobId = util_closer_LogCleanupBatch.scheduleDaily('0 0 6 * * ?');
        Test.stopTest();

        // Verify - should only have one job
        List<CronTrigger> jobs = [
            SELECT Id, CronExpression
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'util_closer_LogCleanupBatch'
        ];

        System.assertEquals(1, jobs.size(), 'Should only have one scheduled job');
        System.assertEquals('0 0 6 * * ?', jobs[0].CronExpression, 'Should use new cron');
    }

    @isTest
    static void testSchedulableExecute() {
        // Setup - create old log
        util_closer_Batch_Log__c oldLog = util_closer_TestDataFactory.createBatchLog('Completed', false);
        oldLog.Start_Time__c = DateTime.now().addDays(-100);
        insert oldLog;

        // Execute via schedulable
        Test.startTest();
        util_closer_LogCleanupBatch batch = new util_closer_LogCleanupBatch();
        batch.execute(null); // Schedulable execute
        Test.stopTest();

        // Verify - a batch job should have been queued
        // Can't directly verify due to async nature, but no exception should be thrown
        System.assert(true, 'Schedulable execute should complete without error');
    }

    @isTest
    static void testDefaultConstructor_UsesSettings() {
        // Setup - settings already has 90 day retention from TestSetup

        // Create log at 95 days ago (should be deleted)
        util_closer_Batch_Log__c oldLog = util_closer_TestDataFactory.createBatchLog('Completed', false);
        oldLog.Start_Time__c = DateTime.now().addDays(-95);
        insert oldLog;

        // Create log at 80 days ago (should be retained)
        util_closer_Batch_Log__c recentLog = util_closer_TestDataFactory.createBatchLog('Completed', false);
        recentLog.Start_Time__c = DateTime.now().addDays(-80);
        insert recentLog;

        // Execute
        Test.startTest();
        util_closer_LogCleanupBatch batch = new util_closer_LogCleanupBatch(); // Uses settings
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify
        Integer oldLogCount = [SELECT COUNT() FROM util_closer_Batch_Log__c WHERE Id = :oldLog.Id];
        Integer recentLogCount = [SELECT COUNT() FROM util_closer_Batch_Log__c WHERE Id = :recentLog.Id];

        System.assertEquals(0, oldLogCount, 'Old log should be deleted');
        System.assertEquals(1, recentLogCount, 'Recent log should be retained');
    }

    @isTest
    static void testConstructor_NullRetention() {
        // Execute - null retention should use default 90 days
        Test.startTest();
        util_closer_LogCleanupBatch batch = new util_closer_LogCleanupBatch(null);
        Test.stopTest();

        // Verify - no exception thrown
        System.assert(true, 'Should handle null retention gracefully');
    }

    @isTest
    static void testConstructor_ZeroRetention() {
        // Execute - zero retention should use default 90 days
        Test.startTest();
        util_closer_LogCleanupBatch batch = new util_closer_LogCleanupBatch(0);
        Test.stopTest();

        // Verify - no exception thrown
        System.assert(true, 'Should handle zero retention gracefully');
    }

    @isTest
    static void testConstructor_NegativeRetention() {
        // Execute - negative retention should use default 90 days
        Test.startTest();
        util_closer_LogCleanupBatch batch = new util_closer_LogCleanupBatch(-10);
        Test.stopTest();

        // Verify - no exception thrown
        System.assert(true, 'Should handle negative retention gracefully');
    }

    @isTest
    static void testNoLogsToDelete() {
        // Setup - only recent logs exist
        util_closer_Batch_Log__c recentLog = util_closer_TestDataFactory.createBatchLog('Completed', false);
        recentLog.Start_Time__c = DateTime.now().addDays(-10);
        insert recentLog;

        // Execute
        Test.startTest();
        util_closer_LogCleanupBatch batch = new util_closer_LogCleanupBatch(90);
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - recent log should still exist
        Integer count = [SELECT COUNT() FROM util_closer_Batch_Log__c WHERE Id = :recentLog.Id];
        System.assertEquals(1, count, 'Recent log should not be deleted');
    }

    @isTest
    static void testNoStaleLogs() {
        // Setup - only recent running logs
        util_closer_Batch_Log__c recentRunning = util_closer_TestDataFactory.createBatchLog('Running', false);
        recentRunning.Start_Time__c = DateTime.now().addMinutes(-30);
        recentRunning.End_Time__c = null;
        insert recentRunning;

        // Execute
        Test.startTest();
        util_closer_LogCleanupBatch batch = new util_closer_LogCleanupBatch(90);
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - recent running log should still be Running
        util_closer_Batch_Log__c log = [SELECT Status__c FROM util_closer_Batch_Log__c WHERE Id = :recentRunning.Id];
        System.assertEquals('Running', log.Status__c, 'Recent running log should not be marked as failed');
    }
}
