# 837 Claims Data Integration Guide

## Overview

This guide explains how to ingest 837 EDI claims files into the Clinical Forecasting Engine database. We support both institutional (837I) and professional (837P) claim formats.

## 837 Claim Types

### 837I - Institutional Claims (UB-04)
**Used for:** Hospital inpatient/outpatient services
**Key for our model:**
- Total Knee Arthroplasty (TKA) - CPT 27447
- Total Hip Arthroplasty (THA) - CPT 27130  
- Spinal Fusion - CPT 22558, 22612
- Cardiac procedures (CABG, PCI)
- Other major surgeries

**Transaction Set:** 005010X223A2

### 837P - Professional Claims (CMS-1500)
**Used for:** Physician/provider services
**Key for our model:**
- Office visits with orthopedic surgeons (99201-99215)
- Consultations
- Pre-operative evaluations
- Physical therapy

**Transaction Set:** 005010X222A1

## Sample 837 Files Provided

### 1. `837I-sample-knee-replacement.edi`
**Content:**
- Patient: Robert Johnson (Member M00001)
- Procedure: Total Knee Arthroplasty (CPT 27447)
- Diagnosis: Osteoarthritis of right knee (ICD-10 M17.11)
- Service Date: 12/01/2024 - 12/03/2024
- Provider: Northeast Orthopedic Center
- Total Charge: $45,000
- Revenue Code: 0360 (Operating Room)

### 2. `837P-sample-orthopedic-consult.edi`
**Content:**
- Patient: Sarah Williams (Member M00002)
- Procedure: Office Visit, New Patient (CPT 99204)
- Diagnosis: Osteoarthritis left knee (M17.12), History of knee surgery (Z96.642)
- Service Date: 11/15/2024
- Provider: Smith Orthopedic Group
- Total Charge: $450
- Prior Auth: PA123456

## Using the Parser

### Parse Single File
```bash
python scripts/parse_837_claims.py
```

### Integrate into ETL Pipeline
```python
from parse_837_claims import parse_837_file, generate_sql_insert

# Parse 837 file
claim_data = parse_837_file('path/to/837.edi')

# Generate SQL
sql = generate_sql_insert(claim_data)

# Execute against database
# ... your database connection logic ...
```

## Data Flow: 837 → Database

```
837 EDI File
    ↓
EDI Parser (parse_837_claims.py)
    ↓
Structured JSON
    ↓
SQL Generator
    ↓
claim_header + claim_line tables
    ↓
Episode Classifier
    ↓
clinical_outcome_event table
```

## Key Mapping: 837 → Our Schema

### claim_header
| 837 Segment | Element | Database Column |
|-------------|---------|-----------------|
| CLM | CLM01 | claim_number |
| CLM | CLM02 | total_charge_amount |
| DTP*434 | DTP03 | service_from_date, service_to_date |
| HI*BK | Composite | diagnosis_code_primary |
| NM1*IL | NM109 | member_id |
| NM1*85 | NM109 | rendering_provider_npi |

### claim_line
| 837 Segment | Element | Database Column |
|-------------|---------|-----------------|
| LX | LX01 | line_number |
| SV1/SV2 | Composite | procedure_code |
| SV1/SV2 | Amount | charge_amount |
| DTP*472 | DTP03 | service_date |

## Production Integration Options

### Option 1: Clearinghouse SFTP Drop
Most realistic for healthcare organizations:

1. **Setup SFTP listener** on your server
2. **Clearinghouse drops 837 files** daily (Change Healthcare, Availity, etc.)
3. **Automated processor** picks up files:
```python
import os
import glob

for file in glob.glob('/sftp/incoming/*.edi'):
    claim = parse_837_file(file)
    load_to_database(claim)
    os.move(file, '/sftp/processed/')
```

### Option 2: Direct Payer Integration
For payers with internal data:

1. **Query internal claims warehouse**
2. **Export to 837 format** OR map directly to schema
3. **Run batch ETL** nightly

### Option 3: API Integration
For modern cloud-based payers:

```python
import requests

# Fetch claims from payer API
response = requests.get('https://api.payer.com/claims', 
                       headers={'Authorization': f'Bearer {token}'})

claims = response.json()
for claim in claims:
    # Transform API format → our schema
    load_to_database(claim)
```

## Episode Classification from Claims

After loading claims, classify into episodes:

```sql
-- Insert into clinical_outcome_event from claims
INSERT INTO clinical_outcome_event (
    member_id, episode_id, outcome_date, outcome_type,
    procedure_codes, diagnosis_codes, total_cost, provider_npi
)
SELECT 
    ch.member_id,
    epm.episode_id,
    ch.service_from_date,
    'completed_procedure',
    STRING_AGG(cl.procedure_code, ','),
    ch.diagnosis_code_primary,
    ch.total_paid_amount,
    ch.rendering_provider_npi
FROM claim_header ch
JOIN claim_line cl ON ch.claim_id = cl.claim_id
JOIN episode_procedure_map epm ON cl.procedure_code = epm.procedure_code
WHERE ch.claim_status = 'paid'
GROUP BY ch.claim_id, ch.member_id, epm.episode_id, 
         ch.service_from_date, ch.diagnosis_code_primary,
         ch.total_paid_amount, ch.rendering_provider_npi;
```

## Validation Checks

Before loading claims, validate:

1. **Member exists** in member table
2. **Provider NPI is valid** (10-digit numeric)
3. **Procedure codes are valid** CPT/HCPCS
4. **Diagnosis codes are valid** ICD-10
5. **Dates are logical** (service date ≤ received date)
6. **Amounts are reasonable** (not negative, within expected ranges)

## Testing with Sample Data

```bash
# 1. Load sample 837 files
python scripts/parse_837_claims.py

# 2. Verify claims loaded
SELECT * FROM claim_header WHERE claim_id LIKE 'CLM_CLAIM00%';

# 3. Check episode classification
SELECT * FROM clinical_outcome_event 
WHERE member_id IN ('M00001', 'M00002');

# 4. Verify forecasting pipeline
SELECT * FROM prediction_result 
WHERE member_id IN ('M00001', 'M00002');
```

## Next Steps

1. ✅ Load sample 837 files using parser
2. ⏭️ Add 270/271 eligibility samples
3. ⏭️ Add 278 prior auth samples  
4. ⏭️ Build complete ETL pipeline
5. ⏭️ Add real-time 837 monitoring
6. ⏭️ Connect to clearinghouse SFTP

## Resources

- **X12 837 Specification:** [washington publishing.com](https://www.wpc-edi.com/reference)
- **CMS 837 Implementation Guides:** [cms.gov](https://www.cms.gov/Regulations-and-Guidance/Administrative-Simplification/TransactionCodeSetsStands)
- **Clearinghouse Partners:** Change Healthcare, Availity, Relay Health
