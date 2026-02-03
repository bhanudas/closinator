/**
 * @description Service class for managing Case Log records.
 * Provides buffered creation of case logs to optimize DML operations.
 */
public with sharing class util_closer_CaseLogService {

    private static final Integer BUFFER_SIZE = 200;
    private static final Integer MAX_JSON_LENGTH = 32000;

    private Id batchLogId;
    private Integer chunkNumber;
    private List<util_closer_Case_Log__c> buffer;

    /**
     * @description Wrapper class for case evaluation results.
     */
    public class CaseEvaluationResult {
        public Id caseId;
        public String caseNumber;
        public String originalStatus;
        public String targetStatus;
        public String matchedRuleDeveloperName;
        public String matchedRuleMasterLabel;
        public String targetReason;
        public String processingResult; // Matched, Not Matched, Updated, Simulated, Failed
        public String errorMessage;
        public Integer rulesEvaluatedCount;
        public List<RuleEvaluation> ruleEvaluations;
        public Boolean childRecordsChecked;
        public Integer childRecordsFound;
        public Long processingTimeMs;

        public CaseEvaluationResult() {
            this.rulesEvaluatedCount = 0;
            this.ruleEvaluations = new List<RuleEvaluation>();
            this.childRecordsChecked = false;
            this.childRecordsFound = 0;
            this.processingTimeMs = 0;
        }
    }

    /**
     * @description Wrapper class for individual rule evaluation details.
     */
    public class RuleEvaluation {
        public String ruleDeveloperName;
        public String ruleMasterLabel;
        public Boolean matched;
        public String failureReason;

        public RuleEvaluation(String developerName, String masterLabel, Boolean matched, String failureReason) {
            this.ruleDeveloperName = developerName;
            this.ruleMasterLabel = masterLabel;
            this.matched = matched;
            this.failureReason = failureReason;
        }
    }

    /**
     * @description Constructor initializes the service for a specific batch log and chunk.
     * @param batchLogId The parent Batch Log Id.
     * @param chunkNumber The batch chunk number being processed.
     */
    public util_closer_CaseLogService(Id batchLogId, Integer chunkNumber) {
        this.batchLogId = batchLogId;
        this.chunkNumber = chunkNumber;
        this.buffer = new List<util_closer_Case_Log__c>();
    }

    /**
     * @description Logs a case evaluation result to the buffer.
     * Automatically flushes when buffer reaches BUFFER_SIZE.
     * @param result The case evaluation result to log.
     */
    public void logCaseEvaluation(CaseEvaluationResult result) {
        if (result == null) {
            return;
        }

        util_closer_Case_Log__c caseLog = new util_closer_Case_Log__c(
            Batch_Log__c = this.batchLogId,
            Case__c = result.caseId,
            Case_Number__c = result.caseNumber,
            Original_Status__c = result.originalStatus,
            Target_Status__c = result.targetStatus,
            Matched_Rule__c = result.matchedRuleDeveloperName,
            Matched_Rule_Label__c = result.matchedRuleMasterLabel,
            Target_Reason__c = result.targetReason,
            Processing_Result__c = result.processingResult,
            Error_Message__c = result.errorMessage,
            Rules_Evaluated_Count__c = result.rulesEvaluatedCount,
            Rule_Evaluation_Details__c = ruleEvaluationsToJson(result.ruleEvaluations),
            Child_Records_Checked__c = result.childRecordsChecked,
            Child_Records_Found__c = result.childRecordsFound,
            Processing_Time_Ms__c = result.processingTimeMs,
            Batch_Chunk_Number__c = this.chunkNumber
        );

        buffer.add(caseLog);

        // Auto-flush when buffer is full
        if (buffer.size() >= BUFFER_SIZE) {
            flushLogs();
        }
    }

    /**
     * @description Flushes all buffered case logs to the database.
     * Should be called at the end of each batch execute to ensure all logs are saved.
     */
    public void flushLogs() {
        if (buffer.isEmpty()) {
            return;
        }

        List<Database.SaveResult> results = util_closer_LogDataAccess.insertCaseLogs(buffer);

        // Log any errors (but don't fail the batch)
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                String errorMsg = '';
                for (Database.Error err : results[i].getErrors()) {
                    errorMsg += err.getMessage() + '; ';
                }
                util_closer_Logger.debug('CaseLogService', 'Failed to insert case log: ' + errorMsg);
            }
        }

        buffer.clear();
    }

    /**
     * @description Creates a CaseEvaluationResult from a Case and CaseChange.
     * Helper method to simplify result creation in the batch.
     * @param c The Case record.
     * @param change The CaseChange from rule evaluation (null if no match).
     * @param isSimulation Whether this is a simulation run.
     * @return A populated CaseEvaluationResult.
     */
    public static CaseEvaluationResult createResult(
        Case c,
        util_closer_RuleEngine.CaseChange change,
        Boolean isSimulation
    ) {
        CaseEvaluationResult result = new CaseEvaluationResult();
        result.caseId = c.Id;
        result.caseNumber = c.CaseNumber;
        result.originalStatus = c.Status;

        if (change != null) {
            result.targetStatus = change.newStatus;
            result.targetReason = change.reason;
            result.processingResult = isSimulation ? 'Simulated' : 'Matched';
        } else {
            result.processingResult = 'Not Matched';
        }

        return result;
    }

    /**
     * @description Creates a CaseEvaluationResult from a DetailedCaseChange.
     * @param c The Case record.
     * @param change The DetailedCaseChange from rule evaluation with details.
     * @param isSimulation Whether this is a simulation run.
     * @return A populated CaseEvaluationResult with rule evaluation details.
     */
    public static CaseEvaluationResult createDetailedResult(
        Case c,
        util_closer_RuleEngine.DetailedCaseChange change,
        Boolean isSimulation
    ) {
        CaseEvaluationResult result = new CaseEvaluationResult();
        result.caseId = c.Id;
        result.caseNumber = c.CaseNumber;
        result.originalStatus = c.Status;

        if (change != null) {
            result.targetStatus = change.newStatus;
            result.targetReason = change.reason;
            result.matchedRuleDeveloperName = change.matchedRuleDeveloperName;
            result.matchedRuleMasterLabel = change.matchedRuleMasterLabel;
            result.rulesEvaluatedCount = change.rulesEvaluatedCount;
            result.childRecordsChecked = change.childRecordsChecked;
            result.childRecordsFound = change.childRecordsFound;
            result.processingResult = isSimulation ? 'Simulated' : 'Matched';

            // Convert rule evaluations
            if (change.ruleEvaluations != null) {
                for (util_closer_RuleEngine.RuleEvaluationDetail detail : change.ruleEvaluations) {
                    result.ruleEvaluations.add(new RuleEvaluation(
                        detail.ruleDeveloperName,
                        detail.ruleMasterLabel,
                        detail.matched,
                        detail.failureReason
                    ));
                }
            }
        } else {
            result.processingResult = 'Not Matched';
        }

        return result;
    }

    /**
     * @description Marks a result as updated after successful DML.
     * @param result The result to update.
     */
    public static void markAsUpdated(CaseEvaluationResult result) {
        if (result != null) {
            result.processingResult = 'Updated';
        }
    }

    /**
     * @description Marks a result as failed with an error message.
     * @param result The result to update.
     * @param errorMessage The error message.
     */
    public static void markAsFailed(CaseEvaluationResult result, String errorMessage) {
        if (result != null) {
            result.processingResult = 'Failed';
            result.errorMessage = errorMessage;
        }
    }

    /**
     * @description Converts rule evaluations to JSON string.
     * @param evaluations List of rule evaluations.
     * @return JSON string or null if empty.
     */
    private String ruleEvaluationsToJson(List<RuleEvaluation> evaluations) {
        if (evaluations == null || evaluations.isEmpty()) {
            return null;
        }

        String json = JSON.serialize(evaluations);
        if (json.length() > MAX_JSON_LENGTH) {
            return json.substring(0, MAX_JSON_LENGTH - 15) + '... [truncated]';
        }
        return json;
    }
}
