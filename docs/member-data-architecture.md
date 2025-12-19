# Member Data Architecture

## Overview

This document explains how member demographic data is sourced and integrated into the Clinical Forecasting Engine.

## Production Sources

In production healthcare environments, member demographic data comes from **proprietary enrollment systems**, not from EDI transactions. Common systems include:

### Commercial Health Plans
- **HealthRules** (HealthEdge)
- **QNXT** (Cognizant)
- **facets** (TriZetto/Cognizant)
- **Pega Health** (Pegasystems)
- **Guidewire** (Guidewire Software)

### Medicare/Medicaid
- **CMS MBR files** (Membership Report)
- **State Medicaid systems** (varies by state)

### Self-Funded Employers
- **HR/Payroll systems** (Workday, ADP, UKG)
- **Benefits administration platforms** (Benefitfocus, bswift)

## Data Format

Member data is typically exported from these systems as:
- **Flat files** (pipe-delimited, comma-delimited)
- **JSON exports** (API responses)
- **Database exports** (direct SQL queries)

**We use JSON** for this prototype because:
1. Structured and human-readable
2. Easy to validate with JSON Schema
3. Common API response format
4. Flexible for nested data (addresses, chronic conditions)

## Schema Design

See `sample-data/members.schema.json` for the complete JSON Schema definition.

### Core Fields
- **member_id**: Unique identifier from enrollment system
- **demographics**: Name, DOB, gender, contact info
- **enrollment**: Plan type, network, enrollment dates, status
- **clinical**: Risk scores, HCC scores, chronic conditions
- **provider**: Assigned PCP information

### Why Not 834 EDI?

The **834 Benefit Enrollment and Maintenance** EDI transaction is used to *communicate enrollment changes* between trading partners (employer → health plan). However:

1. **Not a data source** - It's a transaction notification, not a master data store
2. **Timing issues** - 834s are sent when changes occur, not on-demand
3. **Incomplete data** - May not include clinical risk scores, chronic conditions, etc.
4. **Complexity** - Enrollment systems are the source of truth, not EDI feeds

In a SaaS product, you would:
- Connect directly to the customer's enrollment system database (read-only access)
- Consume enrollment system APIs
- Receive periodic bulk exports (nightly/weekly JSON/CSV files)

## Loading Process

1. **Extract** - JSON file exported from enrollment system
2. **Validate** - Check against JSON Schema
3. **Transform** - Map to database schema
4. **Load** - Bulk insert via database function

```python
# Load members from JSON
with open('members.json', 'r') as f:
    members = json.load(f)

# Validate against schema
validate(members, schema)

# Load to database
db.execute_function('load_members_batch', members)
```

## Referential Integrity

Member data MUST be loaded FIRST before any other data (eligibility, PA, claims) because all other tables have foreign key references to `member.member_id`.

## Mock Data Strategy

For this prototype:
1. **members.json** - 10 realistic member records
2. **Validated** against members.schema.json
3. **Maintains referential integrity** with EDI sample files (270/271, 278, 837)

## Production Integration

For a real SaaS deployment:

### Option 1: Direct Database Connection
```sql
-- Read-only connection to customer's enrollment system
SELECT 
    member_id, first_name, last_name, dob, gender,
    plan_type, network, enrollment_status, risk_score
FROM customer_enrollment_db.members
WHERE enrollment_status = 'active'
```

### Option 2: API Integration
```python
# Call customer's enrollment system API
response = requests.get(
    'https://customer-enrollment-api.com/members',
    headers={'Authorization': f'Bearer {api_key}'}
)
members = response.json()
```

### Option 3: File Transfer
```bash
# Receive nightly SFTP export
sftp://customer-server/exports/members_20241215.json
```

## Data Refresh Cadence

- **Real-time**: API integration (check for changes hourly/daily)
- **Batch**: Nightly or weekly bulk exports
- **Change notifications**: Webhook callbacks when enrollment changes occur

## Security Considerations

- **PHI/PII**: Member data is Protected Health Information (PHI) under HIPAA
- **Encryption**: In transit (TLS) and at rest (database encryption)
- **Access control**: Role-based access, audit logging
- **Data retention**: Follow customer's retention policies
- **De-identification**: Consider de-identifying for non-production environments
</md>
