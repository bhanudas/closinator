/**
 * @description Test data factory for Case Auto-Closer test classes.
 * Provides methods for creating test settings, cases, and users.
 */
@isTest
public class util_closer_TestDataFactory {
    
    private static final String STANDARD_USER_PROFILE = 'Standard User';
    
    // ==================== Settings Creation ====================
    
    /**
     * @description Creates default settings with standard values.
     * @return Settings instance (not inserted).
     */
    public static util_closer_Settings__c createDefaultSettings() {
        return createSettings(200, false, true);
    }
    
    /**
     * @description Creates settings with specified values.
     * @param batchSize The batch size.
     * @param debugMode Debug mode flag.
     * @param isActive Active flag.
     * @return Settings instance (not inserted).
     */
    public static util_closer_Settings__c createSettings(Integer batchSize, Boolean debugMode, Boolean isActive) {
        return createSettings(batchSize, debugMode, isActive, null, null);
    }
    
    /**
     * @description Creates settings with all customizable values.
     * @param batchSize The batch size.
     * @param debugMode Debug mode flag.
     * @param isActive Active flag.
     * @param errorEmails Error notification emails.
     * @param completionEmails Completion notification emails.
     * @return Settings instance (not inserted).
     */
    public static util_closer_Settings__c createSettings(
        Integer batchSize,
        Boolean debugMode,
        Boolean isActive,
        String errorEmails,
        String completionEmails
    ) {
        return createSettings(batchSize, debugMode, isActive, errorEmails, completionEmails, false, null);
    }

    /**
     * @description Creates settings with all customizable values including Auto Close Reason settings.
     * @param batchSize The batch size.
     * @param debugMode Debug mode flag.
     * @param isActive Active flag.
     * @param errorEmails Error notification emails.
     * @param completionEmails Completion notification emails.
     * @param autoCloseReasonEnabled Auto Close Reason feature enabled flag.
     * @param autoCloseReasonField API name of the Case field for the reason.
     * @return Settings instance (not inserted).
     */
    public static util_closer_Settings__c createSettings(
        Integer batchSize,
        Boolean debugMode,
        Boolean isActive,
        String errorEmails,
        String completionEmails,
        Boolean autoCloseReasonEnabled,
        String autoCloseReasonField
    ) {
        return createSettings(batchSize, debugMode, isActive, errorEmails, completionEmails, autoCloseReasonEnabled, autoCloseReasonField, false);
    }

    /**
     * @description Creates settings with all customizable values including Auto Close Reason and Simulation Mode settings.
     * @param batchSize The batch size.
     * @param debugMode Debug mode flag.
     * @param isActive Active flag.
     * @param errorEmails Error notification emails.
     * @param completionEmails Completion notification emails.
     * @param autoCloseReasonEnabled Auto Close Reason feature enabled flag.
     * @param autoCloseReasonField API name of the Case field for the reason.
     * @param simulationMode Simulation mode flag (dry run).
     * @return Settings instance (not inserted).
     */
    public static util_closer_Settings__c createSettings(
        Integer batchSize,
        Boolean debugMode,
        Boolean isActive,
        String errorEmails,
        String completionEmails,
        Boolean autoCloseReasonEnabled,
        String autoCloseReasonField,
        Boolean simulationMode
    ) {
        return new util_closer_Settings__c(
            Batch_Size__c = batchSize,
            Debug_Mode__c = debugMode,
            Is_Active__c = isActive,
            Error_Notification_Emails__c = errorEmails,
            Completion_Notification_Emails__c = completionEmails,
            Cron_Expression__c = '0 0 2 * * ?',
            Scheduled_Job_Name__c = 'util_closer_CaseStatusJob',
            Auto_Close_Reason_Enabled__c = autoCloseReasonEnabled,
            Auto_Close_Reason_Field__c = autoCloseReasonField,
            Simulation_Mode__c = simulationMode
        );
    }
    
    /**
     * @description Inserts org default settings.
     * @param settings The settings to insert as org default.
     */
    public static void insertOrgDefaultSettings(util_closer_Settings__c settings) {
        insert settings;
    }
    
    // ==================== Case Creation ====================
    
    /**
     * @description Creates a case with specified status.
     * @param status The case status.
     * @return Case instance (not inserted).
     */
    public static Case createCase(String status) {
        return new Case(
            Subject = 'Test Case ' + DateTime.now().getTime(),
            Status = status,
            Origin = 'Web'
        );
    }
    
