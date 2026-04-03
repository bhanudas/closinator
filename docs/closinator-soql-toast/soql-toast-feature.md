# Copy SOQL to Clipboard (replaces CSV Export)

## Summary

The Log Viewer's export button now copies a SOQL query to the clipboard instead of downloading a CSV file. The user can paste this query into Developer Console, Workbench, Data Loader, or any other SOQL-capable tool to retrieve the case log data.

## Why the CSV export was removed

The original `exportCaseLogsAsCsv` Apex method queried up to 50,000 `util_closer_Case_Log__c` records and built a CSV string in a single synchronous `@AuraEnabled` call. Salesforce enforces a **6 MB heap size limit** on synchronous Apex. With verbose logging enabled, a single batch run can produce thousands of case log records (one per evaluated case), and the in-memory cost of holding the query results, the CSV row list, and the final joined string simultaneously exceeded the heap limit at roughly 6,000-8,000 records.

The LWC download mechanism (`document.createElement('a')` with a Blob URL) also had compatibility issues in Lightning Web Security contexts.

## How the new button works

1. The user clicks the clipboard icon button in the Case Logs panel header.
2. The LWC calls `getCaseLogExportQuery` -- an Apex method that builds the SOQL string using the same filter logic as the UI (batch log ID, processing result, matched rule, search term) but **does not execute** the query.
3. The SOQL string is copied to the clipboard via `navigator.clipboard.writeText()`.
4. A sticky success toast displays the full SOQL query so the user can verify what was copied.

## Where to run the SOQL

Paste the copied query into any of these tools:

- **Developer Console** -- Setup > Developer Console > Query Editor tab
- **Workbench** -- workbench.developerforce.com > SOQL Query
- **Data Loader** -- Export wizard with custom SOQL
- **VS Code SOQL Extension** -- Salesforce Extensions for VS Code
- **Anonymous Apex** -- `Database.query(soqlString)` in Execute Anonymous

## Files changed

| File | Change |
|------|--------|
| `force-app/main/default/classes/util_closer_LogViewerController.cls` | Replaced `exportCaseLogsAsCsv` with `getCaseLogExportQuery`; removed `escapeCsvValue` helper |
| `force-app/main/default/lwc/util_closer_LogViewer/util_closer_LogViewer.js` | Replaced CSV download handler with clipboard copy + sticky toast |
| `force-app/main/default/lwc/util_closer_LogViewer/util_closer_LogViewer.html` | Changed button icon to `utility:copy_to_clipboard`, updated tooltip |
| `force-app/main/default/classes/util_closer_LogViewerController_Test.cls` | Replaced CSV export tests with SOQL query string tests |
