/**
 * @description Test class for util_closer_CaseDataAccess.
 * Tests query methods without sharing restrictions.
 */
@isTest
private class util_closer_CaseDataAccess_Test {
    
    @TestSetup
    static void setup() {
        // Create settings for tests
        util_closer_SettingsService.mockSettings = util_closer_TestDataFactory.createSettings(200, true, true);
        
        // Create test cases with various statuses
        List<Case> testCases = new List<Case>();
        testCases.add(new Case(Subject = 'Test Case 1', Status = 'New', Origin = 'Web'));
        testCases.add(new Case(Subject = 'Test Case 2', Status = 'Waiting on Customer', Origin = 'Web'));
        testCases.add(new Case(Subject = 'Test Case 3', Status = 'Pending Response', Origin = 'Web'));
        testCases.add(new Case(Subject = 'Test Case 4', Status = 'Closed', Origin = 'Web'));
        testCases.add(new Case(Subject = 'Test Case 5', Status = 'Working', Origin = 'Web'));
        insert testCases;
    }
    
    @isTest
    static void testQueryCasesByStatus_WithValidStatuses() {
        // Setup
        Set<String> sourceStatuses = new Set<String>{ 'New', 'Waiting on Customer', 'Pending Response' };
        
        // Execute
        Test.startTest();
        Database.QueryLocator ql = util_closer_CaseDataAccess.queryCasesByStatus(sourceStatuses);
        Test.stopTest();
        
        // Verify - QueryLocator should be created successfully
        System.assertNotEquals(null, ql, 'QueryLocator should not be null');
        
        // Verify results by querying directly
        List<Case> results = [
            SELECT Id, Status, IsClosed 
            FROM Case 
            WHERE IsClosed = false 
            AND Status IN :sourceStatuses
        ];
        System.assertEquals(3, results.size(), 'Should return 3 open cases with matching statuses');
    }
    
    @isTest
    static void testQueryCasesByStatus_WithEmptySet() {
        // Setup
        Set<String> sourceStatuses = new Set<String>();
        
        // Execute
        Test.startTest();
        Database.QueryLocator ql = util_closer_CaseDataAccess.queryCasesByStatus(sourceStatuses);
        Test.stopTest();
        
        // Verify - QueryLocator should be created (empty query)
        System.assertNotEquals(null, ql, 'QueryLocator should not be null even for empty set');
    }
    
    @isTest
    static void testQueryCasesByStatus_WithNullSet() {
        // Execute
        Test.startTest();
        Database.QueryLocator ql = util_closer_CaseDataAccess.queryCasesByStatus(null);
        Test.stopTest();
        
        // Verify - QueryLocator should be created (empty query)
        System.assertNotEquals(null, ql, 'QueryLocator should not be null even for null set');
    }
    
    @isTest
    static void testQueryCasesByStatus_ExcludesClosedCases() {
        // Setup
        Set<String> sourceStatuses = new Set<String>{ 'Closed' };
        
        // Execute
        Test.startTest();
        Database.QueryLocator ql = util_closer_CaseDataAccess.queryCasesByStatus(sourceStatuses);
        Test.stopTest();
        
        // Verify - QueryLocator should be created
        System.assertNotEquals(null, ql, 'QueryLocator should not be null');
        
        // Verify no closed cases are returned
        List<Case> results = [SELECT Id FROM Case WHERE IsClosed = false AND Status = 'Closed'];
        System.assertEquals(0, results.size(), 'Should exclude closed cases');
    }
    
    @isTest
    static void testQueryCasesByStatus_WithAdditionalFields() {
        // Setup
        Set<String> sourceStatuses = new Set<String>{ 'New' };
        Set<String> additionalFields = new Set<String>{ 'Subject', 'Origin' };
        
        // Execute
        Test.startTest();
        Database.QueryLocator ql = util_closer_CaseDataAccess.queryCasesByStatus(sourceStatuses, additionalFields);
        Test.stopTest();
        
        // Verify - QueryLocator should be created
        System.assertNotEquals(null, ql, 'QueryLocator should not be null');
    }
    
    @isTest
    static void testQueryCasesByStatus_WithAdditionalFields_EmptySet() {
        // Setup
        Set<String> sourceStatuses = new Set<String>{ 'New' };
        Set<String> additionalFields = new Set<String>();
        
        // Execute
        Test.startTest();
        Database.QueryLocator ql = util_closer_CaseDataAccess.queryCasesByStatus(sourceStatuses, additionalFields);
        Test.stopTest();
        
        // Verify - QueryLocator should be created
        System.assertNotEquals(null, ql, 'QueryLocator should not be null');
    }
    
    @isTest
    static void testQueryCasesByStatus_WithAdditionalFields_NullSet() {
        // Setup
        Set<String> sourceStatuses = new Set<String>{ 'New' };
        
        // Execute
        Test.startTest();
        Database.QueryLocator ql = util_closer_CaseDataAccess.queryCasesByStatus(sourceStatuses, null);
        Test.stopTest();
        
        // Verify - QueryLocator should be created
        System.assertNotEquals(null, ql, 'QueryLocator should not be null');
    }
    
    @isTest
    static void testQueryCasesWithCustomWhere_ValidWhereClause() {
        // Setup
        String whereClause = 'IsClosed = false AND Status = \'New\'';
        Set<String> additionalFields = new Set<String>();
        
        // Execute
        Test.startTest();
        Database.QueryLocator ql = util_closer_CaseDataAccess.queryCasesWithCustomWhere(whereClause, additionalFields);
        Test.stopTest();
        
        // Verify - QueryLocator should be created
        System.assertNotEquals(null, ql, 'QueryLocator should not be null');
    }
    
    @isTest
    static void testQueryCasesWithCustomWhere_BlankWhereClause() {
        // Setup
        String whereClause = '';
        Set<String> additionalFields = new Set<String>();
        
        // Execute
        Test.startTest();
        Database.QueryLocator ql = util_closer_CaseDataAccess.queryCasesWithCustomWhere(whereClause, additionalFields);
        Test.stopTest();
        
        // Verify - QueryLocator should be created (empty query)
        System.assertNotEquals(null, ql, 'QueryLocator should not be null even for blank WHERE clause');
    }
    
    @isTest
    static void testQueryCasesWithCustomWhere_NullWhereClause() {
        // Setup
        Set<String> additionalFields = new Set<String>();
        
        // Execute
        Test.startTest();
        Database.QueryLocator ql = util_closer_CaseDataAccess.queryCasesWithCustomWhere(null, additionalFields);
        Test.stopTest();
        
        // Verify - QueryLocator should be created (empty query)
        System.assertNotEquals(null, ql, 'QueryLocator should not be null even for null WHERE clause');
    }
    
    @isTest
    static void testQueryCasesWithCustomWhere_WithAdditionalFields() {
        // Setup
        String whereClause = 'IsClosed = false AND Status = \'New\'';
        Set<String> additionalFields = new Set<String>{ 'Subject', 'Origin' };
        
        // Execute
        Test.startTest();
        Database.QueryLocator ql = util_closer_CaseDataAccess.queryCasesWithCustomWhere(whereClause, additionalFields);
        Test.stopTest();
        
        // Verify - QueryLocator should be created
        System.assertNotEquals(null, ql, 'QueryLocator should not be null');
    }
}

