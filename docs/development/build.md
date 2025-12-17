# Case Status Auto-Closer System Architecture

## System Overview

A configurable, metadata-driven batch system that automatically updates Case statuses based on dynamic rules. The system is designed to be portable across any Salesforce org using standard Case Management.

---

## Namespace Convention

All components must use the prefix: **`util_closer_`**

This ensures isolation in shared/managed package environments.

---

## Development Environment & Workflow

### Salesforce CLI (sf) Usage Guidelines

The agent must use Salesforce CLI (`sf`) for all Salesforce development operations. The CLI provides commands for authentication, org management, source deployment, testing, and data operations.

#### DevHub Configuration

**DevHub Alias:** `tnoxprod`

The DevHub is already authenticated and available under this alias. All scratch org creation operations must reference this DevHub. Before beginning any work, verify the DevHub connection is active and valid. If the DevHub session has expired, re-authenticate before proceeding.

#### Scratch Org Strategy

**Scratch Org Naming Convention:** `util_closer_dev_[feature]` or `util_closer_dev_main`

Create a dedicated scratch org for development work. The scratch org should have a reasonable duration (7-30 days) to allow for iterative development without expiration concerns during active work.

Before creating a new scratch org:

1. Check if an existing scratch org for this project already exists
2. If one exists and is still valid, consider reusing it
3. If creating new, delete any stale scratch orgs to conserve DevHub limits

**Scratch Org Definition Requirements:**

- Enable all features needed for Case Management
- Include standard Case object and related objects
- Enable Custom Metadata Types
- Enable Custom Settings
- Set appropriate org preferences for development

The agent should look for an existing `config/project-scratch-def.json` file. If none exists, create one with appropriate settings for this project before creating the scratch org.

#### Source Push/Pull Strategy

Use source tracking to synchronize code between local filesystem and scratch org:

1. **After creating scratch org:** Perform initial source push to deploy all existing components
2. **During development:** Push changes frequently after each logical unit of work
3. **Before committing:** Pull any changes made directly in the org (metadata modifications, etc.)
4. **Conflict resolution:** If conflicts occur, review carefully and prefer local source unless org changes were intentional

#### Test Execution

Run tests at multiple checkpoints:

1. **After each class creation:** Run tests for that specific class to catch issues early
2. **After completing a feature:** Run all project tests to verify integration
3. **Before merging to main:** Run full test suite with code coverage requirements
4. **Coverage requirement:** Maintain minimum 90% coverage; do not merge if below threshold

When tests fail:

1. Analyze the failure message and stack trace
2. Fix the issue in the source code
3. Push the fix to the scratch org
4. Re-run the failing test to confirm resolution
5. Run the full test suite to ensure no regressions

#### Deployment Validation

Before considering any feature complete:

1. Run a deployment validation (check-only deployment) against the scratch org
2. Verify all components deploy without errors
3. Confirm all tests pass in the deployment context
4. Check code coverage meets requirements

---

### Git Workflow Guidelines

#### Repository Structure

Ensure the repository follows standard SFDX project structure:

```
project-root/
├── .git/
├── .gitignore
├── sfdx-project.json
├── config/
│   └── project-scratch-def.json
├── force-app/
│   └── main/
│       └── default/
│           ├── classes/
│           ├── objects/
│           ├── customMetadata/
│           ├── permissionsets/
│           └── lwc/
└── README.md
```

#### Branch Strategy

**Protected Branch:** `main`

- Contains only complete, tested, deployable features
- Never commit directly to main
- All changes arrive via merge from feature branches
- Must pass all tests before merge

**Feature Branch Naming Convention:** `feature/util_closer_[component-name]`

Examples:

- `feature/util_closer_custom-settings`
- `feature/util_closer_batch-class`
- `feature/util_closer_scheduler`
- `feature/util_closer_permission-sets`
- `feature/util_closer_lwc-manager`

#### Feature Branch Workflow

**Starting a New Feature:**

1. Ensure local main branch is up to date
2. Create new feature branch from main
3. Create or switch to appropriate scratch org
4. Begin development work

**During Development:**

1. Make small, logical commits frequently
2. Write clear, descriptive commit messages
3. Push to remote feature branch regularly to preserve work
4. Each commit should represent a coherent unit of work

**Commit Message Format:**

```
[Component] Brief description of change

- Detail 1 if needed
- Detail 2 if needed
```

Examples:

- `[Settings] Add util_closer_Settings__c custom setting with all fields`
- `[Batch] Implement execute method with partial failure handling`
- `[Test] Add util_closer_CaseStatusBatch_Test with 95% coverage`

**Completing a Feature:**

1. Ensure all tests pass locally and in scratch org
2. Verify code coverage meets 90% threshold
3. Pull any remote changes to main
4. Rebase or merge main into feature branch if needed
5. Resolve any conflicts
6. Run full test suite one final time
7. Merge feature branch into main
8. Push main to remote
9. Delete the feature branch (local and remote)

#### Git Operations Frequency

**Commit frequently when:**

- A new file is created and compiles successfully
- A logical unit of functionality is complete
- Tests are added or updated
- Bug fixes are applied
- Before switching context to different work

**Push to remote when:**

- At least once per development session
- After completing any significant milestone
- Before taking breaks or ending work sessions
- After successful test runs

**Never commit:**

- Code that doesn't compile
- Code with known failing tests (unless tests are marked as expected failures temporarily)
- Sensitive data, credentials, or org-specific configurations
- Debug code or temporary workarounds intended for removal

#### Handling Build Failures

If the build fails at any point:

1. Do NOT merge to main
2. Analyze the failure on the feature branch
3. Make corrective commits on the feature branch
4. Re-test until all issues are resolved
5. Only then proceed with merge to main

---

### Phase-Based Development with Git Integration

Each implementation phase should correspond to one or more feature branches. Only merge to main when a phase is fully complete and tested.

#### Phase 1: Project Setup & Metadata Objects

**Branch:** `feature/util_closer_metadata-foundation`

1. Initialize SFDX project structure if not exists
2. Create scratch org definition file
3. Create scratch org from DevHub `tnoxprod`
4. Create Custom Setting object and fields
5. Create Custom Metadata Type and fields
6. Create sample Custom Metadata records
7. Push to scratch org and verify in Setup
8. Commit all metadata files
9. Merge to main

#### Phase 2: Permission Sets

**Branch:** `feature/util_closer_permission-sets`

