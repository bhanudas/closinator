# Child Object Configuration Bug Fixes

**Branch:** `closinator-child-object-debug`
**Date:** March 23, 2026

Three misconfigured fields on a `util_closer_Case_Status_Rule__mdt` custom metadata record that prevent the child-record filter and owner-name filter from working correctly. The plan below covers the immediate data fixes and accompanying field-level help text improvements to prevent recurrence.

---

## Changes Implemented

### Metadata Record: `Abandoned_Calls`

| Field | Prior Value | Current Value |
| --- | --- | --- |
| `Child_Filter_Field__c` | `UJET__UJET_Session__c.UJET__Fail_Reason__c` | `UJET__Fail_Reason__c` |
| `Child_Filter_Value__c` | `'eu_abandoned'` | `eu_abandoned` |
| `Owner_Name_Like__c` | `%Google%` | `%Google%` (confirmed valid — production user) |

Record source file added to source control: [`customMetadata/util_closer_Case_Status_Rule__mdt.Abandoned_Calls.md-meta.xml`](../../force-app/main/default/customMetadata/util_closer_Case_Status_Rule__mdt.Abandoned_Calls.md-meta.xml)

### Field Help Text

| Field | Prior `inlineHelpText` | Current `inlineHelpText` |
| --- | --- | --- |
| `Child_Filter_Field__c` | `Enter the API name of the field on the child object to check against the filter value.` | `Field API name only. Do not use dot notation. (Example: UJET__Status__c).` |
| `Child_Filter_Value__c` | `Enter value(s) to match. Separate multiple values with semicolons.` | `Raw values only. Do not wrap in quotes. Separate multiple values with semicolons. (Example: Finished;Completed).` |
| `Owner_Name_Like__c` | `Enter a pattern to match the Case Owner Name. Use % as wildcard. Example: %Google% matches any owner name containing Google.` | `Leave blank to match all owners. Use % as wildcard. (Example: %Google%).` |
| `Last_Modified_By_Name_Like__c` | `Enter a pattern to match the Last Modified By Name. Use % as wildcard. Example: %Google% matches any name containing Google.` | `Leave blank to match all. Use % as wildcard. (Example: %Google%).` |

Both changes deployed to `dcca-devcc` on March 23, 2026.

---

## Summary of Errors

| Field | Current Value | Correct Value | Issue |
| --- | --- | --- | --- |
| `Child_Filter_Field__c` | `UJET__UJET_Session__c.UJET__Fail_Reason__c` | `UJET__Fail_Reason__c` | Object name prefix causes the field to fail schema validation and be silently dropped from the query. Evaluation then fails trying to read a field that was never fetched. |
| `Child_Filter_Value__c` | `'eu_abandoned'` | `eu_abandoned` | Literal single quotes are included in the stored value. The code does a case-sensitive exact match — `'eu_abandoned'` (with quotes) will never equal `eu_abandoned` (without quotes). |
| `Owner_Name_Like__c` | `%Google%` | Remove or correct | This restricts the rule to only cases owned by users with "Google" in their name. This appears to be a leftover test value and would exclude virtually all real cases in production. |

---

## Part 1: Metadata Record Fixes

The custom metadata records are not stored in source control in this repository (no `customMetadata/` directory). The fixes must be applied in one of two ways:

1. **Setup UI:** Navigate to Setup → Custom Metadata Types → Case Status Rule → find the record → edit the three fields.
2. **Metadata API deployment:** Create a `customMetadata/` record file and deploy it via `sf project deploy start`.

Option 1 is recommended for a quick targeted fix; option 2 if you want the corrected values tracked in source control going forward.

---

### Error 1: `Child_Filter_Field__c` — Object-qualified field name fails schema validation

**Current value:** `UJET__UJET_Session__c.UJET__Fail_Reason__c`
**Correct value:** `UJET__Fail_Reason__c`

#### Why it breaks

`util_closer_CaseDataAccess.cls` validates the field name against the child object's schema describe map. The map keys are bare field API names (e.g. `ujet__fail_reason__c`). The dot-notation value `ujet__ujet_session__c.ujet__fail_reason__c` is not a valid key, so the field **silently fails validation and is dropped from the SELECT list**. The SOQL query executes successfully but never fetches the filter field.

Later, `util_closer_ChildRecordService.cls` attempts to read the field value from the returned record using `child.get(criteria.childFilterField)`. Because the field was never SELECTed, this throws an `SObjectException`. The catch block returns `false`, and **every child record is treated as non-matching** — the rule silently produces wrong results.

#### Fix

Change the value from `UJET__UJET_Session__c.UJET__Fail_Reason__c` to `UJET__Fail_Reason__c`. The child object is already specified separately in `Child_Object_API_Name__c`, so only the bare field API name belongs here.

---

### Error 2: `Child_Filter_Value__c` — Embedded literal quotes prevent matching

**Current value:** `'eu_abandoned'` (with single quotes)
**Correct value:** `eu_abandoned` (no quotes)

#### Why it breaks

