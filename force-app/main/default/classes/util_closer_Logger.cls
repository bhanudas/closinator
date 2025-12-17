/**
 * @description Conditional debug logging utility based on Debug_Mode__c setting.
 * Provides consistent logging format across all Case Auto-Closer components.
 */
public with sharing class util_closer_Logger {
    
    private static final String LOG_PREFIX = '[util_closer] ';
    
    /**
     * @description Logs a debug message if debug mode is enabled.
     * @param message The message to log.
     */
    public static void debug(String message) {
        if (util_closer_SettingsService.isDebugMode()) {
            System.debug(LoggingLevel.DEBUG, formatMessage(message));
        }
    }
    
    /**
     * @description Logs a debug message with context prefix if debug mode is enabled.
     * @param context The context or component name.
     * @param message The message to log.
     */
    public static void debug(String context, String message) {
        if (util_closer_SettingsService.isDebugMode()) {
            System.debug(LoggingLevel.DEBUG, formatMessage('[' + context + '] ' + message));
        }
    }
    
    /**
     * @description Always logs an error message regardless of debug mode.
     * @param message The error message to log.
     */
    public static void error(String message) {
        System.debug(LoggingLevel.ERROR, formatMessage('ERROR: ' + message));
    }
    
    /**
     * @description Always logs an error message with exception details.
     * @param message The error message to log.
     * @param ex The exception that occurred.
     */
    public static void error(String message, Exception ex) {
        String fullMessage = 'ERROR: ' + message + '\n' +
            'Exception Type: ' + ex.getTypeName() + '\n' +
            'Message: ' + ex.getMessage() + '\n' +
            'Stack Trace: ' + ex.getStackTraceString();
        System.debug(LoggingLevel.ERROR, formatMessage(fullMessage));
    }
    
    /**
     * @description Formats the log message with prefix and timestamp.
     * @param message The message to format.
     * @return The formatted message.
     */
    private static String formatMessage(String message) {
        return LOG_PREFIX + Datetime.now().format('yyyy-MM-dd HH:mm:ss.SSS') + ' - ' + message;
    }
}

