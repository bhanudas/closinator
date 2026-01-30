/**
 * @description Test class for util_closer_SettingsService.
 * Tests all settings retrieval and parsing functionality.
 */
@isTest
private class util_closer_SettingsService_Test {
    
    @isTest
    static void testGetSettings_WithOrgDefault() {
        // Setup
        util_closer_Settings__c settings = util_closer_TestDataFactory.createSettings(100, true, true, 'test@example.com', 'report@example.com');
        util_closer_TestDataFactory.insertOrgDefaultSettings(settings);
        
        // Clear cache to force fresh retrieval
        util_closer_SettingsService.mockSettings = null;
        
        // Execute
        Test.startTest();
        util_closer_Settings__c result = util_closer_SettingsService.getSettings();
        Test.stopTest();
        
        // Verify
        System.assertNotEquals(null, result, 'Settings should not be null');
        System.assertEquals(100, result.Batch_Size__c, 'Batch size should be 100');
        System.assertEquals(true, result.Debug_Mode__c, 'Debug mode should be true');
        System.assertEquals(true, result.Is_Active__c, 'Is Active should be true');
    }
    
    @isTest
    static void testGetSettings_WithoutOrgDefault() {
        // Clear any cached settings
        util_closer_SettingsService.mockSettings = null;
        
        // Execute
        Test.startTest();
        util_closer_Settings__c result = util_closer_SettingsService.getSettings();
        Test.stopTest();
        
        // Verify - should return default settings
        System.assertNotEquals(null, result, 'Settings should not be null even without org default');
        System.assertEquals(200, result.Batch_Size__c, 'Default batch size should be 200');
    }
    
    @isTest
    static void testGetBatchSize_CustomValue() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(150, false, true);
        
        // Execute
        Test.startTest();
        Integer batchSize = util_closer_SettingsService.getBatchSize();
        Test.stopTest();
        
