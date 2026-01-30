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

    /**
     * @description Constructor initializes metrics and loads rules.
     */
    public util_closer_CaseStatusBatch() {
        this.metrics = new util_closer_BatchMetrics();
        this.rules = util_closer_RuleEngine.getActiveRules();
        this.sourceStatuses = util_closer_RuleEngine.getAllSourceStatuses();
        this.autoCloseReasonEnabled = util_closer_SettingsService.isAutoCloseReasonEnabled();
        this.autoCloseReasonField = util_closer_SettingsService.getAutoCloseReasonField();
        util_closer_Logger.debug('CaseStatusBatch', 'Batch initialized with ' + this.rules.size() + ' active rules');
        if (this.autoCloseReasonEnabled) {
            util_closer_Logger.debug('CaseStatusBatch', 'Auto Close Reason enabled, target field: ' + this.autoCloseReasonField);
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

        try {
            // Evaluate cases against rules
            Map<Id, util_closer_RuleEngine.CaseChange> caseChanges = util_closer_RuleEngine.evaluateCases(scope, this.rules);

            if (caseChanges.isEmpty()) {
                util_closer_Logger.debug('CaseStatusBatch', 'No cases require status updates');
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

            // Perform update with partial success
            Database.SaveResult[] saveResults = Database.update(casesToUpdate, false);

            // Process results
            for (Integer i = 0; i < saveResults.size(); i++) {
                Database.SaveResult sr = saveResults[i];
                Case updatedCase = casesToUpdate[i];

                if (sr.isSuccess()) {
                    String originalStatus = originalStatuses.get(updatedCase.Id);
                    this.metrics.recordSuccess(originalStatus, updatedCase.Status);
                } else {
                    String errorMsg = '';
                    for (Database.Error err : sr.getErrors()) {
                        errorMsg += err.getMessage() + '; ';
                    }
                    this.metrics.recordFailure(errorMsg, updatedCase.Id);
                    util_closer_Logger.error('Failed to update Case ' + updatedCase.Id + ': ' + errorMsg);
                }
            }

        } catch (Exception ex) {
            util_closer_Logger.error('Exception in batch execute', ex);
            this.metrics.recordFailure(ex.getMessage(), null);
        }
    }
    
    /**
     * @description Finish method sends notifications and logs completion.
     * @param bc The batchable context.
     */
    public void finish(Database.BatchableContext bc) {
        this.metrics.endTime = DateTime.now();
        
        util_closer_Logger.debug('CaseStatusBatch', 'Batch job completed: ' + bc.getJobId());
        util_closer_Logger.debug('CaseStatusBatch', this.metrics.toLogSummary());
        
        // Send completion report
        util_closer_NotificationService.sendCompletionReport(this.metrics);
        
        // Send error notification if failures occurred
        if (this.metrics.totalRecordsFailed > 0) {
            util_closer_NotificationService.sendErrorNotification(
                'Batch Job Completed with Errors',
                'The batch job completed with ' + this.metrics.totalRecordsFailed + ' failures.',
                null
            );
        }
    }
}

