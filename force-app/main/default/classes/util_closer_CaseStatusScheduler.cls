/**
 * @description Scheduler class for the Case Status Auto-Closer batch job.
 * Provides methods to schedule, unschedule, and check job status.
 */
public with sharing class util_closer_CaseStatusScheduler implements Schedulable {
    
    /**
     * @description Schedulable execute method - runs the batch job.
     * @param sc The schedulable context.
     */
    public void execute(SchedulableContext sc) {
        Integer batchSize = util_closer_SettingsService.getBatchSize();
        util_closer_Logger.debug('CaseStatusScheduler', 'Executing scheduled job with batch size: ' + batchSize);
        Database.executeBatch(new util_closer_CaseStatusBatch(), batchSize);
    }
    
    /**
     * @description Schedules the job using settings from Custom Settings.
     * @return The scheduled job ID.
     */
    public static String scheduleJob() {
        String cronExpression = util_closer_SettingsService.getCronExpression();
        return scheduleJob(cronExpression);
    }
    
    /**
     * @description Schedules the job with a custom cron expression.
     * @param cronExpression The cron expression to use.
     * @return The scheduled job ID.
     */
    public static String scheduleJob(String cronExpression) {
        String jobName = util_closer_SettingsService.getScheduledJobName();
        
        // Unschedule existing job first
        unscheduleJob();
        
        util_closer_Logger.debug('CaseStatusScheduler', 'Scheduling job "' + jobName + '" with cron: ' + cronExpression);
        
        String jobId = System.schedule(jobName, cronExpression, new util_closer_CaseStatusScheduler());
        
        util_closer_Logger.debug('CaseStatusScheduler', 'Job scheduled with ID: ' + jobId);
        
        return jobId;
    }
    
    /**
     * @description Unschedules the existing job by name.
     */
    public static void unscheduleJob() {
        String jobName = util_closer_SettingsService.getScheduledJobName();
        
        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name 
            FROM CronTrigger 
            WHERE CronJobDetail.Name = :jobName
        ];
        
        for (CronTrigger job : jobs) {
            util_closer_Logger.debug('CaseStatusScheduler', 'Aborting job: ' + job.CronJobDetail.Name);
            System.abortJob(job.Id);
        }
    }
    
    /**
     * @description Reschedules the job (unschedule then schedule).
     */
    public static void reschedule() {
        String cronExpression = util_closer_SettingsService.getCronExpression();
        scheduleJob(cronExpression);
    }
    
    /**
     * @description Checks if the job is currently scheduled.
     * @return True if the job is scheduled.
     */
    public static Boolean isJobScheduled() {
        String jobName = util_closer_SettingsService.getScheduledJobName();
        
        List<CronTrigger> jobs = [
            SELECT Id 
            FROM CronTrigger 
            WHERE CronJobDetail.Name = :jobName
            LIMIT 1
        ];
        
        return !jobs.isEmpty();
    }
    
    /**
     * @description Returns information about the scheduled job.
     * @return CronTrigger record with job details, or null if not scheduled.
     */
    public static CronTrigger getScheduledJobInfo() {
        String jobName = util_closer_SettingsService.getScheduledJobName();
        
        List<CronTrigger> jobs = [
            SELECT Id, CronExpression, NextFireTime, PreviousFireTime, 
                   State, TimesTriggered, CronJobDetail.Name
            FROM CronTrigger 
            WHERE CronJobDetail.Name = :jobName
            LIMIT 1
        ];
        
        return jobs.isEmpty() ? null : jobs[0];
    }
}