1. Create feature branch from updated main
2. Create Administrator permission set
3. Create Operator permission set
4. Push to scratch org
5. Verify permission sets in Setup
6. Commit permission set files
7. Merge to main

#### Phase 3: Core Services - Logger and Settings

**Branch:** `feature/util_closer_core-services`

1. Create feature branch from updated main
2. Build `util_closer_Logger` class
3. Push and verify compilation
4. Commit
5. Build `util_closer_SettingsService` class
6. Push and verify compilation
7. Commit
8. Build `util_closer_BatchMetrics` class
9. Push and verify compilation
10. Commit
11. Merge to main

#### Phase 4: Rule Engine and Notifications

**Branch:** `feature/util_closer_rule-engine`

1. Create feature branch from updated main
2. Build `util_closer_RuleEngine` class
3. Push, verify, commit
4. Build `util_closer_NotificationService` class
5. Push, verify, commit
6. Merge to main

#### Phase 5: Batch Infrastructure

**Branch:** `feature/util_closer_batch-system`

1. Create feature branch from updated main
2. Build `util_closer_CaseStatusBatch` class
3. Push, verify, commit
4. Build `util_closer_CaseStatusScheduler` class
5. Push, verify, commit
6. Merge to main

#### Phase 6: Update Permission Sets with Apex Access

**Branch:** `feature/util_closer_permission-set-apex`

1. Create feature branch from updated main
2. Update Administrator permission set with Apex class access
3. Update Operator permission set with Apex class access
4. Push and verify
5. Commit
6. Merge to main

#### Phase 7: Test Data Factory

**Branch:** `feature/util_closer_test-factory`

1. Create feature branch from updated main
2. Build `util_closer_TestDataFactory` class
3. Push and verify compilation (no tests yet, just the factory)
4. Commit
5. Merge to main

#### Phase 8: Unit Tests - Core Services

**Branch:** `feature/util_closer_tests-core`

1. Create feature branch from updated main
2. Build `util_closer_SettingsService_Test`
3. Run test, verify pass, check coverage
4. Commit
5. Build `util_closer_RuleEngine_Test`
6. Run test, verify pass, check coverage
7. Commit
8. Build `util_closer_NotificationService_Test`
9. Run test, verify pass, check coverage
10. Commit
11. Run all tests, verify 90%+ coverage on tested classes
12. Merge to main

#### Phase 9: Unit Tests - Batch and Scheduler

**Branch:** `feature/util_closer_tests-batch`

1. Create feature branch from updated main
2. Build `util_closer_CaseStatusBatch_Test`
3. Run test, verify pass, check coverage
4. Commit
5. Build `util_closer_CaseStatusScheduler_Test`
6. Run test, verify pass, check coverage
7. Commit
8. Build `util_closer_PermissionSet_Test`
9. Run test, verify pass
10. Commit
11. Run full test suite, verify all pass with 90%+ coverage
12. Merge to main

#### Phase 10: UI Components

**Branch:** `feature/util_closer_ui-components`

1. Create feature branch from updated main
2. Build `util_closer_SchedulerController` class
3. Push, verify, commit
4. Build `util_closer_SchedulerController_Test`
5. Run test, verify pass
6. Commit
7. Build `util_closer_schedulerManager` LWC (html, js, css, meta)
8. Push, verify in org
9. Commit
10. Run full test suite
11. Merge to main

#### Phase 11: Final Validation

**Branch:** `feature/util_closer_final-validation`

1. Create feature branch from main
2. Run complete test suite with coverage
3. Fix any issues discovered, commit fixes
4. Perform manual testing in scratch org
5. Document any findings or adjustments
6. Commit any final refinements
7. Verify all success criteria met
8. Merge to main
9. Tag the release (e.g., `v1.0.0`)

---

### Scratch Org Lifecycle Management

**When to Create New Scratch Org:**

- Starting the project fresh
- Current scratch org is expiring soon
- Current scratch org is corrupted or in bad state
- Need clean environment for final validation

**When to Reuse Existing Scratch Org:**

- Continuing work on same feature
- Iterating on bug fixes
- Running incremental tests

**Scratch Org Cleanup:**

- Delete scratch orgs when work is complete
- Delete scratch orgs that have expired
- Keep only active development scratch orgs to conserve limits

---

### Handling Common Scenarios

#### Scenario: Test Fails After Push

1. Do not commit failing code
2. Review test failure output
3. Identify root cause in source
4. Make fix locally
5. Push fix to scratch org
6. Re-run failing test
7. Once passing, commit with message indicating fix

#### Scenario: Merge Conflict with Main

1. Fetch latest main
2. Attempt to rebase feature branch onto main
3. Resolve conflicts file by file
4. After resolution, push to scratch org
5. Run all tests to verify resolution didn't break anything
6. Complete the merge

#### Scenario: Scratch Org Expired Mid-Feature

1. Create new scratch org
2. Push all source from feature branch
3. Run tests to verify state
4. Continue development

#### Scenario: DevHub Session Expired

1. Re-authenticate to DevHub with alias `tnoxprod`
2. Verify authentication successful
3. Continue with scratch org operations

#### Scenario: Need to Hotfix Main

1. Create branch `hotfix/util_closer_[issue]` from main
2. Make minimal fix
3. Test thoroughly
4. Merge to main
5. If feature branches exist, rebase them onto updated main

---

### Quality Gates

Before any merge to main, verify:

1. **Compilation:** All Apex classes compile without errors
2. **Tests Pass:** All unit tests execute successfully
3. **Coverage:** Code coverage exceeds 90% for all classes
4. **No Debug Code:** Remove any temporary debug statements
5. **No Hardcoded Values:** Configuration via Custom Settings/Metadata
6. **Clean History:** Commit messages are clear and meaningful
7. **Documentation:** Code comments where logic is complex

---

## Component Architecture

### 1. Custom Settings (Hierarchy)

**Object Name:** `util_closer_Settings__c`

| Field API Name                      | Type                 | Description                                                                  |
| ----------------------------------- | -------------------- | ---------------------------------------------------------------------------- |
| `Batch_Size__c`                     | Number(5,0)          | Number of records per batch execution (default: 200)                         |
| `Error_Notification_Emails__c`      | Long Text Area(2000) | Semicolon-separated list of emails for error notifications                   |
| `Completion_Notification_Emails__c` | Long Text Area(2000) | Semicolon-separated list of emails for job completion reports                |
| `Debug_Mode__c`                     | Checkbox             | When true, emit verbose debug logs                                           |
| `Is_Active__c`                      | Checkbox             | Master switch to enable/disable the batch job                                |
| `Cron_Expression__c`                | Text(120)            | Cron expression for scheduling (e.g., `0 0 2 * * ?` for 2 AM daily)          |
| `Scheduled_Job_Name__c`             | Text(100)            | Name identifier for the scheduled job (default: `util_closer_CaseStatusJob`) |

