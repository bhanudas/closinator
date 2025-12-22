util_closer_CaseStatusScheduler.unscheduleJob();
System.debug('Job unscheduled');

Boolean isScheduled = util_closer_CaseStatusScheduler.isJobScheduled();
System.debug('Is Job Still Scheduled: ' + isScheduled);  // Should be false





