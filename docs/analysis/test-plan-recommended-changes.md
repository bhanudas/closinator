# Recommended Changes to test-plan.md

**Based on:** DCCA Migration Case Object Analysis  
**Date:** December 19, 2025

---

## Summary of Required Changes

The current `test-plan.md` is designed for generic scratch org testing. To support the DCCA migration environment with its specific Case object configuration, the following changes are recommended:

---

## 1. Update Prerequisites Section

### Current (Section 1):
- Generic scratch org references

### Recommended Addition:
```markdown
### DCCA Migration Testing Prerequisites

- Access to `dcca-migration` sandbox org
- Verify authentication: `sf org display --target-org dcca-migration`
- Understand that the "Call Center" record type uses developer name `PVL`
```

---

## 2. Add Record Type Configuration Section

### New Section: "2.7 Record Type Configuration for Call Center"

```markdown
### 2.7 Verify Call Center Record Type

Query the Call Center (PVL) record type ID:

```bash
sf data query \
  --query "SELECT Id, Name, DeveloperName FROM RecordType WHERE SObjectType = 'Case' AND DeveloperName = 'PVL'" \
  --target-org dcca-migration
```

Expected output:
| Id | Name | DeveloperName |
|----|------|---------------|
| 012cs0000072Q7NAAU | Call Center | PVL |

**Note:** Store this RecordTypeId for test data creation.
```

---

## 3. Update Test Case Data Creation (Section 4)

### Current Approach:
- Creates generic Cases without record type

### Recommended Update:

```markdown
## 4. Create Test Case Data

### 4.0 Get Record Type ID (Required for DCCA)

```bash
# Store the Call Center record type ID
PVL_RECORD_TYPE_ID=$(sf data query \
  --query "SELECT Id FROM RecordType WHERE SObjectType = 'Case' AND DeveloperName = 'PVL'" \
  --target-org dcca-migration \
  --json | jq -r '.result.records[0].Id')
echo "PVL Record Type ID: $PVL_RECORD_TYPE_ID"
```

### 4.1 Create Call Center Cases for Testing

```bash
# Create Case with Call Center record type - Direct Agent Pickup
sf data create record \
  --sobject Case \
  --values "Subject='Test Case - IVR Direct Pickup' Status='New' Origin='IVR call' RecordTypeId='$PVL_RECORD_TYPE_ID'" \
  --target-org dcca-migration

# Create Case with Call Center record type - Transfer from INS
sf data create record \
  --sobject Case \
  --values "Subject='Test Case - INS Transfer' Status='New' Origin='IVR call' Incoming_Division__c='INS' RecordTypeId='$PVL_RECORD_TYPE_ID'" \
  --target-org dcca-migration

# Create Case with Call Center record type - Transfer from OCP  
sf data create record \
  --sobject Case \
  --values "Subject='Test Case - OCP Transfer' Status='New' Origin='IVR call' Incoming_Division__c='OCP' RecordTypeId='$PVL_RECORD_TYPE_ID'" \
  --target-org dcca-migration
```

### 4.2 Create Control Cases (Non-Call Center Record Types)

```bash
# Create Case with different record type (should NOT be processed)
sf data create record \
  --sobject Case \
  --values "Subject='Control Case - General Complaint' Status='New' Origin='Phone'" \
  --target-org dcca-migration
```
```

---

## 4. Add New Test Scenarios (Section 9)

### Add: Scenario 6 - Record Type Filtering

```markdown
### Scenario 6: Call Center Record Type Filtering

**Objective**: Verify only Call Center (PVL) record type cases are processed.

**Steps**:

1. Create test cases with PVL record type (Call Center)
2. Create control cases with other record types (General Complaint, etc.)
3. Run the batch job
4. Verify only PVL cases were closed

```bash
# Verify Call Center cases were closed
sf data query \
  --query "SELECT CaseNumber, Subject, Status, RecordType.Name FROM Case WHERE Subject LIKE 'Test Case%' AND RecordType.DeveloperName = 'PVL'" \
  --target-org dcca-migration
```

**Expected Result**: Only cases with RecordType = "Call Center" are updated.
```

### Add: Scenario 7 - Transfer vs Agent Pickup Handling

```markdown
### Scenario 7: Transfer vs Agent Pickup Cases

**Objective**: Verify correct handling based on Incoming_Division__c field.

**Setup**:
- Cases with `Incoming_Division__c = null` (Agent Pickups)
- Cases with `Incoming_Division__c = 'INS'` (Transfers from Insurance)
- Cases with `Incoming_Division__c = 'OCP'` (Transfers from Consumer Protection)

**Steps**:

```bash
# Query to verify transfer cases
sf data query \
  --query "SELECT CaseNumber, Subject, Status, Incoming_Division__c FROM Case WHERE RecordType.DeveloperName = 'PVL' AND Status = 'New' AND Subject LIKE 'Test Case%'" \
  --target-org dcca-migration
