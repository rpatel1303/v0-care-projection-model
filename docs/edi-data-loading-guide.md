# EDI Data Loading Guide

## Overview
This guide explains how to load sample EDI data (270/271, 278, 837) into the Clinical Forecasting Engine database while maintaining referential integrity.

## Data Loading Architecture

```
EDI Files → Python Parser → Database Functions → Tables
```

### Key Principles
1. **Referential Integrity**: Members must exist before signals/claims
2. **EDI Format**: All source data in standard X12 format
3. **Database Functions**: PostgreSQL functions handle parsing logic and validation
4. **Audit Trail**: All loads tracked with timestamps and source references

## File Structure

### Source Files
- `sample-data/members-master.txt` - Member demographics (pipe-delimited)
- `sample-data/270-eligibility-requests.edi` - Eligibility inquiries (X12)
- `sample-data/278-prior-auth-requests.edi` - Prior authorizations (X12)
- `sample-data/837I-institutional-claims.edi` - Institutional claims (X12)

### Database Functions
- `load_member_from_edi()` - Insert/update member records
- `load_271_eligibility()` - Parse 271 response and create intent events
- `load_278_prior_auth()` - Parse PA request and create intent events
- `load_837_claim()` - Parse claim and create outcome events

## Loading Sequence

### Step 1: Create Database Functions
```bash
psql -d clinical_forecasting -f scripts/05-create-edi-loader-functions.sql
```

### Step 2: Load Episode Definitions
```bash
psql -d clinical_forecasting -f scripts/02-seed-episode-definitions.sql
```

### Step 3: Run Python Loader
```bash
python3 scripts/load_edi_data.py
```

## Data Flow

### 270/271 Eligibility
1. Parse EDI 270 request (eligibility inquiry)
2. Extract member ID, service type codes, provider NPI
3. Call `load_271_eligibility()` function
4. Function creates `eligibility_inquiry_event` record
5. Function automatically creates `clinical_intent_event` with signal strength

### 278 Prior Authorization
1. Parse EDI 278 request
2. Extract member ID, diagnosis codes, procedure codes
3. Call `load_278_prior_auth()` function
4. Function creates `prior_auth_request` record
5. Function maps procedure codes to episode type
6. Function creates `clinical_intent_event` with higher signal strength

### 837 Claims
1. Parse EDI 837I/837P
2. Extract member ID, claim lines, procedure codes
3. Call `load_837_claim()` function
4. Function creates `claim_header` and `claim_line` records
5. Function identifies episode type from procedure codes
6. Function creates `clinical_outcome_event` (ground truth for model)

## Referential Integrity Rules

1. **Members First**: All members must be loaded before any transactions
2. **Episode Mapping**: Procedure codes must exist in `episode_procedure_map`
3. **Provider Validation**: Provider NPIs should exist (or be null)
4. **Date Logic**: Intent signals must precede outcome events
5. **Transaction IDs**: Each EDI transaction gets unique trace number

## Customization

### Adding New Episodes
1. Add episode definition to `episode_of_care_definition`
2. Add procedure mappings to `episode_procedure_map`
3. Add diagnosis mappings to `episode_diagnosis_map`
4. EDI loader will automatically classify new episodes

### Adding New Data Sources
1. Create parser function in Python
2. Create database loader function in SQL
3. Update loading sequence
4. Maintain referential integrity constraints

## Testing

### Verify Data Load
```sql
-- Check member count
SELECT COUNT(*) FROM member;

-- Check eligibility inquiries
SELECT COUNT(*) FROM eligibility_inquiry_event;

-- Check prior auths
SELECT COUNT(*) FROM prior_auth_request;

-- Check claims
SELECT COUNT(*) FROM claim_header;

-- Check intent events (should be elig + PA)
SELECT signal_type, COUNT(*) 
FROM clinical_intent_event 
GROUP BY signal_type;

-- Check outcome events
SELECT event_type, COUNT(*) 
FROM clinical_outcome_event 
GROUP BY event_type;
```

### Verify Referential Integrity
```sql
-- All intent events should have valid members
SELECT COUNT(*) 
FROM clinical_intent_event cie
LEFT JOIN member m ON m.member_id = cie.member_id
WHERE m.member_id IS NULL;
-- Should return 0

-- All outcome events should have valid claims
SELECT COUNT(*) 
FROM clinical_outcome_event coe
LEFT JOIN claim_header ch ON ch.claim_id = coe.confirming_claim_id
WHERE ch.claim_id IS NULL;
-- Should return 0
```

## Production Deployment

### Real-World Integration
1. Replace sample files with production EDI gateway feed
2. Schedule loader to run nightly via cron/Airflow
3. Add error handling and logging
4. Implement incremental loading (only new transactions)
5. Add monitoring alerts for data quality issues

### Performance Optimization
- Add indexes on frequently queried fields
- Batch insert transactions (1000 at a time)
- Use connection pooling for concurrent loads
- Partition large tables by date ranges

## Troubleshooting

### Common Errors
- **"Member does not exist"**: Load members-master.txt first
- **"Episode not found"**: Check procedure code mappings
- **Date format errors**: Verify EDI date formats (YYYYMMDD)
- **Duplicate key violations**: Transaction already loaded

### Debug Mode
Add logging to Python script:
```python
import logging
logging.basicConfig(level=logging.DEBUG)
```
</parameter>
