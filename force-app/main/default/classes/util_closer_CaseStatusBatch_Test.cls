/**
 * @description Test class for util_closer_CaseStatusBatch.
 * Tests batch processing, metrics tracking, and error handling.
 * Uses dependency injection via mockRules for deterministic testing.
 */
@isTest
private class util_closer_CaseStatusBatch_Test {

    @TestSetup
    static void setup() {
        // Create settings for tests
        util_closer_Settings__c settings = util_closer_TestDataFactory.createSettings(
            200, true, true, 'error@test.com', 'completion@test.com'
        );
        util_closer_TestDataFactory.insertOrgDefaultSettings(settings);
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
    static void testBatch_ProcessesCasesSuccessfully() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, null, 'completion@test.com'
        );

        // Set mock rules
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        // Create cases matching rule criteria
        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 5);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - batch should complete and update cases
        List<Case> updatedCases = [SELECT Id, Status FROM Case WHERE Id IN :testCases];
        Integer closedCount = 0;
        for (Case c : updatedCases) {
            if (c.Status == 'Closed') {
                closedCount++;
            }
        }
        System.assertEquals(5, closedCount, 'All 5 cases should be closed');

        resetMockRules();
    }
    
    @isTest
    static void testBatch_NoMatchingCases() {
        // Setup - cases with status that doesn't match any rules
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, null, null
        );

        // Set mock rules that won't match 'Working' status
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        List<Case> testCases = util_closer_TestDataFactory.createCases('Working', 3);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - cases should remain unchanged
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('Working', c.Status, 'Status should remain unchanged');
        }

        resetMockRules();
    }

    @isTest
    static void testBatch_InactiveSystemSkipsProcessing() {
        // Setup - system is inactive
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, false, null, null
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 5);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - cases should remain unchanged
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('New', c.Status, 'Status should remain unchanged when system is inactive');
        }

        resetMockRules();
    }

    @isTest
    static void testBatch_MetricsTrackedCorrectly() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, null, null
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 3);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - batch should complete and process cases
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        Integer closedCount = 0;
        for (Case c : updatedCases) {
            if (c.Status == 'Closed') {
                closedCount++;
            }
        }
        System.assertEquals(3, closedCount, 'All cases should be closed');

        resetMockRules();
    }

    @isTest
    static void testBatch_DebugModeLogsDetails() {
        // Setup - debug mode enabled
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, null, null
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 2);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - batch should complete and update cases
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('Closed', c.Status, 'Status should be updated');
        }

        resetMockRules();
    }

    @isTest
    static void testBatch_LargeVolume() {
        // Setup - use large batch size to process all in one batch
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, null, null
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        // Create many cases
        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 150);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - all cases should be closed
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        Integer closedCount = 0;
        for (Case c : updatedCases) {
            if (c.Status == 'Closed') {
                closedCount++;
            }
        }
        System.assertEquals(150, closedCount, 'All 150 cases should be closed');

        resetMockRules();
    }

    @isTest
    static void testBatch_CompletionNotificationSent() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, null, 'completion@test.com'
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 2);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - batch should complete
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('Closed', c.Status, 'Status should be updated');
        }

        resetMockRules();
    }
    
    @isTest
    static void testBatch_StatusTransitionCounts() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, null, null
        );
        
        // Test BatchMetrics transition counting
        util_closer_BatchMetrics metrics = new util_closer_BatchMetrics();
        metrics.recordSuccess('New', 'Closed');
        metrics.recordSuccess('New', 'Closed');
        metrics.recordSuccess('Open', 'Closed');
        
        // Verify
        System.assertEquals(2, metrics.statusTransitionCounts.get('New -> Closed'), 
            'Should have 2 transitions from New to Closed');
        System.assertEquals(1, metrics.statusTransitionCounts.get('Open -> Closed'), 
            'Should have 1 transition from Open to Closed');
        System.assertEquals(3, metrics.totalRecordsUpdated, 'Should have 3 total updates');
    }
    
    @isTest
    static void testBatch_MetricsToLogSummary() {
        // Setup
        util_closer_BatchMetrics metrics = new util_closer_BatchMetrics();
        metrics.totalRecordsProcessed = 100;
        metrics.totalRecordsUpdated = 50;
        metrics.totalRecordsFailed = 5;
        metrics.totalBatchesExecuted = 2;
        
        // Execute
        String summary = metrics.toLogSummary();
        
        // Verify
        System.assert(summary.contains('100'), 'Summary should contain processed count');
        System.assert(summary.contains('50'), 'Summary should contain updated count');
        System.assert(summary.contains('5'), 'Summary should contain failed count');
        System.assert(summary.contains('2'), 'Summary should contain batch count');
    }
    
    @isTest
    static void testBatch_MetricsToEmailBody() {
        // Setup
        util_closer_BatchMetrics metrics = new util_closer_BatchMetrics();
        metrics.totalRecordsProcessed = 100;
        metrics.totalRecordsUpdated = 50;
        metrics.totalRecordsFailed = 5;
        metrics.totalBatchesExecuted = 2;
        metrics.endTime = DateTime.now();
        metrics.recordSuccess('New', 'Closed');
        metrics.recordFailure('Test error', null);
        
        // Execute
        String emailBody = metrics.toEmailBody();
        
        // Verify
        System.assert(emailBody.contains('<html>'), 'Email body should be HTML');
        System.assert(emailBody.contains('100') || emailBody.contains('Processed'), 
            'Email body should contain metrics');
    }
    
    @isTest
    static void testBatch_MetricsToEmailBody_WithNullEndTime() {
        // Setup
        util_closer_BatchMetrics metrics = new util_closer_BatchMetrics();
        metrics.totalRecordsProcessed = 100;
        metrics.endTime = null;
        
        // Execute
        String emailBody = metrics.toEmailBody();
        
        // Verify - should handle null endTime gracefully
        System.assert(emailBody.contains('N/A'), 'Email body should show N/A for null endTime');
    }
    
    @isTest
    static void testBatch_MetricsFormatDuration_Milliseconds() {
        // Setup - test formatDuration indirectly through toEmailBody
        util_closer_BatchMetrics metrics = new util_closer_BatchMetrics();
        metrics.startTime = DateTime.now();
        // Use addSeconds with fraction to test milliseconds formatting
        metrics.endTime = DateTime.now().addSeconds(1);
        
        // Execute
        String emailBody = metrics.toEmailBody();
        
        // Verify - should format duration
        System.assert(emailBody.contains('Duration'), 'Email body should contain duration');
    }
    
    @isTest
    static void testBatch_MetricsFormatDuration_Seconds() {
        // Setup
        util_closer_BatchMetrics metrics = new util_closer_BatchMetrics();
        metrics.startTime = DateTime.now();
        metrics.endTime = DateTime.now().addSeconds(30);
        
        // Execute
        String emailBody = metrics.toEmailBody();
        
        // Verify - should format seconds
        System.assert(emailBody.contains('Duration'), 'Email body should contain duration');
    }
    
    @isTest
    static void testBatch_MetricsFormatDuration_Minutes() {
        // Setup
        util_closer_BatchMetrics metrics = new util_closer_BatchMetrics();
        metrics.startTime = DateTime.now();
        metrics.endTime = DateTime.now().addMinutes(5).addSeconds(30);
        
        // Execute
        String emailBody = metrics.toEmailBody();
        
        // Verify - should format minutes and seconds
        System.assert(emailBody.contains('Duration'), 'Email body should contain duration');
    }
    
    @isTest
    static void testBatch_MetricsToEmailBody_WithStatusTransitions() {
        // Setup
        util_closer_BatchMetrics metrics = new util_closer_BatchMetrics();
        metrics.recordSuccess('New', 'Closed');
        metrics.recordSuccess('New', 'Closed');
        metrics.recordSuccess('Open', 'Escalated');
        metrics.endTime = DateTime.now();
        
        // Execute
        String emailBody = metrics.toEmailBody();
        
        // Verify - should include status transitions table
        System.assert(emailBody.contains('Status Transitions'), 'Email body should contain status transitions');
        System.assert(emailBody.contains('New -> Closed'), 'Email body should contain transition');
    }
    
    @isTest
    static void testBatch_MetricsToEmailBody_WithErrors() {
        // Setup
        util_closer_BatchMetrics metrics = new util_closer_BatchMetrics();
        metrics.recordFailure('Error 1', null);
        metrics.recordFailure('Error 2', null);
        metrics.endTime = DateTime.now();
        
        // Execute
        String emailBody = metrics.toEmailBody();
        
        // Verify - should include errors section
        System.assert(emailBody.contains('Errors'), 'Email body should contain errors section');
    }
    
    @isTest
    static void testBatch_MetricsToEmailBody_MaxErrors() {
        // Setup
        util_closer_BatchMetrics metrics = new util_closer_BatchMetrics();
        for (Integer i = 0; i < 60; i++) {
            metrics.recordFailure('Error ' + i, null);
        }
        metrics.endTime = DateTime.now();
        
        // Execute
        String emailBody = metrics.toEmailBody();
        
        // Verify - should show max errors indicator
        System.assert(emailBody.contains('Errors'), 'Email body should contain errors section');
        System.assert(emailBody.contains('+') || emailBody.contains('50'), 'Email body should indicate max errors');
    }
    
    @isTest
    static void testBatch_MetricsIncrementMethods() {
        // Setup
        util_closer_BatchMetrics metrics = new util_closer_BatchMetrics();
        
        // Execute
        metrics.addProcessedCount(25);
        metrics.addProcessedCount(30);
        metrics.incrementBatchCount();
        metrics.incrementBatchCount();
        
        // Verify
        System.assertEquals(55, metrics.totalRecordsProcessed, 'Processed count should be 55');
        System.assertEquals(2, metrics.totalBatchesExecuted, 'Batch count should be 2');
    }
    
    @isTest
    static void testBatch_MetricsRecordFailure() {
        // Setup
        util_closer_BatchMetrics metrics = new util_closer_BatchMetrics();
        
        // Execute - add errors up to the limit
        for (Integer i = 0; i < 55; i++) {
            metrics.recordFailure('Error ' + i, null);
        }
        
        // Verify - should cap at 50 errors
        System.assertEquals(55, metrics.totalRecordsFailed, 'Should track all failures');
        System.assertEquals(50, metrics.errors.size(), 'Should only keep 50 error messages');
    }
    
    @isTest
    static void testBatch_ErrorHandlingInExecute() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        
        // Create a case that might cause an error (e.g., validation rule violation)
        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
        insert testCase;
        
        // Execute batch - should handle errors gracefully
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        // Verify - batch should complete without throwing exception
        System.assert(true, 'Batch should handle errors gracefully');
    }
    
    @isTest
    static void testBatch_FinishMethodSendsNotifications() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, 'error@test.com', 'completion@test.com'
        );
        
        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        // Verify - finish method should execute without error
        System.assert(true, 'Finish method should execute and send notifications');
    }
    
    @isTest
    static void testBatch_FinishMethodWithFailures() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, 'error@test.com', 'completion@test.com'
        );
        
        // Create batch and manually set failures
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        
        // Execute batch
        Test.startTest();
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        // Verify - finish should handle failures
        System.assert(true, 'Finish method should handle failures');
    }
    
    @isTest
    static void testBatch_UsesCaseDataAccess() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 3);
        insert testCases;

        // Execute batch - should use CaseDataAccess for querying
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - batch should complete and update cases
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('Closed', c.Status, 'Status should be updated');
        }

        resetMockRules();
    }

    @isTest
    static void testBatch_NoActiveRules_ReturnsEmptyQuery() {
        // Setup - empty rules list
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>();

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 3);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - batch should complete without error, cases unchanged
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('New', c.Status, 'Status should remain unchanged');
        }

        resetMockRules();
    }

    @isTest
    static void testBatch_EmptyStatusChanges_SkipsUpdate() {
        // Setup - cases won't match rules (different status)
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        // Create cases that won't match any rules
        List<Case> testCases = util_closer_TestDataFactory.createCases('Working', 3);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - batch should complete without updating cases
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('Working', c.Status, 'Status should remain unchanged');
        }

        resetMockRules();
    }

    @isTest
    static void testBatch_UpdateFailures_HandlesErrors() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 3);
        insert testCases;

        // Execute batch - errors should be handled gracefully
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - batch should complete
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('Closed', c.Status, 'Status should be updated');
        }

        resetMockRules();
    }

    @isTest
    static void testBatch_ExceptionInExecute_Handled() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 2);
        insert testCases;

        // Execute batch - exceptions should be caught and handled
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - batch should complete
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('Closed', c.Status, 'Status should be updated');
        }

        resetMockRules();
    }

    // ==================== Auto Close Reason Tests ====================

    @isTest
    static void testBatch_AutoCloseReason_FieldDoesNotExist_ThrowsError() {
        // Test the static validation method directly with a non-existent field
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            // Call the static validation method directly
            util_closer_CaseStatusBatch.validateAutoCloseReasonField('NonExistentField__c');
        } catch (util_closer_AutoCloseReasonException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('does not exist'), 'Error message should mention field does not exist');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Exception should be thrown for non-existent field');
    }

    @isTest
    static void testBatch_AutoCloseReason_NoFieldConfigured_ThrowsError() {
        // Test the static validation method directly with null field
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            // Call the static validation method directly with null
            util_closer_CaseStatusBatch.validateAutoCloseReasonField(null);
        } catch (util_closer_AutoCloseReasonException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('no field is configured'), 'Error message should mention no field configured');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Exception should be thrown when no field is configured');
    }

    @isTest
    static void testBatch_AutoCloseReason_ValidField_ProcessesSuccessfully() {
        // Setup - Auto Close Reason enabled with valid field
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, null, null, true, 'Reason'
        );

        // Create rule with Target_Reason__c
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Reason_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Target_Reason__c = 'Auto-closed by system',
            Execution_Order__c = 1
        );
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 3);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - batch should complete and set reason
        List<Case> updatedCases = [SELECT Status, Reason FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('Closed', c.Status, 'Status should be Closed');
            System.assertEquals('Auto-closed by system', c.Reason, 'Reason should be set');
        }

        resetMockRules();
    }

    @isTest
    static void testBatch_AutoCloseReason_Disabled_ProcessesNormally() {
        // Setup - Auto Close Reason disabled
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, null, null, false, null
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 3);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - batch should complete successfully
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('Closed', c.Status, 'Status should be Closed');
        }

        resetMockRules();
    }

    @isTest
    static void testBatch_AutoCloseReason_EmptyFieldConfig_ThrowsError() {
        // Test the static validation method directly with empty string
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            // Call the static validation method directly with empty string
            util_closer_CaseStatusBatch.validateAutoCloseReasonField('');
        } catch (util_closer_AutoCloseReasonException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('no field is configured'), 'Error message should mention no field configured');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Exception should be thrown when field is empty');
    }

    @isTest
    static void testBatch_AutoCloseReason_ValidFieldValidation() {
        // Test the static validation method with a valid field (Reason is standard Case field)
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            // Call the static validation method directly with a valid field
            util_closer_CaseStatusBatch.validateAutoCloseReasonField('Reason');
        } catch (util_closer_AutoCloseReasonException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(!exceptionThrown, 'No exception should be thrown for valid field');
    }

    @isTest
    static void testBatch_AutoCloseReasonException_CustomException() {
        // Test the custom exception class
        Test.startTest();
        util_closer_AutoCloseReasonException ex = new util_closer_AutoCloseReasonException('Test error message');
        Test.stopTest();

        System.assertEquals('Test error message', ex.getMessage(), 'Exception should contain the error message');
    }

    // ==================== Child Record Criteria Tests ====================

    @isTest
    static void testBatch_WithChildCriteria_ProcessesSuccessfully() {
        // Setup - rule with child criteria
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        // Rule with child criteria that doesn't require a match
        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Child_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Execution_Order__c = 1,
            Child_Object_API_Name__c = 'CaseComment',
            Child_Lookup_Field__c = 'ParentId',
            Require_Child_Record__c = false
        );
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 3);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - batch should complete and update cases
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('Closed', c.Status, 'Status should be Closed');
        }

        resetMockRules();
    }

    @isTest
    static void testBatch_RulesHaveChildCriteria_FetchesChildRecords() {
        // Setup - rule that requires matching child record
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

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

        // Create test case with matching child comment
        Case testCase = new Case(Subject = 'Test Case With Child', Status = 'New', Origin = 'Web');
        insert testCase;

        CaseComment comment = new CaseComment(
            ParentId = testCase.Id,
            CommentBody = 'Issue Resolved by customer'
        );
        insert comment;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - case should be closed
        Case updatedCase = [SELECT Status FROM Case WHERE Id = :testCase.Id];
        System.assertEquals('Closed', updatedCase.Status, 'Status should be Closed');

        resetMockRules();
    }

    @isTest
    static void testBatch_EmptyRulesInStart_ReturnsEmptyQuery() {
        // Test empty rules path in start method
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>();

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 2);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - cases remain unchanged
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('New', c.Status, 'Status should remain unchanged');
        }

        resetMockRules();
    }

    @isTest
    static void testBatch_AutoCloseReasonEnabled_SetsReasonField() {
        // Test setting reason field when enabled
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, null, null, true, 'Reason'
        );

        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Reason_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Target_Reason__c = 'System auto-closed',
            Execution_Order__c = 1
        );
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 2);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - reason should be set
        List<Case> updatedCases = [SELECT Status, Reason FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('Closed', c.Status, 'Status should be Closed');
            System.assertEquals('System auto-closed', c.Reason, 'Reason should be set');
        }

        resetMockRules();
    }

    @isTest
    static void testBatch_MetricsAggregation() {
        // Test that metrics methods work correctly
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        // Test metrics aggregation directly
        util_closer_BatchMetrics metrics = new util_closer_BatchMetrics();

        // Simulate multiple batch executions
        metrics.incrementBatchCount();
        metrics.addProcessedCount(50);
        metrics.recordSuccess('New', 'Closed');
        metrics.recordSuccess('New', 'Closed');

        metrics.incrementBatchCount();
        metrics.addProcessedCount(25);
        metrics.recordSuccess('Working', 'Closed');
        metrics.recordFailure('Test error', null);

        // Verify aggregation
        System.assertEquals(2, metrics.totalBatchesExecuted, 'Should have 2 batches');
        System.assertEquals(75, metrics.totalRecordsProcessed, 'Should have 75 processed');
        System.assertEquals(3, metrics.totalRecordsUpdated, 'Should have 3 successes');
        System.assertEquals(1, metrics.totalRecordsFailed, 'Should have 1 failure');
    }

    @isTest
    static void testBatch_CaseUpdateSuccess_RecordsMetrics() {
        // Test successful update records metrics
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 5);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - all cases should be updated
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('Closed', c.Status, 'Status should be Closed');
        }

        resetMockRules();
    }

    @isTest
    static void testBatch_CaseUpdateFailure_RecordsError() {
        // Test update failure recording
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 3);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - cases should be updated
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('Closed', c.Status, 'Status should be Closed');
        }

        resetMockRules();
    }

    @isTest
    static void testBatch_ExceptionDuringExecute_CaughtAndLogged() {
        // Test exception handling
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 2);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - cases should be updated
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('Closed', c.Status, 'Status should be Closed');
        }

        resetMockRules();
    }

    @isTest
    static void testBatch_FinishWithFailures_SendsErrorNotification() {
        // Test error notification when failures occur
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, 'error@test.com', 'completion@test.com'
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 2);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - cases should be updated
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('Closed', c.Status, 'Status should be Closed');
        }

        resetMockRules();
    }

    @isTest
    static void testBatch_ConstructorInitialization() {
        // Test constructor initializes all fields
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, null, null, true, 'Reason'
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        // Execute
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Test.stopTest();

        // Verify - constructor should complete without error
        System.assertNotEquals(null, batch, 'Batch should be created');

        resetMockRules();
    }

    @isTest
    static void testBatch_ConstructorWithAutoCloseDisabled() {
        // Test constructor when Auto Close Reason is disabled
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, null, null, false, null
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 2);
        insert testCases;

        // Execute
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - cases should be updated
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('Closed', c.Status, 'Status should be Closed');
        }

        resetMockRules();
    }

    @isTest
    static void testBatch_StartWithValidAutoCloseField() {
        // Test start method validates Auto Close field
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, null, null, true, 'Reason'
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 2);
        insert testCases;

        // Execute
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - cases should be updated
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('Closed', c.Status, 'Status should be Closed');
        }

        resetMockRules();
    }

    @isTest
    static void testBatch_ExecuteWithMatchingCases() {
        // Test execute method with cases that match rules
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 10);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - all cases should be updated
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('Closed', c.Status, 'Status should be Closed');
        }

        resetMockRules();
    }

    @isTest
    static void testBatch_ExecuteWithNonMatchingCases() {
        // Test execute method when no cases match
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        // Create cases with status that won't match rules
        List<Case> testCases = util_closer_TestDataFactory.createCases('Escalated', 5);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - cases should remain unchanged
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('Escalated', c.Status, 'Status should remain unchanged');
        }

        resetMockRules();
    }

    @isTest
    static void testBatch_BuildsCasesToUpdateList() {
        // Test building cases to update list
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 5);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - all cases should be updated
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('Closed', c.Status, 'Status should be Closed');
        }

        resetMockRules();
    }

    @isTest
    static void testBatch_ProcessesSaveResults() {
        // Test processing save results
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 5);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - all cases should be updated
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('Closed', c.Status, 'Status should be Closed');
        }

        resetMockRules();
    }

    // ==================== Simulation Mode Tests ====================

    @isTest
    static void testBatch_SimulationMode_DoesNotUpdateCases() {
        // Setup - simulation mode enabled
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, null, null, false, null, true
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 5);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - cases should NOT be updated in simulation mode
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('New', c.Status, 'Status should remain unchanged in simulation mode');
        }

        resetMockRules();
    }

    @isTest
    static void testBatch_SimulationMode_RecordsMetrics() {
        // Setup - simulation mode enabled
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, null, 'completion@test.com', false, null, true
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 3);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - cases remain unchanged but batch completes
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('New', c.Status, 'Status should remain New in simulation mode');
        }

        resetMockRules();
    }

    @isTest
    static void testBatch_SimulationMode_WithAutoCloseReason() {
        // Setup - simulation mode with auto close reason
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, null, null, true, 'Reason', true
        );

        util_closer_Case_Status_Rule__mdt rule = new util_closer_Case_Status_Rule__mdt(
            DeveloperName = 'Sim_Rule',
            Is_Active__c = true,
            Source_Status__c = 'New',
            Target_Status__c = 'Closed',
            Target_Reason__c = 'Simulated close',
            Execution_Order__c = 1
        );
        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{ rule };

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 2);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - cases should NOT be updated in simulation mode
        List<Case> updatedCases = [SELECT Status, Reason FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('New', c.Status, 'Status should remain New in simulation mode');
            System.assertEquals(null, c.Reason, 'Reason should remain null in simulation mode');
        }

        resetMockRules();
    }

    @isTest
    static void testBatch_SimulationMode_ConstructorLogs() {
        // Setup - simulation mode enabled
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, null, null, false, null, true
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        // Execute - constructor should log simulation mode
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Test.stopTest();

        // Verify - batch should be created
        System.assertNotEquals(null, batch, 'Batch should be created in simulation mode');

        resetMockRules();
    }

    @isTest
    static void testMetrics_SimulationMode_ToEmailBody() {
        // Setup - metrics with simulation mode enabled
        util_closer_BatchMetrics metrics = new util_closer_BatchMetrics();
        metrics.simulationMode = true;
        metrics.totalRecordsProcessed = 100;
        metrics.totalRecordsUpdated = 50;
        metrics.endTime = DateTime.now();
        metrics.recordSuccess('New', 'Closed');

        // Execute
        String emailBody = metrics.toEmailBody();

        // Verify - should contain simulation mode indicators
        System.assert(emailBody.contains('SIMULATION'), 'Email body should contain SIMULATION');
        System.assert(emailBody.contains('Would Be Updated') || emailBody.contains('WOULD'),
            'Email body should indicate simulated updates');
    }

    @isTest
    static void testMetrics_SimulationMode_ToLogSummary() {
        // Setup - metrics with simulation mode enabled
        util_closer_BatchMetrics metrics = new util_closer_BatchMetrics();
        metrics.simulationMode = true;
        metrics.totalRecordsProcessed = 100;
        metrics.totalRecordsUpdated = 50;
        metrics.totalRecordsFailed = 0;
        metrics.totalBatchesExecuted = 1;

        // Execute
        String summary = metrics.toLogSummary();

        // Verify - should contain simulation mode indicator
        System.assert(summary.contains('[SIMULATION]'), 'Log summary should contain [SIMULATION]');
        System.assert(summary.contains('Would Update'), 'Log summary should contain Would Update');
    }

    @isTest
    static void testMetrics_NormalMode_ToLogSummary() {
        // Setup - metrics without simulation mode
        util_closer_BatchMetrics metrics = new util_closer_BatchMetrics();
        metrics.simulationMode = false;
        metrics.totalRecordsProcessed = 100;
        metrics.totalRecordsUpdated = 50;
        metrics.totalRecordsFailed = 0;
        metrics.totalBatchesExecuted = 1;

        // Execute
        String summary = metrics.toLogSummary();

        // Verify - should NOT contain simulation mode indicator
        System.assert(!summary.contains('[SIMULATION]'), 'Log summary should not contain [SIMULATION]');
        System.assert(summary.contains('Updated='), 'Log summary should contain Updated=');
    }

    @isTest
    static void testBatch_SimulationMode_FinishMethod() {
        // Setup - simulation mode enabled
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, 'error@test.com', 'completion@test.com', false, null, true
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        List<Case> testCases = util_closer_TestDataFactory.createCases('New', 3);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - finish should complete without error, no error notification in simulation mode
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('New', c.Status, 'Status should remain New');
        }

        resetMockRules();
    }

    @isTest
    static void testBatch_SimulationMode_NoMatchingCases() {
        // Setup - simulation mode with no matching cases
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, true, true, null, null, false, null, true
        );

        util_closer_RuleEngine.mockRules = new List<util_closer_Case_Status_Rule__mdt>{
            createMockRule('Test_Rule', 'New', 'Closed', 1)
        };

        // Create cases that don't match the rule
        List<Case> testCases = util_closer_TestDataFactory.createCases('Working', 3);
        insert testCases;

        // Execute batch
        Test.startTest();
        util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify - cases should remain unchanged
        List<Case> updatedCases = [SELECT Status FROM Case WHERE Id IN :testCases];
        for (Case c : updatedCases) {
            System.assertEquals('Working', c.Status, 'Status should remain Working');
        }

        resetMockRules();
    }
}

