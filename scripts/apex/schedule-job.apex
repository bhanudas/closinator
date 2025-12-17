// Schedule the job using settings from Custom Settings
String jobId = util_closer_CaseStatusScheduler.scheduleJob();
System.debug('Scheduled Job ID: ' + jobId);

// Verify it's scheduled
CronTrigger job = util_closer_CaseStatusScheduler.getScheduledJobInfo();
if (job != null) {
    System.debug('Job Name: ' + job.CronJobDetail.Name);
    System.debug('Cron Expression: ' + job.CronExpression);
    System.debug('Next Fire Time: ' + job.NextFireTime);
    System.debug('State: ' + job.State);
} else {
    System.debug('Job not found');
}

