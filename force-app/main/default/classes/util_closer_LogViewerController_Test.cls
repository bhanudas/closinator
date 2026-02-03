/**
 * @description Test class for util_closer_LogViewerController
 * Provides comprehensive test coverage for all controller methods
 * @author Closinator Team
 * @date 2025
 */
@isTest
private class util_closer_LogViewerController_Test {
    
    @TestSetup
    static void setupTestData() {
        // Create batch logs with various statuses and modes
        List<util_closer_Batch_Log__c> batchLogs = new List<util_closer_Batch_Log__c>();
        
        // Completed simulation
        batchLogs.add(new util_closer_Batch_Log__c(
            Status__c = 'Completed',
            Execution_Mode__c = 'Simulation',
            Start_Time__c = Datetime.now().addHours(-2),
            End_Time__c = Datetime.now().addHours(-1),
            Total_Records_Processed__c = 100,
            Total_Records_Matched__c = 50,
            Total_Records_Updated__c = 0,
            Total_Records_Failed__c = 0,
            Active_Rules_Count__c = 3,
            Active_Rules_JSON__c = '["Rule1","Rule2","Rule3"]',
            Batch_Job_Id__c = '7071234567890123'
        ));
        
        // Completed full run
        batchLogs.add(new util_closer_Batch_Log__c(
            Status__c = 'Completed',
            Execution_Mode__c = 'Full',
            Start_Time__c = Datetime.now().addHours(-4),
            End_Time__c = Datetime.now().addHours(-3),
            Total_Records_Processed__c = 200,
            Total_Records_Matched__c = 100,
            Total_Records_Updated__c = 100,
            Total_Records_Failed__c = 0,
            Active_Rules_Count__c = 2,
            Batch_Job_Id__c = '7071234567890124'
        ));
        
        // Failed batch
        batchLogs.add(new util_closer_Batch_Log__c(
            Status__c = 'Failed',
            Execution_Mode__c = 'Full',
            Start_Time__c = Datetime.now().addDays(-1),
            End_Time__c = Datetime.now().addDays(-1).addMinutes(5),
            Total_Records_Processed__c = 50,
            Total_Records_Matched__c = 0,
            Total_Records_Updated__c = 0,
            Total_Records_Failed__c = 50,
            Active_Rules_Count__c = 1,
            Error_Summary__c = 'Test error message',
            Batch_Job_Id__c = '7071234567890125'
        ));
        
        // Running batch
        batchLogs.add(new util_closer_Batch_Log__c(
            Status__c = 'Running',
            Execution_Mode__c = 'Simulation',
            Start_Time__c = Datetime.now(),
            Total_Records_Processed__c = 0,
            Active_Rules_Count__c = 2,
            Batch_Job_Id__c = '7071234567890126'
        ));
        
        // Completed with errors
        batchLogs.add(new util_closer_Batch_Log__c(
            Status__c = 'Completed with Errors',
            Execution_Mode__c = 'Full',
            Start_Time__c = Datetime.now().addDays(-2),
            End_Time__c = Datetime.now().addDays(-2).addHours(1),
            Total_Records_Processed__c = 150,
            Total_Records_Matched__c = 75,
            Total_Records_Updated__c = 70,
            Total_Records_Failed__c = 5,
            Active_Rules_Count__c = 2,
            Error_Summary__c = 'Some records failed',
            Batch_Job_Id__c = '7071234567890127'
        ));
        
        insert batchLogs;
        
        // Create case logs for the first batch log
        List<util_closer_Case_Log__c> caseLogs = new List<util_closer_Case_Log__c>();
        Id batchLogId = batchLogs[0].Id;
        
        // Create various case log results
        String[] results = new String[]{'Matched', 'Not Matched', 'Simulated', 'Failed'};
        String[] statuses = new String[]{'New', 'Open', 'Pending'};
        String[] rules = new String[]{'Close_Old_Cases', 'Escalate_Priority', null};
        
        for (Integer i = 0; i < 25; i++) {
            String result = results[Math.mod(i, results.size())];
            String originalStatus = statuses[Math.mod(i, statuses.size())];
            String matchedRule = result == 'Matched' || result == 'Simulated' ? rules[Math.mod(i, 2)] : null;
            
            caseLogs.add(new util_closer_Case_Log__c(
                Batch_Log__c = batchLogId,
                Case_Number__c = 'CASE-' + String.valueOf(i).leftPad(5, '0'),
                Original_Status__c = originalStatus,
                Target_Status__c = result == 'Matched' || result == 'Simulated' ? 'Closed' : null,
                Processing_Result__c = result,
                Matched_Rule__c = matchedRule,
                Matched_Rule_Label__c = matchedRule,
                Rules_Evaluated_Count__c = 3,
                Processing_Time_Ms__c = Math.random() * 100,
                Error_Message__c = result == 'Failed' ? 'Test error' : null,
                Batch_Chunk_Number__c = Math.mod(i, 3) + 1
            ));
        }
        
        // Add case logs for second batch too
        Id batchLogId2 = batchLogs[1].Id;
        for (Integer i = 0; i < 15; i++) {
            caseLogs.add(new util_closer_Case_Log__c(
                Batch_Log__c = batchLogId2,
                Case_Number__c = 'CASE-2-' + String.valueOf(i).leftPad(5, '0'),
                Original_Status__c = 'Open',
                Target_Status__c = 'Closed',
                Processing_Result__c = 'Updated',
                Matched_Rule__c = 'Close_Old_Cases',
                Matched_Rule_Label__c = 'Close Old Cases',
                Rules_Evaluated_Count__c = 2,
                Processing_Time_Ms__c = 50
            ));
        }
        
        insert caseLogs;
    }
    
