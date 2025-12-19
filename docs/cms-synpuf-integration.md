# CMS Synthetic Data Integration Guide

## Overview
The Centers for Medicare & Medicaid Services (CMS) provides **Synthetic Public Use Files (SynPUFs)** that contain realistic Medicare claims data without exposing actual patient information. This guide explains how to use CMS SynPUFs to enhance our Clinical Forecasting Engine with real-world claim patterns.

## What is CMS SynPUF?

CMS SynPUFs are freely available datasets that:
- Contain **synthetic claims data** based on real Medicare patterns
- Protect beneficiary privacy through statistical de-identification
- Include **5 data types**: Beneficiary Summary, Inpatient Claims, Outpatient Claims, Carrier Claims, Prescription Drug Events
- Cover **2008-2010** time period
- Provide **20 separate samples** (each representing 0.25% of Medicare population)

## Data Availability

### ✅ Available from CMS
- **Claims Data** (837 institutional/professional)
- **Beneficiary Demographics**
- **Diagnosis and Procedure Codes**
- **Provider Information**
- **Prescription Drug Events**

### ❌ NOT Available Publicly
- **270/271 Eligibility Inquiries** (restricted by Privacy Act)
- **278 Prior Authorization Requests** (not in public datasets)
- **Real-time transaction data**

**Our Approach**: Use real CMS claims data + synthetic pre-claim signals

## Downloading CMS SynPUF

