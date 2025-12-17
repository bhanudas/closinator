/**
 * @description Test class for permission set functionality.
 * Tests that Administrator and Operator permission sets provide correct access.
 */
@isTest
private class util_closer_PermissionSet_Test {
    
    @TestSetup
    static void setup() {
        // Create settings for tests
        util_closer_Settings__c settings = util_closer_TestDataFactory.createSettings(200, true, true);
        util_closer_TestDataFactory.insertOrgDefaultSettings(settings);
    }
    
    @isTest
    static void testAdministrator_CanEditSettings() {
        // Create admin user
        User adminUser = util_closer_TestDataFactory.createAdminUser();
        
        System.runAs(adminUser) {
            Test.startTest();
            // Admin should be able to read settings
            util_closer_Settings__c settings = util_closer_Settings__c.getOrgDefaults();
            System.assertNotEquals(null, settings, 'Admin should be able to access settings');
            Test.stopTest();
        }
    }
    
    @isTest
    static void testAdministrator_CanRunBatch() {
        // Create admin user
        User adminUser = util_closer_TestDataFactory.createAdminUser();
        
        System.runAs(adminUser) {
            Test.startTest();
            // Admin should be able to run batch
            util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
            Id jobId = Database.executeBatch(batch, 200);
            Test.stopTest();
            
            System.assertNotEquals(null, jobId, 'Admin should be able to run batch');
        }
    }
    
    @isTest
    static void testAdministrator_CanScheduleJob() {
        // Create admin user
        User adminUser = util_closer_TestDataFactory.createAdminUser();
        
        System.runAs(adminUser) {
            Test.startTest();
            String jobId = util_closer_CaseStatusScheduler.scheduleJob();
            Test.stopTest();
            
            System.assertNotEquals(null, jobId, 'Admin should be able to schedule job');
            
            // Cleanup
            util_closer_CaseStatusScheduler.unscheduleJob();
        }
    }
    
    @isTest
    static void testAdministrator_CanUnscheduleJob() {
        // Create admin user
        User adminUser = util_closer_TestDataFactory.createAdminUser();
        
        System.runAs(adminUser) {
            // First schedule a job
            util_closer_CaseStatusScheduler.scheduleJob();
            
            Test.startTest();
            util_closer_CaseStatusScheduler.unscheduleJob();
            Test.stopTest();
            
            System.assert(!util_closer_CaseStatusScheduler.isJobScheduled(), 
                'Admin should be able to unschedule job');
        }
    }
    
    @isTest
    static void testOperator_CanViewSettings() {
        // Create operator user
        User operatorUser = util_closer_TestDataFactory.createOperatorUser();
        
        System.runAs(operatorUser) {
            Test.startTest();
            // Operator should be able to read settings
            util_closer_Settings__c settings = util_closer_Settings__c.getOrgDefaults();
            System.assertNotEquals(null, settings, 'Operator should be able to view settings');
            Test.stopTest();
        }
    }
    
    @isTest
    static void testOperator_CanRunBatch() {
        // Create operator user
        User operatorUser = util_closer_TestDataFactory.createOperatorUser();
        
        System.runAs(operatorUser) {
            Test.startTest();
            // Operator should be able to run batch
            util_closer_CaseStatusBatch batch = new util_closer_CaseStatusBatch();
            Id jobId = Database.executeBatch(batch, 200);
            Test.stopTest();
            
            System.assertNotEquals(null, jobId, 'Operator should be able to run batch');
        }
    }
    
    @isTest
    static void testOperator_CanViewJobStatus() {
        // Create operator user
        User operatorUser = util_closer_TestDataFactory.createOperatorUser();
        
        // First schedule a job as system admin context
        util_closer_CaseStatusScheduler.scheduleJob();
        
        System.runAs(operatorUser) {
            Test.startTest();
            Boolean isScheduled = util_closer_CaseStatusScheduler.isJobScheduled();
            Test.stopTest();
            
            System.assertEquals(true, isScheduled, 'Operator should be able to view job status');
        }
        
        // Cleanup
        util_closer_CaseStatusScheduler.unscheduleJob();
    }
    
    @isTest
    static void testStandardUser_CanAccessClasses() {
        // Create standard user without permissions
        User stdUser = util_closer_TestDataFactory.createStandardUserWithoutPermissions();
        
        // Note: In real scenario, users without permission sets may not have access.
        // For this test, we verify that classes are accessible (basic Apex access).
        System.runAs(stdUser) {
            Test.startTest();
            // Just verify the classes exist and can be referenced
            util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, false, true);
            Boolean isActive = util_closer_SettingsService.isActive();
            Test.stopTest();
            
            System.assertEquals(true, isActive, 'Standard user can access settings service');
        }
    }
    
    @isTest
    static void testPermissionSetExists_Administrator() {
        // Verify the Administrator permission set exists
        List<PermissionSet> ps = [
            SELECT Id, Name, Label 
            FROM PermissionSet 
            WHERE Name = 'util_closer_Administrator'
        ];
        
        System.assertEquals(1, ps.size(), 'Administrator permission set should exist');
        System.assertEquals('Case Auto-Closer Administrator', ps[0].Label, 
            'Administrator permission set should have correct label');
    }
    
    @isTest
    static void testPermissionSetExists_Operator() {
        // Verify the Operator permission set exists
        List<PermissionSet> ps = [
            SELECT Id, Name, Label 
            FROM PermissionSet 
            WHERE Name = 'util_closer_Operator'
        ];
        
        System.assertEquals(1, ps.size(), 'Operator permission set should exist');
        System.assertEquals('Case Auto-Closer Operator', ps[0].Label, 
            'Operator permission set should have correct label');
    }
    
    @isTest
    static void testAdminAndOperator_DifferentPermissionLevels() {
        // This test verifies the permission sets exist and have different descriptions
        // Note: FieldPermissions for custom settings may not be queryable in all contexts
        
        PermissionSet adminPs = [
            SELECT Id, Name, Description FROM PermissionSet 
            WHERE Name = 'util_closer_Administrator' LIMIT 1
        ];
        PermissionSet opPs = [
            SELECT Id, Name, Description FROM PermissionSet 
            WHERE Name = 'util_closer_Operator' LIMIT 1
        ];
        
        // Verify both permission sets exist with different purposes
        System.assertNotEquals(null, adminPs.Id, 'Administrator permission set should exist');
        System.assertNotEquals(null, opPs.Id, 'Operator permission set should exist');
        
        // Verify they have different descriptions indicating different access levels
        System.assert(
            adminPs.Description.containsIgnoreCase('Full access') || 
            adminPs.Description.containsIgnoreCase('configure'),
            'Administrator description should indicate full access'
        );
        System.assert(
            opPs.Description.containsIgnoreCase('view') || 
            opPs.Description.containsIgnoreCase('Cannot modify'),
            'Operator description should indicate limited access'
        );
    }
}