**Implementation Notes:**

- Use Hierarchy type to allow org-wide defaults with user/profile overrides for testing
- Create an org-wide default record during deployment

---

### 2. Custom Metadata Type

**Object Name:** `util_closer_Case_Status_Rule__mdt`

| Field API Name                           | Type                 | Description                                                                                |
| ---------------------------------------- | -------------------- | ------------------------------------------------------------------------------------------ |
| `Is_Active__c`                           | Checkbox             | Rule is active and should be evaluated                                                     |
| `Execution_Order__c`                     | Number(3,0)          | Order in which rules are evaluated (lower = first)                                         |
| `Source_Status__c`                       | Text(255)            | Current Case Status value to match (supports semicolon-separated list for multiple values) |
| `Target_Status__c`                       | Text(255)            | Status value to set when rule matches                                                      |
| `Days_Since_Last_Modified__c`            | Number(5,0)          | Minimum days since Case was last modified (null = ignore)                                  |
| `Days_Since_Created__c`                  | Number(5,0)          | Minimum days since Case was created (null = ignore)                                        |
| `Days_Since_Last_Activity__c`            | Number(5,0)          | Minimum days since last activity (null = ignore)                                           |
| `Record_Type_Developer_Names__c`         | Long Text Area(2000) | Semicolon-separated RecordType DeveloperNames to include (blank = all)                     |
| `Exclude_Record_Type_Developer_Names__c` | Long Text Area(2000) | Semicolon-separated RecordType DeveloperNames to exclude                                   |
| `Additional_Filter_Logic__c`             | Text(255)            | Optional: SOQL WHERE clause fragment for advanced filtering                                |
| `Description__c`                         | Long Text Area(2000) | Human-readable description of what this rule does                                          |
| `Stop_Processing__c`                     | Checkbox             | If true and this rule matches, do not evaluate subsequent rules for this Case              |

**Example Rule Records to Create:**

1. **Close_Stale_Waiting_Cases**

   - Source_Status\_\_c: `Waiting on Customer;Pending Response`
   - Target_Status\_\_c: `Closed`
   - Days_Since_Last_Modified\_\_c: `30`
   - Execution_Order\_\_c: `10`

2. **Escalate_Old_New_Cases**
   - Source_Status\_\_c: `New`
   - Target_Status\_\_c: `Escalated`
   - Days_Since_Created\_\_c: `7`
   - Execution_Order\_\_c: `20`

---

### 3. Permission Sets

#### 3.1 Administrator Permission Set

**Permission Set Name:** `util_closer_Administrator`
**API Name:** `util_closer_Administrator`
**Label:** `Case Auto-Closer Administrator`
**Description:** `Full access to configure and manage the Case Status Auto-Closer system including settings, scheduling, and manual batch execution.`

**Custom Setting Access:**

| Object                    | Read | Create | Edit | Delete |
| ------------------------- | ---- | ------ | ---- | ------ |
| `util_closer_Settings__c` | ✓    | ✓      | ✓    | ✓      |

**Field-Level Security for `util_closer_Settings__c`:**

| Field                               | Read | Edit |
| ----------------------------------- | ---- | ---- |
| `Batch_Size__c`                     | ✓    | ✓    |
| `Error_Notification_Emails__c`      | ✓    | ✓    |
| `Completion_Notification_Emails__c` | ✓    | ✓    |
| `Debug_Mode__c`                     | ✓    | ✓    |
| `Is_Active__c`                      | ✓    | ✓    |
| `Cron_Expression__c`                | ✓    | ✓    |
| `Scheduled_Job_Name__c`             | ✓    | ✓    |

**Apex Class Access:**

| Apex Class                        | Enabled |
| --------------------------------- | ------- |
| `util_closer_CaseStatusBatch`     | ✓       |
| `util_closer_CaseStatusScheduler` | ✓       |
| `util_closer_SchedulerController` | ✓       |
| `util_closer_SettingsService`     | ✓       |
| `util_closer_RuleEngine`          | ✓       |
| `util_closer_NotificationService` | ✓       |
| `util_closer_Logger`              | ✓       |
| `util_closer_BatchMetrics`        | ✓       |

**Custom Metadata Type Access:**

- `util_closer_Case_Status_Rule__mdt`: Read access (Custom Metadata is readable by default but listing for clarity)

**System Permissions:**

| Permission    | Enabled |
| ------------- | ------- |
| `Run Flows`   | ✓       |
| `API Enabled` | ✓       |

---

#### 3.2 Operator Permission Set

**Permission Set Name:** `util_closer_Operator`
**API Name:** `util_closer_Operator`
**Label:** `Case Auto-Closer Operator`
**Description:** `Ability to view settings and manually execute the Case Status Auto-Closer batch job. Cannot modify configuration.`

**Custom Setting Access:**

| Object                    | Read | Create | Edit | Delete |
| ------------------------- | ---- | ------ | ---- | ------ |
| `util_closer_Settings__c` | ✓    | ✗      | ✗    | ✗      |

**Field-Level Security for `util_closer_Settings__c`:**

| Field                               | Read | Edit |
| ----------------------------------- | ---- | ---- |
| `Batch_Size__c`                     | ✓    | ✗    |
| `Error_Notification_Emails__c`      | ✓    | ✗    |
| `Completion_Notification_Emails__c` | ✓    | ✗    |
| `Debug_Mode__c`                     | ✓    | ✗    |
| `Is_Active__c`                      | ✓    | ✗    |
| `Cron_Expression__c`                | ✓    | ✗    |
| `Scheduled_Job_Name__c`             | ✓    | ✗    |

**Apex Class Access:**

| Apex Class                        | Enabled |
| --------------------------------- | ------- |
| `util_closer_CaseStatusBatch`     | ✓       |
| `util_closer_CaseStatusScheduler` | ✓       |
| `util_closer_SchedulerController` | ✓       |
| `util_closer_SettingsService`     | ✓       |
| `util_closer_RuleEngine`          | ✓       |
| `util_closer_NotificationService` | ✓       |
| `util_closer_Logger`              | ✓       |
| `util_closer_BatchMetrics`        | ✓       |