    @isTest
    static void testGetBatchLogs_NoFilter() {
        Test.startTest();
        util_closer_LogViewerController.BatchLogResult result = 
            util_closer_LogViewerController.getBatchLogs(null, 1, 10);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(5, result.totalRecords, 'Should have 5 batch logs');
        System.assertEquals(10, result.pageSize, 'Page size should be 10');
        System.assertEquals(1, result.pageNumber, 'Page number should be 1');
        System.assert(result.records.size() <= 10, 'Should return at most 10 records');
        System.assertNotEquals(null, result.statusCounts, 'Status counts should not be null');
        System.assertNotEquals(null, result.modeCounts, 'Mode counts should not be null');
    }
    
    @isTest
    static void testGetBatchLogs_WithStatusFilter() {
        util_closer_LogViewerController.BatchLogFilter filter = new util_closer_LogViewerController.BatchLogFilter();
        filter.status = 'Completed';
        String filterJson = JSON.serialize(filter);
        
        Test.startTest();
        util_closer_LogViewerController.BatchLogResult result = 
            util_closer_LogViewerController.getBatchLogs(filterJson, 1, 50);
        Test.stopTest();
        
        System.assertEquals(2, result.totalRecords, 'Should have 2 completed batch logs');
        for (util_closer_Batch_Log__c log : result.records) {
            System.assertEquals('Completed', log.Status__c, 'All records should be Completed');
        }
    }
    
    @isTest
    static void testGetBatchLogs_WithModeFilter() {
        util_closer_LogViewerController.BatchLogFilter filter = new util_closer_LogViewerController.BatchLogFilter();
        filter.executionMode = 'Simulation';
        String filterJson = JSON.serialize(filter);
        
        Test.startTest();
        util_closer_LogViewerController.BatchLogResult result = 
            util_closer_LogViewerController.getBatchLogs(filterJson, 1, 50);
        Test.stopTest();
        
        System.assertEquals(2, result.totalRecords, 'Should have 2 simulation batch logs');
        for (util_closer_Batch_Log__c log : result.records) {
            System.assertEquals('Simulation', log.Execution_Mode__c, 'All records should be Simulation');
        }
    }
    
    @isTest
    static void testGetBatchLogs_WithDateFilter() {
        util_closer_LogViewerController.BatchLogFilter filter = new util_closer_LogViewerController.BatchLogFilter();
        filter.startDate = Date.today().addDays(-3);
        filter.endDate = Date.today();
        String filterJson = JSON.serialize(filter);
        
        Test.startTest();
        util_closer_LogViewerController.BatchLogResult result = 
            util_closer_LogViewerController.getBatchLogs(filterJson, 1, 50);
        Test.stopTest();
        
        System.assert(result.totalRecords > 0, 'Should have some results within date range');
    }
    
    @isTest
    static void testGetBatchLogs_WithSearchTerm() {
        util_closer_LogViewerController.BatchLogFilter filter = new util_closer_LogViewerController.BatchLogFilter();
        filter.searchTerm = '7071234567890123';
        String filterJson = JSON.serialize(filter);
        
        Test.startTest();
        util_closer_LogViewerController.BatchLogResult result = 
            util_closer_LogViewerController.getBatchLogs(filterJson, 1, 50);
        Test.stopTest();
        
        System.assertEquals(1, result.totalRecords, 'Should find 1 batch log by job ID');
    }
    
