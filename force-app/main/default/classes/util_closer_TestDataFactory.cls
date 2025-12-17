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
        return new util_closer_Settings__c(
            Batch_Size__c = batchSize,
            Debug_Mode__c = debugMode,
            Is_Active__c = isActive,
            Error_Notification_Emails__c = errorEmails,
            Completion_Notification_Emails__c = completionEmails,
            Cron_Expression__c = '0 0 2 * * ?',
            Scheduled_Job_Name__c = 'util_closer_CaseStatusJob'
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
        String uniqueId = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.random()).substring(2, 6);
        
        return new User(
            FirstName = 'Test',
            LastName = 'User' + uniqueId,
            Email = 'testuser' + uniqueId + '@test.util_closer.com',
            Username = 'testuser' + uniqueId + '@test.util_closer.com',
            Alias = 'tuser' + uniqueId.substring(0, 3),
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
}

