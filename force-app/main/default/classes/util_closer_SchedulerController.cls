/**
 * @description Apex controller for the Scheduler Manager LWC.
 * Provides methods for job scheduling, settings management, and batch execution.
 */
public with sharing class util_closer_SchedulerController {
    
    /**
     * @description Gets the current job status and details.
     * @return Map containing job status information.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getJobStatus() {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            CronTrigger jobInfo = util_closer_CaseStatusScheduler.getScheduledJobInfo();
            
            if (jobInfo != null) {
                result.put('isScheduled', true);
                result.put('jobId', jobInfo.Id);
                result.put('cronExpression', jobInfo.CronExpression);
                result.put('nextFireTime', jobInfo.NextFireTime);
                result.put('previousFireTime', jobInfo.PreviousFireTime);
                result.put('state', jobInfo.State);
                result.put('timesTriggered', jobInfo.TimesTriggered);
                result.put('jobName', util_closer_SettingsService.getScheduledJobName());
            } else {
                result.put('isScheduled', false);
                result.put('jobName', util_closer_SettingsService.getScheduledJobName());
            }
            
            // Check if batch is currently running
            List<AsyncApexJob> runningJobs = [
                SELECT Id, Status, JobType, CreatedDate
                FROM AsyncApexJob
                WHERE JobType = 'BatchApex'
                AND Status IN ('Holding', 'Queued', 'Preparing', 'Processing')
                AND ApexClass.Name = 'util_closer_CaseStatusBatch'
                LIMIT 1
            ];
            result.put('isBatchRunning', !runningJobs.isEmpty());
            
        } catch (Exception ex) {
            throw new AuraHandledException('Error getting job status: ' + ex.getMessage());
        }
        
        return result;
    }
    
    /**
     * @description Reschedules the job with a new cron expression.
     * @param cronExpression The new cron expression.
     * @return Success message.
     */
    @AuraEnabled
    public static String rescheduleJob(String cronExpression) {
        try {
            // Validate cron expression format (basic validation)
            if (String.isBlank(cronExpression)) {
                throw new AuraHandledException('Cron expression cannot be empty');
            }
            
            // Attempt to schedule (this will validate the cron expression)
            String jobId = util_closer_CaseStatusScheduler.scheduleJob(cronExpression);
            
            return 'Job successfully scheduled with ID: ' + jobId;
            
        } catch (System.StringException ex) {
            throw new AuraHandledException('Invalid cron expression: ' + ex.getMessage());
        } catch (Exception ex) {
            throw new AuraHandledException('Error scheduling job: ' + ex.getMessage());
        }
    }
    
    /**
     * @description Unschedules the job.
     */
    @AuraEnabled
    public static void unscheduleJob() {
        try {
            util_closer_CaseStatusScheduler.unscheduleJob();
        } catch (Exception ex) {
            throw new AuraHandledException('Error unscheduling job: ' + ex.getMessage());
        }
    }
    
    /**
     * @description Gets the current custom settings values.
     * @return Map of settings values.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getSettings() {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            util_closer_Settings__c settings = util_closer_SettingsService.getSettings();
            
            result.put('batchSize', settings.Batch_Size__c);
            result.put('debugMode', settings.Debug_Mode__c);
            result.put('isActive', settings.Is_Active__c);
            result.put('cronExpression', settings.Cron_Expression__c);
            result.put('scheduledJobName', settings.Scheduled_Job_Name__c);
            result.put('errorEmails', settings.Error_Notification_Emails__c);
            result.put('completionEmails', settings.Completion_Notification_Emails__c);
            
        } catch (Exception ex) {
            throw new AuraHandledException('Error getting settings: ' + ex.getMessage());
        }
        
        return result;
    }
    
    /**
     * @description Updates the custom settings.
     * @param settingsMap Map of settings values to update.
     */
    @AuraEnabled
    public static void updateSettings(Map<String, Object> settingsMap) {
        try {
            // Get or create settings
            util_closer_Settings__c settings = util_closer_Settings__c.getOrgDefaults();
            
            if (settings == null || settings.Id == null) {
                settings = new util_closer_Settings__c();
            }
            
            // Update fields from map
            if (settingsMap.containsKey('batchSize')) {
                settings.Batch_Size__c = (Decimal) settingsMap.get('batchSize');
            }
            if (settingsMap.containsKey('debugMode')) {
                settings.Debug_Mode__c = (Boolean) settingsMap.get('debugMode');
            }
            if (settingsMap.containsKey('isActive')) {
                settings.Is_Active__c = (Boolean) settingsMap.get('isActive');
            }
            if (settingsMap.containsKey('cronExpression')) {
                settings.Cron_Expression__c = (String) settingsMap.get('cronExpression');
            }
            if (settingsMap.containsKey('scheduledJobName')) {
                settings.Scheduled_Job_Name__c = (String) settingsMap.get('scheduledJobName');
            }
            if (settingsMap.containsKey('errorEmails')) {
                settings.Error_Notification_Emails__c = (String) settingsMap.get('errorEmails');
            }
            if (settingsMap.containsKey('completionEmails')) {
                settings.Completion_Notification_Emails__c = (String) settingsMap.get('completionEmails');
            }
            
            upsert settings;
            
        } catch (Exception ex) {
            throw new AuraHandledException('Error updating settings: ' + ex.getMessage());
        }
    }
    
    /**
     * @description Manually executes the batch job.
     * @return The batch job ID.
     */
    @AuraEnabled
    public static String runBatchNow() {
        try {
            // Check if system is active
            if (!util_closer_SettingsService.isActive()) {
                throw new AuraHandledException('Warning: The system is currently inactive. The batch will run but no Cases will be processed. Activate the system first if you want to process Cases.');
            }
            
            Integer batchSize = util_closer_SettingsService.getBatchSize();
            Id jobId = Database.executeBatch(new util_closer_CaseStatusBatch(), batchSize);
            
            return String.valueOf(jobId);
            
        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new AuraHandledException('Error running batch: ' + ex.getMessage());
        }
    }
}