```

**Considerations**:
- Should transfer cases have different closure rules?
- Are transfers still owned by the original division?
- Business decision: Close all vs. route back to originating division
```

### Add: Scenario 8 - IVR Call Origin Cases

```markdown
### Scenario 8: IVR Call Origin Processing

**Objective**: Verify cases originating from Contact Center AI are processed correctly.

**Setup**: Cases with `Origin = 'IVR call'` and `Subject = 'Voice Inbound (IVR) via Contact Center AI'`

**Verification**:
```bash
sf data query \
  --query "SELECT COUNT(Id) FROM Case WHERE RecordType.DeveloperName = 'PVL' AND Status = 'New' AND Origin = 'IVR call'" \
  --target-org dcca-migration
```
```

---

## 5. Update Custom Metadata Rule Examples

### Current Rules:
- `Close_Stale_Waiting_Cases` - targets "Waiting on Customer"
- `Escalate_Old_New_Cases` - targets "New"

### Recommended Addition for DCCA:

```markdown
### 5.4 DCCA-Specific Rule: Close Stale New Call Center Cases

Create a rule specifically for Call Center record type:

File: `force-app/main/default/customMetadata/util_closer_Case_Status_Rule.Close_Stale_New_PVL_Cases.md-meta.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Close Stale New PVL Cases</label>
    <protected>false</protected>
    <values>
        <field>Is_Active__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>Execution_Order__c</field>
        <value xsi:type="xsd:double">15</value>
    </values>
    <values>
        <field>Source_Status__c</field>
        <value xsi:type="xsd:string">New</value>
    </values>
    <values>
        <field>Target_Status__c</field>
        <value xsi:type="xsd:string">Closed</value>
    </values>
    <values>
        <field>Days_Since_Created__c</field>
        <value xsi:type="xsd:double">30</value>
    </values>
    <values>
        <field>Record_Type_Developer_Name__c</field>
        <value xsi:type="xsd:string">PVL</value>
    </values>
    <values>
        <field>Description__c</field>
        <value xsi:type="xsd:string">Close Call Center cases in New status for over 30 days</value>
    </values>
</CustomMetadata>
```

**Note**: This requires adding `Record_Type_Developer_Name__c` field to the custom metadata type if not already present.
```

---

## 6. Add DCCA Troubleshooting Section

```markdown
## 11.6 DCCA-Specific Troubleshooting

### Issue: Cases with wrong record type being processed

**Diagnosis**:
```bash
sf data query \
  --query "SELECT RecordType.DeveloperName, COUNT(Id) FROM Case WHERE Status = 'Closed' AND LastModifiedDate = TODAY GROUP BY RecordType.DeveloperName" \
  --target-org dcca-migration
```

**Solution**: Ensure rule includes `Record_Type_Developer_Name__c = 'PVL'`

### Issue: Understanding Transfer vs Pickup

**Query**:
```bash
sf data query \
  --query "SELECT Incoming_Division__c, Origin, COUNT(Id) cnt FROM Case WHERE RecordType.DeveloperName = 'PVL' AND Status = 'New' GROUP BY Incoming_Division__c, Origin" \
  --target-org dcca-migration
```

**Interpretation**:
- `Incoming_Division__c = null` → Direct agent pickup
- `Incoming_Division__c = 'INS'|'OCP'` → Transfer from other division
```

---

## 7. Update Appendix

### Add: DCCA Call Center Test Data Summary

```markdown
## Appendix B: DCCA Call Center Test Data

| Case Subject | Record Type | Origin | Incoming Division | Initial Status | Expected After Batch |
|--------------|-------------|--------|-------------------|----------------|---------------------|
| Test Case - IVR Direct Pickup | PVL | IVR call | null | New | Closed |
| Test Case - INS Transfer | PVL | IVR call | INS | New | Closed |
| Test Case - OCP Transfer | PVL | IVR call | OCP | New | Closed |
| Control Case - General Complaint | General_Complaint | Phone | null | New | New (no change) |

### Current Data Volume in dcca-migration

| Metric | Count |
|--------|-------|
| Total Call Center "New" Cases | 3,123 |
| Cases > 30 days old | 2,827 (90.5%) |
| Cases > 7 days old | 3,001 (96.1%) |
| Oldest Case | May 12, 2022 |
| Transfer Cases (INS/OCP) | 268 (8.6%) |
| Agent Pickup Cases | 2,855 (91.4%) |
```

---

## Implementation Priority

1. **High**: Add Record Type filtering to Closinator rules
2. **High**: Update test data creation to include record type
3. **Medium**: Add transfer/pickup differentiation scenarios
4. **Medium**: Add DCCA-specific troubleshooting
5. **Low**: Consider separate rules for transfers vs pickups

---

*Document Version: 1.0*  
*Last Updated: December 19, 2025*


