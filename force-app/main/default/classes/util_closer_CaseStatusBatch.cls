/**
 * @description Main batch class that processes Cases and updates their statuses based on metadata rules.
 * Implements Database.Stateful to maintain metrics across batch executions.
 */
public with sharing class util_closer_CaseStatusBatch implements Database.Batchable<SObject>, Database.Stateful, Database.RaisesPlatformEvents {
    
    private util_closer_BatchMetrics metrics;
    private List<util_closer_Case_Status_Rule__mdt> rules;
    private Set<String> sourceStatuses;
    
    /**
     * @description Constructor initializes metrics and loads rules.
     */
    public util_closer_CaseStatusBatch() {
        this.metrics = new util_closer_BatchMetrics();
        this.rules = util_closer_RuleEngine.getActiveRules();
        this.sourceStatuses = util_closer_RuleEngine.getAllSourceStatuses();
        util_closer_Logger.debug('CaseStatusBatch', 'Batch initialized with ' + this.rules.size() + ' active rules');
    }
    
    /**
     * @description Start method builds and executes query for Cases to process.
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
        
        String query = 'SELECT Id, Status, RecordTypeId, RecordType.DeveloperName, ' +
                       'LastModifiedDate, CreatedDate, LastActivityDate ' +
                       'FROM Case ' +
                       'WHERE IsClosed = false ' +
                       'AND Status IN :sourceStatuses';
        
        util_closer_Logger.debug('CaseStatusBatch', 'Query: ' + query);
        
        return Database.getQueryLocator(query);
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
            Map<Id, String> statusChanges = util_closer_RuleEngine.evaluateCases(scope, this.rules);
            
            if (statusChanges.isEmpty()) {
                util_closer_Logger.debug('CaseStatusBatch', 'No cases require status updates');
                return;
            }
            
            // Build list of Cases to update
            List<Case> casesToUpdate = new List<Case>();
            Map<Id, String> originalStatuses = new Map<Id, String>();
            
            for (Case c : scope) {
                if (statusChanges.containsKey(c.Id)) {
                    originalStatuses.put(c.Id, c.Status);
                    casesToUpdate.add(new Case(
                        Id = c.Id,
                        Status = statusChanges.get(c.Id)
                    ));
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

