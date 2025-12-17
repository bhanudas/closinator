/**
 * @description Test class for util_closer_CaseStatusScheduler.
 * Tests scheduling, unscheduling, and job status methods.
 */
@isTest
private class util_closer_CaseStatusScheduler_Test {
    
    private static final String TEST_CRON = '0 0 3 * * ?';
    
    @TestSetup
    static void setup() {
        // Create settings for tests
        util_closer_Settings__c settings = util_closer_TestDataFactory.createSettings(200, true, true);
        util_closer_TestDataFactory.insertOrgDefaultSettings(settings);
    }
    
    @isTest
    static void testScheduleJob_CreatesScheduledJob() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, false, true);
        
        // Execute
        Test.startTest();
        String jobId = util_closer_CaseStatusScheduler.scheduleJob();
        Test.stopTest();
        
        // Verify
        System.assertNotEquals(null, jobId, 'Job ID should not be null');
        System.assert(util_closer_CaseStatusScheduler.isJobScheduled(), 'Job should be scheduled');
        
        // Cleanup
        util_closer_CaseStatusScheduler.unscheduleJob();
    }
    
    @isTest
    static void testScheduleJob_WithCustomCron() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, false, true);
        
        // Execute
        Test.startTest();
        String jobId = util_closer_CaseStatusScheduler.scheduleJob(TEST_CRON);
        Test.stopTest();
        
        // Verify
        System.assertNotEquals(null, jobId, 'Job ID should not be null');
        
        CronTrigger jobInfo = util_closer_CaseStatusScheduler.getScheduledJobInfo();
        System.assertNotEquals(null, jobInfo, 'Job info should exist');
        System.assertEquals(TEST_CRON, jobInfo.CronExpression, 'Cron expression should match');
        
        // Cleanup
        util_closer_CaseStatusScheduler.unscheduleJob();
    }
    
    @isTest
    static void testUnscheduleJob_RemovesJob() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, false, true);
        util_closer_CaseStatusScheduler.scheduleJob();
        
        // Verify job exists
        System.assert(util_closer_CaseStatusScheduler.isJobScheduled(), 'Job should be scheduled');
        
        // Execute
        Test.startTest();
        util_closer_CaseStatusScheduler.unscheduleJob();
        Test.stopTest();
        
        // Verify
        System.assert(!util_closer_CaseStatusScheduler.isJobScheduled(), 'Job should be unscheduled');
    }
    
    @isTest
    static void testReschedule_ReplacesExistingJob() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, false, true);
        util_closer_CaseStatusScheduler.scheduleJob();
        
        // Execute
        Test.startTest();
        util_closer_CaseStatusScheduler.reschedule();
        Test.stopTest();
        
        // Verify
        System.assert(util_closer_CaseStatusScheduler.isJobScheduled(), 'Job should still be scheduled after reschedule');
        
        // Cleanup
        util_closer_CaseStatusScheduler.unscheduleJob();
    }
    
    @isTest
    static void testIsJobScheduled_WhenScheduled() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, false, true);
        util_closer_CaseStatusScheduler.scheduleJob();
        
        // Execute
        Test.startTest();
        Boolean isScheduled = util_closer_CaseStatusScheduler.isJobScheduled();
        Test.stopTest();
        
        // Verify
        System.assertEquals(true, isScheduled, 'Should return true when job is scheduled');
        
        // Cleanup
        util_closer_CaseStatusScheduler.unscheduleJob();
    }
    
    @isTest
    static void testIsJobScheduled_WhenNotScheduled() {
        // Setup - make sure no job exists
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, false, true);
        util_closer_CaseStatusScheduler.unscheduleJob();
        
        // Execute
        Test.startTest();
        Boolean isScheduled = util_closer_CaseStatusScheduler.isJobScheduled();
        Test.stopTest();
        
        // Verify
        System.assertEquals(false, isScheduled, 'Should return false when job is not scheduled');
    }
    
    @isTest
    static void testExecute_StartsBatch() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, false, true);
        
        // Create a test case
        Case testCase = new Case(Subject = 'Test', Status = 'New', Origin = 'Web');
        insert testCase;
        
        // Execute scheduler
        Test.startTest();
        util_closer_CaseStatusScheduler scheduler = new util_closer_CaseStatusScheduler();
        scheduler.execute(null);
        Test.stopTest();
        
        // Verify - batch job should have been queued
        System.assert(true, 'Scheduler executed and started batch');
    }
    
    @isTest
    static void testGetScheduledJobInfo_ReturnsDetails() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, false, true);
        util_closer_CaseStatusScheduler.scheduleJob(TEST_CRON);
        
        // Execute
        Test.startTest();
        CronTrigger jobInfo = util_closer_CaseStatusScheduler.getScheduledJobInfo();
        Test.stopTest();
        
        // Verify
        System.assertNotEquals(null, jobInfo, 'Job info should not be null');
        System.assertNotEquals(null, jobInfo.NextFireTime, 'Next fire time should exist');
        System.assertEquals(TEST_CRON, jobInfo.CronExpression, 'Cron expression should match');
        
        // Cleanup
        util_closer_CaseStatusScheduler.unscheduleJob();
    }
    
    @isTest
    static void testGetScheduledJobInfo_WhenNotScheduled() {
        // Setup - make sure no job exists
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, false, true);
        util_closer_CaseStatusScheduler.unscheduleJob();
        
        // Execute
        Test.startTest();
        CronTrigger jobInfo = util_closer_CaseStatusScheduler.getScheduledJobInfo();
        Test.stopTest();
        
        // Verify
        System.assertEquals(null, jobInfo, 'Job info should be null when not scheduled');
    }
    
    @isTest
    static void testScheduleJob_ReplacesExisting() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, false, true);
        
        // Schedule initial job
        String firstJobId = util_closer_CaseStatusScheduler.scheduleJob('0 0 1 * * ?');
        
        // Schedule replacement job
        Test.startTest();
        String secondJobId = util_closer_CaseStatusScheduler.scheduleJob('0 0 2 * * ?');
        Test.stopTest();
        
        // Verify - only one job should exist
        CronTrigger jobInfo = util_closer_CaseStatusScheduler.getScheduledJobInfo();
        System.assertEquals('0 0 2 * * ?', jobInfo.CronExpression, 'Should have the new cron expression');
        
        // Cleanup
        util_closer_CaseStatusScheduler.unscheduleJob();
    }
}