The `parseValues` method in `util_closer_ChildRecordService.cls` splits the stored string on semicolons and trims whitespace only — there is no quote-stripping logic. This produces a Set containing the literal string `'eu_abandoned'` (7 characters, with quotes).

At match time, the `Equals` operator does an exact `Set.contains()` check against `String.valueOf(fieldValue)`. The actual field value on the child record is `eu_abandoned` (no quotes). Since `'eu_abandoned' != eu_abandoned`, the comparison **always returns false** and no child records are ever matched.

#### Fix

Change the value from `'eu_abandoned'` to `eu_abandoned`. No quotes, no special delimiters — just the raw picklist/text value exactly as it appears on the record.

---

### Error 3: `Owner_Name_Like__c` — Test data leftover excludes all production cases

**Current value:** `%Google%`
**Correct value:** Blank (removed), or replaced with a real production pattern

#### Why it breaks

`util_closer_RuleEngine.cls` evaluates this field against each case's `Owner.Name` using a regex-based LIKE pattern match. The pattern `%Google%` translates to `(?i)^.*Google.*$`, meaning the owner's name must contain "Google". In production, virtually no case owners will have "Google" in their name, so **every case is excluded from this rule**.

When the field is blank, the `String.isNotBlank()` guard skips the check entirely, allowing all cases through regardless of owner.

#### Fix

Clear the `Owner_Name_Like__c` field (set it to blank/null). If there is a legitimate owner restriction needed, replace `%Google%` with the correct production pattern.

---

## Part 2: Field Help Text Improvements

All three errors share the same root cause: the field-level `description` and `inlineHelpText` on the custom metadata type don't give users enough information to avoid common mistakes. The `inlineHelpText` value is what appears on the record editing screen in Salesforce Setup, making it the most effective place to guide users at the moment they are entering values.

Files to edit:

- [`Child_Filter_Field__c.field-meta.xml`](../../force-app/main/default/objects/util_closer_Case_Status_Rule__mdt/fields/Child_Filter_Field__c.field-meta.xml)
- [`Child_Filter_Value__c.field-meta.xml`](../../force-app/main/default/objects/util_closer_Case_Status_Rule__mdt/fields/Child_Filter_Value__c.field-meta.xml)
- [`Owner_Name_Like__c.field-meta.xml`](../../force-app/main/default/objects/util_closer_Case_Status_Rule__mdt/fields/Owner_Name_Like__c.field-meta.xml)
- [`Last_Modified_By_Name_Like__c.field-meta.xml`](../../force-app/main/default/objects/util_closer_Case_Status_Rule__mdt/fields/Last_Modified_By_Name_Like__c.field-meta.xml)

---

### `Child_Filter_Field__c`

| | Current | Proposed |
| --- | --- | --- |
| `description` | `API name of the field on the child object to evaluate (e.g., UJET__Status__c).` | `API name of the field on the child object to evaluate. Enter the field name only, without the object prefix. Correct: UJET__Fail_Reason__c. Incorrect: UJET__UJET_Session__c.UJET__Fail_Reason__c.` |
| `inlineHelpText` | `Enter the API name of the field on the child object to check against the filter value.` | `Field API name only. Do not use dot notation. (Example: UJET__Status__c).` |

---

### `Child_Filter_Value__c`

| | Current | Proposed |
| --- | --- | --- |
| `description` | `Value(s) to match on the child filter field. Use semicolon to separate multiple values (e.g., Finished;Completed).` | `Raw value(s) to match on the child filter field. Do not wrap in quotes. Use semicolons to separate multiple values. Example: eu_abandoned or Finished;Completed.` |
| `inlineHelpText` | `Enter value(s) to match. Separate multiple values with semicolons.` | `Raw values only. Do not wrap in quotes. Separate multiple values with semicolons. (Example: Finished;Completed).` |

---

### `Owner_Name_Like__c`

| | Current | Proposed |
| --- | --- | --- |
| `description` | `Pattern to match against Owner Name using LIKE operator. Supports % as wildcard. Example: Google% matches names starting with Google.` | `Optional LIKE pattern to restrict this rule by Case Owner Name. Leave blank to apply to all owners. Use % as multi-character wildcard and _ as single-character wildcard.` |
| `inlineHelpText` | `Enter a pattern to match the Case Owner Name. Use % as wildcard. Example: %Google% matches any owner name containing Google.` | `Leave blank to match all owners. Use % as wildcard. (Example: %Google%).` |

---

### `Last_Modified_By_Name_Like__c` (related fix)

This field has the same help text pattern as `Owner_Name_Like__c` and should be updated for consistency.

| | Current | Proposed |
| --- | --- | --- |
| `description` | `Pattern to match against Last Modified By Name using LIKE operator. Supports % as wildcard. Example: %Google% matches names containing Google.` | `Optional LIKE pattern to restrict this rule by Last Modified By Name. Leave blank to apply to all. Use % as multi-character wildcard and _ as single-character wildcard.` |
| `inlineHelpText` | `Enter a pattern to match the Last Modified By Name. Use % as wildcard. Example: %Google% matches any name containing Google.` | `Leave blank to match all. Use % as wildcard. (Example: %Google%).` |