    @isTest
    static void testGetBatchLogs_WithSorting() {
        util_closer_LogViewerController.BatchLogFilter filter = new util_closer_LogViewerController.BatchLogFilter();
        filter.sortField = 'Start_Time__c';
        filter.sortDirection = 'asc';
        String filterJson = JSON.serialize(filter);
        
        Test.startTest();
        util_closer_LogViewerController.BatchLogResult result = 
            util_closer_LogViewerController.getBatchLogs(filterJson, 1, 50);
        Test.stopTest();
        
        System.assertEquals(5, result.records.size(), 'Should return all 5 records');
        // Verify ascending order
        Datetime prevTime = null;
        for (util_closer_Batch_Log__c log : result.records) {
            if (prevTime != null && log.Start_Time__c != null) {
                System.assert(log.Start_Time__c >= prevTime, 'Records should be in ascending order');
            }
            prevTime = log.Start_Time__c;
        }
    }
    
    @isTest
    static void testGetBatchLogs_Pagination() {
        Test.startTest();
        util_closer_LogViewerController.BatchLogResult result1 = 
            util_closer_LogViewerController.getBatchLogs(null, 1, 2);
        util_closer_LogViewerController.BatchLogResult result2 = 
            util_closer_LogViewerController.getBatchLogs(null, 2, 2);
        Test.stopTest();
        
        System.assertEquals(2, result1.pageSize, 'Page size should be 2');
        System.assertEquals(2, result1.records.size(), 'First page should have 2 records');
        System.assertEquals(3, result1.totalPages, 'Should have 3 total pages');
        
        System.assertEquals(2, result2.pageNumber, 'Second page number should be 2');
        System.assertEquals(2, result2.records.size(), 'Second page should have 2 records');
        
        // Verify different records on each page
        System.assertNotEquals(result1.records[0].Id, result2.records[0].Id, 'Different pages should have different records');
    }
    
    @isTest
    static void testGetBatchLogs_InvalidPageSize() {
        Test.startTest();
        util_closer_LogViewerController.BatchLogResult result = 
            util_closer_LogViewerController.getBatchLogs(null, 1, 500);
        Test.stopTest();
        
        System.assertEquals(200, result.pageSize, 'Page size should be capped at 200');
    }
    
    @isTest
    static void testGetCaseLogs_NoFilter() {
        util_closer_Batch_Log__c batchLog = [SELECT Id FROM util_closer_Batch_Log__c WHERE Status__c = 'Completed' AND Execution_Mode__c = 'Simulation' LIMIT 1];
        
        util_closer_LogViewerController.CaseLogFilter filter = new util_closer_LogViewerController.CaseLogFilter();
        filter.batchLogId = batchLog.Id;
        String filterJson = JSON.serialize(filter);
        
        Test.startTest();
        util_closer_LogViewerController.CaseLogResult result = 
            util_closer_LogViewerController.getCaseLogs(filterJson, 1, 50);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(25, result.totalRecords, 'Should have 25 case logs');
        System.assertNotEquals(null, result.resultCounts, 'Result counts should not be null');
        System.assertNotEquals(null, result.ruleCounts, 'Rule counts should not be null');
    }
    
    @isTest
    static void testGetCaseLogs_NoBatchLogId() {
        Test.startTest();
        util_closer_LogViewerController.CaseLogResult result = 
            util_closer_LogViewerController.getCaseLogs(null, 1, 50);
        Test.stopTest();
        
        System.assertEquals(0, result.totalRecords, 'Should have 0 records without batch log ID');
        System.assertEquals(0, result.records.size(), 'Records list should be empty');
    }
    
    @isTest
    static void testGetCaseLogs_WithResultFilter() {
        util_closer_Batch_Log__c batchLog = [SELECT Id FROM util_closer_Batch_Log__c WHERE Status__c = 'Completed' AND Execution_Mode__c = 'Simulation' LIMIT 1];
        
        util_closer_LogViewerController.CaseLogFilter filter = new util_closer_LogViewerController.CaseLogFilter();
        filter.batchLogId = batchLog.Id;
        filter.processingResult = 'Matched';
        String filterJson = JSON.serialize(filter);
        
        Test.startTest();
        util_closer_LogViewerController.CaseLogResult result = 
            util_closer_LogViewerController.getCaseLogs(filterJson, 1, 50);
        Test.stopTest();
        
        System.assert(result.totalRecords > 0, 'Should have some matched records');
        for (util_closer_Case_Log__c log : result.records) {
            System.assertEquals('Matched', log.Processing_Result__c, 'All records should be Matched');
        }
    }
    
