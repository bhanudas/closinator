util_closer_Settings__c settings = util_closer_Settings__c.getOrgDefaults();
settings.Is_Active__c = true;
settings.Debug_Mode__c = true;
settings.Batch_Size__c = 200;
settings.Cron_Expression__c = '0 0 2 * * ?';
settings.Scheduled_Job_Name__c = 'util_closer_CaseStatusJob';
upsert settings;
System.debug('Settings created/updated: ' + settings.Id);

