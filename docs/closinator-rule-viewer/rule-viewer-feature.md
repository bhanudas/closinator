# Read-Only Rules Display on Closinator Dashboard

**Branch:** `closinator-rule-viewer`
**Date:** March 30, 2026

Users need to see which rules and criteria are active on the Closinator dashboard without navigating to Setup or Custom Metadata. This feature adds a new read-only LWC component that displays all active `util_closer_Case_Status_Rule__mdt` records in a collapsible, accordion-based layout between the Scheduler Manager and Log Viewer.

---

## Architecture

The Closinator dashboard is a flexipage that composes independent LWC components. Each component has its own Apex controller following a one-to-one pattern:

| Component | Controller | Responsibility |
| --- | --- | --- |
| `util_closer_schedulerManager` | `util_closer_SchedulerController` | Job scheduling, cron, settings |
| **`util_closer_RuleViewer` (NEW)** | **`util_closer_RuleViewerController` (NEW)** | **Read-only rule display** |
| `util_closer_LogViewer` | `util_closer_LogViewerController` | Batch/case log browsing |

The new controller wraps the existing `util_closer_RuleEngine.getActiveRules()` method, which already queries all active rules ordered by `Execution_Order__c`. No new SOQL or data access layer is needed.

---

## Files Created

### Apex

- [`util_closer_RuleViewerController.cls`](../../force-app/main/default/classes/util_closer_RuleViewerController.cls) -- single `@AuraEnabled(cacheable=true)` method returning `List<Map<String, Object>>`
- [`util_closer_RuleViewerController.cls-meta.xml`](../../force-app/main/default/classes/util_closer_RuleViewerController.cls-meta.xml)
- [`util_closer_RuleViewerController_Test.cls`](../../force-app/main/default/classes/util_closer_RuleViewerController_Test.cls) -- 5 test methods, 100% line coverage
- [`util_closer_RuleViewerController_Test.cls-meta.xml`](../../force-app/main/default/classes/util_closer_RuleViewerController_Test.cls-meta.xml)

### LWC

- [`util_closer_RuleViewer.html`](../../force-app/main/default/lwc/util_closer_RuleViewer/util_closer_RuleViewer.html)
- [`util_closer_RuleViewer.js`](../../force-app/main/default/lwc/util_closer_RuleViewer/util_closer_RuleViewer.js)
- [`util_closer_RuleViewer.css`](../../force-app/main/default/lwc/util_closer_RuleViewer/util_closer_RuleViewer.css)
- [`util_closer_RuleViewer.js-meta.xml`](../../force-app/main/default/lwc/util_closer_RuleViewer/util_closer_RuleViewer.js-meta.xml)

## Files Modified

- [`util_closer_Dashboard.flexipage-meta.xml`](../../force-app/main/default/flexipages/util_closer_Dashboard.flexipage-meta.xml) -- insert `util_closer_RuleViewer` between the scheduler and log viewer

---

## Apex Controller Design

`util_closer_RuleViewerController.getActiveRules()` calls `util_closer_RuleEngine.getActiveRules()` and maps each `util_closer_Case_Status_Rule__mdt` record into a flat `Map<String, Object>` with camelCase keys. This avoids serialization issues with null custom metadata fields and gives the LWC clean, predictable JSON.

### Field Mapping

| MDT Field | Map Key | Criteria Group |
| --- | --- | --- |
| `DeveloperName` | `developerName` | Core |
| `MasterLabel` | `label` | Core |
| `Execution_Order__c` | `executionOrder` | Core |
| `Source_Status__c` | `sourceStatus` | Core |
| `Target_Status__c` | `targetStatus` | Core |
| `Target_Reason__c` | `targetReason` | Core |
| `Description__c` | `description` | Core |
| `Stop_Processing__c` | `stopProcessing` | Core |
| `Days_Since_Last_Modified__c` | `daysSinceLastModified` | Timing |
| `Days_Since_Created__c` | `daysSinceCreated` | Timing |
| `Days_Since_Last_Activity__c` | `daysSinceLastActivity` | Timing |
| `Record_Type_Developer_Names__c` | `recordTypeDeveloperNames` | Filtering |
| `Exclude_Record_Type_Developer_Names__c` | `excludeRecordTypeDeveloperNames` | Filtering |
| `Origins__c` | `origins` | Filtering |
| `Owner_Name_Like__c` | `ownerNameLike` | Filtering |
| `Last_Modified_By_Name_Like__c` | `lastModifiedByNameLike` | Filtering |
| `Additional_Filter_Logic__c` | `additionalFilterLogic` | Filtering |
| `Child_Object_API_Name__c` | `childObjectApiName` | Child Object |
| `Child_Lookup_Field__c` | `childLookupField` | Child Object |
| `Child_Filter_Field__c` | `childFilterField` | Child Object |
| `Child_Filter_Value__c` | `childFilterValue` | Child Object |
| `Child_Filter_Operator__c` | `childFilterOperator` | Child Object |
| `Require_Child_Record__c` | `requireChildRecord` | Child Object |

### Error Handling

Follows the same pattern as `util_closer_SchedulerController`: catch blocks wrap exceptions in `AuraHandledException` with `setMessage()` so the LWC receives a readable error string. A `@TestVisible` static boolean `throwExceptionOnGetRules` enables deterministic exception testing.

---

## LWC UI Design

### Collapsed State (Default)

The component renders a `lightning-card` with a compact header showing the title, a count badge (e.g., "3"), and a chevron toggle button. When collapsed, the card body is hidden. This takes up a single line on the dashboard -- zero crowding.

### Expanded State

When expanded, the card body contains a `lightning-accordion` with one section per active rule. Each section uses progressive disclosure:

**Section header (always visible):**

> #1 -- Rule Label | Source Status -> Target Status | 30d since modified

