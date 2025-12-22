// Run the Case Status Auto-Closer batch job
Integer batchSize = util_closer_SettingsService.getBatchSize();
System.debug('Starting batch with size: ' + batchSize);

Id batchJobId = Database.executeBatch(new util_closer_CaseStatusBatch(), batchSize);
System.debug('Batch Job ID: ' + batchJobId);





