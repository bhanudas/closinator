# DCCA Migration Case Object Analysis

**Generated:** December 19, 2025  
**Source Org:** dcca-migration (Sandbox)  
**Purpose:** Analyze Case object schema and data to inform Closinator test-plan.md updates

---

## Executive Summary

This analysis examines the Case object in the `dcca-migration` sandbox to understand how the Closinator batch job should be configured to handle Call Center cases. Key findings indicate significant cleanup opportunities with **3,123 "New" status cases**, of which **90.5% are over 30 days old**.

---

## 1. Case Record Types

The org has **12 active Case record types**:

| Record Type Name | Developer Name | Description |
|------------------|----------------|-------------|
| **Call Center** | `PVL` | Call Center Case Type used for Call Center related calls |
| BREG Case | BREG_Case | - |
| BREG Complaint | BREG_Complaint | - |
| BREG Refund Request Case | BREG_Refund_Request_Case | Record type for Refund Request Case |
| CATV Complaint | CATV_Complaint | - |
| DCA Complaint | DCA_Complaint | - |
| DFI Complaint | DFI_Complaint | - |
| DO Referral | DO_Referral | Director's Office referrals |
| General Complaint | General_Complaint | - |
| INS Complaint | INS_Complaint | - |
| OCP Complaint | OCP_Complaint | - |
| RICO Complaint | RICO_Complaint | - |

**Key Finding:** The "Call Center" record type uses developer name `PVL` (not "Call_Center"). This must be used in any record type filtering logic.

---

## 2. Call Center (PVL) Case Statistics

### 2.1 Case Status Distribution

| Status | Count | Percentage |
|--------|-------|------------|
| Closed | 131,207 | 97.5% |
| New | 3,123 | 2.3% |
| In Progress | 227 | 0.17% |
| In-Progress | 2 | <0.01% |

**Total Call Center Cases:** 134,559

### 2.2 "New" Status Cases - Age Analysis

| Metric | Value |
|--------|-------|
| Total "New" Cases | 3,123 |
| Older than 7 days | 3,001 (96.1%) |
| Older than 30 days | 2,827 (90.5%) |
| Oldest Case | May 12, 2022 (over 2.5 years!) |
| Newest Case | December 20, 2025 |

**Critical Finding:** The vast majority of "New" Call Center cases are stale and should be candidates for automatic closure.

---

## 3. Transfers vs. Agent Pickups

### 3.1 Identification Method

Cases can be categorized by analyzing two key fields:

1. **`Origin`** - Indicates how the case was created
2. **`Incoming_Division__c`** - Indicates if the call was routed from a specific division

### 3.2 Origin Distribution for "New" Call Center Cases

| Origin | Count | Interpretation |
|--------|-------|----------------|
| `null` | 1,449 | Legacy/manually created cases |
| IVR call | 1,612 | Cases from Contact Center AI/UJET |
| Outbound call | 58 | Agent-initiated outbound calls |
| Phone | 4 | Direct phone cases |

### 3.3 Incoming Division Distribution

| Incoming Division | Count | Type |
|-------------------|-------|------|
| `null` | 2,800 | **Agent Pickup** - Direct handling |
| INS | 207 | **Transfer** - Routed from Insurance Division |
| OCP | 61 | **Transfer** - Routed from Office of Consumer Protection |
| PVL | 55 | **Agent Pickup** - Handled by PVL directly |

### 3.4 Cross-Reference: Origin × Incoming Division

| Incoming Division | Origin | Count | Classification |
|-------------------|--------|-------|----------------|
| null | null | 1,448 | Legacy Agent Pickup |
| null | IVR call | 1,291 | Direct IVR Agent Pickup |
| null | Outbound call | 58 | Outbound Agent Pickup |
| null | Phone | 3 | Direct Phone Agent Pickup |
| **INS** | IVR call | 207 | **INS Division Transfer** |
| **OCP** | null | 1 | OCP Transfer (manual) |
| **OCP** | IVR call | 60 | **OCP Division Transfer** |
| PVL | IVR call | 54 | PVL Direct Pickup |
| PVL | Phone | 1 | PVL Direct Phone |

### 3.5 Summary Classification

**Transfer Cases (Incoming_Division = INS or OCP):** 268 cases (8.6%)
- These are calls that came through the IVR for a specific division but were handled by Call Center agents

**Agent Pickup Cases:** 2,855 cases (91.4%)
- Direct calls handled by Call Center agents
- Includes legacy cases, IVR calls with null Incoming_Division, and outbound calls

---

## 4. Relevant Case Fields

### 4.1 Standard Fields for Closinator

| Field | Type | Use in Closinator |
|-------|------|-------------------|
| `Status` | Picklist | Source status for matching rules |
| `RecordTypeId` | Reference | Filter by Call Center (PVL) record type |
| `CreatedDate` | DateTime | Days_Since_Created calculation |
| `LastModifiedDate` | DateTime | Days_Since_Last_Modified calculation |
| `IsClosed` | Boolean | Exclude already closed cases |
| `OwnerId` | Reference | All are User-owned (not Queue) |

### 4.2 Call Center Specific Fields

