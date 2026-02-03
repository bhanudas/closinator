/**
 * @description Controller for the Log Viewer LWC component.
 * Provides paginated access to Batch Logs and Case Logs with filtering capabilities.
 * Designed to handle 10,000+ records efficiently through server-side pagination.
 * @author Closinator Team
 * @date 2025
 */
public with sharing class util_closer_LogViewerController {
    
    private static final Integer DEFAULT_PAGE_SIZE = 50;
    private static final Integer MAX_PAGE_SIZE = 200;
    
    /**
     * @description Wrapper class for paginated batch log results
     */
    public class BatchLogResult {
        @AuraEnabled public List<util_closer_Batch_Log__c> records { get; set; }
        @AuraEnabled public Integer totalRecords { get; set; }
        @AuraEnabled public Integer pageSize { get; set; }
        @AuraEnabled public Integer pageNumber { get; set; }
        @AuraEnabled public Integer totalPages { get; set; }
        @AuraEnabled public Map<String, Integer> statusCounts { get; set; }
        @AuraEnabled public Map<String, Integer> modeCounts { get; set; }
    }
    
    /**
     * @description Wrapper class for paginated case log results
     */
    public class CaseLogResult {
        @AuraEnabled public List<util_closer_Case_Log__c> records { get; set; }
        @AuraEnabled public Integer totalRecords { get; set; }
        @AuraEnabled public Integer pageSize { get; set; }
        @AuraEnabled public Integer pageNumber { get; set; }
        @AuraEnabled public Integer totalPages { get; set; }
        @AuraEnabled public Map<String, Integer> resultCounts { get; set; }
        @AuraEnabled public Map<String, Integer> ruleCounts { get; set; }
    }
    
    /**
     * @description Filter criteria for batch logs
     */
    public class BatchLogFilter {
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String executionMode { get; set; }
        @AuraEnabled public Date startDate { get; set; }
        @AuraEnabled public Date endDate { get; set; }
        @AuraEnabled public String searchTerm { get; set; }
        @AuraEnabled public String sortField { get; set; }
        @AuraEnabled public String sortDirection { get; set; }
    }
    
    /**
     * @description Filter criteria for case logs
     */
    public class CaseLogFilter {
        @AuraEnabled public String batchLogId { get; set; }
        @AuraEnabled public String processingResult { get; set; }
        @AuraEnabled public String matchedRule { get; set; }
        @AuraEnabled public String originalStatus { get; set; }
        @AuraEnabled public String targetStatus { get; set; }
        @AuraEnabled public String searchTerm { get; set; }
        @AuraEnabled public String sortField { get; set; }
        @AuraEnabled public String sortDirection { get; set; }
    }
    
    /**
     * @description Get paginated batch logs with filter counts
     * @param filterJson JSON string containing BatchLogFilter
     * @param pageNumber Page number (1-based)
     * @param pageSize Number of records per page
     * @return BatchLogResult with records and metadata
     */
    @AuraEnabled(cacheable=false)
    public static BatchLogResult getBatchLogs(String filterJson, Integer pageNumber, Integer pageSize) {
        BatchLogFilter filter = parseBatchLogFilter(filterJson);
        pageSize = validatePageSize(pageSize);
        pageNumber = Math.max(1, pageNumber);
        
        BatchLogResult result = new BatchLogResult();
        result.pageSize = pageSize;
        result.pageNumber = pageNumber;
        
        // Build dynamic query
        String baseQuery = 'SELECT Id, Name, Status__c, Execution_Mode__c, Start_Time__c, End_Time__c, ' +
                          'Duration_Seconds__c, Total_Records_Processed__c, Total_Records_Matched__c, ' +
                          'Total_Records_Updated__c, Total_Records_Failed__c, Active_Rules_Count__c, ' +
                          'Running_User__c, Error_Summary__c, CreatedDate ' +
                          'FROM util_closer_Batch_Log__c';
        
        String countQuery = 'SELECT COUNT() FROM util_closer_Batch_Log__c';
        
        String whereClause = buildBatchWhereClause(filter);
        if (String.isNotBlank(whereClause)) {
            baseQuery += ' WHERE ' + whereClause;
            countQuery += ' WHERE ' + whereClause;
        }
        
        // Get total count
        result.totalRecords = Database.countQuery(countQuery);
        result.totalPages = (Integer)Math.ceil((Decimal)result.totalRecords / pageSize);
        
        // Add sorting
        String sortField = String.isNotBlank(filter?.sortField) ? filter.sortField : 'CreatedDate';
        String sortDirection = filter?.sortDirection == 'asc' ? 'ASC' : 'DESC';
        baseQuery += ' ORDER BY ' + String.escapeSingleQuotes(sortField) + ' ' + sortDirection + ' NULLS LAST';
        
        // Add pagination
        Integer offset = (pageNumber - 1) * pageSize;
        baseQuery += ' LIMIT :pageSize OFFSET :offset';
        
        // Execute query
        result.records = Database.query(baseQuery);
        
        // Get filter counts
        result.statusCounts = getBatchStatusCounts(filter);
        result.modeCounts = getBatchModeCounts(filter);
        
        return result;
    }
    
    /**
     * @description Get paginated case logs for a specific batch with filter counts
     * @param filterJson JSON string containing CaseLogFilter
     * @param pageNumber Page number (1-based)
     * @param pageSize Number of records per page
     * @return CaseLogResult with records and metadata
     */
    @AuraEnabled(cacheable=false)
    public static CaseLogResult getCaseLogs(String filterJson, Integer pageNumber, Integer pageSize) {
        CaseLogFilter filter = parseCaseLogFilter(filterJson);
        pageSize = validatePageSize(pageSize);
        pageNumber = Math.max(1, pageNumber);
        
        CaseLogResult result = new CaseLogResult();
        result.pageSize = pageSize;
        result.pageNumber = pageNumber;
        
        // Validate batch log ID
        if (String.isBlank(filter?.batchLogId)) {
            result.records = new List<util_closer_Case_Log__c>();
            result.totalRecords = 0;
            result.totalPages = 0;
            result.resultCounts = new Map<String, Integer>();
            result.ruleCounts = new Map<String, Integer>();
            return result;
        }
        
        // Build dynamic query
        String baseQuery = 'SELECT Id, Name, Case__c, Case_Number__c, Original_Status__c, Target_Status__c, ' +
                          'Target_Reason__c, Processing_Result__c, Matched_Rule__c, Matched_Rule_Label__c, ' +
                          'Rules_Evaluated_Count__c, Processing_Time_Ms__c, Error_Message__c, ' +
                          'Batch_Chunk_Number__c, Child_Records_Checked__c, Child_Records_Found__c, ' +
                          'Rule_Evaluation_Details__c, CreatedDate ' +
                          'FROM util_closer_Case_Log__c';
        
        String countQuery = 'SELECT COUNT() FROM util_closer_Case_Log__c';
        
        String whereClause = buildCaseWhereClause(filter);
        baseQuery += ' WHERE ' + whereClause;
        countQuery += ' WHERE ' + whereClause;
        
        // Get total count
        result.totalRecords = Database.countQuery(countQuery);
        result.totalPages = (Integer)Math.ceil((Decimal)result.totalRecords / pageSize);
        
        // Add sorting
        String sortField = String.isNotBlank(filter?.sortField) ? filter.sortField : 'CreatedDate';
        String sortDirection = filter?.sortDirection == 'asc' ? 'ASC' : 'DESC';
        baseQuery += ' ORDER BY ' + String.escapeSingleQuotes(sortField) + ' ' + sortDirection + ' NULLS LAST';
        
        // Add pagination
        Integer offset = (pageNumber - 1) * pageSize;
        baseQuery += ' LIMIT :pageSize OFFSET :offset';
        
        // Execute query
        result.records = Database.query(baseQuery);
        
        // Get filter counts
        result.resultCounts = getCaseResultCounts(filter);
        result.ruleCounts = getCaseRuleCounts(filter);
        
        return result;
    }
    
    /**
     * @description Get a single batch log record with full details
     * @param batchLogId The batch log record ID
     * @return The batch log record
     */
    @AuraEnabled(cacheable=true)
    public static util_closer_Batch_Log__c getBatchLogDetails(Id batchLogId) {
        if (batchLogId == null) {
            return null;
        }
        
        List<util_closer_Batch_Log__c> logs = [
            SELECT Id, Name, Status__c, Execution_Mode__c, Start_Time__c, End_Time__c,
                   Duration_Seconds__c, Total_Records_Processed__c, Total_Records_Matched__c,
                   Total_Records_Updated__c, Total_Records_Failed__c, Total_Batches_Executed__c,
                   Active_Rules_Count__c, Active_Rules_JSON__c, Status_Transitions_JSON__c,
                   Running_User__c, Batch_Job_Id__c, Error_Summary__c, CreatedDate
            FROM util_closer_Batch_Log__c
            WHERE Id = :batchLogId
            LIMIT 1
        ];
        
        return logs.isEmpty() ? null : logs[0];
    }
    
    /**
     * @description Export case logs for a batch as CSV data
     * @param batchLogId The batch log ID
     * @param filterJson Filter criteria
     * @return CSV string of case log data
     */
    @AuraEnabled
    public static String exportCaseLogsAsCsv(Id batchLogId, String filterJson) {
        CaseLogFilter filter = parseCaseLogFilter(filterJson);
        if (filter == null) {
            filter = new CaseLogFilter();
        }
        filter.batchLogId = batchLogId;
        
        String whereClause = buildCaseWhereClause(filter);
        String query = 'SELECT Name, Case_Number__c, Original_Status__c, Target_Status__c, ' +
                      'Processing_Result__c, Matched_Rule_Label__c, Error_Message__c, CreatedDate ' +
                      'FROM util_closer_Case_Log__c WHERE ' + whereClause +
                      ' ORDER BY CreatedDate DESC LIMIT 50000';
        
        List<util_closer_Case_Log__c> logs = Database.query(query);
        
        // Build CSV
        List<String> headers = new List<String>{
            'Log Name', 'Case Number', 'Original Status', 'Target Status',
            'Result', 'Matched Rule', 'Error Message', 'Created Date'
        };
        
        List<String> rows = new List<String>{ String.join(headers, ',') };
        
        for (util_closer_Case_Log__c log : logs) {
            List<String> values = new List<String>{
                escapeCsvValue(log.Name),
                escapeCsvValue(log.Case_Number__c),
                escapeCsvValue(log.Original_Status__c),
                escapeCsvValue(log.Target_Status__c),
                escapeCsvValue(log.Processing_Result__c),
                escapeCsvValue(log.Matched_Rule_Label__c),
                escapeCsvValue(log.Error_Message__c),
                log.CreatedDate != null ? log.CreatedDate.format() : ''
            };
            rows.add(String.join(values, ','));
        }
        
        return String.join(rows, '\n');
    }
    
    /**
     * @description Get available filter options for case logs
     * @param batchLogId The batch log ID
     * @return Map of filter field to available values
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getCaseLogFilterOptions(Id batchLogId) {
        Map<String, List<String>> options = new Map<String, List<String>>();
        
        if (batchLogId == null) {
            return options;
        }
        
        // Get unique original statuses
        Set<String> originalStatuses = new Set<String>();
        Set<String> targetStatuses = new Set<String>();
        Set<String> rules = new Set<String>();
        
        for (AggregateResult ar : [
            SELECT Original_Status__c status
            FROM util_closer_Case_Log__c
            WHERE Batch_Log__c = :batchLogId AND Original_Status__c != null
            GROUP BY Original_Status__c
        ]) {
            originalStatuses.add((String)ar.get('status'));
        }
        
        for (AggregateResult ar : [
            SELECT Target_Status__c status
            FROM util_closer_Case_Log__c
            WHERE Batch_Log__c = :batchLogId AND Target_Status__c != null
            GROUP BY Target_Status__c
        ]) {
            targetStatuses.add((String)ar.get('status'));
        }
        
        for (AggregateResult ar : [
            SELECT Matched_Rule_Label__c rule
            FROM util_closer_Case_Log__c
            WHERE Batch_Log__c = :batchLogId AND Matched_Rule_Label__c != null
            GROUP BY Matched_Rule_Label__c
        ]) {
            rules.add((String)ar.get('rule'));
        }
        
        options.put('originalStatuses', new List<String>(originalStatuses));
        options.put('targetStatuses', new List<String>(targetStatuses));
        options.put('matchedRules', new List<String>(rules));
        
        return options;
    }
    
    // ============= Private Helper Methods =============
    
    private static BatchLogFilter parseBatchLogFilter(String filterJson) {
        if (String.isBlank(filterJson)) {
            return null;
        }
        try {
            return (BatchLogFilter)JSON.deserialize(filterJson, BatchLogFilter.class);
        } catch (Exception e) {
            return null;
        }
    }
    
    private static CaseLogFilter parseCaseLogFilter(String filterJson) {
        if (String.isBlank(filterJson)) {
            return null;
        }
        try {
            return (CaseLogFilter)JSON.deserialize(filterJson, CaseLogFilter.class);
        } catch (Exception e) {
            return null;
        }
    }
    
    private static Integer validatePageSize(Integer pageSize) {
        if (pageSize == null || pageSize < 1) {
            return DEFAULT_PAGE_SIZE;
        }
        return Math.min(pageSize, MAX_PAGE_SIZE);
    }
    
    private static String buildBatchWhereClause(BatchLogFilter filter) {
        List<String> conditions = new List<String>();
        
        if (filter != null) {
            if (String.isNotBlank(filter.status)) {
                conditions.add('Status__c = \'' + String.escapeSingleQuotes(filter.status) + '\'');
            }
            if (String.isNotBlank(filter.executionMode)) {
                conditions.add('Execution_Mode__c = \'' + String.escapeSingleQuotes(filter.executionMode) + '\'');
            }
            if (filter.startDate != null) {
                conditions.add('Start_Time__c >= ' + formatDate(filter.startDate));
            }
            if (filter.endDate != null) {
                conditions.add('Start_Time__c <= ' + formatDate(filter.endDate.addDays(1)));
            }
            if (String.isNotBlank(filter.searchTerm)) {
                String searchTerm = '%' + String.escapeSingleQuotes(filter.searchTerm) + '%';
                conditions.add('(Name LIKE \'' + searchTerm + '\' OR Batch_Job_Id__c LIKE \'' + searchTerm + '\')');
            }
        }
        
        return String.join(conditions, ' AND ');
    }
    
    private static String buildCaseWhereClause(CaseLogFilter filter) {
        List<String> conditions = new List<String>();
        
        // Batch Log ID is required
        conditions.add('Batch_Log__c = \'' + String.escapeSingleQuotes(filter.batchLogId) + '\'');
        
        if (String.isNotBlank(filter.processingResult)) {
            conditions.add('Processing_Result__c = \'' + String.escapeSingleQuotes(filter.processingResult) + '\'');
        }
        if (String.isNotBlank(filter.matchedRule)) {
            conditions.add('Matched_Rule_Label__c = \'' + String.escapeSingleQuotes(filter.matchedRule) + '\'');
        }
        if (String.isNotBlank(filter.originalStatus)) {
            conditions.add('Original_Status__c = \'' + String.escapeSingleQuotes(filter.originalStatus) + '\'');
        }
        if (String.isNotBlank(filter.targetStatus)) {
            conditions.add('Target_Status__c = \'' + String.escapeSingleQuotes(filter.targetStatus) + '\'');
        }
        if (String.isNotBlank(filter.searchTerm)) {
            String searchTerm = '%' + String.escapeSingleQuotes(filter.searchTerm) + '%';
            conditions.add('(Name LIKE \'' + searchTerm + '\' OR Case_Number__c LIKE \'' + searchTerm + '\')');
        }
        
        return String.join(conditions, ' AND ');
    }
    
    private static Map<String, Integer> getBatchStatusCounts(BatchLogFilter filter) {
        Map<String, Integer> counts = new Map<String, Integer>();
        
        // Clone filter without status to get counts for all statuses
        BatchLogFilter countFilter = filter != null ? filter : new BatchLogFilter();
        String tempStatus = countFilter.status;
        countFilter.status = null;
        
        String whereClause = buildBatchWhereClause(countFilter);
        String query = 'SELECT Status__c status, COUNT(Id) cnt FROM util_closer_Batch_Log__c';
        if (String.isNotBlank(whereClause)) {
            query += ' WHERE ' + whereClause;
        }
        query += ' GROUP BY Status__c';
        
        for (AggregateResult ar : Database.query(query)) {
            String status = (String)ar.get('status');
            Integer cnt = (Integer)ar.get('cnt');
            counts.put(status != null ? status : 'null', cnt);
        }
        
        countFilter.status = tempStatus;
        return counts;
    }
    
    private static Map<String, Integer> getBatchModeCounts(BatchLogFilter filter) {
        Map<String, Integer> counts = new Map<String, Integer>();
        
        // Clone filter without mode to get counts for all modes
        BatchLogFilter countFilter = filter != null ? filter : new BatchLogFilter();
        String tempMode = countFilter.executionMode;
        countFilter.executionMode = null;
        
        String whereClause = buildBatchWhereClause(countFilter);
        String query = 'SELECT Execution_Mode__c mode, COUNT(Id) cnt FROM util_closer_Batch_Log__c';
        if (String.isNotBlank(whereClause)) {
            query += ' WHERE ' + whereClause;
        }
        query += ' GROUP BY Execution_Mode__c';
        
        for (AggregateResult ar : Database.query(query)) {
            String mode = (String)ar.get('mode');
            Integer cnt = (Integer)ar.get('cnt');
            counts.put(mode != null ? mode : 'null', cnt);
        }
        
        countFilter.executionMode = tempMode;
        return counts;
    }
    
    private static Map<String, Integer> getCaseResultCounts(CaseLogFilter filter) {
        Map<String, Integer> counts = new Map<String, Integer>();
        
        if (String.isBlank(filter?.batchLogId)) {
            return counts;
        }
        
        // Clone filter without result to get counts for all results
        CaseLogFilter countFilter = new CaseLogFilter();
        countFilter.batchLogId = filter.batchLogId;
        countFilter.originalStatus = filter.originalStatus;
        countFilter.targetStatus = filter.targetStatus;
        countFilter.matchedRule = filter.matchedRule;
        countFilter.searchTerm = filter.searchTerm;
        
        String whereClause = buildCaseWhereClause(countFilter);
        String query = 'SELECT Processing_Result__c result, COUNT(Id) cnt FROM util_closer_Case_Log__c ' +
                      'WHERE ' + whereClause + ' GROUP BY Processing_Result__c';
        
        for (AggregateResult ar : Database.query(query)) {
            String result = (String)ar.get('result');
            Integer cnt = (Integer)ar.get('cnt');
            counts.put(result != null ? result : 'null', cnt);
        }
        
        return counts;
    }
    
    private static Map<String, Integer> getCaseRuleCounts(CaseLogFilter filter) {
        Map<String, Integer> counts = new Map<String, Integer>();
        
        if (String.isBlank(filter?.batchLogId)) {
            return counts;
        }
        
        // Clone filter without rule to get counts for all rules
        CaseLogFilter countFilter = new CaseLogFilter();
        countFilter.batchLogId = filter.batchLogId;
        countFilter.processingResult = filter.processingResult;
        countFilter.originalStatus = filter.originalStatus;
        countFilter.targetStatus = filter.targetStatus;
        countFilter.searchTerm = filter.searchTerm;
        
        String whereClause = buildCaseWhereClause(countFilter);
        String query = 'SELECT Matched_Rule_Label__c rule, COUNT(Id) cnt FROM util_closer_Case_Log__c ' +
                      'WHERE ' + whereClause + ' GROUP BY Matched_Rule_Label__c';
        
        for (AggregateResult ar : Database.query(query)) {
            String rule = (String)ar.get('rule');
            Integer cnt = (Integer)ar.get('cnt');
            counts.put(rule != null ? rule : 'No Match', cnt);
        }
        
        return counts;
    }
    
    private static String formatDate(Date d) {
        return Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0)).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }
    
    private static String escapeCsvValue(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        // Escape quotes and wrap in quotes if contains comma, quote, or newline
        if (value.contains(',') || value.contains('"') || value.contains('\n')) {
            return '"' + value.replace('"', '""') + '"';
        }
        return value;
    }
}
