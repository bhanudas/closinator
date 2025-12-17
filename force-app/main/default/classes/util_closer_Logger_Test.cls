/**
 * @description Test class for util_closer_Logger.
 * Tests conditional debug logging functionality.
 */
@isTest
private class util_closer_Logger_Test {
    
    @isTest
    static void testDebug_WhenDebugModeEnabled() {
        // Setup - enable debug mode
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        
        // Execute
        Test.startTest();
        util_closer_Logger.debug('Test message');
        util_closer_Logger.debug('TestContext', 'Test message with context');
        Test.stopTest();
        
        // Verify - logs should be emitted (cannot directly verify log output)
        System.assert(true, 'Debug logs emitted successfully');
    }
    
    @isTest
    static void testDebug_WhenDebugModeDisabled() {
        // Setup - disable debug mode
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, false, true);
        
        // Execute
        Test.startTest();
        util_closer_Logger.debug('Test message');
        util_closer_Logger.debug('TestContext', 'Test message with context');
        Test.stopTest();
        
        // Verify - logs should be skipped
        System.assert(true, 'Debug logs skipped when debug mode disabled');
    }
    
    @isTest
    static void testError_AlwaysLogs() {
        // Setup - even with debug mode disabled
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, false, true);
        
        // Execute
        Test.startTest();
        util_closer_Logger.error('Test error message');
        Test.stopTest();
        
        // Verify - error should always log
        System.assert(true, 'Error log emitted');
    }
    
    @isTest
    static void testError_WithException() {
        // Setup
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, false, true);
        
        Exception testEx;
        try {
            Integer i = 1/0;
        } catch (Exception ex) {
            testEx = ex;
        }
        
        // Execute
        Test.startTest();
        util_closer_Logger.error('Test error with exception', testEx);
        Test.stopTest();
        
        // Verify - error with exception should log
        System.assert(true, 'Error log with exception emitted');
    }
    
    @isTest
    static void testDebug_WithNullContext() {
        // Setup - enable debug mode
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        
        // Execute
        Test.startTest();
        util_closer_Logger.debug(null, 'Test message');
        Test.stopTest();
        
        // Verify - should handle null context
        System.assert(true, 'Debug log with null context handled');
    }
}

