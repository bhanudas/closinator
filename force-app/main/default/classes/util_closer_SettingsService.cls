/**
 * @description Centralized access to Custom Settings with caching and null-safety.
 * Provides all configuration values for the Case Auto-Closer system.
 */
public with sharing class util_closer_SettingsService {
    
    private static util_closer_Settings__c cachedSettings;
    private static final Integer DEFAULT_BATCH_SIZE = 200;
    private static final String DEFAULT_JOB_NAME = 'util_closer_CaseStatusJob';
    private static final String DEFAULT_CRON = '0 0 2 * * ?';
    
    @TestVisible
    private static util_closer_Settings__c mockSettings;
    
    /**
     * @description Returns org default settings or creates runtime default.
     * @return The settings instance.
     */
    public static util_closer_Settings__c getSettings() {
        if (mockSettings != null) {
            return mockSettings;
        }
        
        if (cachedSettings == null) {
            cachedSettings = util_closer_Settings__c.getOrgDefaults();
            if (cachedSettings == null || cachedSettings.Id == null) {
                cachedSettings = createDefaultSettings();
            }
        }
        return cachedSettings;
    }
    
    /**
     * @description Returns the batch size with fallback to 200.
     * @return The batch size.
     */
    public static Integer getBatchSize() {
        util_closer_Settings__c settings = getSettings();
        return (settings.Batch_Size__c != null && settings.Batch_Size__c > 0) 
            ? (Integer)settings.Batch_Size__c 
            : DEFAULT_BATCH_SIZE;
    }
    
    /**
     * @description Returns the debug mode flag.
     * @return True if debug mode is enabled.
     */
    public static Boolean isDebugMode() {
        return getSettings().Debug_Mode__c == true;
    }
    
    /**
     * @description Returns the master active flag.
     * @return True if the system is active.
     */
    public static Boolean isActive() {
        return getSettings().Is_Active__c == true;
    }
    
    /**
     * @description Parses and returns error notification emails.
     * @return List of email addresses.
     */
    public static List<String> getErrorEmails() {
        return parseEmailList(getSettings().Error_Notification_Emails__c);
    }
    
    /**
     * @description Parses and returns completion notification emails.
     * @return List of email addresses.
     */
    public static List<String> getCompletionEmails() {
        return parseEmailList(getSettings().Completion_Notification_Emails__c);
    }
    
    /**
     * @description Returns the cron expression.
     * @return The cron expression string.
     */
    public static String getCronExpression() {
        String cron = getSettings().Cron_Expression__c;
        return String.isNotBlank(cron) ? cron : DEFAULT_CRON;
    }
    
    /**
     * @description Returns the scheduled job name with default.
     * @return The job name.
     */
    public static String getScheduledJobName() {
        String jobName = getSettings().Scheduled_Job_Name__c;
        return String.isNotBlank(jobName) ? jobName : DEFAULT_JOB_NAME;
    }
    
    /**
     * @description Clears the cached settings. Useful for testing.
     */
    @TestVisible
    private static void clearCache() {
        cachedSettings = null;
        mockSettings = null;
    }
    
    /**
     * @description Creates default settings instance (not persisted).
     * @return Default settings.
     */
    private static util_closer_Settings__c createDefaultSettings() {
        return new util_closer_Settings__c(
            Batch_Size__c = DEFAULT_BATCH_SIZE,
            Debug_Mode__c = false,
            Is_Active__c = true,
            Cron_Expression__c = DEFAULT_CRON,
            Scheduled_Job_Name__c = DEFAULT_JOB_NAME
        );
    }
    
    /**
     * @description Parses a semicolon-separated email list.
     * @param emailString The semicolon-separated string.
     * @return List of trimmed email addresses.
     */
    private static List<String> parseEmailList(String emailString) {
        List<String> emails = new List<String>();
        if (String.isNotBlank(emailString)) {
            for (String email : emailString.split(';')) {
                String trimmed = email.trim();
                if (String.isNotBlank(trimmed)) {
                    emails.add(trimmed);
                }
            }
        }
        return emails;
    }
}

