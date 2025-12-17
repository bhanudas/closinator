# Closinator - Case Status Auto-Closer

A configurable, metadata-driven Salesforce batch system that automatically updates Case statuses based on dynamic rules. The system is designed to be portable across any Salesforce org using standard Case Management.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
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

### Key Components

- **Batch Processor** (`util_closer_CaseStatusBatch`): Processes Cases and applies rules
- **Rule Engine** (`util_closer_RuleEngine`): Evaluates Custom Metadata rules and builds queries
- **Scheduler** (`util_closer_CaseStatusScheduler`): Manages scheduled job execution
- **Settings Service** (`util_closer_SettingsService`): Centralized configuration access
- **Logger** (`util_closer_Logger`): Debug logging utility
- **Notification Service** (`util_closer_NotificationService`): Email notification handling
- **Scheduler Manager LWC**: Lightning Web Component for managing the scheduler

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

1. **Assign Permission Sets** (optional but recommended):

   - `util_closer_Administrator`: Full access to manage the system
   - `util_closer_Operator`: Basic access to run batch jobs

2. **Configure Custom Settings:**

   Use the provided script or configure via the Lightning Web Component:

```bash
sf apex run --file scripts/apex/create-settings.apex --target-org myorg
```

3. **Create Custom Metadata Rules:**

   Deploy the Custom Metadata Type records from `force-app/main/default/customMetadata/` or create your own rules via Setup → Custom Metadata Types.

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

1. Navigate to any Lightning page
2. Add the `util_closer_schedulerManager` component
3. Use the UI to:
   - View current job status
   - Schedule/unschedule jobs
   - Update settings
   - Run batch jobs immediately
   - View next execution time

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
│           ├── lwc/                   # Lightning Web Components
│           ├── objects/               # Custom objects/fields
│           └── permissionsets/        # Permission sets
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

This project is proprietary and confidential.

## Support

For issues, questions, or contributions, please contact the development team or create an issue in the repository.
