# Closinator - Case Status Auto-Closer

A configurable, metadata-driven Salesforce batch system that automatically updates Case statuses based on dynamic rules. The system is designed to be portable across any Salesforce org using standard Case Management.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Security](#security)
- [Configuration](#configuration)
- [Usage](#usage)
- [Manual Test Runner](#manual-test-runner)
- [Architecture](#architecture)
- [Development](#development)

## Features

### Core Capabilities

- **Metadata-Driven Rules**: Configure Case status update rules using Custom Metadata Types (CMT) - no code changes required
- **Flexible Rule Criteria**: Support for multiple criteria including:
  - Days since last modified
  - Days since created
  - Days since last activity
  - Record type filtering (include/exclude)
  - Custom filter logic
- **Batch Processing**: Efficient batch processing with configurable batch sizes
- **Scheduled Execution**: Built-in scheduler with configurable cron expressions
- **Rule Execution Order**: Control rule execution order via metadata
- **Stop Processing Flag**: Rules can stop further processing after execution
- **Comprehensive Logging**: Debug mode for detailed execution logs
- **Email Notifications**: Configurable email notifications for errors and completion
- **Metrics Tracking**: Built-in batch metrics tracking
- **Lightning Web Component**: UI for managing scheduler and settings
- **Dedicated Lightning Tab**: Easy access via "Case Auto-Closer" tab in Lightning navigation
- **Lightning App Page**: Pre-configured page with scheduler manager component
- **Without Sharing Query Layer**: Query all Case records regardless of sharing rules for maximum batch coverage

### Key Components

- **Batch Processor** (`util_closer_CaseStatusBatch`): Processes Cases and applies rules
- **Rule Engine** (`util_closer_RuleEngine`): Evaluates Custom Metadata rules and builds queries
- **Scheduler** (`util_closer_CaseStatusScheduler`): Manages scheduled job execution
- **Settings Service** (`util_closer_SettingsService`): Centralized configuration access
- **Logger** (`util_closer_Logger`): Debug logging utility
- **Notification Service** (`util_closer_NotificationService`): Email notification handling
- **Scheduler Manager LWC**: Lightning Web Component for managing the scheduler
- **Lightning Tab** (`util_closer_Scheduler_Manager`): Dedicated tab for accessing the scheduler manager
- **Lightning App Page** (`util_closer_Scheduler_Manager`): Pre-configured page containing the scheduler manager component
- **Case Data Access** (`util_closer_CaseDataAccess`): Without sharing data access layer for querying all Cases

## Installation

### Prerequisites

- Salesforce CLI (`sf`) version 2.x or higher
- Access to a Salesforce org (Production, Sandbox, or Scratch Org)
- Appropriate permissions to deploy Apex classes, Custom Metadata Types, Custom Settings, and Lightning Web Components

### Verify Salesforce CLI Installation

```bash
sf version
```

Expected output: Version 2.x or higher

### Deploy to Salesforce Org

1. **Authenticate to your Salesforce org:**

```bash
sf org login web --alias myorg --set-default
```

2. **Deploy the source code:**

```bash
sf project deploy start --target-org myorg
```

3. **Verify deployment:**

```bash
sf data query --query "SELECT Name FROM ApexClass WHERE Name LIKE 'util_closer_%'" --target-org myorg
```

Expected: All `util_closer_*` classes should be listed.

### Post-Deployment Setup

1. **Assign Permission Sets** (required):

   See the [Security](#security) section for detailed information on permission sets.
   
   - `util_closer_Administrator`: Full access to manage the system (assign to admins)
   - `util_closer_Operator`: Basic access to run batch jobs (assign to operators)
   
   **Important:** Users must have appropriate Case object permissions (Read and Edit) to run batch jobs successfully.

2. **Configure Custom Settings:**

   Use the provided script or configure via the Lightning Web Component:

```bash
sf apex run --file scripts/apex/create-settings.apex --target-org myorg
```

3. **Create Custom Metadata Rules:**

   Deploy the Custom Metadata Type records from `force-app/main/default/customMetadata/` or create your own rules via Setup → Custom Metadata Types.

4. **Access the Lightning Tab:**

   After deployment, users with the `util_closer_Administrator` permission set will see the "Case Auto-Closer" tab in their Lightning navigation. The tab provides direct access to the scheduler manager interface.

## Security

The Case Status Auto-Closer system uses Salesforce's security model to control access. Most Apex classes are declared with `with sharing` to respect the user's object and field-level security permissions. However, the system includes a `without sharing` data access layer (`util_closer_CaseDataAccess`) that allows querying all Case records regardless of sharing rules, ensuring maximum batch coverage while still respecting field-level security for updates.

### Permission Sets

Two permission sets are provided to grant appropriate access levels:

#### Administrator Permission Set (`util_closer_Administrator`)

**Purpose:** Full access to configure and manage the Case Status Auto-Closer system including settings, scheduling, and manual batch execution.

**Access Granted:**

- **Apex Class Access:** All `util_closer_*` classes enabled
  - `util_closer_CaseStatusBatch`
  - `util_closer_CaseStatusScheduler`
  - `util_closer_CaseDataAccess`
  - `util_closer_SchedulerController`
  - `util_closer_SettingsService`
  - `util_closer_RuleEngine`
  - `util_closer_NotificationService`
  - `util_closer_Logger`
  - `util_closer_BatchMetrics`

- **Custom Settings Access:** Full CRUD access to `util_closer_Settings__c`
  - Read, Create, Edit, Delete

- **Field-Level Security:** All fields editable
  - `Batch_Size__c` - Read/Edit
  - `Completion_Notification_Emails__c` - Read/Edit
  - `Cron_Expression__c` - Read/Edit
  - `Debug_Mode__c` - Read/Edit
  - `Error_Notification_Emails__c` - Read/Edit
  - `Is_Active__c` - Read/Edit
  - `Scheduled_Job_Name__c` - Read/Edit

- **System Permissions:**
  - `API Enabled` - Required for Apex execution
  - `Run Flows` - Required for scheduled job execution

- **Tab Visibility:**
  - `util_closer_Scheduler_Manager` tab - Visible (provides access to the scheduler manager interface)

**When to Use:** Assign to system administrators, Salesforce admins, or users who need to configure and manage the system.

#### Operator Permission Set (`util_closer_Operator`)

**Purpose:** Ability to view settings and manually execute the Case Status Auto-Closer batch job. Cannot modify configuration.

**Access Granted:**

- **Apex Class Access:** All `util_closer_*` classes enabled (same as Administrator)
  - `util_closer_CaseStatusBatch`
  - `util_closer_CaseStatusScheduler`
  - `util_closer_CaseDataAccess`
  - `util_closer_SchedulerController`
  - `util_closer_SettingsService`
  - `util_closer_RuleEngine`
  - `util_closer_NotificationService`
  - `util_closer_Logger`
  - `util_closer_BatchMetrics`

- **Custom Settings Access:** Read-only access to `util_closer_Settings__c`
  - Read only (no Create, Edit, or Delete)

- **Field-Level Security:** All fields read-only
  - `Batch_Size__c` - Read only
  - `Completion_Notification_Emails__c` - Read only
  - `Cron_Expression__c` - Read only
  - `Debug_Mode__c` - Read only
  - `Error_Notification_Emails__c` - Read only
  - `Is_Active__c` - Read only
  - `Scheduled_Job_Name__c` - Read only

- **System Permissions:**
  - `API Enabled` - Required for Apex execution

**When to Use:** Assign to users who need to run batch jobs manually or view system status, but should not modify configuration.

### Assigning Permission Sets

#### Via Salesforce UI

1. Navigate to **Setup** → **Users** → **Permission Sets**
2. Find the permission set (`Case Auto-Closer Administrator` or `Case Auto-Closer Operator`)
3. Click **Manage Assignments**
4. Click **Add Assignments**
5. Select users and click **Assign**

#### Via Salesforce CLI

```bash
# Assign Administrator permission set to a user
sf data create record \
  --sobject PermissionSetAssignment \
  --values "AssigneeId=USER_ID PermissionSetId=PERMISSION_SET_ID" \
  --target-org myorg

# Query permission set IDs first
sf data query \
  --query "SELECT Id, Name FROM PermissionSet WHERE Name IN ('util_closer_Administrator', 'util_closer_Operator')" \
  --target-org myorg
```

### Case Object Permissions

**Important:** Users must have appropriate Case object permissions to run the batch job successfully. The batch job reads and updates Case records, so users need:

- **Read Access** to Case object and fields:
  - `Id`
  - `Status`
  - `LastModifiedDate`
  - `CreatedDate`
  - Any fields referenced in rule criteria (e.g., Record Type, Last Activity Date)

- **Edit Access** to Case object and `Status` field:
  - Required to update Case statuses based on rules

#### Without Sharing Query Layer

The system includes a **without sharing** data access layer (`util_closer_CaseDataAccess`) that allows the batch job to query **all Case records** matching the rule criteria, regardless of sharing rules. This ensures maximum coverage for batch processing.

**How it works:**
- **Query Phase**: Uses `util_closer_CaseDataAccess` (without sharing) to query all Cases matching rule criteria, bypassing sharing restrictions
- **Update Phase**: Uses `util_closer_CaseStatusBatch` (with sharing) to respect field-level security when updating records

**Benefits:**
- Processes all Cases matching criteria, not just those visible to the running user
- Ensures consistent batch execution regardless of who schedules the job
- Maximizes the number of Cases that can be processed

**Security Considerations:**
- Updates still respect field-level security (FLS) - users without edit access to Cases will see update failures
- Sharing rules are bypassed only for querying, not for updating
- The running user must still have appropriate object permissions for updates to succeed
- All batch executions are logged and auditable

**Note:** If a user doesn't have edit access to Cases, the batch job will still query all matching Cases but will fail to update those records. Check batch execution logs for specific failure reasons.

### Custom Metadata Type Access

Custom Metadata Types are readable by all users by default. However, to create or modify Custom Metadata records (`util_closer_Case_Status_Rule__mdt`), users need:

- **Customize Application** permission (typically System Administrator profile)
- Or a custom permission set with Custom Metadata Type access

**Recommendation:** Only System Administrators should create or modify Custom Metadata rules.

### Security Best Practices

1. **Principle of Least Privilege:**
   - Assign `util_closer_Operator` to most users who only need to run jobs
   - Reserve `util_closer_Administrator` for users who need to configure the system

2. **Case Object Security:**
   - Ensure users have appropriate Case object permissions based on your organization's security model
   - Consider using sharing rules if Cases need to be restricted by ownership or criteria

3. **Audit Trail:**
   - The system logs all batch executions (if Debug Mode is enabled)
   - Review batch job execution logs regularly via Setup → Apex Jobs

4. **Email Notifications:**
   - Configure error and completion notification emails in Custom Settings
   - Only administrators should be able to modify notification settings

5. **Scheduled Job Security:**
   - Scheduled jobs run in the context of the user who scheduled them
   - Ensure the scheduling user has appropriate permissions
   - Consider using a dedicated integration user for scheduled jobs

### Troubleshooting Permission Issues

**Issue:** User cannot run batch job
- **Solution:** Verify user has the appropriate permission set assigned and Case object edit permissions

**Issue:** Batch job fails with "insufficient access rights" errors
- **Solution:** Check Case object and field-level security for the running user

**Issue:** User cannot view or edit Custom Settings
- **Solution:** Verify permission set assignment and field-level security permissions

**Issue:** Scheduled job fails to execute
- **Solution:** Verify the user who scheduled the job still has active permission set and Case object access

**Issue:** User cannot see the "Case Auto-Closer" tab
- **Solution:** Verify the user has the `util_closer_Administrator` permission set assigned, which includes tab visibility for `util_closer_Scheduler_Manager`

## Configuration

### Custom Settings (`util_closer_Settings__c`)

Configure system-wide settings via Custom Settings:

| Field | Description | Default |
|-------|-------------|---------|
| `Is_Active__c` | Enable/disable the entire system | `true` |
| `Batch_Size__c` | Number of records processed per batch | `200` |
| `Debug_Mode__c` | Enable detailed debug logging | `false` |
| `Cron_Expression__c` | Cron expression for scheduled execution | `0 0 2 * * ?` (Daily 2 AM) |
| `Scheduled_Job_Name__c` | Name of the scheduled job | `util_closer_CaseStatusJob` |
| `Error_Notification_Emails__c` | Comma-separated emails for error notifications | (empty) |
| `Completion_Notification_Emails__c` | Comma-separated emails for completion notifications | (empty) |

### Custom Metadata Rules (`util_closer_Case_Status_Rule__mdt`)

Create rules to define when and how Cases should be updated:

| Field | Description | Required |
|-------|-------------|----------|
| `DeveloperName` | Unique identifier for the rule | Yes |
| `MasterLabel` | Display name | Yes |
| `Is_Active__c` | Enable/disable this rule | Yes |
| `Execution_Order__c` | Order in which rules are evaluated | Yes |
| `Source_Status__c` | Semicolon-separated list of source statuses | Yes |
| `Target_Status__c` | Target status to set | Yes |
| `Days_Since_Last_Modified__c` | Minimum days since last modified | No |
| `Days_Since_Created__c` | Minimum days since created | No |
| `Days_Since_Last_Activity__c` | Minimum days since last activity | No |
| `Record_Type_Developer_Names__c` | Semicolon-separated record types to include | No |
| `Exclude_Record_Type_Developer_Names__c` | Semicolon-separated record types to exclude | No |
| `Additional_Filter_Logic__c` | Additional SOQL WHERE clause logic | No |
| `Stop_Processing__c` | Stop processing after this rule executes | No |
| `Description__c` | Rule description | No |

### Example Rule Configuration

**Close Stale Waiting Cases:**
- Source Status: `Waiting on Customer;Pending Response`
- Target Status: `Closed`
- Days Since Last Modified: `30`
- Execution Order: `1`

**Escalate Old New Cases:**
- Source Status: `New`
- Target Status: `Escalated`
- Days Since Created: `7`
- Execution Order: `2`

## Usage

### Running Batch Job Manually

Execute the batch job immediately:

```bash
sf apex run --file scripts/apex/run-batch.apex --target-org myorg
```

Or via Anonymous Apex:

```apex
Id batchJobId = Database.executeBatch(new util_closer_CaseStatusBatch(), 200);
System.debug('Batch Job ID: ' + batchJobId);
```

### Scheduling the Job

Schedule the job using Custom Settings configuration:

```bash
sf apex run --file scripts/apex/schedule-job.apex --target-org myorg
```

Or via Anonymous Apex:

```apex
String jobId = util_closer_CaseStatusScheduler.scheduleJob();
System.debug('Scheduled Job ID: ' + jobId);
```

### Using the Lightning Web Component

#### Option 1: Dedicated Tab (Recommended)

The easiest way to access the scheduler manager is through the dedicated "Case Auto-Closer" tab:

1. **Access the Tab:**
   - Users with the `util_closer_Administrator` permission set will see the "Case Auto-Closer" tab in their Lightning navigation
   - Click the tab to open the scheduler manager interface

2. **Use the Interface:**
   - View current job status and next execution time
   - Schedule or unschedule jobs
   - Update system settings (batch size, debug mode, cron expression, etc.)
   - Run batch jobs immediately
   - Configure email notifications

#### Option 2: Add to Custom Lightning Page

You can also add the component to any Lightning page:

1. Navigate to **Setup** → **Lightning App Builder**
2. Create or edit a Lightning page
3. Add the `util_closer_schedulerManager` component
4. Use the UI to manage scheduler and settings

### Monitoring Batch Execution

Check batch job status:

```bash
sf data query --query "SELECT Id, Status, JobType, NumberOfErrors, TotalJobItems FROM AsyncApexJob WHERE ApexClass.Name = 'util_closer_CaseStatusBatch' ORDER BY CreatedDate DESC LIMIT 5" --target-org myorg
```

View debug logs (if Debug Mode is enabled):

```bash
sf apex get log --target-org myorg
```

## Manual Test Runner

The project includes a comprehensive test plan document (`docs/development/test-plan.md`) that provides step-by-step instructions for manually testing the system using Salesforce CLI commands.

### Using Cursor + Composer 1 for Manual Testing

You can use Cursor IDE with Composer 1 (AI assistant) to execute the test plan interactively:

1. **Open the test plan:**
   - Open `docs/development/test-plan.md` in Cursor
   - The test plan contains all necessary SF CLI commands

2. **Execute commands with Composer 1:**
   - Copy commands from the test plan
   - Ask Composer 1 to execute them, for example:
     - "Run the command to create a scratch org"
     - "Execute the batch job using the script"
     - "Check the batch job status"

3. **Follow the test plan sections:**
   - **Environment Setup**: Create scratch org and deploy code
   - **Configure Custom Settings**: Set up system configuration
   - **Create Test Case Data**: Generate test Cases
   - **Backdate Test Records**: Adjust dates for testing
   - **Run Batch Job**: Execute and verify results
   - **Schedule Job**: Test scheduled execution
   - **Test Scenarios**: Validate different rule configurations

### Example Workflow

```bash
# 1. Create scratch org (Composer can execute this)
sf org create scratch --definition-file config/project-scratch-def.json --alias util_closer_dev_test --duration-days 7 --set-default --target-dev-hub tnoxprod

# 2. Deploy source (Composer can execute this)
sf project deploy start --target-org util_closer_dev_test

# 3. Create settings (Composer can execute this)
sf apex run --file scripts/apex/create-settings.apex --target-org util_closer_dev_test

# 4. Run batch (Composer can execute this)
sf apex run --file scripts/apex/run-batch.apex --target-org util_closer_dev_test
```

**Benefits of using Cursor + Composer 1:**
- Interactive command execution
- Context-aware assistance
- Error handling and troubleshooting
- Step-by-step guidance through the test plan
- Ability to modify commands on the fly

## Architecture

### System Overview

The Case Status Auto-Closer is built on a metadata-driven architecture that separates configuration from code:

```
┌─────────────────────────────────────────────────────────────┐
│                    Lightning Web Component                    │
│              (util_closer_schedulerManager)                   │
└───────────────────────┬───────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                  Scheduler Controller                         │
│            (util_closer_SchedulerController)                 │
└───────────────────────┬───────────────────────────────────────┘
                        │
        ┌───────────────┴───────────────┐
        │                               │
        ▼                               ▼
┌──────────────────┐          ┌──────────────────┐
│   Scheduler      │          │  Settings Service│
│ (util_closer_    │          │ (util_closer_     │
│  CaseStatus      │          │  SettingsService) │
│  Scheduler)      │          └──────────────────┘
└────────┬─────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│                    Batch Processor                           │
│            (util_closer_CaseStatusBatch)                     │
└───────────────────────┬───────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                    Rule Engine                               │
│            (util_closer_RuleEngine)                          │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │         Custom Metadata Rules                      │    │
│  │    (util_closer_Case_Status_Rule__mdt)            │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Key Design Principles

1. **Metadata-Driven**: All business rules are stored in Custom Metadata Types
2. **Separation of Concerns**: Clear separation between batch processing, rule evaluation, and configuration
3. **Extensibility**: Easy to add new rules without code changes
4. **Testability**: Comprehensive test coverage with test data factory
5. **Observability**: Built-in logging and metrics tracking

### Data Flow

1. **Scheduler** triggers the batch job based on cron expression
2. **Batch Processor** queries Cases matching rule criteria
3. **Rule Engine** evaluates each Case against active rules in execution order
4. **Batch Processor** updates Case statuses based on matching rules
5. **Notification Service** sends emails if configured
6. **Logger** records execution details (if debug mode enabled)

## Development

### Project Structure

```
closinator/
├── config/
│   └── project-scratch-def.json      # Scratch org definition
├── docs/
│   └── development/
│       ├── build.md                   # Build documentation
│       └── test-plan.md               # Manual test plan
├── force-app/
│   └── main/
│       └── default/
│           ├── classes/               # Apex classes
│           ├── customMetadata/        # Custom Metadata records
│           ├── flexipages/            # Lightning App Pages
│           ├── lwc/                   # Lightning Web Components
│           ├── objects/               # Custom objects/fields
│           ├── permissionsets/        # Permission sets
│           └── tabs/                  # Lightning Tabs
├── scripts/
│   └── apex/                          # Utility Apex scripts
└── manifest/
    └── package.xml                    # Package manifest
```

### Running Tests

Execute Apex unit tests:

```bash
sf apex run test --class-names util_closer_CaseStatusBatch_Test --target-org myorg
```

Run all tests:

```bash
sf apex run test --code-coverage --result-format human --target-org myorg
```

### Code Quality

The project includes:

- **ESLint**: For Lightning Web Component code
- **Prettier**: For code formatting
- **Husky**: Git hooks for pre-commit checks
- **Lint-staged**: Run linters on staged files

Run linting:

```bash
npm run lint
```

Format code:

```bash
npm run prettier
```

### Contributing

1. Create a feature branch
2. Make your changes
3. Run tests and linting
4. Submit a pull request

## License

MIT

## Support

For issues, questions, or contributions, please contact the development team or create an issue in the repository.