    @isTest
    static void testGetCaseLogs_WithRuleFilter() {
        util_closer_Batch_Log__c batchLog = [SELECT Id FROM util_closer_Batch_Log__c WHERE Status__c = 'Completed' AND Execution_Mode__c = 'Simulation' LIMIT 1];
        
        util_closer_LogViewerController.CaseLogFilter filter = new util_closer_LogViewerController.CaseLogFilter();
        filter.batchLogId = batchLog.Id;
        filter.matchedRule = 'Close_Old_Cases';
        String filterJson = JSON.serialize(filter);
        
        Test.startTest();
        util_closer_LogViewerController.CaseLogResult result = 
            util_closer_LogViewerController.getCaseLogs(filterJson, 1, 50);
        Test.stopTest();
        
        for (util_closer_Case_Log__c log : result.records) {
            System.assertEquals('Close_Old_Cases', log.Matched_Rule_Label__c, 'All records should match Close_Old_Cases');
        }
    }
    
    @isTest
    static void testGetCaseLogs_WithStatusFilters() {
        util_closer_Batch_Log__c batchLog = [SELECT Id FROM util_closer_Batch_Log__c WHERE Status__c = 'Completed' AND Execution_Mode__c = 'Simulation' LIMIT 1];
        
        util_closer_LogViewerController.CaseLogFilter filter = new util_closer_LogViewerController.CaseLogFilter();
        filter.batchLogId = batchLog.Id;
        filter.originalStatus = 'New';
        String filterJson = JSON.serialize(filter);
        
        Test.startTest();
        util_closer_LogViewerController.CaseLogResult result = 
            util_closer_LogViewerController.getCaseLogs(filterJson, 1, 50);
        Test.stopTest();
        
        for (util_closer_Case_Log__c log : result.records) {
            System.assertEquals('New', log.Original_Status__c, 'All records should have New original status');
        }
    }
    
    @isTest
    static void testGetCaseLogs_WithSearchTerm() {
        util_closer_Batch_Log__c batchLog = [SELECT Id FROM util_closer_Batch_Log__c WHERE Status__c = 'Completed' AND Execution_Mode__c = 'Simulation' LIMIT 1];
        
        util_closer_LogViewerController.CaseLogFilter filter = new util_closer_LogViewerController.CaseLogFilter();
        filter.batchLogId = batchLog.Id;
        filter.searchTerm = 'CASE-00010';
        String filterJson = JSON.serialize(filter);
        
        Test.startTest();
        util_closer_LogViewerController.CaseLogResult result = 
            util_closer_LogViewerController.getCaseLogs(filterJson, 1, 50);
        Test.stopTest();
        
        System.assertEquals(1, result.totalRecords, 'Should find 1 case log by case number');
    }
    
    @isTest
    static void testGetCaseLogs_Pagination() {
        util_closer_Batch_Log__c batchLog = [SELECT Id FROM util_closer_Batch_Log__c WHERE Status__c = 'Completed' AND Execution_Mode__c = 'Simulation' LIMIT 1];
        
        util_closer_LogViewerController.CaseLogFilter filter = new util_closer_LogViewerController.CaseLogFilter();
        filter.batchLogId = batchLog.Id;
        String filterJson = JSON.serialize(filter);
        
        Test.startTest();
        util_closer_LogViewerController.CaseLogResult result1 = 
            util_closer_LogViewerController.getCaseLogs(filterJson, 1, 10);
        util_closer_LogViewerController.CaseLogResult result2 = 
            util_closer_LogViewerController.getCaseLogs(filterJson, 2, 10);
        Test.stopTest();
        
        System.assertEquals(10, result1.records.size(), 'First page should have 10 records');
        System.assertEquals(10, result2.records.size(), 'Second page should have 10 records');
        System.assertEquals(3, result1.totalPages, 'Should have 3 total pages');
    }
    