**Section body (on click):** A read-only detail grid grouped into four categories. Only populated fields are displayed -- blank/null criteria are hidden via `template if:true` guards.

- **Core:** Source Status, Target Status, Target Reason, Execution Order, Description, Stop Processing
- **Timing:** Days Since Last Modified, Days Since Created, Days Since Last Activity
- **Filtering:** Record Types (include/exclude), Origins, Owner Name Like, Last Modified By Name Like, Additional Filter Logic
- **Child Object:** Child Object API Name, Lookup Field, Filter Field, Filter Value, Filter Operator, Require Child Record

### Styling

CSS uses SLDS design tokens matching `util_closer_schedulerManager`:

| Element | Pattern Source | Token |
| --- | --- | --- |
| Section background | `.settings-section` | `var(--slds-g-color-neutral-base-100, #ffffff)` |
| Section border | `.config-section` | `1px solid var(--slds-g-color-border-base-1, #e5e5e5)` |
| Border radius | `.config-section` | `0.5rem` |
| Field labels | `.setting-label` | `font-weight: 600; color: var(--slds-g-color-neutral-base-30)` |
| Field values | `.setting-value` | `color: var(--slds-g-color-neutral-base-10)` |
| Count badge | `.success` badge | green variant with white text |

### JS Patterns

| Pattern | Source | Implementation |
| --- | --- | --- |
| Data loading | Scheduler `@wire(getJobStatus)` | `@wire(getActiveRules)` with `wiredRulesResult` for `refreshApex` |
| Error handling | Scheduler `handleError()` | Same `error.body.message` extraction + `ShowToastEvent` |
| Refresh | Scheduler `handleRefresh()` | `refreshApex(this.wiredRulesResult)` + success toast |
| State | Scheduler `@track` properties | `@track isExpanded`, `@track rules`, `@track isLoading`, `@track error` |

---

## Test Coverage

| Test Method | Lines Covered | Purpose |
| --- | --- | --- |
| `testGetActiveRules_ReturnsMappedData` | All map puts + return | Happy path with 2 mock rules |
| `testGetActiveRules_EmptyRules` | getActiveRules + empty loop + return | Zero rules returns empty list |
| `testGetActiveRules_ForcedException` | Exception flag + catch + throw | AuraHandledException with correct message |
| `testGetActiveRules_NullFields` | All map puts with nulls | Optional fields don't crash |
| `testGetActiveRules_VerifyFieldMapping` | All map puts | Every MDT field maps to correct key |

Coverage target: **100% lines, 100% methods, all 5 tests passing.**

Tests use `util_closer_RuleEngine.mockRules` for dependency injection, the same proven pattern from `util_closer_RuleEngine_Test.cls`. No test data factory changes or DML required.

---

## Flexipage Layout

The dashboard flexipage stacks three components vertically in the main region:

```
+----------------------------------------------+
|  util_closer_schedulerManager                |
|  (Scheduler, cron, settings)                 |
+----------------------------------------------+
|  util_closer_RuleViewer (NEW)                |
|  (Collapsed: "Active Rules [3]" + chevron)   |
+----------------------------------------------+
|  util_closer_LogViewer                       |
|  (Batch logs, case logs, filters)            |
+----------------------------------------------+
```

The rule viewer sits between the scheduler (configuration) and log viewer (execution results), creating a natural top-to-bottom flow: configure -> view rules -> view results.

---

## Deployment Manifest

Components to promote when moving this feature to a higher environment.

### Deployment Order

Deploy in the order listed below. The LWC depends on the Apex controller, and the FlexiPage depends on the LWC.

### 1. Apex Classes (New)

| Type | Component Name | File Path |
| --- | --- | --- |
| ApexClass | `util_closer_RuleViewerController` | `force-app/main/default/classes/util_closer_RuleViewerController.cls` |
| ApexClass | `util_closer_RuleViewerController` | `force-app/main/default/classes/util_closer_RuleViewerController.cls-meta.xml` |
| ApexClass | `util_closer_RuleViewerController_Test` | `force-app/main/default/classes/util_closer_RuleViewerController_Test.cls` |
| ApexClass | `util_closer_RuleViewerController_Test` | `force-app/main/default/classes/util_closer_RuleViewerController_Test.cls-meta.xml` |

### 2. Lightning Web Component (New)

| Type | Component Name | File Path |
| --- | --- | --- |
| LightningComponentBundle | `util_closer_RuleViewer` | `force-app/main/default/lwc/util_closer_RuleViewer/util_closer_RuleViewer.html` |
| LightningComponentBundle | `util_closer_RuleViewer` | `force-app/main/default/lwc/util_closer_RuleViewer/util_closer_RuleViewer.js` |
| LightningComponentBundle | `util_closer_RuleViewer` | `force-app/main/default/lwc/util_closer_RuleViewer/util_closer_RuleViewer.css` |
| LightningComponentBundle | `util_closer_RuleViewer` | `force-app/main/default/lwc/util_closer_RuleViewer/util_closer_RuleViewer.js-meta.xml` |

### 3. FlexiPage (Modified)

| Type | Component Name | File Path |
| --- | --- | --- |
| FlexiPage | `util_closer_Dashboard` | `force-app/main/default/flexipages/util_closer_Dashboard.flexipage-meta.xml` |

### Summary

| | New | Modified | Total |
| --- | --- | --- | --- |
| Apex Classes | 4 files (2 classes) | 0 | 4 |
| LWC Bundle | 4 files (1 component) | 0 | 4 |
| FlexiPage | 0 | 1 file | 1 |
| **Total** | **8** | **1** | **9** |

### Not Included

- No custom objects, fields, or metadata types changed
- No permission sets updated
- No existing Apex classes modified
- No existing LWC components modified
