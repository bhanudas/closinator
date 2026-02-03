/**
 * @description Main batch class that processes Cases and updates their statuses based on metadata rules.
 * Implements Database.Stateful to maintain metrics across batch executions.
 */
public with sharing class util_closer_CaseStatusBatch implements Database.Batchable<SObject>, Database.Stateful, Database.RaisesPlatformEvents {

    private util_closer_BatchMetrics metrics;
    private List<util_closer_Case_Status_Rule__mdt> rules;
    private Set<String> sourceStatuses;
    private Boolean autoCloseReasonEnabled;
    private String autoCloseReasonField;
    private Boolean simulationMode;

    // Verbose logging state
    private Boolean verboseLoggingEnabled;
    private Boolean logRuleEvaluations;
    private util_closer_Batch_Log__c batchLog;

    /**
     * @description Constructor initializes metrics and loads rules.
     */
    public util_closer_CaseStatusBatch() {
        this.metrics = new util_closer_BatchMetrics();
        this.rules = util_closer_RuleEngine.getActiveRules();
        this.sourceStatuses = util_closer_RuleEngine.getAllSourceStatuses();
        this.autoCloseReasonEnabled = util_closer_SettingsService.isAutoCloseReasonEnabled();
        this.autoCloseReasonField = util_closer_SettingsService.getAutoCloseReasonField();
        this.simulationMode = util_closer_SettingsService.isSimulationMode();
        this.verboseLoggingEnabled = util_closer_SettingsService.isVerboseLoggingEnabled();
        this.logRuleEvaluations = util_closer_SettingsService.isLogRuleEvaluationsEnabled();

        util_closer_Logger.debug('CaseStatusBatch', 'Batch initialized with ' + this.rules.size() + ' active rules');
        if (this.simulationMode) {
            util_closer_Logger.debug('CaseStatusBatch', '*** SIMULATION MODE ENABLED - No records will be updated ***');
        }
        if (this.autoCloseReasonEnabled) {
            util_closer_Logger.debug('CaseStatusBatch', 'Auto Close Reason enabled, target field: ' + this.autoCloseReasonField);
        }
        if (this.verboseLoggingEnabled) {
            util_closer_Logger.debug('CaseStatusBatch', 'Verbose logging enabled');
        }
    }

    /**
     * @description Start method builds and executes query for Cases to process.
     * Uses CaseDataAccess class to query without sharing restrictions, allowing
     * the batch to process all Cases matching the criteria regardless of sharing rules.
     * @param bc The batchable context.
     * @return QueryLocator for Cases matching rule criteria.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        util_closer_Logger.debug('CaseStatusBatch', 'Batch job started: ' + bc.getJobId());

        // Create batch log at start
        try {
            this.batchLog = util_closer_BatchLogService.createBatchLog(
                bc.getJobId(),
                this.rules,
                this.simulationMode
            );
            util_closer_Logger.debug('CaseStatusBatch', 'Created batch log: ' + this.batchLog.Id);
        } catch (Exception ex) {
            util_closer_Logger.error('Failed to create batch log', ex);
            // Continue without batch logging - don't fail the entire batch
        }

        // Check if system is active
        if (!util_closer_SettingsService.isActive()) {
            util_closer_Logger.debug('CaseStatusBatch', 'System is inactive. Returning empty query.');
            return Database.getQueryLocator('SELECT Id FROM Case WHERE Id = null');
        }

        // Check if there are active rules
        if (this.rules.isEmpty()) {
            util_closer_Logger.debug('CaseStatusBatch', 'No active rules. Returning empty query.');
            return Database.getQueryLocator('SELECT Id FROM Case WHERE Id = null');
        }

        // Validate Auto Close Reason configuration if enabled
        if (this.autoCloseReasonEnabled) {
            validateAutoCloseReasonField();
        }

        // Use CaseDataAccess to query without sharing restrictions
        // This allows the batch to process all Cases matching criteria,
        // regardless of the running user's sharing access
        util_closer_Logger.debug('CaseStatusBatch', 'Querying Cases without sharing restrictions for statuses: ' + this.sourceStatuses);
        return util_closer_CaseDataAccess.queryCasesByStatus(this.sourceStatuses);
    }

    /**
     * @description Validates that the configured Auto Close Reason field exists on the Case object.
     * Throws an exception if the field is not found, which will abort the batch job.
     */
    private void validateAutoCloseReasonField() {
        validateAutoCloseReasonField(this.autoCloseReasonField);
    }

    /**
     * @description Pre-fetches child records for all Cases in the batch scope.
     * Uses ChildRecordService to query children in bulk to avoid SOQL in loops.
     * @param scope List of Cases in the current batch scope.
     * @return Map of Case ID to list of child records.
     */
    private Map<Id, List<SObject>> fetchChildRecordsForBatch(List<Case> scope) {
        Set<Id> caseIds = new Set<Id>();
        for (Case c : scope) {
            caseIds.add(c.Id);
        }

        Map<String, util_closer_ChildRecordService.ChildCriteria> criteriaMap =
            util_closer_ChildRecordService.getChildCriteriaFromRules(this.rules);

        util_closer_Logger.debug('CaseStatusBatch', 'Fetching child records for ' + caseIds.size() + ' Cases with ' + criteriaMap.size() + ' criteria configurations');

        return util_closer_ChildRecordService.queryChildRecords(caseIds, criteriaMap);
    }

    /**
     * @description Static validation method to check if the Auto Close Reason field configuration is valid.
     * Can be used for validation outside of batch context.
     * @param fieldApiName The API name of the field to validate.
     * @throws util_closer_AutoCloseReasonException if configuration is invalid.
     */
    @TestVisible
    private static void validateAutoCloseReasonField(String fieldApiName) {
        if (String.isBlank(fieldApiName)) {
            String errorMsg = 'Auto Close Reason is enabled but no field is configured. ' +
                'Please set the Auto Close Reason Field in Custom Settings or disable the feature.';
            util_closer_Logger.error(errorMsg);
            throw new util_closer_AutoCloseReasonException(errorMsg);
        }

        // Check if the field exists on the Case object
        Map<String, Schema.SObjectField> caseFields = Schema.SObjectType.Case.fields.getMap();
        if (!caseFields.containsKey(fieldApiName.toLowerCase())) {
            String errorMsg = 'Auto Close Reason field "' + fieldApiName + '" does not exist on the Case object. ' +
                'Please create this field or update the Auto Close Reason Field setting.';
            util_closer_Logger.error(errorMsg);
            throw new util_closer_AutoCloseReasonException(errorMsg);
        }

        util_closer_Logger.debug('CaseStatusBatch', 'Auto Close Reason field validated: ' + fieldApiName);
    }

    /**
     * @description Execute method processes each batch of Cases.
     * @param bc The batchable context.
     * @param scope List of Cases to process.
     */
    public void execute(Database.BatchableContext bc, List<Case> scope) {
        util_closer_Logger.debug('CaseStatusBatch', 'Executing batch with ' + scope.size() + ' records');

        this.metrics.incrementBatchCount();
        this.metrics.addProcessedCount(scope.size());

        // Initialize case log service for verbose logging
        util_closer_CaseLogService caseLogService = null;
        if (this.verboseLoggingEnabled && this.batchLog != null) {
            caseLogService = new util_closer_CaseLogService(this.batchLog.Id, this.metrics.totalBatchesExecuted);
        }

        try {
            // Pre-fetch child records if any rules have child criteria
            Map<Id, List<SObject>> childDataMap = null;
            if (util_closer_RuleEngine.rulesHaveChildCriteria(this.rules)) {
                childDataMap = fetchChildRecordsForBatch(scope);
            }

            // Track case evaluation results for verbose logging
            Map<Id, util_closer_CaseLogService.CaseEvaluationResult> caseResults =
                new Map<Id, util_closer_CaseLogService.CaseEvaluationResult>();

            // Evaluate cases against rules
            Map<Id, util_closer_RuleEngine.CaseChange> caseChanges;

            if (this.verboseLoggingEnabled && this.logRuleEvaluations) {
                // Use detailed evaluation for verbose logging
                Map<Id, util_closer_RuleEngine.DetailedCaseChange> detailedChanges =
                    util_closer_RuleEngine.evaluateCasesWithDetails(scope, this.rules, childDataMap, true);

                // Convert to standard CaseChange map and create evaluation results
                caseChanges = new Map<Id, util_closer_RuleEngine.CaseChange>();
                for (Case c : scope) {
                    Long startTime = System.currentTimeMillis();
                    util_closer_RuleEngine.DetailedCaseChange detailedChange = detailedChanges.get(c.Id);

                    util_closer_CaseLogService.CaseEvaluationResult result =
                        util_closer_CaseLogService.createDetailedResult(c, detailedChange, this.simulationMode);
                    result.processingTimeMs = System.currentTimeMillis() - startTime;
                    caseResults.put(c.Id, result);

                    if (detailedChange != null) {
                        caseChanges.put(c.Id, detailedChange);
                    }
                }
            } else {
                // Standard evaluation
                caseChanges = util_closer_RuleEngine.evaluateCases(scope, this.rules, childDataMap);

                // Create basic evaluation results for verbose logging
                if (this.verboseLoggingEnabled) {
                    for (Case c : scope) {
                        util_closer_RuleEngine.CaseChange change = caseChanges.get(c.Id);
                        util_closer_CaseLogService.CaseEvaluationResult result =
                            util_closer_CaseLogService.createResult(c, change, this.simulationMode);
                        caseResults.put(c.Id, result);
                    }
                }
            }

            if (caseChanges.isEmpty()) {
                util_closer_Logger.debug('CaseStatusBatch', 'No cases require status updates');

                // Log all cases as not matched if verbose logging is enabled
                if (caseLogService != null) {
                    for (util_closer_CaseLogService.CaseEvaluationResult result : caseResults.values()) {
                        caseLogService.logCaseEvaluation(result);
                    }
                    caseLogService.flushLogs();
                }
                return;
            }

            // Build list of Cases to update
            List<Case> casesToUpdate = new List<Case>();
            Map<Id, String> originalStatuses = new Map<Id, String>();

            for (Case c : scope) {
                if (caseChanges.containsKey(c.Id)) {
                    originalStatuses.put(c.Id, c.Status);
                    util_closer_RuleEngine.CaseChange change = caseChanges.get(c.Id);

                    Case caseToUpdate = new Case(
                        Id = c.Id,
                        Status = change.newStatus
                    );

                    // Set reason field if feature is enabled and rule has a reason configured
                    if (this.autoCloseReasonEnabled && String.isNotBlank(change.reason)) {
                        caseToUpdate.put(this.autoCloseReasonField, change.reason);
                        util_closer_Logger.debug('CaseStatusBatch', 'Setting reason for Case ' + c.Id + ': ' + change.reason);
                    }

                    casesToUpdate.add(caseToUpdate);
                }
            }

            // SIMULATION MODE: Log what would happen but don't update
            if (this.simulationMode) {
                util_closer_Logger.debug('CaseStatusBatch', '*** SIMULATION: Would update ' + casesToUpdate.size() + ' Cases ***');
                for (Case c : casesToUpdate) {
                    String originalStatus = originalStatuses.get(c.Id);
                    String reasonInfo = '';
                    if (this.autoCloseReasonEnabled && this.autoCloseReasonField != null) {
                        Object reasonValue = c.get(this.autoCloseReasonField);
                        if (reasonValue != null) {
                            reasonInfo = ', Reason: ' + String.valueOf(reasonValue);
                        }
                    }
                    util_closer_Logger.debug('CaseStatusBatch',
                        '[SIMULATION] Case ' + c.Id + ': ' + originalStatus + ' -> ' + c.Status + reasonInfo);
                    // Record as "simulated success" for metrics
                    this.metrics.recordSuccess(originalStatus, c.Status);
                }

                // Log simulated results
                if (caseLogService != null) {
                    for (util_closer_CaseLogService.CaseEvaluationResult result : caseResults.values()) {
                        caseLogService.logCaseEvaluation(result);
                    }
                    caseLogService.flushLogs();
                }
                return;
            }

            // Perform update with partial success (only if NOT in simulation mode)
            Database.SaveResult[] saveResults = Database.update(casesToUpdate, false);

            // Process results
            for (Integer i = 0; i < saveResults.size(); i++) {
                Database.SaveResult sr = saveResults[i];
                Case updatedCase = casesToUpdate[i];

                if (sr.isSuccess()) {
                    String originalStatus = originalStatuses.get(updatedCase.Id);
                    this.metrics.recordSuccess(originalStatus, updatedCase.Status);

                    // Update case log result
                    if (caseResults.containsKey(updatedCase.Id)) {
                        util_closer_CaseLogService.markAsUpdated(caseResults.get(updatedCase.Id));
                    }
                } else {
                    String errorMsg = '';
                    for (Database.Error err : sr.getErrors()) {
                        errorMsg += err.getMessage() + '; ';
                    }
                    this.metrics.recordFailure(errorMsg, updatedCase.Id);
                    util_closer_Logger.error('Failed to update Case ' + updatedCase.Id + ': ' + errorMsg);

                    // Update case log result
                    if (caseResults.containsKey(updatedCase.Id)) {
                        util_closer_CaseLogService.markAsFailed(caseResults.get(updatedCase.Id), errorMsg);
                    }
                }
            }

            // Log all case results
            if (caseLogService != null) {
                for (util_closer_CaseLogService.CaseEvaluationResult result : caseResults.values()) {
                    caseLogService.logCaseEvaluation(result);
                }
                caseLogService.flushLogs();
            }

        } catch (Exception ex) {
            util_closer_Logger.error('Exception in batch execute', ex);
            this.metrics.recordFailure(ex.getMessage(), null);

            // Flush any pending case logs
            if (caseLogService != null) {
                try {
                    caseLogService.flushLogs();
                } catch (Exception flushEx) {
                    util_closer_Logger.debug('CaseStatusBatch', 'Failed to flush case logs: ' + flushEx.getMessage());
                }
            }
        }
    }

    /**
     * @description Finish method sends notifications and logs completion.
     * @param bc The batchable context.
     */
    public void finish(Database.BatchableContext bc) {
        this.metrics.endTime = DateTime.now();

        String modeIndicator = this.simulationMode ? ' [SIMULATION MODE]' : '';
        util_closer_Logger.debug('CaseStatusBatch', 'Batch job completed' + modeIndicator + ': ' + bc.getJobId());

        if (this.simulationMode) {
            util_closer_Logger.debug('CaseStatusBatch', '*** SIMULATION COMPLETE - No records were actually updated ***');
            util_closer_Logger.debug('CaseStatusBatch', 'Cases that WOULD have been updated: ' + this.metrics.totalRecordsUpdated);
        }

        util_closer_Logger.debug('CaseStatusBatch', this.metrics.toLogSummary());

        // Mark metrics as simulation if applicable
        if (this.simulationMode) {
            this.metrics.simulationMode = true;
        }

        // Finalize batch log
        if (this.batchLog != null) {
            try {
                util_closer_BatchLogService.finalizeBatchLog(this.batchLog, this.metrics);
                util_closer_Logger.debug('CaseStatusBatch', 'Finalized batch log: ' + this.batchLog.Id);
            } catch (Exception ex) {
                util_closer_Logger.error('Failed to finalize batch log', ex);
            }
        }

        // Send completion report
        util_closer_NotificationService.sendCompletionReport(this.metrics);

        // Send error notification if failures occurred (not applicable in simulation mode)
        if (!this.simulationMode && this.metrics.totalRecordsFailed > 0) {
            util_closer_NotificationService.sendErrorNotification(
                'Batch Job Completed with Errors',
                'The batch job completed with ' + this.metrics.totalRecordsFailed + ' failures.',
                null
            );
        }
    }
}