    @isTest
    static void testGetBatchLogDetails() {
        util_closer_Batch_Log__c batchLog = [SELECT Id FROM util_closer_Batch_Log__c LIMIT 1];
        
        Test.startTest();
        util_closer_Batch_Log__c result = util_closer_LogViewerController.getBatchLogDetails(batchLog.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(batchLog.Id, result.Id, 'Should return correct batch log');
    }
    
    @isTest
    static void testGetBatchLogDetails_NullId() {
        Test.startTest();
        util_closer_Batch_Log__c result = util_closer_LogViewerController.getBatchLogDetails(null);
        Test.stopTest();
        
        System.assertEquals(null, result, 'Result should be null for null ID');
    }
    
    @isTest
    static void testExportCaseLogsAsCsv() {
        util_closer_Batch_Log__c batchLog = [SELECT Id FROM util_closer_Batch_Log__c WHERE Status__c = 'Completed' AND Execution_Mode__c = 'Simulation' LIMIT 1];
        
        Test.startTest();
        String csv = util_closer_LogViewerController.exportCaseLogsAsCsv(batchLog.Id, null);
        Test.stopTest();
        
        System.assert(String.isNotBlank(csv), 'CSV should not be blank');
        System.assert(csv.contains('Log Name'), 'CSV should contain header');
        System.assert(csv.contains('CLOG-'), 'CSV should contain case log names');
    }
    
    @isTest
    static void testExportCaseLogsAsCsv_WithFilter() {
        util_closer_Batch_Log__c batchLog = [SELECT Id FROM util_closer_Batch_Log__c WHERE Status__c = 'Completed' AND Execution_Mode__c = 'Simulation' LIMIT 1];
        
        util_closer_LogViewerController.CaseLogFilter filter = new util_closer_LogViewerController.CaseLogFilter();
        filter.processingResult = 'Matched';
        String filterJson = JSON.serialize(filter);
        
        Test.startTest();
        String csv = util_closer_LogViewerController.exportCaseLogsAsCsv(batchLog.Id, filterJson);
        Test.stopTest();
        
        System.assert(String.isNotBlank(csv), 'CSV should not be blank');
        // Count rows (including header)
        List<String> rows = csv.split('\n');
        System.assert(rows.size() > 1, 'CSV should have data rows');
    }
    
    @isTest
    static void testGetCaseLogFilterOptions() {
        util_closer_Batch_Log__c batchLog = [SELECT Id FROM util_closer_Batch_Log__c WHERE Status__c = 'Completed' AND Execution_Mode__c = 'Simulation' LIMIT 1];
        
        Test.startTest();
        Map<String, List<String>> options = util_closer_LogViewerController.getCaseLogFilterOptions(batchLog.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, options, 'Options should not be null');
        System.assert(options.containsKey('originalStatuses'), 'Should have original statuses');
        System.assert(options.containsKey('targetStatuses'), 'Should have target statuses');
        System.assert(options.containsKey('matchedRules'), 'Should have matched rules');
    }
    
    @isTest
    static void testGetCaseLogFilterOptions_NullId() {
        Test.startTest();
        Map<String, List<String>> options = util_closer_LogViewerController.getCaseLogFilterOptions(null);
        Test.stopTest();
        
        System.assertNotEquals(null, options, 'Options should not be null');
        System.assertEquals(0, options.size(), 'Options should be empty for null ID');
    }
    
    @isTest
    static void testCombinedFilters() {
        util_closer_LogViewerController.BatchLogFilter filter = new util_closer_LogViewerController.BatchLogFilter();
        filter.status = 'Completed';
        filter.executionMode = 'Simulation';
        filter.startDate = Date.today().addDays(-7);
        filter.endDate = Date.today();
        filter.sortField = 'Total_Records_Processed__c';
        filter.sortDirection = 'desc';
        String filterJson = JSON.serialize(filter);
        
        Test.startTest();
        util_closer_LogViewerController.BatchLogResult result = 
            util_closer_LogViewerController.getBatchLogs(filterJson, 1, 50);
        Test.stopTest();
        
        System.assertEquals(1, result.totalRecords, 'Should find 1 completed simulation within date range');
    }
    
    @isTest
    static void testInvalidFilterJson() {
        Test.startTest();
        util_closer_LogViewerController.BatchLogResult result = 
            util_closer_LogViewerController.getBatchLogs('invalid json', 1, 50);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Should handle invalid JSON gracefully');
        System.assertEquals(5, result.totalRecords, 'Should return all records when filter is invalid');
    }
    
    @isTest
    static void testNegativePageNumber() {
        Test.startTest();
        util_closer_LogViewerController.BatchLogResult result = 
            util_closer_LogViewerController.getBatchLogs(null, -1, 50);
        Test.stopTest();
        
        System.assertEquals(1, result.pageNumber, 'Negative page number should default to 1');
    }
    
    @isTest
    static void testZeroPageSize() {
        Test.startTest();
        util_closer_LogViewerController.BatchLogResult result = 
            util_closer_LogViewerController.getBatchLogs(null, 1, 0);
        Test.stopTest();
        
        System.assertEquals(50, result.pageSize, 'Zero page size should default to 50');
    }
}
