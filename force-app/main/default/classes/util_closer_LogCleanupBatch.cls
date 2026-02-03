/**
 * @description Scheduled batch job to clean up old log records.
 * Deletes Batch_Log__c records older than the configured retention period.
 * Case_Log__c records are cascade deleted due to Master-Detail relationship.
 */
public with sharing class util_closer_LogCleanupBatch implements Database.Batchable<SObject>, Schedulable {

    private static final Integer DEFAULT_RETENTION_DAYS = 90;
    private static final Integer STALE_LOG_HOURS = 24;

    private Integer retentionDays;

    /**
     * @description Default constructor uses settings for retention days.
     */
    public util_closer_LogCleanupBatch() {
        this.retentionDays = util_closer_SettingsService.getLogRetentionDays();
    }

    /**
     * @description Constructor with explicit retention days for testing.
     * @param retentionDays Number of days to retain logs.
     */
    public util_closer_LogCleanupBatch(Integer retentionDays) {
        this.retentionDays = retentionDays != null && retentionDays > 0
            ? retentionDays
            : DEFAULT_RETENTION_DAYS;
    }

    /**
     * @description Schedulable execute method to run the cleanup batch.
     * @param sc The schedulable context.
     */
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new util_closer_LogCleanupBatch(), 200);
    }

    /**
     * @description Start method queries Batch Logs older than retention period.
     * @param bc The batchable context.
     * @return QueryLocator for old Batch Log records.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        DateTime cutoffDate = DateTime.now().addDays(-this.retentionDays);
        util_closer_Logger.debug('LogCleanupBatch',
            'Starting cleanup for logs older than ' + this.retentionDays + ' days (before ' + cutoffDate + ')');

        return Database.getQueryLocator([
            SELECT Id
            FROM util_closer_Batch_Log__c
            WHERE Start_Time__c < :cutoffDate
            ORDER BY Start_Time__c ASC
        ]);
    }

    /**
     * @description Execute method deletes each batch of old Batch Logs.
     * @param bc The batchable context.
     * @param scope List of Batch Log records to delete.
     */
    public void execute(Database.BatchableContext bc, List<util_closer_Batch_Log__c> scope) {
        util_closer_Logger.debug('LogCleanupBatch', 'Deleting ' + scope.size() + ' old batch logs');

        try {
            util_closer_LogDataAccess.deleteBatchLogs(scope);
        } catch (Exception ex) {
            util_closer_Logger.error('LogCleanupBatch', ex);
        }
    }

    /**
     * @description Finish method logs completion and handles stale "Running" logs.
     * @param bc The batchable context.
     */
    public void finish(Database.BatchableContext bc) {
        util_closer_Logger.debug('LogCleanupBatch', 'Cleanup batch completed: ' + bc.getJobId());

        // Mark stale "Running" logs as Failed
        markStaleBatchLogsFailed();
    }

    /**
     * @description Identifies and marks stale "Running" batch logs as Failed.
     * A batch log is considered stale if it's been "Running" for more than 24 hours.
     */
    private void markStaleBatchLogsFailed() {
        try {
            List<util_closer_Batch_Log__c> staleLogs = util_closer_LogDataAccess.queryStaleBatchLogs(STALE_LOG_HOURS);

            if (staleLogs.isEmpty()) {
                return;
            }

            util_closer_Logger.debug('LogCleanupBatch',
                'Found ' + staleLogs.size() + ' stale batch logs to mark as failed');

            for (util_closer_Batch_Log__c log : staleLogs) {
                log.Status__c = 'Failed';
                log.End_Time__c = DateTime.now();
                log.Error_Summary__c = 'Batch log marked as failed - was running for more than ' +
                    STALE_LOG_HOURS + ' hours without completion.';
            }

            update staleLogs;
        } catch (Exception ex) {
            util_closer_Logger.error('LogCleanupBatch - markStaleBatchLogsFailed', ex);
        }
    }

    /**
     * @description Schedules the cleanup batch to run daily at 3 AM.
     * @return The scheduled job Id.
     */
    public static String scheduleDaily() {
        return scheduleDaily('0 0 3 * * ?');
    }

    /**
     * @description Schedules the cleanup batch with a custom cron expression.
     * @param cronExpression The cron expression for scheduling.
     * @return The scheduled job Id.
     */
    public static String scheduleDaily(String cronExpression) {
        String jobName = 'util_closer_LogCleanupBatch';

        // Abort existing job if present
        List<CronTrigger> existingJobs = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = :jobName
            LIMIT 1
        ];

        if (!existingJobs.isEmpty()) {
            System.abortJob(existingJobs[0].Id);
        }

        return System.schedule(jobName, cronExpression, new util_closer_LogCleanupBatch());
    }
}
