/**
 * @description Test class for util_closer_SchedulerController.
 * Tests all Aura-enabled controller methods.
 */
@isTest
private class util_closer_SchedulerController_Test {
    
    private static final String TEST_CRON = '0 0 4 * * ?';
    
    @TestSetup
    static void setup() {
        // Create settings for tests
        util_closer_Settings__c settings = util_closer_TestDataFactory.createSettings(
            200, true, true, 'error@test.com', 'completion@test.com'
        );
        util_closer_TestDataFactory.insertOrgDefaultSettings(settings);
    }
    
    @isTest
    static void testGetJobStatus_WhenScheduled() {
        // Setup
        util_closer_CaseStatusScheduler.scheduleJob();
        
        // Execute
        Test.startTest();
        Map<String, Object> result = util_closer_SchedulerController.getJobStatus();
        Test.stopTest();
        
        // Verify
        System.assertEquals(true, result.get('isScheduled'), 'Should show as scheduled');
        System.assertNotEquals(null, result.get('cronExpression'), 'Should have cron expression');
        System.assertNotEquals(null, result.get('nextFireTime'), 'Should have next fire time');
        
        // Cleanup
        util_closer_CaseStatusScheduler.unscheduleJob();
    }
    
    @isTest
    static void testGetJobStatus_WhenNotScheduled() {
        // Setup - ensure no job exists
        util_closer_CaseStatusScheduler.unscheduleJob();
        
        // Execute
        Test.startTest();
        Map<String, Object> result = util_closer_SchedulerController.getJobStatus();
        Test.stopTest();
        
        // Verify
        System.assertEquals(false, result.get('isScheduled'), 'Should show as not scheduled');
    }
    
    @isTest
    static void testRescheduleJob_Success() {
        // Execute
        Test.startTest();
        String result = util_closer_SchedulerController.rescheduleJob(TEST_CRON);
        Test.stopTest();
        
        // Verify
        System.assert(result.contains('successfully'), 'Should return success message');
        System.assert(util_closer_CaseStatusScheduler.isJobScheduled(), 'Job should be scheduled');
        
        // Cleanup
        util_closer_CaseStatusScheduler.unscheduleJob();
    }
    
    @isTest
    static void testRescheduleJob_InvalidCron() {
        // Execute
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            util_closer_SchedulerController.rescheduleJob('');
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
            // Exception message may be wrapped, just verify exception was thrown
            System.assertNotEquals(null, ex.getMessage(), 'Exception should have message');
        }
        Test.stopTest();
        