**System Permissions:**

| Permission    | Enabled |
| ------------- | ------- |
| `API Enabled` | ✓       |

---

### 4. Apex Classes

#### 4.1 Settings Service Class

**Class Name:** `util_closer_SettingsService`

**Purpose:** Centralized access to Custom Settings with caching and null-safety.

**Public Methods:**

- `static util_closer_Settings__c getSettings()` - Returns org default or creates runtime default
- `static Integer getBatchSize()` - Returns batch size with fallback to 200
- `static Boolean isDebugMode()` - Returns debug mode flag
- `static Boolean isActive()` - Returns master active flag
- `static List<String> getErrorEmails()` - Parses and returns error notification emails
- `static List<String> getCompletionEmails()` - Parses and returns completion notification emails
- `static String getCronExpression()` - Returns cron expression
- `static String getScheduledJobName()` - Returns job name with default

**Implementation Requirements:**

- Use lazy-loaded singleton pattern for settings retrieval
- Handle null settings gracefully with sensible defaults
- Provide `@TestVisible` method to inject mock settings

---

#### 4.2 Logger Utility Class

**Class Name:** `util_closer_Logger`

**Purpose:** Conditional debug logging based on Debug_Mode\_\_c setting.

**Public Methods:**

- `static void debug(String message)` - Logs at DEBUG level if debug mode enabled
- `static void debug(String context, String message)` - Logs with context prefix
- `static void error(String message)` - Always logs at ERROR level
- `static void error(String message, Exception ex)` - Logs exception details

**Implementation Requirements:**

- Check `util_closer_SettingsService.isDebugMode()` before emitting debug logs
- Format messages consistently with timestamp and context
- Include stack trace information for exceptions

---

#### 4.3 Rule Engine Class

**Class Name:** `util_closer_RuleEngine`

**Purpose:** Evaluates Custom Metadata rules and builds dynamic SOQL queries.

**Public Methods:**

- `static List<util_closer_Case_Status_Rule__mdt> getActiveRules()` - Returns active rules ordered by Execution_Order\_\_c
- `static String buildQueryForRule(util_closer_Case_Status_Rule__mdt rule)` - Constructs SOQL WHERE clause for a rule
- `static Map<Id, String> evaluateCases(List<Case> cases, List<util_closer_Case_Status_Rule__mdt> rules)` - Returns Map of CaseId to new Status value
- `static String buildBatchQuery()` - Builds complete SOQL query for batch start method

**Implementation Requirements:**

- Handle all date calculations relative to `System.today()`
- Support semicolon-separated values in Source_Status\_\_c and RecordType fields
- Safely handle null/blank optional fields
- Use dynamic SOQL construction with proper escaping (use `String.escapeSingleQuotes()`)
- Log query construction details when debug mode enabled
- For `evaluateCases`: Process each Case against rules in order, respect `Stop_Processing__c` flag

**Query Building Logic:**

```
Base query should select: Id, Status, RecordTypeId, RecordType.DeveloperName,
                          LastModifiedDate, CreatedDate, LastActivityDate

WHERE clause must include:
- Status IN :sourceStatusSet (union of all active rules' source statuses)
- IsClosed = false
```

---

#### 4.4 Notification Service Class

**Class Name:** `util_closer_NotificationService`

**Purpose:** Handles all email notifications for errors and completion reports.

**Public Methods:**

- `static void sendErrorNotification(String subject, String body, Exception ex)` - Sends error email
- `static void sendCompletionReport(util_closer_BatchMetrics metrics)` - Sends completion summary

**Implementation Requirements:**