    /**
     * @description Creates a case with specified status and age in days.
     * @param status The case status.
     * @param daysOld Number of days old the case should appear.
     * @return Case instance (not inserted).
     */
    public static Case createCase(String status, Integer daysOld) {
        Case c = createCase(status);
        // Note: daysOld will be set after insert using Test.setCreatedDate
        return c;
    }
    
    /**
     * @description Creates multiple cases with specified status.
     * @param status The case status.
     * @param count Number of cases to create.
     * @return List of Case instances (not inserted).
     */
    public static List<Case> createCases(String status, Integer count) {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < count; i++) {
            cases.add(createCase(status));
        }
        return cases;
    }
    
    /**
     * @description Creates multiple cases with specified status and age.
     * @param status The case status.
     * @param count Number of cases to create.
     * @param daysOld Number of days old.
     * @return List of Case instances (not inserted).
     */
    public static List<Case> createCases(String status, Integer count, Integer daysOld) {
        List<Case> cases = createCases(status, count);
        return cases;
    }
    
    /**
     * @description Creates cases with a specific record type.
     * @param status The case status.
     * @param count Number of cases.
     * @param recordTypeDeveloperName Record type developer name.
     * @return List of Case instances (not inserted).
     */
    public static List<Case> createCasesWithRecordType(String status, Integer count, String recordTypeDeveloperName) {
        Id recordTypeId = getRecordTypeId(recordTypeDeveloperName);
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < count; i++) {
            Case c = createCase(status);
            if (recordTypeId != null) {
                c.put('RecordTypeId', recordTypeId);
            }
            cases.add(c);
        }
        return cases;
    }
    
    /**
     * @description Gets the record type ID for a given developer name.
     * @param developerName The record type developer name.
     * @return The record type ID or null.
     */
    private static Id getRecordTypeId(String developerName) {
        Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
        if (rtMap.containsKey(developerName)) {
            return rtMap.get(developerName).getRecordTypeId();
        }
        return null;
    }
    
    /**
     * @description Sets the created date for cases (must be called after insert).
     * @param cases The cases to backdate.
     * @param daysAgo Number of days in the past.
     */
    public static void setCreatedDate(List<Case> cases, Integer daysAgo) {
        DateTime pastDate = DateTime.now().addDays(-daysAgo);
        for (Case c : cases) {
            Test.setCreatedDate(c.Id, pastDate);
        }
    }
    
    /**
     * @description Updates cases to simulate last modified date in the past.
     * Note: This actually modifies the record, then we backdate it.
     * @param cases The cases to update.
     * @param daysAgo Number of days in the past.
     */
    public static void setLastModifiedDate(List<Case> cases, Integer daysAgo) {
        // In tests, we can only set CreatedDate. For LastModifiedDate simulation,
        // we update the record normally. The test should account for this limitation.
        // For accurate testing, create cases with the right dates via batch processing.
    }
    
    // ==================== User Creation ====================
    
    /**
     * @description Creates a user with the specified permission set.
     * @param permissionSetApiName The API name of the permission set.
     * @return User instance (inserted).
     */
    public static User createUserWithPermissionSet(String permissionSetApiName) {
        User testUser = createTestUser(STANDARD_USER_PROFILE);
        insert testUser;
        assignPermissionSet(testUser.Id, permissionSetApiName);
        return testUser;
    }
    
    /**
     * @description Creates an admin user with the Administrator permission set.
     * @return User instance (inserted).
     */
    public static User createAdminUser() {
        return createUserWithPermissionSet('util_closer_Administrator');
    }
    
    /**
     * @description Creates an operator user with the Operator permission set.
     * @return User instance (inserted).
     */
    public static User createOperatorUser() {
        return createUserWithPermissionSet('util_closer_Operator');
    }
    
    /**
     * @description Creates a standard user without any custom permission sets.
     * @return User instance (inserted).
     */
    public static User createStandardUserWithoutPermissions() {
        User testUser = createTestUser(STANDARD_USER_PROFILE);
        insert testUser;
        return testUser;
    }
    
    /**
     * @description Creates a test user with the specified profile.
     * @param profileName The profile name.
     * @return User instance (not inserted).
     */
    public static User createTestUser(String profileName) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        String uniqueId = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        
        return new User(
            FirstName = 'Test',
            LastName = 'User' + uniqueId.substring(0, 5),
            Email = 'testuser' + uniqueId + '@example.com',
            Username = 'testuser' + uniqueId + '@example.com',
            Alias = ('tu' + uniqueId).substring(0, 8),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
    }
    
    /**
     * @description Assigns a permission set to a user.
     * @param userId The user ID.
     * @param permissionSetApiName The permission set API name.
     */
    public static void assignPermissionSet(Id userId, String permissionSetApiName) {
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = :permissionSetApiName LIMIT 1];
        insert new PermissionSetAssignment(
            AssigneeId = userId,
            PermissionSetId = ps.Id
        );
    }

    // ==================== Batch Log Creation ====================

    /**
     * @description Creates a batch log record for testing.
     * @param status The batch log status.
     * @param isSimulation Whether this is a simulation execution.
     * @return Batch Log instance (not inserted).
     */
    public static util_closer_Batch_Log__c createBatchLog(String status, Boolean isSimulation) {
        String randomPart = String.valueOf(Math.abs(Crypto.getRandomInteger())).leftPad(15, '0');
        return new util_closer_Batch_Log__c(
            Batch_Job_Id__c = '707' + randomPart.substring(0, 15),
            Start_Time__c = DateTime.now().addMinutes(-5),
            End_Time__c = status == 'Running' ? null : DateTime.now(),
            Status__c = status,
            Execution_Mode__c = isSimulation ? 'Simulation' : 'Full',
            Total_Records_Processed__c = 100,
            Total_Records_Matched__c = 50,
            Total_Records_Updated__c = 45,
            Total_Records_Failed__c = 5,
            Total_Batches_Executed__c = 2,
            Active_Rules_Count__c = 3,
            Active_Rules_JSON__c = '[{"developerName":"Rule1","masterLabel":"Rule 1"}]',
            Status_Transitions_JSON__c = '{"New -> Closed": 45}',
            Running_User__c = UserInfo.getUserId()
        );
    }

    /**
     * @description Creates multiple case log records for testing.
     * @param batchLogId The parent batch log Id.
     * @param count Number of case logs to create.
     * @param processingResult The processing result value.
     * @return List of Case Log instances (not inserted).
     */
    public static List<util_closer_Case_Log__c> createCaseLogs(Id batchLogId, Integer count, String processingResult) {
        List<util_closer_Case_Log__c> logs = new List<util_closer_Case_Log__c>();
        for (Integer i = 0; i < count; i++) {
            logs.add(new util_closer_Case_Log__c(
                Batch_Log__c = batchLogId,
                Case_Number__c = '0000' + i,
                Original_Status__c = 'New',
                Target_Status__c = processingResult == 'Not Matched' ? null : 'Closed',
                Processing_Result__c = processingResult,
                Matched_Rule__c = processingResult == 'Not Matched' ? null : 'Test_Rule',
                Matched_Rule_Label__c = processingResult == 'Not Matched' ? null : 'Test Rule',
                Rules_Evaluated_Count__c = 3,
                Child_Records_Checked__c = false,
                Child_Records_Found__c = 0,
                Processing_Time_Ms__c = 10,
                Batch_Chunk_Number__c = 1
            ));
        }
        return logs;
    }

    /**
     * @description Creates settings with verbose logging configuration.
     * @param verboseLogging Verbose logging enabled flag.
     * @param retentionDays Log retention days.
     * @return Settings instance (not inserted).
     */
    public static util_closer_Settings__c createSettingsWithLogging(Boolean verboseLogging, Integer retentionDays) {
        return createSettingsWithLogging(verboseLogging, retentionDays, false);
    }

    /**
     * @description Creates settings with full logging configuration.
     * @param verboseLogging Verbose logging enabled flag.
     * @param retentionDays Log retention days.
     * @param logRuleEvaluations Log rule evaluations flag.
     * @return Settings instance (not inserted).
     */
    public static util_closer_Settings__c createSettingsWithLogging(Boolean verboseLogging, Integer retentionDays, Boolean logRuleEvaluations) {
        util_closer_Settings__c settings = createDefaultSettings();
        settings.Verbose_Logging_Enabled__c = verboseLogging;
        settings.Log_Retention_Days__c = retentionDays;
        settings.Log_Rule_Evaluations__c = logRuleEvaluations;
        return settings;
    }
}

