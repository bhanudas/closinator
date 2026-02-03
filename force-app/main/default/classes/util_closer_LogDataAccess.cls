/**
 * @description Without-sharing data access class for log operations.
 * Provides CRUD operations for Batch_Log__c and Case_Log__c objects
 * without enforcing sharing rules to ensure consistent logging access.
 */
public without sharing class util_closer_LogDataAccess {

    /**
     * @description Inserts a single Batch Log record.
     * @param batchLog The Batch Log record to insert.
     * @return The inserted Batch Log with Id populated.
     */
    public static util_closer_Batch_Log__c insertBatchLog(util_closer_Batch_Log__c batchLog) {
        insert batchLog;
        return batchLog;
    }

    /**
     * @description Updates a single Batch Log record.
     * @param batchLog The Batch Log record to update.
     */
    public static void updateBatchLog(util_closer_Batch_Log__c batchLog) {
        update batchLog;
    }

    /**
     * @description Inserts a list of Case Log records.
     * Uses Database.insert with allOrNone=false for partial success.
     * @param caseLogs The list of Case Log records to insert.
     * @return List of Database.SaveResult for each insert operation.
     */
    public static List<Database.SaveResult> insertCaseLogs(List<util_closer_Case_Log__c> caseLogs) {
        return Database.insert(caseLogs, false);
    }

    /**
     * @description Queries Batch Logs older than the specified cutoff date.
     * Used by cleanup batch to identify logs for deletion.
     * @param cutoffDate The cutoff DateTime - logs older than this will be returned.
     * @return List of Batch Log Ids for deletion.
     */
    public static List<util_closer_Batch_Log__c> queryBatchLogsOlderThan(DateTime cutoffDate) {
        return [
            SELECT Id
            FROM util_closer_Batch_Log__c
            WHERE Start_Time__c < :cutoffDate
            ORDER BY Start_Time__c ASC
            LIMIT 10000
        ];
    }

    /**
     * @description Queries stale "Running" Batch Logs older than the specified hours.
     * Used to identify batch logs that may have failed without proper completion.
     * @param hoursOld Number of hours - Running logs older than this are considered stale.
     * @return List of stale Batch Log records.
     */
    public static List<util_closer_Batch_Log__c> queryStaleBatchLogs(Integer hoursOld) {
        DateTime cutoff = DateTime.now().addHours(-hoursOld);
        return [
            SELECT Id, Start_Time__c, Batch_Job_Id__c
            FROM util_closer_Batch_Log__c
            WHERE Status__c = 'Running'
            AND Start_Time__c < :cutoff
            LIMIT 1000
        ];
    }

    /**
     * @description Deletes Batch Log records. Case Logs are cascade deleted due to Master-Detail.
     * @param batchLogs The list of Batch Log records to delete.
     */
    public static void deleteBatchLogs(List<util_closer_Batch_Log__c> batchLogs) {
        delete batchLogs;
    }

    /**
     * @description Queries a Batch Log by its Batch Job Id.
     * @param jobId The AsyncApexJob Id.
     * @return The Batch Log record or null if not found.
     */
    public static util_closer_Batch_Log__c queryBatchLogByJobId(String jobId) {
        List<util_closer_Batch_Log__c> logs = [
            SELECT Id, Batch_Job_Id__c, Start_Time__c, End_Time__c, Status__c,
                   Execution_Mode__c, Total_Records_Processed__c, Total_Records_Matched__c,
                   Total_Records_Updated__c, Total_Records_Failed__c, Total_Batches_Executed__c,
                   Active_Rules_Count__c, Active_Rules_JSON__c, Status_Transitions_JSON__c,
                   Error_Summary__c, Running_User__c
            FROM util_closer_Batch_Log__c
            WHERE Batch_Job_Id__c = :jobId
            LIMIT 1
        ];
        return logs.isEmpty() ? null : logs[0];
    }
}
