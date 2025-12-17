/**
 * @description Test class for util_closer_NotificationService.
 * Tests email notification functionality for errors and completion reports.
 */
@isTest
private class util_closer_NotificationService_Test {
    
    @isTest
    static void testSendErrorNotification_SendsEmail() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, 'error@test.com', null
        );
        
        Exception testException = new CalloutException('Test error message');
        
        // Execute
        Test.startTest();
        Integer emailsBefore = Limits.getEmailInvocations();
        util_closer_NotificationService.sendErrorNotification(
            'Test Error Subject',
            'Test error body content',
            testException
        );
        Integer emailsAfter = Limits.getEmailInvocations();
        Test.stopTest();
        
        // Verify - email should have been sent
        System.assertEquals(1, emailsAfter - emailsBefore, 'One email should be sent');
    }
    
    @isTest
    static void testSendErrorNotification_NoRecipients() {
        // Setup - no error emails configured
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, null, null
        );
        
        // Execute - should not throw exception
        Test.startTest();
        Integer emailsBefore = Limits.getEmailInvocations();
        util_closer_NotificationService.sendErrorNotification(
            'Test Error Subject',
            'Test error body content',
            null
        );
        Integer emailsAfter = Limits.getEmailInvocations();
        Test.stopTest();
        
        // Verify - no email should be sent
        System.assertEquals(0, emailsAfter - emailsBefore, 'No email should be sent when no recipients configured');
    }
    
    @isTest
    static void testSendErrorNotification_NullException() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, 'error@test.com', null
        );
        
        // Execute - should handle null exception gracefully
        Test.startTest();
        Integer emailsBefore = Limits.getEmailInvocations();
        util_closer_NotificationService.sendErrorNotification(
            'Test Error Subject',
            'Test error body content',
            null
        );
        Integer emailsAfter = Limits.getEmailInvocations();
        Test.stopTest();
        
        // Verify
        System.assertEquals(1, emailsAfter - emailsBefore, 'Email should be sent even with null exception');
    }
    
    @isTest
    static void testSendCompletionReport_SendsEmail() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, null, 'completion@test.com'
        );
        
        util_closer_BatchMetrics metrics = new util_closer_BatchMetrics();
        metrics.totalRecordsProcessed = 100;
        metrics.totalRecordsUpdated = 50;
        metrics.totalRecordsFailed = 5;
        metrics.totalBatchesExecuted = 2;
        metrics.endTime = DateTime.now();
        metrics.recordSuccess('New', 'Closed');
        
        // Execute
        Test.startTest();
        Integer emailsBefore = Limits.getEmailInvocations();
        util_closer_NotificationService.sendCompletionReport(metrics);
        Integer emailsAfter = Limits.getEmailInvocations();
        Test.stopTest();
        
        // Verify
        System.assertEquals(1, emailsAfter - emailsBefore, 'One email should be sent');
    }
    
    @isTest
    static void testSendCompletionReport_IncludesMetrics() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, null, 'completion@test.com'
        );
        
        util_closer_BatchMetrics metrics = new util_closer_BatchMetrics();
        metrics.totalRecordsProcessed = 250;
        metrics.totalRecordsUpdated = 100;
        metrics.totalRecordsFailed = 10;
        metrics.totalBatchesExecuted = 3;
        metrics.endTime = DateTime.now();
        metrics.recordSuccess('Waiting on Customer', 'Closed');
        metrics.recordSuccess('Waiting on Customer', 'Closed');
        metrics.recordFailure('Validation error', null);
        
        // Verify metrics email body contains expected content
        String emailBody = metrics.toEmailBody();
        
        System.assert(emailBody.contains('250') || emailBody.contains('100'), 
            'Email body should contain metrics values');
        System.assert(emailBody.containsIgnoreCase('Closed') || emailBody.containsIgnoreCase('transition'), 
            'Email body should contain status transition info');
    }
    
    @isTest
    static void testSendCompletionReport_NoRecipients() {
        // Setup - no completion emails configured
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, null, null
        );
        
        util_closer_BatchMetrics metrics = new util_closer_BatchMetrics();
        
        // Execute - should not throw exception
        Test.startTest();
        Integer emailsBefore = Limits.getEmailInvocations();
        util_closer_NotificationService.sendCompletionReport(metrics);
        Integer emailsAfter = Limits.getEmailInvocations();
        Test.stopTest();
        
        // Verify - no email should be sent
        System.assertEquals(0, emailsAfter - emailsBefore, 'No email should be sent when no recipients configured');
    }
    
    @isTest
    static void testSendErrorNotification_MultipleRecipients() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, 'user1@test.com;user2@test.com;user3@test.com', null
        );
        
        // Execute
        Test.startTest();
        Integer emailsBefore = Limits.getEmailInvocations();
        util_closer_NotificationService.sendErrorNotification(
            'Test Error',
            'Error details',
            null
        );
        Integer emailsAfter = Limits.getEmailInvocations();
        Test.stopTest();
        
        // Verify - single email to multiple recipients
        System.assertEquals(1, emailsAfter - emailsBefore, 'One email should be sent to multiple recipients');
    }
}

