# Clinical Forecasting Engine: Data Pipeline Architecture

## Executive Summary

This document defines the **specific claim types**, **data formats**, and **ETL pipeline architecture** needed to build a production-ready knee replacement forecasting engine.

---

## 1. Specific Claim Types Required for TKA Forecasting

### A. **INSTITUTIONAL CLAIMS** (CMS-1450/UB-04 format)
**Primary Need: HIGH**

**Why We Need This:**
- Total Knee Arthroplasty (TKA) is predominantly performed in:
  - **Hospital Outpatient Departments** (HOPD) - ~60% of TKAs
  - **Ambulatory Surgery Centers** (ASC) - ~30% of TKAs  
  - **Hospital Inpatient** - ~10% (high-risk patients with comorbidities)

**What to Extract:**
```sql
-- Key fields from institutional claims
SELECT 
  claim_id,
  member_id,
  from_date,
  thru_date,
  bill_type,                    -- 0131 (hospital outpatient), 0831 (ASC)
  place_of_service,             -- 22 (outpatient), 24 (ASC), 21 (inpatient)
  facility_npi,
  rendering_provider_npi,
  revenue_codes,                -- 0360 (OR), 0490 (ambulatory surgery)
  procedure_codes,              -- 27447 (TKA primary)
  diagnosis_codes,              -- M17.x (osteoarthritis)
  drg_code,                     -- 469/470 (major joint replacement)
  total_allowed_amt,
  total_paid_amt
FROM institutional_claims
WHERE procedure_codes LIKE '%27447%'  -- TKA CPT code
   OR drg_code IN ('469', '470')
```

**CMS SynPUF Files Needed:**
- **Inpatient Claims** (DE1\_0\_2008\_to\_2010\_Inpatient\_Claims\_Sample\_1.csv)
- **Outpatient Claims** (DE1\_0\_2008\_to\_2010\_Outpatient\_Claims\_Sample\_1.csv)

---

### B. **PROFESSIONAL CLAIMS** (CMS-1500 format)
**Primary Need: MEDIUM**

**Why We Need This:**
- Captures **surgeon and anesthesiologist services** billed separately
- Important for **total episode cost** calculation
- Shows **pre-op office visits** (can be intent signal)

**What to Extract:**
```sql
-- Key fields from professional claims
SELECT 
  claim_id,
  member_id,
  service_date,
  rendering_provider_npi,
  provider_specialty,           -- 20 (orthopedic surgery)
  place_of_service,             -- 11 (office), 22 (outpatient), 24 (ASC)
  procedure_code,               -- 27447 (surgeon), 01402 (anesthesia)
  modifier_1,                   -- LT/RT (laterality)
  diagnosis_codes,
  allowed_amt,
  paid_amt
FROM professional_claims
WHERE procedure_code IN ('27447', '01402', '99213', '99214')
   OR diagnosis_codes LIKE 'M17%'
```

**CMS SynPUF Files Needed:**
- **Carrier Claims** (DE1\_0\_2008\_to\_2010\_Carrier\_Claims\_Sample\_1.csv)

---

### C. **PHARMACY CLAIMS** (NCPDP format)
**Primary Need: LOW (for MVP)**

**Why It's Useful (but not critical for MVP):**
- **Pre-op prescriptions** can signal upcoming surgery:
  - Pain medications (oxycodone, hydrocodone)
  - Pre-op antibiotics (cefazolin)
  - Anti-coagulants (for DVT prevention post-op)
- **Post-op fills** confirm surgery occurred

**What to Extract (if available):**
```sql
SELECT 
  member_id,
  service_date,
  ndc_code,
  drug_name,
  days_supply,
  quantity,
  prescriber_npi
FROM pharmacy_claims
WHERE ndc_code IN (
  '00406-0505-01',  -- Oxycodone 5mg
  '00093-0058-01'   -- Cefazolin 1g
)
```

**CMS SynPUF Files Needed:**
- **Prescription Drug Events** (DE1\_0\_2008\_to\_2010\_Prescription\_Drug\_Events\_Sample\_1.csv)

---

## 2. Data Format Landscape & Transformation Strategy

### A. **EDI (X12) Formats**

**What You'll Encounter:**

| Transaction | Name | Source System | Format |
|------------|------|---------------|---------|
| **270/271** | Eligibility Inquiry/Response | EDI Gateway, Clearinghouse | X12 EDI |
| **278** | Prior Authorization Request/Response | UM Platform, EDI Gateway | X12 EDI |
| **837I** | Institutional Claim | Claims Adjudication | X12 EDI |
| **837P** | Professional Claim | Claims Adjudication | X12 EDI |

**Challenge:** EDI is **human-unreadable**, hierarchical, and lacks standard field names.