        // Verify
        System.assertEquals(150, batchSize, 'Batch size should be 150');
    }
    
    @isTest
    static void testGetBatchSize_DefaultFallback() {
        // Setup - null batch size
        util_closer_SettingsService.mockSettings = new util_closer_Settings__c(
            Batch_Size__c = null,
            Is_Active__c = true
        );
        
        // Execute
        Test.startTest();
        Integer batchSize = util_closer_SettingsService.getBatchSize();
        Test.stopTest();
        
        // Verify
        System.assertEquals(200, batchSize, 'Default batch size should be 200');
    }
    
    @isTest
    static void testGetBatchSize_ZeroFallback() {
        // Setup - zero batch size should use default
        util_closer_SettingsService.mockSettings = new util_closer_Settings__c(
            Batch_Size__c = 0,
            Is_Active__c = true
        );
        
        // Execute
        Test.startTest();
        Integer batchSize = util_closer_SettingsService.getBatchSize();
        Test.stopTest();
        
        // Verify
        System.assertEquals(200, batchSize, 'Zero batch size should fallback to 200');
    }
    
    @isTest
    static void testIsDebugMode_True() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        
        // Execute
        Test.startTest();
        Boolean debugMode = util_closer_SettingsService.isDebugMode();
        Test.stopTest();
        
        // Verify
        System.assertEquals(true, debugMode, 'Debug mode should be true');
    }
    
    @isTest
    static void testIsDebugMode_False() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, false, true);
        
        // Execute
        Test.startTest();
        Boolean debugMode = util_closer_SettingsService.isDebugMode();
        Test.stopTest();
        
        // Verify
        System.assertEquals(false, debugMode, 'Debug mode should be false');
    }
    
    @isTest
    static void testGetErrorEmails_ParsesList() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, false, true, 'user1@test.com; user2@test.com ; user3@test.com', null
        );
        
        // Execute
        Test.startTest();
        List<String> emails = util_closer_SettingsService.getErrorEmails();
        Test.stopTest();
        
        // Verify
        System.assertEquals(3, emails.size(), 'Should have 3 emails');
        System.assertEquals('user1@test.com', emails[0], 'First email should be trimmed');
        System.assertEquals('user2@test.com', emails[1], 'Second email should be trimmed');
        System.assertEquals('user3@test.com', emails[2], 'Third email should be trimmed');
    }
    
    @isTest
    static void testGetErrorEmails_EmptyList() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, false, true, null, null);
        
        // Execute
        Test.startTest();
        List<String> emails = util_closer_SettingsService.getErrorEmails();
        Test.stopTest();
        
        // Verify
        System.assertEquals(0, emails.size(), 'Should have 0 emails');
    }
    
    @isTest
    static void testGetCompletionEmails_ParsesList() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, false, true, null, 'report@test.com;admin@test.com'
        );
        
        // Execute
        Test.startTest();
        List<String> emails = util_closer_SettingsService.getCompletionEmails();
        Test.stopTest();
        
        // Verify
        System.assertEquals(2, emails.size(), 'Should have 2 emails');
    }
    
    @isTest
    static void testIsActive_True() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, false, true);
        
        // Execute
        Test.startTest();
        Boolean isActive = util_closer_SettingsService.isActive();
        Test.stopTest();
        
        // Verify
        System.assertEquals(true, isActive, 'Is Active should be true');
    }
    
    @isTest
    static void testIsActive_False() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, false, false);
        
        // Execute
        Test.startTest();
        Boolean isActive = util_closer_SettingsService.isActive();
        Test.stopTest();
        
        // Verify
        System.assertEquals(false, isActive, 'Is Active should be false');
    }
    
    @isTest
    static void testGetCronExpression_CustomValue() {
        // Setup
        util_closer_SettingsService.mockSettings = new util_closer_Settings__c(
            Cron_Expression__c = '0 0 6 * * ?',
            Is_Active__c = true
        );
        
        // Execute
        Test.startTest();
        String cron = util_closer_SettingsService.getCronExpression();
        Test.stopTest();
        
        // Verify
        System.assertEquals('0 0 6 * * ?', cron, 'Should return custom cron expression');
    }
    
    @isTest
    static void testGetCronExpression_DefaultValue() {
        // Setup
        util_closer_SettingsService.mockSettings = new util_closer_Settings__c(
            Cron_Expression__c = null,
            Is_Active__c = true
        );
        
        // Execute
        Test.startTest();
        String cron = util_closer_SettingsService.getCronExpression();
        Test.stopTest();
        
        // Verify
        System.assertEquals('0 0 2 * * ?', cron, 'Should return default cron expression');
    }
    
    @isTest
    static void testGetScheduledJobName_CustomValue() {
        // Setup
        util_closer_SettingsService.mockSettings = new util_closer_Settings__c(
            Scheduled_Job_Name__c = 'CustomJobName',
            Is_Active__c = true
        );
        
        // Execute
        Test.startTest();
        String jobName = util_closer_SettingsService.getScheduledJobName();
        Test.stopTest();
        
        // Verify
        System.assertEquals('CustomJobName', jobName, 'Should return custom job name');
    }
    
    @isTest
    static void testGetScheduledJobName_DefaultValue() {
        // Setup
        util_closer_SettingsService.mockSettings = new util_closer_Settings__c(
            Scheduled_Job_Name__c = null,
            Is_Active__c = true
        );

        // Execute
        Test.startTest();
        String jobName = util_closer_SettingsService.getScheduledJobName();
        Test.stopTest();

        // Verify
        System.assertEquals('util_closer_CaseStatusJob', jobName, 'Should return default job name');
    }

    @isTest
    static void testIsAutoCloseReasonEnabled_True() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, false, true, null, null, true, 'Reason'
        );

        // Execute
        Test.startTest();
        Boolean isEnabled = util_closer_SettingsService.isAutoCloseReasonEnabled();
        Test.stopTest();

        // Verify
        System.assertEquals(true, isEnabled, 'Auto Close Reason should be enabled');
    }

    @isTest
    static void testIsAutoCloseReasonEnabled_False() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, false, true, null, null, false, null
        );

        // Execute
        Test.startTest();
        Boolean isEnabled = util_closer_SettingsService.isAutoCloseReasonEnabled();
        Test.stopTest();

        // Verify
        System.assertEquals(false, isEnabled, 'Auto Close Reason should be disabled');
    }

    @isTest
    static void testIsAutoCloseReasonEnabled_Null() {
        // Setup - null value should return false
        util_closer_SettingsService.mockSettings = new util_closer_Settings__c(
            Is_Active__c = true,
            Auto_Close_Reason_Enabled__c = null
        );

        // Execute
        Test.startTest();
        Boolean isEnabled = util_closer_SettingsService.isAutoCloseReasonEnabled();
        Test.stopTest();

        // Verify
        System.assertEquals(false, isEnabled, 'Null Auto Close Reason Enabled should return false');
    }

    @isTest
    static void testGetAutoCloseReasonField_CustomValue() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(
            200, false, true, null, null, true, 'Close_Reason__c'
        );

        // Execute
        Test.startTest();
        String fieldName = util_closer_SettingsService.getAutoCloseReasonField();
        Test.stopTest();

        // Verify
        System.assertEquals('Close_Reason__c', fieldName, 'Should return configured field name');
    }

    @isTest
    static void testGetAutoCloseReasonField_WithSpaces() {
        // Setup - field name with leading/trailing spaces should be trimmed
        util_closer_SettingsService.mockSettings = new util_closer_Settings__c(
            Is_Active__c = true,
            Auto_Close_Reason_Field__c = '  Reason  '
        );

        // Execute
        Test.startTest();
        String fieldName = util_closer_SettingsService.getAutoCloseReasonField();
        Test.stopTest();

        // Verify
        System.assertEquals('Reason', fieldName, 'Field name should be trimmed');
    }

    @isTest
    static void testGetAutoCloseReasonField_Null() {
        // Setup - null field should return null
        util_closer_SettingsService.mockSettings = new util_closer_Settings__c(
            Is_Active__c = true,
            Auto_Close_Reason_Field__c = null
        );

        // Execute
        Test.startTest();
        String fieldName = util_closer_SettingsService.getAutoCloseReasonField();
        Test.stopTest();

        // Verify
        System.assertEquals(null, fieldName, 'Null field should return null');
    }

    @isTest
    static void testGetAutoCloseReasonField_Empty() {
        // Setup - empty string should return null
        util_closer_SettingsService.mockSettings = new util_closer_Settings__c(
            Is_Active__c = true,
            Auto_Close_Reason_Field__c = ''
        );

        // Execute
        Test.startTest();
        String fieldName = util_closer_SettingsService.getAutoCloseReasonField();
        Test.stopTest();

        // Verify
        System.assertEquals(null, fieldName, 'Empty string should return null');
    }

    @isTest
    static void testGetAutoCloseReasonField_Whitespace() {
        // Setup - whitespace only should return null
        util_closer_SettingsService.mockSettings = new util_closer_Settings__c(
            Is_Active__c = true,
            Auto_Close_Reason_Field__c = '   '
        );

        // Execute
        Test.startTest();
        String fieldName = util_closer_SettingsService.getAutoCloseReasonField();
        Test.stopTest();

        // Verify
        System.assertEquals(null, fieldName, 'Whitespace only should return null');
    }
}

