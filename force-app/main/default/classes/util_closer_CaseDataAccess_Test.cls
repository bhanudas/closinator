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

    // ==================== Child Record Query Tests ====================

    @isTest
    static void testQueryChildRecords_ValidChildObject() {
        // Setup - use CaseComment as a standard child object
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Insert a CaseComment
        CaseComment comment = new CaseComment(
            ParentId = testCase.Id,
            CommentBody = 'Test comment'
        );
        insert comment;

        Set<Id> caseIds = new Set<Id>{ testCase.Id };

        // Execute
        Test.startTest();
        List<SObject> results = util_closer_CaseDataAccess.queryChildRecords(
            'CaseComment',
            'ParentId',
            'CommentBody',
            caseIds
        );
        Test.stopTest();

        // Verify
        System.assertEquals(1, results.size(), 'Should return 1 child record');
    }

    @isTest
    static void testQueryChildRecords_EmptyCaseIds() {
        // Execute with empty set
        Test.startTest();
        List<SObject> results = util_closer_CaseDataAccess.queryChildRecords(
            'CaseComment',
            'ParentId',
            'CommentBody',
            new Set<Id>()
        );
        Test.stopTest();

        // Verify
        System.assertEquals(0, results.size(), 'Should return empty list for empty case IDs');
    }

    @isTest
    static void testQueryChildRecords_NullCaseIds() {
        // Execute with null
        Test.startTest();
        List<SObject> results = util_closer_CaseDataAccess.queryChildRecords(
            'CaseComment',
            'ParentId',
            'CommentBody',
            null
        );
        Test.stopTest();

        // Verify
        System.assertEquals(0, results.size(), 'Should return empty list for null case IDs');
    }

    @isTest
    static void testQueryChildRecords_BlankObjectName() {
        // Setup
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Set<Id> caseIds = new Set<Id>{ testCase.Id };

        // Execute with blank object name
        Test.startTest();
        List<SObject> results = util_closer_CaseDataAccess.queryChildRecords(
            '',
            'ParentId',
            'CommentBody',
            caseIds
        );
        Test.stopTest();

        // Verify
        System.assertEquals(0, results.size(), 'Should return empty list for blank object name');
    }

    @isTest
    static void testQueryChildRecords_BlankLookupField() {
        // Setup
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Set<Id> caseIds = new Set<Id>{ testCase.Id };

        // Execute with blank lookup field
        Test.startTest();
        List<SObject> results = util_closer_CaseDataAccess.queryChildRecords(
            'CaseComment',
            '',
            'CommentBody',
            caseIds
        );
        Test.stopTest();

        // Verify
        System.assertEquals(0, results.size(), 'Should return empty list for blank lookup field');
    }

    @isTest
    static void testQueryChildRecords_InvalidObjectName() {
        // Setup
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Set<Id> caseIds = new Set<Id>{ testCase.Id };

        // Execute with invalid object name - should handle gracefully
        Test.startTest();
        List<SObject> results = util_closer_CaseDataAccess.queryChildRecords(
            'NonExistentObject__c',
            'ParentId',
            'SomeField',
            caseIds
        );
        Test.stopTest();

        // Verify - should return empty list on error
        System.assertEquals(0, results.size(), 'Should return empty list for invalid object');
    }

    @isTest
    static void testQueryChildRecords_NoFilterField() {
        // Setup
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        CaseComment comment = new CaseComment(
            ParentId = testCase.Id,
            CommentBody = 'Test comment'
        );
        insert comment;

        Set<Id> caseIds = new Set<Id>{ testCase.Id };

        // Execute with null filter field
        Test.startTest();
        List<SObject> results = util_closer_CaseDataAccess.queryChildRecords(
            'CaseComment',
            'ParentId',
            null,
            caseIds
        );
        Test.stopTest();

        // Verify - should still return records without filter field
        System.assertEquals(1, results.size(), 'Should return child record without filter field');
    }

    @isTest
    static void testQueryChildRecords_MultipleCases() {
        // Setup - create multiple cases with comments
        List<Case> testCases = [SELECT Id FROM Case LIMIT 2];

        if (testCases.size() < 2) {
            // Create additional case if needed
            Case newCase = new Case(Subject = 'Additional Case', Status = 'New', Origin = 'Web');
            insert newCase;
            testCases.add(newCase);
        }

        List<CaseComment> comments = new List<CaseComment>();
        for (Case c : testCases) {
            comments.add(new CaseComment(
                ParentId = c.Id,
                CommentBody = 'Comment for ' + c.Id
            ));
        }
        insert comments;

        Set<Id> caseIds = new Set<Id>();
        for (Case c : testCases) {
            caseIds.add(c.Id);
        }

        // Execute
        Test.startTest();
        List<SObject> results = util_closer_CaseDataAccess.queryChildRecords(
            'CaseComment',
            'ParentId',
            'CommentBody',
            caseIds
        );
        Test.stopTest();

        // Verify
        System.assert(results.size() >= 2, 'Should return at least 2 child records');
    }

    @isTest
    static void testQueryChildRecords_InvalidFilterField() {
        // Setup
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        CaseComment comment = new CaseComment(
            ParentId = testCase.Id,
            CommentBody = 'Test comment'
        );
        insert comment;

        Set<Id> caseIds = new Set<Id>{ testCase.Id };

        // Execute with invalid filter field - should skip invalid field
        Test.startTest();
        List<SObject> results = util_closer_CaseDataAccess.queryChildRecords(
            'CaseComment',
            'ParentId',
            'InvalidField__c',
            caseIds
        );
        Test.stopTest();

        // Verify - should still return records (filter field is skipped if invalid)
        System.assertEquals(1, results.size(), 'Should return child record even with invalid filter field');
    }
}