**Example 270 Inquiry (raw):**
```
ISA*00*          *00*          *ZZ*SENDER         *ZZ*RECEIVER       *230101*1200*^*00501*000000001*0*P*:~
GS*HS*SENDER*RECEIVER*20230101*1200*1*X*005010X279A1~
ST*270*0001*005010X279A1~
BHT*0022*13*ABC123*20230101*1200~
HL*1**20*1~
NM1*PR*2*BLUE CROSS*****PI*12345~
HL*2*1*21*1~
NM1*1P*1*SMITH*JOHN****XX*1234567890~
HL*3*2*22*0~
NM1*IL*1*DOE*JANE****MI*123456789~
DMG*D8*19800115~
DTP*291*D8*20230115~
EQ*30~
SE*13*0001~
GE*1*1~
IEA*1*000000001~
```

**Your ETL Pipeline Must:**
1. **Parse EDI** using an X12 parser library (Python: `pyx12`, `x12-parser`)
2. **Extract key segments:**
   - `NM1` segments → member/provider identifiers
   - `EQ` segments → service type codes (30 = surgery)
   - `DTP` segments → service date
3. **Normalize** into your `eligibility_inquiry_event` table

---

### B. **Relational Database Formats (Internal Systems)**

**What You'll Encounter:**

Most payers have **already parsed EDI** into normalized relational tables:

```sql
-- Typical internal eligibility inquiry table
CREATE TABLE elig_inquiry_log (
  inquiry_id BIGINT PRIMARY KEY,
  inquiry_dt DATE,
  member_id VARCHAR(20),
  provider_npi VARCHAR(10),
  service_type_code VARCHAR(3),
  coverage_status VARCHAR(20),
  plan_id VARCHAR(10)
)
```

**Your Pipeline:** Simpler! Just map columns 1:1 to your canonical schema.

---

### C. **Proprietary Vendor Formats**

**Common Scenarios:**

| Vendor Type | Format | Example |
|-------------|--------|---------|
| UM Platform (InterQual, MCG) | Proprietary database tables | SQL export |
| Clearinghouse (Change Healthcare) | JSON API | REST endpoints |
| Data Warehouse (Snowflake, Databricks) | Parquet/Delta Lake | Spark jobs |

**Your Pipeline Must:**
- **Build adapters** for each source system
- **Standardize** into your canonical `clinical_intent_event` table

---

## 3. Data Pipeline Architecture (End-to-End)

### **Architecture Diagram:**

```
┌─────────────────────────────────────────────────────────────────┐
│                       SOURCE SYSTEMS                            │
├─────────────────────────────────────────────────────────────────┤
│  EDI Gateway    UM Platform    Claims ADJ    Data Warehouse    │
│   (270/271)       (278/PA)      (837/FHIR)    (Snowflake)      │
└────┬─────────────────┬────────────────┬────────────────┬────────┘
     │                 │                │                │
     │                 │                │                │
┌────▼─────────────────▼────────────────▼────────────────▼────────┐
│                     INGESTION LAYER                             │
├─────────────────────────────────────────────────────────────────┤
│  • X12 Parser (Python/Apache Camel)                             │
│  • API Connectors (REST/GraphQL)                                │
│  • Database Replication (CDC/Fivetran)                          │
│  • File Watchers (S3/SFTP → Lambda)                             │
└────┬────────────────────────────────────────────────────────────┘
     │
     │ Raw data lands in staging
     │
┌────▼────────────────────────────────────────────────────────────┐
│                   STAGING / RAW ZONE                            │
├─────────────────────────────────────────────────────────────────┤
│  • S3 / Blob Storage (Parquet files)                            │
│  • Raw tables: elig_raw, pa_raw, claim_raw                      │
│  • Append-only, immutable logs                                  │
└────┬────────────────────────────────────────────────────────────┘
     │
     │ Transform & normalize
     │
┌────▼────────────────────────────────────────────────────────────┐
│                  TRANSFORMATION LAYER (ETL)                     │
├─────────────────────────────────────────────────────────────────┤
│  • dbt, Apache Spark, or SQL stored procedures                  │
│  • Business rules:                                              │
│    - Map service codes → service categories                     │
│    - Deduplicate claims (adjustments/voids)                     │
│    - Calculate signal strength scores                           │
│    - Link member/provider/plan dimensions                       │
└────┬────────────────────────────────────────────────────────────┘
     │
     │ Clean, canonical data
     │
┌────▼────────────────────────────────────────────────────────────┐
│              CANONICAL SCHEMA (Your Forecasting DB)             │
├─────────────────────────────────────────────────────────────────┤
│  ✓ eligibility_inquiry_event                                    │
│  ✓ prior_auth_request                                           │
│  ✓ claim_header / claim_line                                    │
│  ✓ clinical_intent_event (unified)                              │
│  ✓ clinical_outcome_event (ground truth)                        │
└────┬────────────────────────────────────────────────────────────┘
     │
     │ Model scoring
     │
┌────▼────────────────────────────────────────────────────────────┐
│                    ML PREDICTION LAYER                          │
├─────────────────────────────────────────────────────────────────┤
│  • Batch scoring (nightly): Score all active members            │
│  • Feature engineering: Signal counts, recency, patterns        │
│  • Model inference: XGBoost/Neural Net → probability scores     │
│  • Write to: prediction_result table                            │
└────┬────────────────────────────────────────────────────────────┘
     │
     │ Dashboard queries
     │
┌────▼────────────────────────────────────────────────────────────┐
│              CLINICAL FORECASTING DASHBOARD (UI)                │
├─────────────────────────────────────────────────────────────────┤
│  • Executive view: Volume & cost forecasts                      │
│  • Clinical ops view: High-risk member lists                    │
│  • Care management: Intervention tracking                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Specific Pipeline Implementation (MVP)

### **Phase 1: File-Based Ingestion (Simplest)**

**For prototyping with CMS SynPUF data:**

```python
# scripts/ingest_cms_synpuf.py