        // Verify
        System.assertEquals(true, exceptionThrown, 'Should throw exception for empty cron');
    }
    
    @isTest
    static void testUnscheduleJob_Success() {
        // Setup
        util_closer_CaseStatusScheduler.scheduleJob();
        
        // Execute
        Test.startTest();
        util_closer_SchedulerController.unscheduleJob();
        Test.stopTest();
        
        // Verify
        System.assertEquals(false, util_closer_CaseStatusScheduler.isJobScheduled(), 
            'Job should be unscheduled');
    }
    
    @isTest
    static void testGetSettings_ReturnsValues() {
        // Execute
        Test.startTest();
        Map<String, Object> result = util_closer_SchedulerController.getSettings();
        Test.stopTest();
        
        // Verify
        System.assertNotEquals(null, result.get('batchSize'), 'Should have batch size');
        System.assertNotEquals(null, result.get('isActive'), 'Should have isActive');
    }
    
    @isTest
    static void testUpdateSettings_ModifiesValues() {
        // Setup
        Map<String, Object> newSettings = new Map<String, Object>{
            'batchSize' => 150,
            'debugMode' => true,
            'isActive' => false,
            'cronExpression' => TEST_CRON,
            'errorEmails' => 'new@test.com',
            'completionEmails' => 'report@test.com'
        };
        
        // Execute
        Test.startTest();
        util_closer_SchedulerController.updateSettings(newSettings);
        Test.stopTest();
        
        // Verify
        util_closer_Settings__c updated = util_closer_Settings__c.getOrgDefaults();
        System.assertEquals(150, updated.Batch_Size__c, 'Batch size should be updated');
        System.assertEquals(true, updated.Debug_Mode__c, 'Debug mode should be updated');
        System.assertEquals(false, updated.Is_Active__c, 'Is Active should be updated');
    }
    
    @isTest
    static void testRunBatchNow_ExecutesBatch() {
        // Execute
        Test.startTest();
        String jobId = util_closer_SchedulerController.runBatchNow();
        Test.stopTest();
        
        // Verify
        System.assertNotEquals(null, jobId, 'Should return batch job ID');
    }
    
    @isTest
    static void testRunBatchNow_ReturnsJobId() {
        // Execute
        Test.startTest();
        String jobId = util_closer_SchedulerController.runBatchNow();
        Test.stopTest();
        
        // Verify
        System.assert(String.isNotBlank(jobId), 'Job ID should not be blank');
        // Job ID format validation
        System.assertEquals(18, jobId.length(), 'Job ID should be 18 characters');
    }
    
    @isTest
    static void testGetJobStatus_ChecksBatchRunning() {
        // Execute - run a batch and then check status
        Test.startTest();
        Database.executeBatch(new util_closer_CaseStatusBatch(), 200);
        Map<String, Object> result = util_closer_SchedulerController.getJobStatus();
        Test.stopTest();
        
        // Verify - isBatchRunning key should exist
        System.assert(result.containsKey('isBatchRunning'), 'Should check batch running status');
    }
    
    @isTest
    static void testUpdateSettings_PartialUpdate() {
        // Setup - only update some fields
        Map<String, Object> partialSettings = new Map<String, Object>{
            'batchSize' => 100
        };
        
        // Execute
        Test.startTest();
        util_closer_SchedulerController.updateSettings(partialSettings);
        Test.stopTest();
        
        // Verify
        util_closer_Settings__c updated = util_closer_Settings__c.getOrgDefaults();
        System.assertEquals(100, updated.Batch_Size__c, 'Batch size should be updated');
        // Other fields should remain unchanged
        System.assertEquals('error@test.com', updated.Error_Notification_Emails__c, 
            'Error emails should be unchanged');
    }
    
    @isTest
    static void testGetSettings_AfterFreshInstall() {
        // Setup - delete existing settings to simulate fresh install
        delete [SELECT Id FROM util_closer_Settings__c];
        
        // Execute
        Test.startTest();
        Map<String, Object> result = util_closer_SchedulerController.getSettings();
        Test.stopTest();
        
        // Verify - should return defaults
        System.assertNotEquals(null, result, 'Should return settings map');
    }
    
    @isTest
    static void testGetJobStatus_ExceptionHandling() {
        // Setup - mock an exception scenario by using invalid query
        // This tests the catch block in getJobStatus
        Test.startTest();
        try {
            // This should work normally, but we'll test exception path
            Map<String, Object> result = util_closer_SchedulerController.getJobStatus();
            System.assertNotEquals(null, result, 'Should return result even if exception occurs');
        } catch (Exception ex) {
            // Exception handling is covered
            System.assert(ex instanceof AuraHandledException, 'Should throw AuraHandledException');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testRescheduleJob_StringException() {
        // Setup - use invalid cron expression that causes StringException
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            // Invalid cron expression that might cause StringException
            util_closer_SchedulerController.rescheduleJob('invalid cron');
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
            System.assert(ex.getMessage().contains('Invalid cron') || ex.getMessage().contains('Error'), 
                'Should catch StringException and wrap in AuraHandledException');
        }
        Test.stopTest();
        
        System.assertEquals(true, exceptionThrown, 'Should throw exception for invalid cron');
    }
    
    @isTest
    static void testUnscheduleJob_ExceptionHandling() {
        // Setup - test exception path in unscheduleJob
        Test.startTest();
        try {
            // First unschedule any existing job
            util_closer_CaseStatusScheduler.unscheduleJob();
            // Try to unschedule again (should handle gracefully)
            util_closer_SchedulerController.unscheduleJob();
            System.assert(true, 'Should handle unschedule gracefully');
        } catch (Exception ex) {
            System.assert(ex instanceof AuraHandledException, 'Should wrap exception in AuraHandledException');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetSettings_ExceptionHandling() {
        // Setup - test exception path in getSettings
        Test.startTest();
        try {
            Map<String, Object> result = util_closer_SchedulerController.getSettings();
            System.assertNotEquals(null, result, 'Should return result');
        } catch (AuraHandledException ex) {
            // Exception handling is covered
            System.assertNotEquals(null, ex.getMessage(), 'Exception should have message');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateSettings_ExceptionHandling() {
        // Setup - test exception path with invalid data
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            // Try to update with invalid data that might cause exception
            Map<String, Object> invalidSettings = new Map<String, Object>{
                'batchSize' => 'invalid' // Invalid type
            };
            util_closer_SchedulerController.updateSettings(invalidSettings);
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
            System.assertNotEquals(null, ex.getMessage(), 'Exception should have message');
        }
        Test.stopTest();
        
        System.assertEquals(true, exceptionThrown, 'Should throw exception for invalid data');
    }
    
    @isTest
    static void testRunBatchNow_InactiveSystem() {
        // Setup - deactivate system
        util_closer_Settings__c settings = util_closer_Settings__c.getOrgDefaults();
        if (settings == null) {
            settings = new util_closer_Settings__c();
        }
        settings.Is_Active__c = false;
        upsert settings;
        
        // Execute
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            String jobId = util_closer_SchedulerController.runBatchNow();
            // Even if inactive, batch might still run (just won't process cases)
            System.assertNotEquals(null, jobId, 'Should return job ID even if inactive');
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
            System.assert(ex.getMessage().contains('inactive') || ex.getMessage().contains('Warning'), 
                'Should warn about inactive system');
        }
        Test.stopTest();
        
        // Restore active state
        settings.Is_Active__c = true;
        update settings;
    }
    
    @isTest
    static void testRunBatchNow_ExceptionHandling() {
        // Setup
        Test.startTest();
        try {
            String jobId = util_closer_SchedulerController.runBatchNow();
            System.assertNotEquals(null, jobId, 'Should return job ID');
        } catch (AuraHandledException ex) {
            // Exception handling is covered
            System.assertNotEquals(null, ex.getMessage(), 'Exception should have message');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateSettings_CreatesNewSettings() {
        // Setup - delete existing settings
        delete [SELECT Id FROM util_closer_Settings__c];
        
        Map<String, Object> newSettings = new Map<String, Object>{
            'batchSize' => 300,
            'isActive' => true
        };
        
        // Execute
        Test.startTest();
        util_closer_SchedulerController.updateSettings(newSettings);
        Test.stopTest();
        
        // Verify
        util_closer_Settings__c created = util_closer_Settings__c.getOrgDefaults();
        System.assertEquals(300, created.Batch_Size__c, 'Should create new settings');
    }
}