| Field | Type | Values/Purpose |
|-------|------|----------------|
| `Origin` | Picklist | IVR call, Phone, Outbound call, Email, Web, etc. |
| `Incoming_Division__c` | Picklist | PVL, INS, OCP (indicates transfer source) |
| `Routed_to_Division__c` | Picklist | Target division for routing |
| `Division__c` | Picklist | Currently null for all "New" cases |
| `UJET__MenuPathId__c` | Number | UJET call center integration |

### 4.3 Available Status Values

```
New, On Hold, Escalated, In-Progress, Intake, Investigation, Legal, 
Pending Payment, Complete, Closed, Pending Submission, Received, 
Processing In Progress, Records In Progress, Held, Approved, Rejected, 
Completed, Expired, Withdrawn, Bounced Check
```

---

## 5. Queue Configuration

The org has the following relevant queues for Call Center cases:

| Queue Name | Developer Name |
|------------|----------------|
| PVL - Tier 1 | PVL_Tier_1_Agents |
| PVL - Supervisors | PVL_Supervisors |
| OCP - Tier 1 Agents | OCP_Tier_1_Agents |

**Note:** All 3,123 "New" cases are currently owned by Users, not Queues.

---

## 6. Recommended Test Plan Updates

### 6.1 Add Record Type Filter to Closinator

The current test-plan.md creates generic Cases without specifying a record type. For DCCA migration testing, we need to:

1. **Add `RecordTypeId` filter** to the batch job query to target only Call Center (PVL) cases
2. **Create test data with specific record type** using the PVL RecordTypeId

### 6.2 New Test Scenarios to Add

#### Scenario: Call Center Cases Only
- **Objective:** Verify only Call Center record type cases are processed
- **Setup:** Create cases with PVL and non-PVL record types
- **Expected:** Only PVL cases are closed by the batch job

#### Scenario: Transfer Cases Handling
- **Objective:** Verify transfer cases (Incoming_Division__c = INS/OCP) are handled appropriately
- **Setup:** Create cases with Incoming_Division__c values
- **Consider:** Should transfers have different rules than direct agent pickups?

#### Scenario: IVR Call Cases
- **Objective:** Verify Origin = 'IVR call' cases are closed properly
- **Setup:** Create cases with Origin = 'IVR call' and Subject like "Voice Inbound (IVR) via Contact Center AI"

### 6.3 Recommended Custom Metadata Rule Updates

Based on the data analysis, create rules specifically for Call Center cases:

```xml
<!-- Close Stale New Call Center Cases -->
<CustomMetadata>
    <DeveloperName>Close_Stale_New_PVL_Cases</DeveloperName>
    <Source_Status__c>New</Source_Status__c>
    <Target_Status__c>Closed</Target_Status__c>
    <Days_Since_Created__c>30</Days_Since_Created__c>
    <Record_Type_Developer_Name__c>PVL</Record_Type_Developer_Name__c>
    <Description__c>Close Call Center cases that have been in New status for over 30 days</Description__c>
</CustomMetadata>
```

### 6.4 Data Volume Considerations

With 2,827 cases older than 30 days eligible for closure:
- **Batch Size:** Consider running in smaller batches (50-100) to avoid governor limits
- **Staging:** May want to process in waves over multiple days
- **Notification:** Alert stakeholders before mass closure

---

## 7. Queries Used in This Analysis

Store these queries for reference and verification:

```sql
-- Count by Status
SELECT Status, COUNT(Id) cnt 
FROM Case 
WHERE RecordType.DeveloperName = 'PVL' 
GROUP BY Status ORDER BY Status

-- Count by Origin for New cases
SELECT Origin, COUNT(Id) cnt 
FROM Case 
WHERE RecordType.DeveloperName = 'PVL' AND Status = 'New' 
GROUP BY Origin ORDER BY Origin

-- Cross-reference Origin and Incoming Division
SELECT Incoming_Division__c, Origin, COUNT(Id) cnt 
FROM Case 
WHERE RecordType.DeveloperName = 'PVL' AND Status = 'New' 
GROUP BY Incoming_Division__c, Origin 
ORDER BY Incoming_Division__c, Origin

-- Age analysis
SELECT COUNT(Id) cnt 
FROM Case 
WHERE RecordType.DeveloperName = 'PVL' 
AND Status = 'New' 
AND CreatedDate < LAST_N_DAYS:30

-- Date range
SELECT MIN(CreatedDate) oldest, MAX(CreatedDate) newest 
FROM Case 
WHERE RecordType.DeveloperName = 'PVL' AND Status = 'New'
```

---

## 8. Files Generated

This analysis was performed without modifying the main project. Supporting data files are stored in:

```
docs/analysis/
├── dcca-migration-case-object-analysis.md (this file)
└── queries/
    └── (add SOQL files here for reuse)
```

---

## 9. Next Steps

1. **Update `util_closer_Case_Status_Rule__mdt`** custom metadata to include record type filtering capability
2. **Modify `util_closer_RuleEngine.cls`** to support record type-based rules if not already supported
3. **Update `test-plan.md`** with:
   - Record type-specific test scenarios
   - Transfer vs. agent pickup test cases
   - IVR call origin test cases
   - DCCA-specific data volume considerations
4. **Create a pilot run** in dcca-migration sandbox targeting a small subset of stale cases

---

*Document Version: 1.0*  
*Analysis Date: December 19, 2025*