- Use `Messaging.SingleEmailMessage` for sending
- Handle empty email lists gracefully (log warning, don't throw)
- Include org name and instance in email subject
- Format HTML emails with clear structure
- Include timestamp and batch job ID in all emails

---

#### 4.5 Batch Metrics Inner/Wrapper Class

**Class Name:** `util_closer_BatchMetrics`

**Purpose:** Tracks and reports batch execution statistics.

**Properties:**

- `Integer totalRecordsProcessed`
- `Integer totalRecordsUpdated`
- `Integer totalRecordsFailed`
- `Integer totalBatchesExecuted`
- `DateTime startTime`
- `DateTime endTime`
- `List<String> errors` (max 50 entries to avoid heap issues)
- `Map<String, Integer> statusTransitionCounts` (tracks "OldStatus -> NewStatus" counts)

**Public Methods:**

- `void recordSuccess(String fromStatus, String toStatus)`
- `void recordFailure(String errorMessage, Id caseId)`
- `String toEmailBody()` - Formats metrics as HTML email content
- `String toLogSummary()` - Formats metrics for debug log

---

#### 4.6 Main Batch Class

**Class Name:** `util_closer_CaseStatusBatch`

**Interfaces:** `Database.Batchable<SObject>, Database.Stateful, Database.RaisesPlatformEvents`

**Instance Variables (Stateful):**

- `util_closer_BatchMetrics metrics`
- `List<util_closer_Case_Status_Rule__mdt> rules` (cached in constructor)

**Constructor:**

- `util_closer_CaseStatusBatch()` - Initialize metrics, load rules, log startup

**Batchable Methods:**

**`start(Database.BatchableContext bc)`**

- Log batch job ID
- Build and execute query via `util_closer_RuleEngine.buildBatchQuery()`
- Return `Database.QueryLocator`
- If no active rules exist, log warning and return empty query

**`execute(Database.BatchableContext bc, List<Case> scope)`**

- Increment batch counter in metrics
- Call `util_closer_RuleEngine.evaluateCases(scope, rules)`
- Build list of Cases to update with new Status values
- Perform `Database.update()` with `allOrNone = false`
- Process `Database.SaveResult[]` to track successes and failures
- Update metrics accordingly
- Catch any unexpected exceptions, log them, add to metrics errors

**`finish(Database.BatchableContext bc)`**

- Set endTime in metrics
- Log completion summary
- Send completion report via `util_closer_NotificationService`
- If any failures occurred, also send error notification

**Implementation Requirements:**

- Verify `util_closer_SettingsService.isActive()` in start method; return empty QueryLocator if inactive
- Handle partial failures gracefully
- Limit error list to 50 items to prevent heap overflow in large failure scenarios

---

#### 4.7 Scheduler Class

**Class Name:** `util_closer_CaseStatusScheduler`

**Interfaces:** `Schedulable`

**Public Methods:**

- `void execute(SchedulableContext sc)` - Instantiate and execute batch with configured batch size
- `static String scheduleJob()` - Schedule using settings, return Job ID
- `static String scheduleJob(String cronExpression)` - Schedule with custom cron
- `static void unscheduleJob()` - Abort existing scheduled job by name
- `static void reschedule()` - Unschedule then schedule (for UI use)
- `static Boolean isJobScheduled()` - Check if job currently scheduled
- `static CronTrigger getScheduledJobInfo()` - Return current job details

**Implementation Requirements:**

- Use `System.scheduleBatch()` is NOT appropriate here; use `System.schedule()` with the Schedulable
- In `execute()`, call `Database.executeBatch(new util_closer_CaseStatusBatch(), batchSize)`
- Query `CronTrigger` and `CronJobDetail` to check existing jobs
- Handle exceptions in scheduling methods gracefully

---

### 5. Lightning Web Component for Rescheduling

#### 5.1 Apex Controller

**Class Name:** `util_closer_SchedulerController`

**Methods (all `@AuraEnabled`):**

- `static Map<String, Object> getJobStatus()` - Returns current job state, next fire time, cron expression
- `static String rescheduleJob(String cronExpression)` - Reschedule with new cron, return success message
- `static void unscheduleJob()` - Cancel scheduled job
- `static Map<String, Object> getSettings()` - Return current custom settings values
- `static void updateSettings(Map<String, Object> settingsMap)` - Update custom settings
- `static String runBatchNow()` - Manually execute batch immediately, return batch job ID

**Implementation Requirements:**

- Include proper error handling with `AuraHandledException`
- Validate cron expression format before scheduling
- Return meaningful error messages
- `runBatchNow()` should check `Is_Active__c` and warn if system is inactive
- `updateSettings()` must verify caller has edit permission on settings

---

#### 5.2 LWC Component

**Component Name:** `util_closer_schedulerManager`

**Features:**

- Display current job status (Scheduled/Not Scheduled, Next Fire Time)
- Input field for cron expression with common presets dropdown
- Buttons: Schedule, Unschedule, Reschedule, Run Now
- Settings section showing current configuration (editable for Administrators)
- Toast notifications for success/error feedback
- Refresh button to reload status
- Visual indicator when batch is currently running

**UI Layout:**

```
┌─────────────────────────────────────────────────────────┐
│  Case Status Auto-Closer Scheduler                      │
├─────────────────────────────────────────────────────────┤
│  Status: ● Scheduled                                    │
│  Next Run: 2024-01-15 02:00:00 AM                      │
│  Job Name: util_closer_CaseStatusJob                    │
├─────────────────────────────────────────────────────────┤
│  Schedule Configuration                                 │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Cron Expression: [0 0 2 * * ?          ]        │   │
│  └─────────────────────────────────────────────────┘   │
│  Presets: [Daily 2 AM ▼]                               │
│                                                         │
│  [Reschedule]  [Unschedule]  [Run Now]  [Refresh]      │
├─────────────────────────────────────────────────────────┤
│  Current Settings                            [Edit]     │
│  • Batch Size: 200                                      │
│  • Debug Mode: Off                                      │
│  • Active: Yes                                          │
│  • Error Emails: admin@company.com                      │
│  • Completion Emails: ops@company.com                   │
└─────────────────────────────────────────────────────────┘
```

**Common Cron Presets:**

- Daily 2 AM: `0 0 2 * * ?`
- Daily 6 AM: `0 0 6 * * ?`
- Every 6 Hours: `0 0 */6 * * ?`
- Weekdays 3 AM: `0 0 3 ? * MON-FRI`
- Weekly Sunday 1 AM: `0 0 1 ? * SUN`

**Conditional UI Elements:**

- "Edit" button for settings only visible to users with edit permission
- "Run Now" button shows confirmation modal before execution
- Settings fields become editable inputs when Edit mode is active

---

### 6. Test Classes

#### 6.1 Test Data Factory

**Class Name:** `util_closer_TestDataFactory`

**Annotations:** `@isTest`

**Public Methods:**

```
// Settings Creation
static util_closer_Settings__c createDefaultSettings()
static util_closer_Settings__c createSettings(Integer batchSize, Boolean debugMode, Boolean isActive)
static util_closer_Settings__c createSettings(Integer batchSize, Boolean debugMode, Boolean isActive, String errorEmails, String completionEmails)
static void insertOrgDefaultSettings(util_closer_Settings__c settings)

// Case Creation
static Case createCase(String status)
static Case createCase(String status, Integer daysOld)
static List<Case> createCases(String status, Integer count)
static List<Case> createCases(String status, Integer count, Integer daysOld)
static List<Case> createCasesWithRecordType(String status, Integer count, String recordTypeDeveloperName)

// User Creation for Permission Testing
static User createUserWithPermissionSet(String permissionSetApiName)
static User createAdminUser()
static User createOperatorUser()
static User createStandardUserWithoutPermissions()

// Helper Methods
static void setLastModifiedDate(List<Case> cases, Integer daysAgo)
static void setCreatedDate(List<Case> cases, Integer daysAgo)
static User createTestUser(String profileName)
static void assignPermissionSet(Id userId, String permissionSetApiName)
```

**Implementation Requirements:**

- All methods should handle DML internally or return unsaved records based on method name convention
- Use `Test.setCreatedDate()` for backdating records
- For LastModifiedDate simulation, update records after initial insert with calculated dates
- Include SeeAllData=false by default
- Create reusable, composable methods
- User creation methods should use 'Standard User' profile as base

**Important Note on Custom Metadata in Tests:**
Custom Metadata records ARE accessible in tests without SeeAllData. The test factory should NOT attempt to create Custom Metadata records. Instead, tests should either:

1. Use actual deployed metadata records
2. Mock the `util_closer_RuleEngine` methods using dependency injection or a mockable wrapper

---

#### 6.2 Settings Service Test Class

**Class Name:** `util_closer_SettingsService_Test`

**Test Methods:**

- `testGetSettings_WithOrgDefault()` - Verify retrieval with existing settings
- `testGetSettings_WithoutOrgDefault()` - Verify fallback behavior
- `testGetBatchSize_CustomValue()` - Verify custom batch size returned
- `testGetBatchSize_DefaultFallback()` - Verify 200 default
- `testIsDebugMode_True()` - Verify debug mode flag
- `testIsDebugMode_False()` - Verify debug mode flag
- `testGetErrorEmails_ParsesList()` - Verify semicolon parsing
- `testGetErrorEmails_EmptyList()` - Verify empty handling
- `testGetCompletionEmails_ParsesList()` - Verify semicolon parsing
- `testIsActive_True()` - Verify active flag
- `testIsActive_False()` - Verify inactive flag

**Coverage Target:** 100%

---

#### 6.3 Rule Engine Test Class

**Class Name:** `util_closer_RuleEngine_Test`

**Test Methods:**

- `testGetActiveRules_ReturnsOrderedRules()` - Verify rules returned in Execution_Order
- `testGetActiveRules_ExcludesInactive()` - Verify inactive rules filtered
- `testBuildQueryForRule_BasicSourceStatus()` - Verify simple query construction
- `testBuildQueryForRule_MultipleSourceStatuses()` - Verify semicolon-separated handling
- `testBuildQueryForRule_WithDaysSinceLastModified()` - Verify date calculation
- `testBuildQueryForRule_WithDaysSinceCreated()` - Verify date calculation
- `testBuildQueryForRule_WithRecordTypeFilter()` - Verify record type inclusion
- `testBuildQueryForRule_WithExcludedRecordTypes()` - Verify record type exclusion
- `testBuildQueryForRule_WithAdditionalFilterLogic()` - Verify custom WHERE append
- `testEvaluateCases_SingleRuleMatch()` - Verify single rule evaluation
- `testEvaluateCases_MultipleRulesFirstMatch()` - Verify order-based matching
- `testEvaluateCases_StopProcessingFlag()` - Verify stop processing behavior
- `testEvaluateCases_NoMatch()` - Verify empty map for non-matching cases
- `testBuildBatchQuery_CombinesActiveRules()` - Verify complete query generation
- `testBuildBatchQuery_NoActiveRules()` - Verify handling when no rules exist

**Coverage Target:** 95%+

---

#### 6.4 Batch Class Test

**Class Name:** `util_closer_CaseStatusBatch_Test`

**Test Methods:**

- `testBatch_ProcessesCasesSuccessfully()` - Happy path with matching cases
- `testBatch_NoMatchingCases()` - Verify graceful handling of empty results
- `testBatch_PartialFailures()` - Verify partial success handling with validation rule failures
- `testBatch_InactiveSystemSkipsProcessing()` - Verify Is_Active\_\_c check
- `testBatch_NoActiveRulesSkipsProcessing()` - Verify empty rules handling
- `testBatch_MetricsTrackedCorrectly()` - Verify all metrics populated
- `testBatch_ErrorNotificationSent()` - Verify error emails on failure
- `testBatch_CompletionNotificationSent()` - Verify completion emails
- `testBatch_DebugModeLogsDetails()` - Verify enhanced logging (check debug logs generated)
- `testBatch_LargeVolume()` - Test with 500+ records across multiple batches
- `testBatch_StatusTransitionCounts()` - Verify transition tracking in metrics

**Setup Requirements:**

- Use `Test.startTest()` / `Test.stopTest()` to execute batch synchronously
- Create Custom Settings with test emails
- Ensure test Cases exist that match rule criteria

**Coverage Target:** 95%+

---

#### 6.5 Scheduler Test Class

**Class Name:** `util_closer_CaseStatusScheduler_Test`

**Test Methods:**

- `testScheduleJob_CreatesScheduledJob()` - Verify job scheduled
- `testScheduleJob_WithCustomCron()` - Verify custom cron expression used
- `testUnscheduleJob_RemovesJob()` - Verify job aborted
- `testReschedule_ReplacesExistingJob()` - Verify unschedule then schedule
- `testIsJobScheduled_WhenScheduled()` - Verify returns true
- `testIsJobScheduled_WhenNotScheduled()` - Verify returns false
- `testExecute_StartsBatch()` - Verify batch initiated from scheduler
- `testGetScheduledJobInfo_ReturnsDetails()` - Verify CronTrigger info returned

**Coverage Target:** 95%+

---

#### 6.6 Notification Service Test Class

**Class Name:** `util_closer_NotificationService_Test`

**Test Methods:**

- `testSendErrorNotification_SendsEmail()` - Verify email sent with correct content
- `testSendErrorNotification_NoRecipients()` - Verify graceful handling
- `testSendCompletionReport_SendsEmail()` - Verify formatted report sent
- `testSendCompletionReport_IncludesMetrics()` - Verify all metrics in body
- `testSendCompletionReport_NoRecipients()` - Verify graceful handling

**Implementation Notes:**

- Use `System.assertEquals()` on `Messaging.reserveSingleEmailCapacity()` or check email invocations
- Consider using `Messaging.InternalEmailMessage` for testing without actual sends

**Coverage Target:** 90%+

---

#### 6.7 Controller Test Class

**Class Name:** `util_closer_SchedulerController_Test`

**Test Methods:**

- `testGetJobStatus_WhenScheduled()` - Verify status map returned
- `testGetJobStatus_WhenNotScheduled()` - Verify status map returned
- `testRescheduleJob_Success()` - Verify reschedule works
- `testRescheduleJob_InvalidCron()` - Verify error handling
- `testUnscheduleJob_Success()` - Verify unschedule works
- `testGetSettings_ReturnsValues()` - Verify settings retrieval
- `testUpdateSettings_ModifiesValues()` - Verify settings update
- `testRunBatchNow_ExecutesBatch()` - Verify manual batch execution
- `testRunBatchNow_ReturnsJobId()` - Verify job ID returned
- `testUpdateSettings_WithoutPermission_ThrowsError()` - Verify permission enforcement

**Coverage Target:** 90%+

---

#### 6.8 Permission Set Test Class

**Class Name:** `util_closer_PermissionSet_Test`

**Test Methods:**

- `testAdministrator_CanEditSettings()` - Verify admin can modify settings
- `testAdministrator_CanRunBatch()` - Verify admin can execute batch
- `testAdministrator_CanScheduleJob()` - Verify admin can schedule
- `testAdministrator_CanUnscheduleJob()` - Verify admin can unschedule
- `testOperator_CanViewSettings()` - Verify operator can read settings
- `testOperator_CannotEditSettings()` - Verify operator cannot modify settings
- `testOperator_CanRunBatch()` - Verify operator can execute batch
- `testOperator_CanViewJobStatus()` - Verify operator can see job status
- `testUserWithoutPermission_CannotAccessBatch()` - Verify no access without permission set
- `testUserWithoutPermission_CannotAccessSettings()` - Verify no access without permission set

**Implementation Pattern:**

```
// Each test should follow this pattern:
User testUser = util_closer_TestDataFactory.createAdminUser();
System.runAs(testUser) {
    // Perform operation
    // Assert expected behavior
}
```

**Coverage Target:** 90%+

---

## Deployment Package Structure

```
project-root/
├── .git/
├── .gitignore
├── sfdx-project.json
├── config/
│   └── project-scratch-def.json
├── README.md
└── force-app/
    └── main/
        └── default/
            ├── classes/
            │   ├── util_closer_SettingsService.cls
            │   ├── util_closer_SettingsService.cls-meta.xml
            │   ├── util_closer_Logger.cls
            │   ├── util_closer_Logger.cls-meta.xml
            │   ├── util_closer_BatchMetrics.cls
            │   ├── util_closer_BatchMetrics.cls-meta.xml
            │   ├── util_closer_RuleEngine.cls
            │   ├── util_closer_RuleEngine.cls-meta.xml
            │   ├── util_closer_NotificationService.cls
            │   ├── util_closer_NotificationService.cls-meta.xml
            │   ├── util_closer_CaseStatusBatch.cls
            │   ├── util_closer_CaseStatusBatch.cls-meta.xml
            │   ├── util_closer_CaseStatusScheduler.cls
            │   ├── util_closer_CaseStatusScheduler.cls-meta.xml
            │   ├── util_closer_SchedulerController.cls
            │   ├── util_closer_SchedulerController.cls-meta.xml
            │   ├── util_closer_TestDataFactory.cls
            │   ├── util_closer_TestDataFactory.cls-meta.xml
            │   ├── util_closer_SettingsService_Test.cls
            │   ├── util_closer_SettingsService_Test.cls-meta.xml
            │   ├── util_closer_RuleEngine_Test.cls
            │   ├── util_closer_RuleEngine_Test.cls-meta.xml
            │   ├── util_closer_CaseStatusBatch_Test.cls
            │   ├── util_closer_CaseStatusBatch_Test.cls-meta.xml
            │   ├── util_closer_CaseStatusScheduler_Test.cls
            │   ├── util_closer_CaseStatusScheduler_Test.cls-meta.xml
            │   ├── util_closer_NotificationService_Test.cls
            │   ├── util_closer_NotificationService_Test.cls-meta.xml
            │   ├── util_closer_SchedulerController_Test.cls
            │   ├── util_closer_SchedulerController_Test.cls-meta.xml
            │   ├── util_closer_PermissionSet_Test.cls
            │   └── util_closer_PermissionSet_Test.cls-meta.xml
            ├── customMetadata/
            │   ├── util_closer_Case_Status_Rule.Close_Stale_Waiting_Cases.md-meta.xml
            │   └── util_closer_Case_Status_Rule.Escalate_Old_New_Cases.md-meta.xml
            ├── objects/
            │   ├── util_closer_Settings__c/
            │   │   ├── util_closer_Settings__c.object-meta.xml
            │   │   └── fields/
            │   │       ├── Batch_Size__c.field-meta.xml
            │   │       ├── Error_Notification_Emails__c.field-meta.xml
            │   │       ├── Completion_Notification_Emails__c.field-meta.xml
            │   │       ├── Debug_Mode__c.field-meta.xml
            │   │       ├── Is_Active__c.field-meta.xml
            │   │       ├── Cron_Expression__c.field-meta.xml
            │   │       └── Scheduled_Job_Name__c.field-meta.xml
            │   └── util_closer_Case_Status_Rule__mdt/
            │       ├── util_closer_Case_Status_Rule__mdt.object-meta.xml
            │       └── fields/
            │           ├── Is_Active__c.field-meta.xml
            │           ├── Execution_Order__c.field-meta.xml
            │           ├── Source_Status__c.field-meta.xml
            │           ├── Target_Status__c.field-meta.xml
            │           ├── Days_Since_Last_Modified__c.field-meta.xml
            │           ├── Days_Since_Created__c.field-meta.xml
            │           ├── Days_Since_Last_Activity__c.field-meta.xml
            │           ├── Record_Type_Developer_Names__c.field-meta.xml
            │           ├── Exclude_Record_Type_Developer_Names__c.field-meta.xml
            │           ├── Additional_Filter_Logic__c.field-meta.xml
            │           ├── Description__c.field-meta.xml
            │           └── Stop_Processing__c.field-meta.xml
            ├── permissionsets/
            │   ├── util_closer_Administrator.permissionset-meta.xml
            │   └── util_closer_Operator.permissionset-meta.xml
            └── lwc/
                └── util_closer_schedulerManager/
                    ├── util_closer_schedulerManager.html
                    ├── util_closer_schedulerManager.js
                    ├── util_closer_schedulerManager.js-meta.xml
                    └── util_closer_schedulerManager.css
```

---

## Agent Implementation Instructions

### Pre-Implementation Setup

1. Verify DevHub `tnoxprod` is authenticated and active
2. Check for existing project structure; initialize if needed
3. Create or verify scratch org definition file exists
4. Create scratch org from DevHub
5. Set up initial Git repository if not exists
6. Create `.gitignore` appropriate for SFDX projects

### Phase 1: Project Setup & Metadata Objects

**Branch:** `feature/util_closer_metadata-foundation`

1. Initialize SFDX project structure if not exists
2. Create scratch org definition file
3. Create scratch org from DevHub `tnoxprod`
4. Create Custom Setting object and fields
5. Create Custom Metadata Type and fields
6. Create sample Custom Metadata records
7. Push to scratch org and verify in Setup
8. Commit all metadata files
9. Merge to main

### Phase 2: Permission Sets

**Branch:** `feature/util_closer_permission-sets`

1. Create feature branch from updated main
2. Create Administrator permission set
3. Create Operator permission set
4. Push to scratch org
5. Verify permission sets in Setup
6. Commit permission set files
7. Merge to main

### Phase 3: Core Services - Logger and Settings

**Branch:** `feature/util_closer_core-services`

1. Create feature branch from updated main
2. Build `util_closer_Logger` class
3. Push and verify compilation
4. Commit
5. Build `util_closer_SettingsService` class
6. Push and verify compilation
7. Commit
8. Build `util_closer_BatchMetrics` class
9. Push and verify compilation
10. Commit
11. Merge to main

### Phase 4: Rule Engine and Notifications

**Branch:** `feature/util_closer_rule-engine`

1. Create feature branch from updated main
2. Build `util_closer_RuleEngine` class
3. Push, verify, commit
4. Build `util_closer_NotificationService` class
5. Push, verify, commit
6. Merge to main

### Phase 5: Batch Infrastructure

**Branch:** `feature/util_closer_batch-system`

1. Create feature branch from updated main
2. Build `util_closer_CaseStatusBatch` class
3. Push, verify, commit
4. Build `util_closer_CaseStatusScheduler` class
5. Push, verify, commit
6. Merge to main

### Phase 6: Update Permission Sets with Apex Access

**Branch:** `feature/util_closer_permission-set-apex`

1. Create feature branch from updated main
2. Update Administrator permission set with Apex class access
3. Update Operator permission set with Apex class access
4. Push and verify
5. Commit
6. Merge to main

### Phase 7: Test Data Factory

**Branch:** `feature/util_closer_test-factory`

1. Create feature branch from updated main
2. Build `util_closer_TestDataFactory` class
3. Push and verify compilation (no tests yet, just the factory)
4. Commit
5. Merge to main

### Phase 8: Unit Tests - Core Services

**Branch:** `feature/util_closer_tests-core`

1. Create feature branch from updated main
2. Build `util_closer_SettingsService_Test`
3. Run test, verify pass, check coverage
4. Commit
5. Build `util_closer_RuleEngine_Test`
6. Run test, verify pass, check coverage
7. Commit
8. Build `util_closer_NotificationService_Test`
9. Run test, verify pass, check coverage
10. Commit
11. Run all tests, verify 90%+ coverage on tested classes
12. Merge to main

### Phase 9: Unit Tests - Batch and Scheduler

**Branch:** `feature/util_closer_tests-batch`

1. Create feature branch from updated main
2. Build `util_closer_CaseStatusBatch_Test`
3. Run test, verify pass, check coverage
4. Commit
5. Build `util_closer_CaseStatusScheduler_Test`
6. Run test, verify pass, check coverage
7. Commit
8. Build `util_closer_PermissionSet_Test`
9. Run test, verify pass
10. Commit
11. Run full test suite, verify all pass with 90%+ coverage
12. Merge to main

### Phase 10: UI Components

**Branch:** `feature/util_closer_ui-components`

1. Create feature branch from updated main
2. Build `util_closer_SchedulerController` class
3. Push, verify, commit
4. Build `util_closer_SchedulerController_Test`
5. Run test, verify pass
6. Commit
7. Build `util_closer_schedulerManager` LWC (html, js, css, meta)
8. Push, verify in org
9. Commit
10. Run full test suite
11. Merge to main

### Phase 11: Final Validation

**Branch:** `feature/util_closer_final-validation`

1. Create feature branch from main
2. Run complete test suite with coverage
3. Fix any issues discovered, commit fixes
4. Perform manual testing in scratch org
5. Document any findings or adjustments
6. Commit any final refinements
7. Verify all success criteria met
8. Merge to main
9. Tag the release (e.g., `v1.0.0`)

---

## Permission Set Assignment Guide

### For Administrators (Full Control)

Assign `util_closer_Administrator` to users who need to:

- Configure batch size, email lists, and other settings
- Schedule, reschedule, or unschedule the automated job
- Manually trigger batch execution
- Enable/disable the system
- Toggle debug mode

### For Operations Staff (Execute Only)

Assign `util_closer_Operator` to users who need to:

- View current configuration and job status
- Manually trigger batch execution when needed
- Monitor job results
- Cannot modify any settings or scheduling

---

## Success Criteria Checklist

- [ ] All Apex classes compile without errors
- [ ] All test classes pass
- [ ] Code coverage > 90% for each class
- [ ] Batch processes Cases correctly based on metadata rules
- [ ] Error emails sent when failures occur
- [ ] Completion emails sent with accurate metrics
- [ ] Debug mode produces verbose logs
- [ ] Scheduler can be scheduled/unscheduled via LWC
- [ ] Custom Settings control all configurable behavior
- [ ] System handles 10,000+ records across multiple batches
- [ ] No hardcoded values (all configurable via settings/metadata)
- [ ] Administrator permission set grants full access
- [ ] Operator permission set grants execute-only access
- [ ] Users without permission sets cannot access the system
- [ ] Permission-based tests all pass
- [ ] All features merged to main branch
- [ ] Release tagged in Git

---

## Error Recovery Instructions

### Salesforce CLI Errors

**If DevHub authentication fails:**

- Re-authenticate using web login flow with alias `tnoxprod`
- Verify DevHub is enabled in the target org
- Check that user has appropriate DevHub permissions

**If scratch org creation fails:**

- Check DevHub scratch org limits
- Review scratch org definition file for errors
- Delete unused scratch orgs to free up capacity
- Verify edition and features requested are valid

**If source push fails:**

- Review error messages for specific component failures
- Check for metadata API version mismatches
- Verify dependencies are deployed in correct order
- Pull from org to check for conflicts

### Test Failures

**If tests fail due to Custom Metadata not being visible:**

- Ensure metadata records are deployed before running tests
- Custom Metadata IS visible in tests without `SeeAllData=true`

**If batch fails with governor limits:**

- Reduce `Batch_Size__c` in Custom Settings
- Review any triggers/flows on Case for optimization

**If emails not sending in tests:**

- Verify test context allows email - use `System.assertEquals` on Limits
- Check `Messaging.reserveSingleEmailCapacity()` in test setup

**If permission set tests fail:**

- Ensure permission sets are deployed before running tests
- Verify test users are created with correct profile ('Standard User')
- Check that permission set assignments complete before `System.runAs()` block

**If "Apex class not found" errors in permission set:**

- Deploy Apex classes before updating permission set with class access
- Use separate deployment steps: classes first, then permission set updates

### Git Recovery

**If merge conflicts occur:**

- Do not force push or override without careful review
- Resolve conflicts file by file
- Test thoroughly after conflict resolution
- Verify org state matches expected after push

**If commits were made to wrong branch:**

- Use cherry-pick to move commits to correct branch
- Reset incorrect branch to proper state
- Never force push to main branch

**If work is lost:**

- Check Git reflog for recent commits
- Review remote branches for pushed work
- Check scratch org for any unsaved changes (pull before scratch org deletion)