import pandas as pd
import psycopg2
from datetime import datetime

# 1. Load CMS Outpatient Claims
df_outpatient = pd.read_csv('DE1_0_2008_Outpatient_Claims_Sample_1.csv')

# 2. Filter for TKA procedures (CPT 27447)
tka_claims = df_outpatient[
    df_outpatient['ICD9_PRCDR_CD_1'].isin(['27447', '8154'])  # TKA codes
]

# 3. Transform to canonical schema
canonical_claims = tka_claims.rename(columns={
    'DESYNPUF_ID': 'member_id',
    'CLM_FROM_DT': 'from_date',
    'CLM_THRU_DT': 'thru_date',
    'NCH_PRMRY_PYR_CLM_PD_AMT': 'paid_amt'
})

# 4. Load into database
conn = psycopg2.connect(os.environ['DATABASE_URL'])
canonical_claims.to_sql('claim_header', conn, if_exists='append')
```

**Run Schedule:** Daily batch job (Airflow, cron, or GitHub Actions)

---

### **Phase 2: EDI Real-Time Ingestion**

**For production with live 270/271 stream:**

```python
# app/api/ingest/eligibility/route.ts

import { parseX12 } from '@/lib/x12-parser'
import { db } from '@/lib/db'

export async function POST(req: Request) {
  const rawEDI = await req.text()
  
  // 1. Parse EDI 270/271
  const parsed = parseX12(rawEDI)
  
  // 2. Extract fields
  const inquiry = {
    inquiry_ts: new Date(),
    member_id: parsed.subscriber.memberId,
    provider_npi: parsed.provider.npi,
    service_type_codes: parsed.serviceTypes,
    coverage_status: parsed.coverageStatus,
    plan_id: parsed.payer.planId,
    raw_270_ref: rawEDI  // Store original for audit
  }
  
  // 3. Insert into database
  await db.eligibility_inquiry_event.create(inquiry)
  
  // 4. Check if this creates a high-risk signal
  await scoreIntentSignal(inquiry.member_id)
  
  return Response.json({ success: true })
}
```

**Deployment:** API endpoint called by your EDI gateway webhook

---

### **Phase 3: Database Replication (Change Data Capture)**

**For existing UM/PA platform:**

```yaml
# fivetran_config.yml (or Airbyte equivalent)

connector: postgres
source:
  host: um-platform.company.com
  database: utilization_management
  tables:
    - prior_auth_requests
    - referral_requests
  
destination:
  type: postgres
  host: forecasting-db.company.com
  database: clinical_forecasting
  
transforms:
  - type: dbt
    models:
      - staging/stg_prior_auth.sql
      - canonical/clinical_intent_event.sql
```

**Run Schedule:** Near real-time (5-15 minute lag)

---

## 5. Data Format Conversion Examples

### **Example 1: EDI 270 → canonical schema**

```python
# lib/parsers/x12_270_parser.py

def parse_270_to_canonical(raw_edi: str) -> dict:
    """Parse X12 270 eligibility inquiry to canonical format"""
    
    segments = raw_edi.split('~')
    
    # Extract subscriber (HL*3)
    subscriber = next(s for s in segments if s.startswith('NM1*IL'))
    member_id = subscriber.split('*')[9]
    
    # Extract provider (HL*2)
    provider = next(s for s in segments if s.startswith('NM1*1P'))
    provider_npi = provider.split('*')[9]
    
    # Extract service type (EQ segment)
    service_types = [s.split('*')[1] for s in segments if s.startswith('EQ')]
    
    # Map X12 service type codes to categories
    service_category = map_service_type_to_category(service_types[0])
    
    return {
        'inquiry_ts': datetime.now(),
        'source_channel': 'api',
        'member_id': member_id,
        'provider_npi': provider_npi,
        'service_type_codes': service_types,
        'service_category': service_category,
        'coverage_status': 'active',
        'raw_270_ref': raw_edi
    }