### Option 1: CMS Website
1. Visit: https://www.cms.gov/data-research/statistics-trends-and-reports/medicare-claims-synthetic-public-use-files
2. Select DE-SynPUF (Data Entrepreneurs' Synthetic PUF)
3. Download Sample 1 (or any of 20 samples)
4. Files are provided as CSV

### Option 2: AWS S3 Public Bucket
```bash
# Download directly from S3
aws s3 cp s3://cms-synpuf/DE1_0_2008_Beneficiary_Summary_File_Sample_1.csv . --no-sign-request
aws s3 cp s3://cms-synpuf/DE1_0_2008_to_2010_Inpatient_Claims_Sample_1.csv . --no-sign-request
aws s3 cp s3://cms-synpuf/DE1_0_2008_to_2010_Outpatient_Claims_Sample_1.csv . --no-sign-request
```

## SynPUF File Structure

### 1. Beneficiary Summary File
Contains member demographics and enrollment:
```
DESYNPUF_ID          - Unique beneficiary ID
BENE_BIRTH_DT        - Birth date
BENE_SEX_IDENT_CD    - Gender (1=Male, 2=Female)
BENE_RACE_CD         - Race code
SP_STATE_CODE        - State
BENE_COUNTY_CD       - County
BENE_HI_CVRAGE_TOT_MONS - Hospital insurance months
PLAN_CVRG_MOS_NUM    - Plan coverage months
SP_ALZHDMTA          - Alzheimer's flag
SP_CHF               - Chronic heart failure flag
SP_CHRNKIDN          - Chronic kidney disease flag
SP_OSTEOART          - Osteoarthritis flag (KEY FOR TKA PREDICTION!)
```

### 2. Inpatient Claims File
Hospital claims including surgeries:
```
DESYNPUF_ID          - Beneficiary ID
CLM_ID               - Claim ID
CLM_FROM_DT          - Service from date
CLM_THRU_DT          - Service through date
PRVDR_NUM            - Provider number
CLM_PMT_AMT          - Payment amount
NCH_PRMRY_PYR_CLM_PD_AMT - Primary payer amount
CLM_ADMSN_DT         - Admission date
CLM_DRG_CD           - DRG code
ICD9_DGNS_CD_1       - Primary diagnosis
ICD9_PRCDR_CD_1      - Primary procedure (KEY: Look for knee replacement codes!)
```

### 3. Outpatient Claims File
Outpatient procedures and services

### 4. Carrier Claims File
Professional services (physician claims)

## Mapping SynPUF to Our Schema

### Step 1: Import Beneficiaries as Members
```sql
-- Import CMS beneficiaries
INSERT INTO member (
  member_id,
  date_of_birth,
  gender,
  plan_id,
  product_id,
  line_of_business,
  effective_date,
  risk_score,
  state,
  county
)
SELECT
  DESYNPUF_ID,
  TO_DATE(BENE_BIRTH_DT, 'YYYYMMDD'),
  CASE BENE_SEX_IDENT_CD WHEN 1 THEN 'M' WHEN 2 THEN 'F' END,
  'PLAN_MA_001',
  'PROD_MA',
  'MA',
  '2024-01-01',
  -- Calculate risk score based on chronic conditions
  1.0 + 
    (CASE WHEN SP_ALZHDMTA = 1 THEN 0.5 ELSE 0 END) +
    (CASE WHEN SP_CHF = 1 THEN 0.4 ELSE 0 END) +
    (CASE WHEN SP_CHRNKIDN = 1 THEN 0.3 ELSE 0 END) +
    (CASE WHEN SP_OSTEOART = 1 THEN 0.6 ELSE 0 END),
  SP_STATE_CODE,
  BENE_COUNTY_CD
FROM cms_synpuf_beneficiary
WHERE SP_OSTEOART = 1  -- Focus on members with osteoarthritis
LIMIT 100;
```

### Step 2: Import Historical TKA Claims
```sql
-- Find knee replacement procedures in inpatient claims
-- ICD-9 Procedure Codes for TKA: 81.54, 81.55
-- (Note: SynPUF uses ICD-9, current system uses ICD-10/CPT)

INSERT INTO claim_header (
  claim_id,
  member_id,
  claim_type,
  from_date,
  thru_date,
  received_ts,
  adjudicated_ts,
  paid_date,
  claim_status,
  rendering_provider_npi,
  place_of_service,
  total_billed_amt,
  total_allowed_amt,
  total_paid_amt,
  line_of_business,
  plan_id
)
SELECT
  CLM_ID,
  DESYNPUF_ID,
  'institutional',
  TO_DATE(CLM_FROM_DT, 'YYYYMMDD'),
  TO_DATE(CLM_THRU_DT, 'YYYYMMDD'),
  TO_DATE(CLM_FROM_DT, 'YYYYMMDD') + INTERVAL '5 days',  -- Simulate received date
  TO_DATE(CLM_FROM_DT, 'YYYYMMDD') + INTERVAL '10 days', -- Simulate adjudication
  TO_DATE(CLM_FROM_DT, 'YYYYMMDD') + INTERVAL '20 days', -- Simulate payment
  'paid',
  PRVDR_NUM,
  '21',  -- Inpatient hospital
  CLM_PMT_AMT * 1.15,  -- Estimate billed as 15% higher
  CLM_PMT_AMT,
  CLM_PMT_AMT,
  'MA',
  'PLAN_MA_001'
FROM cms_synpuf_inpatient
WHERE ICD9_PRCDR_CD_1 IN ('8154', '8155')  -- TKA procedure codes
   OR ICD9_PRCDR_CD_2 IN ('8154', '8155')
   OR ICD9_PRCDR_CD_3 IN ('8154', '8155');

-- Create claim lines
INSERT INTO claim_line (
  claim_id,
  line_num,
  service_date,
  procedure_code,
  units,
  billed_amt,
  allowed_amt,
  paid_amt,
  line_status
)
SELECT
  CLM_ID,
  1,
  TO_DATE(CLM_FROM_DT, 'YYYYMMDD'),
  '27447',  -- Map ICD-9 81.54/81.55 to CPT 27447
  1,
  CLM_PMT_AMT * 1.15,
  CLM_PMT_AMT,
  CLM_PMT_AMT,
  'paid'
FROM cms_synpuf_inpatient
WHERE ICD9_PRCDR_CD_1 IN ('8154', '8155')
   OR ICD9_PRCDR_CD_2 IN ('8154', '8155')
   OR ICD9_PRCDR_CD_3 IN ('8154', '8155');
```

### Step 3: Generate Synthetic Pre-Claim Signals
Since 270/271 and 278 data isn't available, we generate realistic signals:

```sql
-- For each TKA claim, generate backcast eligibility queries
INSERT INTO eligibility_inquiry_event (
  inquiry_ts,
  source_channel,
  payer_id,
  member_id,
  provider_npi,
  service_type_codes,
  place_of_service,
  coverage_status,
  plan_id,
  product_id
)
SELECT
  TO_DATE(CLM_FROM_DT, 'YYYYMMDD') - INTERVAL '45 days' - (random() * 30 || ' days')::INTERVAL,
  CASE (random() * 3)::INT
    WHEN 0 THEN 'portal'
    WHEN 1 THEN 'api'
    ELSE 'clearinghouse'
  END,
  'PAYER_MA_001',
  DESYNPUF_ID,
  PRVDR_NUM,
  ARRAY['2', 'BT'],  -- Surgical services
  '21',
  'active',
  'PLAN_MA_001',
  'PROD_MA'
FROM cms_synpuf_inpatient
WHERE ICD9_PRCDR_CD_1 IN ('8154', '8155');

-- Generate prior auth requests (typically 30-60 days before procedure)
INSERT INTO prior_auth_request (
  request_ts,
  decision_ts,
  status,
  member_id,
  requesting_provider_npi,
  servicing_provider_npi,
  service_from_date,
  service_to_date,
  place_of_service,
  diagnosis_codes,
  procedure_codes,
  clinical_type,
  line_of_business,
  plan_id,
  urgency
)
SELECT
  TO_DATE(CLM_FROM_DT, 'YYYYMMDD') - INTERVAL '40 days' - (random() * 20 || ' days')::INTERVAL,
  TO_DATE(CLM_FROM_DT, 'YYYYMMDD') - INTERVAL '38 days' - (random() * 20 || ' days')::INTERVAL,
  'approved',
  DESYNPUF_ID,
  PRVDR_NUM,
  PRVDR_NUM,
  TO_DATE(CLM_FROM_DT, 'YYYYMMDD'),
  TO_DATE(CLM_FROM_DT, 'YYYYMMDD'),
  '21',
  ARRAY['M17.11'],  -- Convert ICD-9 diagnosis to ICD-10
  ARRAY['27447'],
  'surgery',
  'MA',
  'PLAN_MA_001',
  CASE WHEN random() < 0.2 THEN 'expedited' ELSE 'standard' END
FROM cms_synpuf_inpatient
WHERE ICD9_PRCDR_CD_1 IN ('8154', '8155');
```

## Using SynPUF for Model Training

### Advantages
1. **Real cost distributions**: Actual Medicare payment amounts
2. **Real demographic patterns**: Age, gender, comorbidity distributions
3. **Real geographic variation**: State and county-level patterns
4. **Large sample size**: 100,000+ beneficiaries across 20 samples
5. **Free and legal**: No data use agreements required

### Limitations
1. **Old data**: 2008-2010 (costs need inflation adjustment)
2. **No pre-claim signals**: Must synthesize 270/271 and 278 data
3. **ICD-9 codes**: Need mapping to current ICD-10
4. **Limited inferential value**: Synthetic data doesn't perfectly match real patterns

## Cost Inflation Adjustment

```sql
-- Adjust 2008-2010 costs to 2024 dollars
-- Medical inflation ~3.5% annually
UPDATE claim_header
SET total_billed_amt = total_billed_amt * 1.60,  -- ~14 years * 3.5%
    total_allowed_amt = total_allowed_amt * 1.60,
    total_paid_amt = total_paid_amt * 1.60
WHERE created_at >= '2024-01-01'  -- Only update imported SynPUF claims
  AND claim_id LIKE 'CLM_%';      -- Only SynPUF claims
```

## Recommended Hybrid Approach

**Best Practice**: Combine CMS SynPUF with synthetic signals

1. **Use SynPUF for**:
   - Historical claim outcomes (ground truth)
   - Cost modeling
   - Member demographics
   - Geographic distributions

2. **Generate Synthetic Data for**:
   - 270/271 eligibility queries
   - 278 prior authorization requests
   - Referrals
   - Rx benefit checks

3. **Validate with Domain Experts**:
   - Ensure signal timing is realistic (30-90 days before procedure)
   - Verify signal strength calculations
   - Confirm cost estimates align with current rates

## Implementation Checklist

- [ ] Download CMS SynPUF Sample 1
- [ ] Create staging tables for SynPUF import
- [ ] Filter for osteoarthritis members
- [ ] Import TKA claims as outcomes
- [ ] Generate backcast eligibility queries
- [ ] Generate backcast prior auths
- [ ] Adjust costs for inflation
- [ ] Validate data quality
- [ ] Use for model training
- [ ] Document data lineage

## Resources

- [CMS SynPUF Documentation](https://www.cms.gov/data-research/statistics-trends-and-reports/medicare-claims-synthetic-public-use-files)
- [DE-SynPUF User Guide](https://www.cms.gov/files/document/de-synpuf-readme.pdf)
- [ICD-9 to ICD-10 Mapping](https://www.cms.gov/medicare/coding-billing/icd-10-codes/2023-icd-10-cm)
- [CPT Code Reference](https://www.aapc.com/codes/cpt-codes-range/)
