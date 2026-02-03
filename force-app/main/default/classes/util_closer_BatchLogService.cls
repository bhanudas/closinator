/**
 * @description Service class for managing Batch Log records.
 * Provides methods to create, update, and finalize batch logs during batch execution.
 */
public with sharing class util_closer_BatchLogService {

    private static final Integer MAX_JSON_LENGTH = 32000;

    /**
     * @description Creates a new Batch Log record at batch start.
     * @param jobId The AsyncApexJob ID.
     * @param rules List of active rules at execution time.
     * @param isSimulation Whether the batch is running in simulation mode.
     * @return The created Batch Log record with Id populated.
     */
    public static util_closer_Batch_Log__c createBatchLog(
        String jobId,
        List<util_closer_Case_Status_Rule__mdt> rules,
        Boolean isSimulation
    ) {
        util_closer_Batch_Log__c batchLog = new util_closer_Batch_Log__c(
            Batch_Job_Id__c = jobId,
            Start_Time__c = DateTime.now(),
            Status__c = 'Running',
            Execution_Mode__c = isSimulation ? 'Simulation' : 'Full',
            Active_Rules_Count__c = rules != null ? rules.size() : 0,
            Active_Rules_JSON__c = rulesToJson(rules),
            Running_User__c = UserInfo.getUserId(),
            Total_Records_Processed__c = 0,
            Total_Records_Matched__c = 0,
            Total_Records_Updated__c = 0,
            Total_Records_Failed__c = 0,
            Total_Batches_Executed__c = 0
        );

        return util_closer_LogDataAccess.insertBatchLog(batchLog);
    }

    /**
     * @description Updates batch log progress during execution.
     * Called periodically to update metrics while batch is running.
     * @param batchLog The Batch Log record to update.
     * @param metrics The current batch metrics.
     */
    public static void updateBatchProgress(
        util_closer_Batch_Log__c batchLog,
        util_closer_BatchMetrics metrics
    ) {
        if (batchLog == null || batchLog.Id == null) {
            return;
        }

        batchLog.Total_Records_Processed__c = metrics.totalRecordsProcessed;
        batchLog.Total_Records_Matched__c = metrics.totalRecordsUpdated + metrics.totalRecordsFailed;
        batchLog.Total_Records_Updated__c = metrics.totalRecordsUpdated;
        batchLog.Total_Records_Failed__c = metrics.totalRecordsFailed;
        batchLog.Total_Batches_Executed__c = metrics.totalBatchesExecuted;
        batchLog.Status_Transitions_JSON__c = transitionsToJson(metrics.statusTransitionCounts);
        batchLog.Error_Summary__c = truncateText(String.join(metrics.errors, '\n'), MAX_JSON_LENGTH);

        util_closer_LogDataAccess.updateBatchLog(batchLog);
    }

    /**
     * @description Finalizes the batch log at batch completion.
     * Sets end time, final status, and all final metrics.
     * @param batchLog The Batch Log record to finalize.
     * @param metrics The final batch metrics.
     */
    public static void finalizeBatchLog(
        util_closer_Batch_Log__c batchLog,
        util_closer_BatchMetrics metrics
    ) {
        if (batchLog == null || batchLog.Id == null) {
            return;
        }

        batchLog.End_Time__c = DateTime.now();
        batchLog.Total_Records_Processed__c = metrics.totalRecordsProcessed;
        batchLog.Total_Records_Matched__c = metrics.totalRecordsUpdated + metrics.totalRecordsFailed;
        batchLog.Total_Records_Updated__c = metrics.totalRecordsUpdated;
        batchLog.Total_Records_Failed__c = metrics.totalRecordsFailed;
        batchLog.Total_Batches_Executed__c = metrics.totalBatchesExecuted;
        batchLog.Status_Transitions_JSON__c = transitionsToJson(metrics.statusTransitionCounts);
        batchLog.Error_Summary__c = truncateText(String.join(metrics.errors, '\n'), MAX_JSON_LENGTH);

        // Set final status based on results
        if (metrics.totalRecordsFailed > 0) {
            batchLog.Status__c = 'Completed with Errors';
        } else {
            batchLog.Status__c = 'Completed';
        }

        util_closer_LogDataAccess.updateBatchLog(batchLog);
    }

    /**
     * @description Marks a batch log as failed with an error message.
     * @param batchLog The Batch Log record.
     * @param errorMessage The error message describing the failure.
     */
    public static void markBatchLogFailed(
        util_closer_Batch_Log__c batchLog,
        String errorMessage
    ) {
        if (batchLog == null || batchLog.Id == null) {
            return;
        }

        batchLog.End_Time__c = DateTime.now();
        batchLog.Status__c = 'Failed';
        batchLog.Error_Summary__c = truncateText(errorMessage, MAX_JSON_LENGTH);

        util_closer_LogDataAccess.updateBatchLog(batchLog);
    }

    /**
     * @description Converts list of rules to JSON array of rule info.
     * @param rules List of rule metadata records.
     * @return JSON string array of rule names and labels.
     */
    @TestVisible
    private static String rulesToJson(List<util_closer_Case_Status_Rule__mdt> rules) {
        if (rules == null || rules.isEmpty()) {
            return '[]';
        }

        List<Map<String, String>> ruleList = new List<Map<String, String>>();
        for (util_closer_Case_Status_Rule__mdt rule : rules) {
            Map<String, String> ruleInfo = new Map<String, String>();
            ruleInfo.put('developerName', rule.DeveloperName);
            ruleInfo.put('masterLabel', rule.MasterLabel);
            ruleList.add(ruleInfo);
        }

        String json = JSON.serialize(ruleList);
        return truncateText(json, MAX_JSON_LENGTH);
    }

    /**
     * @description Converts status transition counts map to JSON object.
     * @param transitions Map of transition strings to counts.
     * @return JSON string representation of transitions.
     */
    @TestVisible
    private static String transitionsToJson(Map<String, Integer> transitions) {
        if (transitions == null || transitions.isEmpty()) {
            return '{}';
        }

        String json = JSON.serialize(transitions);
        return truncateText(json, MAX_JSON_LENGTH);
    }

    /**
     * @description Truncates text to maximum length with indicator.
     * @param text The text to truncate.
     * @param maxLength Maximum allowed length.
     * @return Truncated text with "... [truncated]" indicator if needed.
     */
    @TestVisible
    private static String truncateText(String text, Integer maxLength) {
        if (text == null) {
            return null;
        }
        if (text.length() <= maxLength) {
            return text;
        }
        return text.substring(0, maxLength - 15) + '... [truncated]';
    }
}
