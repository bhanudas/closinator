# Case Status Auto-Closer: SF CLI Integration Test Plan

This document provides step-by-step instructions for manually testing the Case Status Auto-Closer (Closinator) system in a Salesforce scratch org using the SF CLI.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Environment Setup](#2-environment-setup)
3. [Configure Custom Settings](#3-configure-custom-settings)
4. [Create Test Case Data](#4-create-test-case-data)
5. [Backdate Test Records](#5-backdate-test-records)
6. [Run the Batch Job Manually](#6-run-the-batch-job-manually)
7. [Verify Batch Execution Results](#7-verify-batch-execution-results)
8. [Schedule and Verify Scheduled Job](#8-schedule-and-verify-scheduled-job)
9. [Test Scenarios](#9-test-scenarios)
10. [Cleanup Commands](#10-cleanup-commands)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Prerequisites

Before running these tests, ensure you have:

- Salesforce CLI (`sf`) installed and updated
- Access to DevHub (`tnoxprod`) with valid authentication
- Project source code available locally
- Terminal access in the project root directory

### Verify SF CLI Installation

```bash
sf version
```

Expected output: Version 2.x or higher

---

## 2. Environment Setup

### 2.1 Verify DevHub Authentication

```bash
sf org list --all
```

Look for `tnoxprod` in the Dev Hubs section. If not authenticated:

```bash
sf org login web --alias tnoxprod --set-default-dev-hub
```

### 2.2 Check for Existing Scratch Org

```bash
sf org list --all
```

Look for an existing scratch org for this project (e.g., `util_closer_dev_main`).

### 2.3 Create Scratch Org (if needed)

```bash
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias util_closer_dev_test \
  --duration-days 7 \
  --set-default \
  --target-dev-hub tnoxprod
```

### 2.4 Deploy Source to Scratch Org

```bash
sf project deploy start --target-org util_closer_dev_test
```

### 2.5 Verify Deployment

Verify Apex classes deployed:

```bash
sf data query --query "SELECT Name FROM ApexClass WHERE Name LIKE 'util_closer_%'" --target-org util_closer_dev_test
```

Expected: All `util_closer_*` classes listed (CaseStatusBatch, RuleEngine, SettingsService, etc.)

Verify Custom Metadata records deployed:

```bash
sf data query --query "SELECT DeveloperName, Is_Active__c, Source_Status__c, Target_Status__c FROM util_closer_Case_Status_Rule__mdt" --target-org util_closer_dev_test
```

Expected output:
| DeveloperName | Is_Active__c | Source_Status__c | Target_Status__c |
|---------------|--------------|-----------------------------------|------------------|
| Close_Stale_Waiting_Cases | true | Waiting on Customer;Pending Response | Closed |
| Escalate_Old_New_Cases | true | New | Escalated |

### 2.6 Open Scratch Org (Optional)

```bash
sf org open --target-org util_closer_dev_test
```

---

## 3. Configure Custom Settings

The system requires custom settings to be configured before the batch job will process records.

### 3.1 Create Org-Default Custom Settings

```bash
sf data create record \
  --sobject util_closer_Settings__c \
  --values "Batch_Size__c=200 Is_Active__c=true Debug_Mode__c=true Cron_Expression__c='0 0 2 * * ?' Scheduled_Job_Name__c='util_closer_CaseStatusJob'" \
  --target-org util_closer_dev_test
```

### 3.2 Verify Settings Created

```bash
sf data query --query "SELECT Id, Batch_Size__c, Is_Active__c, Debug_Mode__c, Cron_Expression__c, Scheduled_Job_Name__c FROM util_closer_Settings__c" --target-org util_closer_dev_test
```

Expected: One record with the configured values.

### 3.3 Alternative: Update Existing Settings

If settings already exist, update them:

```bash
sf apex run --target-org util_closer_dev_test --file -
```

Then paste the following Apex and press Ctrl+D (or Cmd+D on Mac):

```apex
util_closer_Settings__c settings = util_closer_Settings__c.getOrgDefaults();
settings.Is_Active__c = true;
settings.Debug_Mode__c = true;
settings.Batch_Size__c = 200;
settings.Cron_Expression__c = '0 0 2 * * ?';
settings.Scheduled_Job_Name__c = 'util_closer_CaseStatusJob';
upsert settings;
System.debug('Settings updated: ' + settings.Id);
```

---

## 4. Create Test Case Data

Create test Cases that match the deployed rule criteria.

### 4.1 Create Cases for "Close Stale Waiting Cases" Rule

This rule targets Cases with status "Waiting on Customer" or "Pending Response" that haven't been modified in 30+ days.

```bash
# Create Case 1 - Waiting on Customer
sf data create record \
  --sobject Case \
  --values "Subject='Test Case - Waiting on Customer 1' Status='Waiting on Customer' Origin='Web'" \
  --target-org util_closer_dev_test

# Create Case 2 - Waiting on Customer
sf data create record \
  --sobject Case \
  --values "Subject='Test Case - Waiting on Customer 2' Status='Waiting on Customer' Origin='Web'" \
  --target-org util_closer_dev_test

# Create Case 3 - Pending Response (if this status exists in your org)
sf data create record \
  --sobject Case \
  --values "Subject='Test Case - Pending Response' Status='Pending Response' Origin='Web'" \
  --target-org util_closer_dev_test
```

### 4.2 Create Cases for "Escalate Old New Cases" Rule

This rule targets Cases with status "New" that were created 7+ days ago.

```bash
# Create Case 4 - New (to be escalated)
sf data create record \
  --sobject Case \
  --values "Subject='Test Case - New for Escalation 1' Status='New' Origin='Web'" \
  --target-org util_closer_dev_test

# Create Case 5 - New (to be escalated)
sf data create record \
  --sobject Case \
  --values "Subject='Test Case - New for Escalation 2' Status='New' Origin='Web'" \
  --target-org util_closer_dev_test
```

### 4.3 Create Control Cases (Should NOT be Updated)

Create Cases that should NOT match any rules:

```bash
# Case with status that doesn't match any rule
sf data create record \
  --sobject Case \
  --values "Subject='Control Case - Working' Status='Working' Origin='Web'" \
  --target-org util_closer_dev_test

# Case that's already closed
sf data create record \
  --sobject Case \
  --values "Subject='Control Case - Already Closed' Status='Closed' Origin='Web'" \
  --target-org util_closer_dev_test
```

### 4.4 Verify Test Cases Created

```bash
sf data query \
  --query "SELECT Id, CaseNumber, Subject, Status, CreatedDate, LastModifiedDate FROM Case WHERE Subject LIKE 'Test Case%' OR Subject LIKE 'Control Case%' ORDER BY CreatedDate DESC" \
  --target-org util_closer_dev_test
```

---

## 5. Backdate Test Records

The rules require Cases to be a certain age (30+ days or 7+ days). Since you can't directly set `LastModifiedDate` or `CreatedDate` via standard DML outside of test context, we use a workaround.

### 5.1 Backdate Cases Using Anonymous Apex

Create a file named `backdate-cases.apex` with the following content:

```apex
// Get test cases to backdate
List<Case> waitingCases = [
    SELECT Id, Subject, Status 
    FROM Case 
    WHERE Status IN ('Waiting on Customer', 'Pending Response')
    AND Subject LIKE 'Test Case%'
];

List<Case> newCases = [
    SELECT Id, Subject, Status 
    FROM Case 
    WHERE Status = 'New'
    AND Subject LIKE 'Test Case%'
];

System.debug('Found ' + waitingCases.size() + ' waiting cases to backdate');
System.debug('Found ' + newCases.size() + ' new cases to backdate');

// IMPORTANT: In production Apex, you cannot modify LastModifiedDate directly.
// This test plan uses a workaround by updating a dummy field and letting time pass,
// OR by using the approach below which only works for simulation purposes.

// For testing, we'll output the Case IDs so you can verify the batch will find them
for (Case c : waitingCases) {
    System.debug('Waiting Case: ' + c.Id + ' - ' + c.Subject);
}
for (Case c : newCases) {
    System.debug('New Case: ' + c.Id + ' - ' + c.Subject);
}

System.debug('NOTE: To properly test date-based rules, you have two options:');
System.debug('1. Wait the required days (30 or 7 days)');
System.debug('2. Temporarily modify the rule thresholds to 0 days for testing');
```

Run the script:

```bash
sf apex run --file backdate-cases.apex --target-org util_closer_dev_test
```

### 5.2 Workaround: Modify Rules for Immediate Testing

For immediate testing without waiting, temporarily modify the rule thresholds:

```bash
sf apex run --target-org util_closer_dev_test --file -
```

Paste the following and press Ctrl+D:

```apex
// Query the current rules (read-only - Custom Metadata can't be modified via Apex DML)
List<util_closer_Case_Status_Rule__mdt> rules = [
    SELECT DeveloperName, Days_Since_Last_Modified__c, Days_Since_Created__c 
    FROM util_closer_Case_Status_Rule__mdt
];

for (util_closer_Case_Status_Rule__mdt rule : rules) {
    System.debug('Rule: ' + rule.DeveloperName);
    System.debug('  Days Since Last Modified: ' + rule.Days_Since_Last_Modified__c);
    System.debug('  Days Since Created: ' + rule.Days_Since_Created__c);
}

System.debug('');
System.debug('To test immediately, deploy modified rule metadata with Days thresholds set to 0.');
System.debug('See section 5.3 below for instructions.');
```

### 5.3 Deploy Modified Rules for Testing (Optional)

Create temporary test rule files with 0-day thresholds. 

Create file `force-app/main/default/customMetadata/util_closer_Case_Status_Rule.Test_Close_Immediately.md-meta.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>Test Close Immediately</label>
    <protected>false</protected>
    <values>
        <field>Is_Active__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>Execution_Order__c</field>
        <value xsi:type="xsd:double">5</value>
    </values>
    <values>
        <field>Source_Status__c</field>
        <value xsi:type="xsd:string">Waiting on Customer</value>
    </values>
    <values>
        <field>Target_Status__c</field>
        <value xsi:type="xsd:string">Closed</value>
    </values>
    <values>
        <field>Days_Since_Last_Modified__c</field>
        <value xsi:type="xsd:double">0</value>
    </values>
    <values>
        <field>Description__c</field>
        <value xsi:type="xsd:string">TEST RULE - Immediately close Waiting on Customer cases. DELETE AFTER TESTING.</value>
    </values>
    <values>
        <field>Stop_Processing__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
</CustomMetadata>
```

Deploy the test rule:

```bash
sf project deploy start \
  --source-dir force-app/main/default/customMetadata/util_closer_Case_Status_Rule.Test_Close_Immediately.md-meta.xml \
  --target-org util_closer_dev_test
```

Verify the test rule is deployed:

```bash
sf data query \
  --query "SELECT DeveloperName, Is_Active__c, Days_Since_Last_Modified__c FROM util_closer_Case_Status_Rule__mdt WHERE Is_Active__c = true ORDER BY Execution_Order__c" \
  --target-org util_closer_dev_test
```

---

## 6. Run the Batch Job Manually

### 6.1 Execute Batch via Anonymous Apex

```bash
sf apex run --target-org util_closer_dev_test --file -
```

Paste the following and press Ctrl+D:

```apex
// Execute the batch job with a small batch size for testing
Integer batchSize = 10;
Id batchJobId = Database.executeBatch(new util_closer_CaseStatusBatch(), batchSize);
System.debug('Batch Job Started: ' + batchJobId);
System.debug('Monitor progress with: SELECT Status, NumberOfErrors, JobItemsProcessed, TotalJobItems FROM AsyncApexJob WHERE Id = \'' + batchJobId + '\'');
```

### 6.2 Alternative: Use a Script File

Create file `scripts/apex/run-batch.apex`:

```apex
// Run the Case Status Auto-Closer batch job
Integer batchSize = util_closer_SettingsService.getBatchSize();
System.debug('Starting batch with size: ' + batchSize);

Id batchJobId = Database.executeBatch(new util_closer_CaseStatusBatch(), batchSize);
System.debug('Batch Job ID: ' + batchJobId);
```

Run it:

```bash
sf apex run --file scripts/apex/run-batch.apex --target-org util_closer_dev_test
```

---

## 7. Verify Batch Execution Results

### 7.1 Check Batch Job Status

```bash
sf data query \
  --query "SELECT Id, Status, ApexClass.Name, NumberOfErrors, JobItemsProcessed, TotalJobItems, CreatedDate, CompletedDate FROM AsyncApexJob WHERE ApexClass.Name = 'util_closer_CaseStatusBatch' ORDER BY CreatedDate DESC LIMIT 5" \
  --target-org util_closer_dev_test
```

Expected: Status = `Completed`, NumberOfErrors = `0`

### 7.2 Verify Case Status Changes

Check if the "Waiting on Customer" cases were closed:

```bash
sf data query \
  --query "SELECT Id, CaseNumber, Subject, Status, LastModifiedDate FROM Case WHERE Subject LIKE 'Test Case - Waiting%'" \
  --target-org util_closer_dev_test
```

Expected: Status should now be `Closed` (if using test rules with 0-day threshold)

Check if the "New" cases were escalated:

```bash
sf data query \
  --query "SELECT Id, CaseNumber, Subject, Status, LastModifiedDate FROM Case WHERE Subject LIKE 'Test Case - New%'" \
  --target-org util_closer_dev_test
```

Expected: Status should now be `Escalated` (if using test rules with 0-day threshold)

### 7.3 Verify Control Cases Were NOT Modified

```bash
sf data query \
  --query "SELECT Id, CaseNumber, Subject, Status FROM Case WHERE Subject LIKE 'Control Case%'" \
  --target-org util_closer_dev_test
```

Expected: Statuses should remain `Working` and `Closed` respectively.

### 7.4 Check Debug Logs (if Debug Mode enabled)

```bash
sf apex tail log --target-org util_closer_dev_test
```

Or query recent logs:

```bash
sf data query \
  --query "SELECT Id, LogUser.Name, Operation, LogLength, LastModifiedDate FROM ApexLog ORDER BY LastModifiedDate DESC LIMIT 10" \
  --target-org util_closer_dev_test
```

---

## 8. Schedule and Verify Scheduled Job

### 8.1 Schedule the Job

```bash
sf apex run --target-org util_closer_dev_test --file -
```

Paste and press Ctrl+D:

```apex
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
}
```

### 8.2 Verify Scheduled Job via Query

```bash
sf data query \
  --query "SELECT Id, CronExpression, NextFireTime, State, CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name LIKE 'util_closer%'" \
  --target-org util_closer_dev_test
```

Expected: One record with State = `WAITING` and NextFireTime in the future.

### 8.3 Check if Job is Scheduled

```bash
sf apex run --target-org util_closer_dev_test --file -
```

Paste and press Ctrl+D:

```apex
Boolean isScheduled = util_closer_CaseStatusScheduler.isJobScheduled();
System.debug('Is Job Scheduled: ' + isScheduled);

CronTrigger jobInfo = util_closer_CaseStatusScheduler.getScheduledJobInfo();
if (jobInfo != null) {
    System.debug('Next Fire Time: ' + jobInfo.NextFireTime);
    System.debug('Times Triggered: ' + jobInfo.TimesTriggered);
}
```

### 8.4 Reschedule with Custom Cron

```bash
sf apex run --target-org util_closer_dev_test --file -
```

Paste and press Ctrl+D:

```apex
// Reschedule to run every hour for testing
String newCron = '0 0 * * * ?';  // Every hour at minute 0
String jobId = util_closer_CaseStatusScheduler.scheduleJob(newCron);
System.debug('Rescheduled with ID: ' + jobId);

CronTrigger job = util_closer_CaseStatusScheduler.getScheduledJobInfo();
System.debug('New Cron Expression: ' + job.CronExpression);
System.debug('Next Fire Time: ' + job.NextFireTime);
```

### 8.5 Unschedule the Job

```bash
sf apex run --target-org util_closer_dev_test --file -
```

Paste and press Ctrl+D:

```apex
util_closer_CaseStatusScheduler.unscheduleJob();
System.debug('Job unscheduled');

Boolean isScheduled = util_closer_CaseStatusScheduler.isJobScheduled();
System.debug('Is Job Still Scheduled: ' + isScheduled);  // Should be false
```

### 8.6 Verify Job is Unscheduled

```bash
sf data query \
  --query "SELECT Id, CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name LIKE 'util_closer%'" \
  --target-org util_closer_dev_test
```

Expected: No records returned.

---

## 9. Test Scenarios

### Scenario 1: Happy Path - Cases Updated Successfully

**Objective**: Verify that Cases matching rule criteria are updated correctly.

**Steps**:
1. Configure settings with `Is_Active__c = true`
2. Create Cases with statuses matching the rules
3. Deploy test rules with 0-day thresholds (or wait required days)
4. Run the batch job
5. Verify Case statuses changed as expected

**Expected Results**:
- "Waiting on Customer" cases → Status = "Closed"
- "New" cases → Status = "Escalated"
- Control cases → No change

---

### Scenario 2: Inactive System - No Processing

**Objective**: Verify no Cases are processed when system is inactive.

**Steps**:

```bash
# Deactivate the system
sf apex run --target-org util_closer_dev_test --file -
```

Paste:
```apex
util_closer_Settings__c settings = util_closer_Settings__c.getOrgDefaults();
settings.Is_Active__c = false;
upsert settings;
System.debug('System deactivated');
```

```bash
# Create a new test case
sf data create record \
  --sobject Case \
  --values "Subject='Inactive Test Case' Status='Waiting on Customer' Origin='Web'" \
  --target-org util_closer_dev_test

# Run the batch
sf apex run --target-org util_closer_dev_test --file -
```

Paste:
```apex
Database.executeBatch(new util_closer_CaseStatusBatch(), 10);
```

```bash
# Verify case was NOT updated
sf data query \
  --query "SELECT Subject, Status FROM Case WHERE Subject = 'Inactive Test Case'" \
  --target-org util_closer_dev_test
```

**Expected Result**: Case Status remains "Waiting on Customer"

**Cleanup** - Reactivate the system:
```bash
sf apex run --target-org util_closer_dev_test --file -
```

Paste:
```apex
util_closer_Settings__c settings = util_closer_Settings__c.getOrgDefaults();
settings.Is_Active__c = true;
upsert settings;
System.debug('System reactivated');
```

---

### Scenario 3: No Matching Cases

**Objective**: Verify batch completes gracefully when no Cases match.

**Steps**:

```bash
# Deactivate all rules temporarily
sf apex run --target-org util_closer_dev_test --file -
```

Paste:
```apex
// Note: Cannot modify Custom Metadata via Apex DML
// For this test, create cases that don't match any rule criteria
System.debug('Create cases with status that does not match any rule');
```

```bash
# Create case with non-matching status
sf data create record \
  --sobject Case \
  --values "Subject='No Match Test Case' Status='Working' Origin='Web'" \
  --target-org util_closer_dev_test

# Run batch
sf apex run --target-org util_closer_dev_test --file -
```

Paste:
```apex
Id jobId = Database.executeBatch(new util_closer_CaseStatusBatch(), 10);
System.debug('Batch started: ' + jobId);
```

```bash
# Check job completed without errors
sf data query \
  --query "SELECT Status, NumberOfErrors, JobItemsProcessed FROM AsyncApexJob WHERE ApexClass.Name = 'util_closer_CaseStatusBatch' ORDER BY CreatedDate DESC LIMIT 1" \
  --target-org util_closer_dev_test
```

**Expected Result**: Job Status = "Completed", NumberOfErrors = 0

---

### Scenario 4: Verify Execution Order

**Objective**: Confirm rules are evaluated in Execution_Order__c sequence.

**Steps**:

```bash
# Query rules and their order
sf data query \
  --query "SELECT DeveloperName, Execution_Order__c, Source_Status__c, Target_Status__c FROM util_closer_Case_Status_Rule__mdt WHERE Is_Active__c = true ORDER BY Execution_Order__c" \
  --target-org util_closer_dev_test
```

**Expected Result**: Rules listed in ascending Execution_Order (e.g., 10, 20, ...)

---

### Scenario 5: Debug Mode Logging

**Objective**: Verify verbose logging when Debug Mode is enabled.

**Steps**:

```bash
# Enable debug mode
sf apex run --target-org util_closer_dev_test --file -
```

Paste:
```apex
util_closer_Settings__c settings = util_closer_Settings__c.getOrgDefaults();
settings.Debug_Mode__c = true;
upsert settings;
System.debug('Debug mode enabled');
```

```bash
# Start log capture
sf apex tail log --target-org util_closer_dev_test &

# Run batch in another terminal or wait
sf apex run --target-org util_closer_dev_test --file -
```

Paste:
```apex
Database.executeBatch(new util_closer_CaseStatusBatch(), 10);
```

**Expected Result**: Detailed debug logs showing:
- Batch initialization with rule count
- Query construction details
- Case evaluation results
- Status transition details

---

## 10. Cleanup Commands

### 10.1 Delete Test Cases

```bash
sf apex run --target-org util_closer_dev_test --file -
```

Paste:
```apex
List<Case> testCases = [
    SELECT Id FROM Case 
    WHERE Subject LIKE 'Test Case%' 
    OR Subject LIKE 'Control Case%'
    OR Subject LIKE '%Test Case'
];
System.debug('Deleting ' + testCases.size() + ' test cases');
delete testCases;
```

### 10.2 Delete Test Rules (if created)

```bash
# Delete from local filesystem
rm -f force-app/main/default/customMetadata/util_closer_Case_Status_Rule.Test_*.md-meta.xml

# Deploy to remove from org (destructive change)
sf project deploy start --target-org util_closer_dev_test
```

### 10.3 Reset Custom Settings

```bash
sf apex run --target-org util_closer_dev_test --file -
```

Paste:
```apex
util_closer_Settings__c settings = util_closer_Settings__c.getOrgDefaults();
if (settings.Id != null) {
    delete settings;
    System.debug('Settings deleted');
}
```

### 10.4 Unschedule All Jobs

```bash
sf apex run --target-org util_closer_dev_test --file -
```

Paste:
```apex
util_closer_CaseStatusScheduler.unscheduleJob();
System.debug('All util_closer jobs unscheduled');
```

### 10.5 Delete Scratch Org (when testing is complete)

```bash
sf org delete scratch --target-org util_closer_dev_test --no-prompt
```

---

## 11. Troubleshooting

### Issue: "Case Status value does not exist"

**Cause**: The target status (e.g., "Escalated") doesn't exist in the org's Case Status picklist.

**Solution**: Add the status value via Setup or modify the rule to use an existing status.

```bash
sf org open --target-org util_closer_dev_test --path "/lightning/setup/CaseStatus/home"
```

### Issue: Batch Job Shows "Failed"

**Diagnosis**:

```bash
sf data query \
  --query "SELECT Id, Status, ExtendedStatus, NumberOfErrors FROM AsyncApexJob WHERE ApexClass.Name = 'util_closer_CaseStatusBatch' ORDER BY CreatedDate DESC LIMIT 1" \
  --target-org util_closer_dev_test
```

**Common causes**:
- Missing object/field permissions
- Validation rule failures on Case
- Trigger exceptions

### Issue: No Cases Being Processed

**Diagnosis**:

```bash
sf apex run --target-org util_closer_dev_test --file -
```

Paste:
```apex
// Check if system is active
System.debug('Is Active: ' + util_closer_SettingsService.isActive());

// Check if there are active rules
List<util_closer_Case_Status_Rule__mdt> rules = util_closer_RuleEngine.getActiveRules();
System.debug('Active Rules: ' + rules.size());

// Check source statuses being queried
Set<String> statuses = util_closer_RuleEngine.getAllSourceStatuses();
System.debug('Source Statuses: ' + statuses);

// Check for matching cases
Integer caseCount = [SELECT COUNT() FROM Case WHERE Status IN :statuses AND IsClosed = false];
System.debug('Matching Open Cases: ' + caseCount);
```

### Issue: Settings Not Found

**Diagnosis**:

```bash
sf data query \
  --query "SELECT Id, SetupOwnerId, Batch_Size__c, Is_Active__c FROM util_closer_Settings__c" \
  --target-org util_closer_dev_test
```

**Solution**: Create org-default settings (see Section 3).

### Issue: Scheduled Job Not Running

**Diagnosis**:

```bash
sf data query \
  --query "SELECT Id, State, NextFireTime, CronExpression, CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name LIKE 'util_closer%'" \
  --target-org util_closer_dev_test
```

Check that:
- State is "WAITING" (not "DELETED" or "ERROR")
- NextFireTime is in the future
- CronExpression is valid

---

## Quick Reference: Common Commands

| Task | Command |
|------|---------|
| Deploy source | `sf project deploy start --target-org util_closer_dev_test` |
| Query Cases | `sf data query --query "SELECT Id, Status FROM Case" --target-org util_closer_dev_test` |
| Run batch | `sf apex run --file scripts/apex/run-batch.apex --target-org util_closer_dev_test` |
| Check batch status | `sf data query --query "SELECT Status FROM AsyncApexJob WHERE ApexClass.Name='util_closer_CaseStatusBatch' ORDER BY CreatedDate DESC LIMIT 1" --target-org util_closer_dev_test` |
| Schedule job | `sf apex run -c "util_closer_CaseStatusScheduler.scheduleJob();" --target-org util_closer_dev_test` |
| Open org | `sf org open --target-org util_closer_dev_test` |
| View logs | `sf apex tail log --target-org util_closer_dev_test` |

---

## Appendix: Test Data Summary

| Case Subject | Initial Status | Expected After Batch | Rule Applied |
|--------------|----------------|---------------------|--------------|
| Test Case - Waiting on Customer 1 | Waiting on Customer | Closed | Close_Stale_Waiting_Cases |
| Test Case - Waiting on Customer 2 | Waiting on Customer | Closed | Close_Stale_Waiting_Cases |
| Test Case - Pending Response | Pending Response | Closed | Close_Stale_Waiting_Cases |
| Test Case - New for Escalation 1 | New | Escalated | Escalate_Old_New_Cases |
| Test Case - New for Escalation 2 | New | Escalated | Escalate_Old_New_Cases |
| Control Case - Working | Working | Working (no change) | None |
| Control Case - Already Closed | Closed | Closed (no change) | None (already closed) |

---

*Document Version: 1.0*  
*Last Updated: December 2024*