def map_service_type_to_category(service_type_code: str) -> str:
    """Map X12 service type codes to clinical categories"""
    mapping = {
        '30': 'surgery',
        'BN': 'ortho_knee',  # Orthopedic services
        'UC': 'surgery'      # Surgical services
    }
    return mapping.get(service_type_code, 'other')
```

---

### **Example 2: Internal PA table → canonical schema**

```sql
-- Transform internal UM platform PA table

INSERT INTO prior_auth_request (
  pa_id,
  request_ts,
  decision_ts,
  status,
  member_id,
  requesting_provider_npi,
  procedure_codes,
  diagnosis_codes,
  service_from_date,
  place_of_service
)
SELECT 
  pa_case_id,
  create_date,
  decision_date,
  CASE pa_status
    WHEN 'A' THEN 'approved'
    WHEN 'D' THEN 'denied'
    WHEN 'P' THEN 'pended'
  END,
  member_num,
  provider_npi,
  STRING_AGG(cpt_code, '|'),
  STRING_AGG(dx_code, '|'),
  requested_service_date,
  pos_code
FROM um_platform.pa_requests
LEFT JOIN um_platform.pa_services USING (pa_case_id)
WHERE create_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY 1,2,3,4,5,6,9,10
```

---

## 6. Recommended Tech Stack

### **Data Ingestion:**
- **EDI Parsing:** Python `pyx12` or Apache Camel (Java)
- **API Integration:** Next.js API routes or Python FastAPI
- **File Processing:** AWS Lambda + S3 triggers

### **ETL/Transformation:**
- **dbt** (preferred): SQL-based, version-controlled, testable
- **Apache Airflow**: Orchestration for complex dependencies
- **Spark**: For large-scale CMS dataset processing

### **Database:**
- **PostgreSQL** (via Supabase or Neon): Cost-effective, JSON support
- **Snowflake**: If you need data warehouse scale (100M+ rows)

### **ML Serving:**
- **Batch:** Python script → Airflow → write to prediction_result
- **Real-time:** FastAPI endpoint with model loaded in memory

---

## 7. MVP Data Pipeline Recommendation

### **What to build first (2-week sprint):**

```
Week 1: Data Ingestion
├─ Download CMS SynPUF outpatient claims
├─ Parse to claim_header / claim_line tables
├─ Generate synthetic 270/271 inquiries (Python script)
├─ Generate synthetic PA requests (Python script)
└─ Load all into Supabase

Week 2: Transformation & Dashboard
├─ Build clinical_intent_event from elig + PA
├─ Build clinical_outcome_event from claims
├─ Create prediction_result with rule-based scores
└─ Connect dashboard APIs to real data
```

### **What to defer (post-MVP):**
- Real-time EDI parsing (use batch for now)
- Pharmacy claims integration
- Change Data Capture from live UM system
- ML model deployment (start with rule-based scoring)

---

## 8. Key Decisions You Need to Make

| Decision | Option A | Option B | Recommendation |
|----------|----------|----------|----------------|
| **Database** | Supabase (PostgreSQL) | Snowflake Data Warehouse | Supabase for MVP |
| **Claims Source** | CMS SynPUF (free) | Request internal data | CMS SynPUF for demo |
| **ETL Tool** | dbt (SQL) | Python scripts | dbt (more maintainable) |
| **Intent Signals** | Synthetic generator | Wait for real EDI access | Synthetic (faster) |
| **Batch vs Real-time** | Daily batch jobs | Real-time streaming | Batch for MVP |

---

## Summary: What You Actually Need

### **Claim Types (Priority Order):**
1. **Institutional Outpatient Claims** (CMS-1450) - CRITICAL
2. **Institutional Inpatient Claims** (CMS-1450) - HIGH
3. **Professional Claims** (CMS-1500) - MEDIUM
4. **Pharmacy Claims** (NCPDP) - LOW (defer)

### **Data Formats You'll Handle:**
- X12 EDI (270/271, 278, 837) → Needs parsing library
- Internal relational tables → Simple SQL mapping
- Vendor APIs (JSON/REST) → HTTP clients
- Flat files (CSV/Parquet) → Pandas/Spark

### **Pipeline Phases:**
1. **MVP (now):** File-based ingestion, synthetic signals
2. **Production (Q2):** Real-time EDI, CDC from UM platform
3. **Scale (Q3):** Multi-payer, multi-episode expansion

---

Let me know if you want me to build:
- A) CMS SynPUF data loader script
- B) Synthetic 270/271 generator
- C) dbt transformation models
- D) All of the above
