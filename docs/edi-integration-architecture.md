# EDI Integration Architecture for Multi-Episode Clinical Forecasting Engine

## Executive Summary

This document outlines the **EDI-first architecture** that makes the Clinical Forecasting Engine **payor-agnostic, portable, and SaaS-ready**. By standardizing on HIPAA-mandated EDI transaction sets (837, 270/271, 278), the solution can be deployed across any healthcare organization without custom integrations.

---

## Why EDI is the Right Choice for SaaS

### 1. **Regulatory Mandate**
- **HIPAA requires** all covered entities to accept EDI transactions
- **Universal adoption** across US healthcare system
- **Standard format** eliminates vendor lock-in

### 2. **Payor Agnostic**
- Works with **all insurance companies** (UnitedHealth, Anthem, Aetna, Cigna, Blue Cross, Medicare, Medicaid)
- Works with **all providers** (hospitals, physician groups, ASCs)
- Works with **all clearinghouses** (Change Healthcare, Availity, Waystar)

### 3. **Comprehensive Data Coverage**
- **837**: Complete claims data with procedures, diagnoses, costs
- **270/271**: Real-time eligibility checks (strongest intent signal)
- **278**: Prior authorization requests (second strongest intent signal)
- **835**: Remittance advice (payment/adjustment data)
- **276/277**: Claim status inquiry/response

### 4. **Scalability**
- Clearinghouses aggregate **millions of transactions daily**
- Already have **EDI parsing infrastructure**
- Can plug into existing data flows

---

## EDI Transaction Set Details

### **837 - Claims (Outcome Data)**

**Purpose**: Historical procedure data - your "ground truth" for training ML models

**Two Subtypes**:
- **837I (Institutional)**: Hospital inpatient/outpatient claims
- **837P (Professional)**: Physician office claims

**Key Data Elements**:
```
Loop 2300 - Claim Level
- CLM01: Claim ID
- CLM02: Total charge amount
- DTP: Service dates (admission/discharge)
- CL1: Admission source/type/hour
- HI: Diagnosis codes (ICD-10)

Loop 2400 - Line Level
- SV2/SV1: Procedure codes (CPT/HCPCS)
- SV202/SV101: Charge amounts
- DTP: Service line dates
- REF: Authorization numbers
```

**What We Extract**:
- Member ID → `claim_header.member_id`
- Service dates → `claim_header.service_date`
- Procedure codes → `claim_line.procedure_code`
- Diagnosis codes → `claim_line.diagnosis_code`
- Total cost → `claim_header.total_paid_amount`
- Provider NPI → `claim_header.billing_provider_npi`
- **Episode classification** → Derive `episode_code` by matching procedure/diagnosis codes

**Critical for**:
- Training ML models (historical outcomes)
- Cost benchmarking
- Provider performance analysis
- Model validation (did prediction match outcome?)

---

### **270/271 - Eligibility Inquiry/Response (Intent Signal)**

**Purpose**: Real-time benefit checks - member is exploring coverage for specific service

**Signal Strength**: ⭐⭐⭐⭐⭐ (Highest)

**Key Data Elements**:
```
270 Request:
- HL: Subscriber/Dependent hierarchy
- TRN: Transaction trace number
- NM1: Member demographic data
- EQ: Service type inquiry (specific procedures)

271 Response:
- EB: Eligibility/benefit information
- DTP: Benefit period dates
- MSG: Additional information
```

**What We Extract**:
- Member ID → `eligibility_inquiry_event.member_id`
- Inquiry date → `eligibility_inquiry_event.inquiry_date`
- Service type code → `eligibility_inquiry_event.service_type_code`
- Procedure code (if provided) → `eligibility_inquiry_event.procedure_code`
- Provider NPI → `eligibility_inquiry_event.provider_npi`
- **Episode classification** → Derive `episode_code` from service type + procedure code

**Why It's Powerful**:
- Real-time signal (happens 30-90 days before procedure)
- Provider-initiated (high intent)
- Specific procedure inquiry = strong predictor

**Example Pattern**:
```
Member M00001 checks eligibility for:
- Service Type: 47 (Hospital Inpatient)
- Procedure: 27447 (Total Knee Arthroplasty)
- Date: 60 days before actual surgery
→ 85% probability of TKA within 90 days
```

---

### **278 - Prior Authorization Request/Response (Intent Signal)**

**Purpose**: Provider requesting authorization for planned procedure

**Signal Strength**: ⭐⭐⭐⭐⭐ (Highest)

**Key Data Elements**:
```
278 Request:
- BHT: Authorization type (request/certification)
- UM: Service line information
- HI: Diagnosis codes
- SV1/SV2: Procedure codes
- DTP: Proposed service dates

278 Response:
- AAA: Authorization decision
- REF: Authorization number
- MSG: Decision notes
```

**What We Extract**:
- Member ID → `prior_auth_request.member_id`
- Request date → `prior_auth_request.request_date`
- Procedure code → `prior_auth_request.procedure_code`
- Diagnosis code → `prior_auth_request.diagnosis_code`
- Service dates → `prior_auth_request.service_start_date`
- Authorization status → `prior_auth_request.authorization_status`
- **Episode classification** → Derive `episode_code` from procedure/diagnosis

**Why It's Powerful**:
- Happens 15-60 days before procedure
- Requires clinical necessity documentation
- Status changes are predictive:
  - "Approved" → 90%+ probability of procedure
  - "Pended" → 60% probability (awaiting info)
  - "Denied" → May resubmit or appeal

**Example Pattern**:
```
Prior Auth submitted for:
- Procedure: 27447 (TKA)
- Diagnosis: M17.11 (Right knee osteoarthritis)
- Status: Approved
- Service Date: 2025-01-15
→ 95% probability of TKA on or near 2025-01-15
```

---

## Multi-Episode Architecture

### Episode Classification Logic

**Step 1: Identify Primary Procedure**
```sql
-- From 270/271 eligibility inquiry
SELECT episode_code 
FROM episode_procedure_map 
WHERE procedure_code = '27447' 
AND is_primary_indicator = true;
-- Returns: 'TKA'

-- From 278 prior auth
SELECT episode_code 
FROM episode_procedure_map 
WHERE procedure_code = '33533';
-- Returns: 'CABG'
```

**Step 2: Validate with Diagnosis Codes**
```sql
-- Confirm episode matches diagnosis
SELECT episode_code, relevance_score
FROM episode_diagnosis_map
WHERE diagnosis_code = 'M17.11'
ORDER BY relevance_score DESC;
-- Returns: 'TKA' with 0.95 relevance
```

**Step 3: Handle Ambiguous Cases**
```sql
-- If multiple episodes match, use relevance scores and procedure hierarchy
-- Example: Procedure 29827 (rotator cuff repair) + diagnosis M75.100
SELECT 
    epm.episode_code,
    edm.relevance_score,
    epm.is_primary_indicator
FROM episode_procedure_map epm
JOIN episode_diagnosis_map edm ON epm.episode_code = edm.episode_code
WHERE epm.procedure_code = '29827' 
AND edm.diagnosis_code = 'M75.100'
ORDER BY edm.relevance_score DESC, epm.is_primary_indicator DESC
LIMIT 1;
```

---

## Data Pipeline Architecture

### Pipeline Stages

```
┌─────────────────────────────────────────────────────────────────┐
│                     INGESTION LAYER                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  EDI Files (837/270/271/278)                                   │
│          ↓                                                      │
│  Clearinghouse API / SFTP / Direct Connection                  │
│          ↓                                                      │
│  EDI Parser (X12 format → JSON/Relational)                     │
│          ↓                                                      │
│  Raw EDI Storage (S3/Blob + PostgreSQL)                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│                   TRANSFORMATION LAYER                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Episode Classification                                      │
│     - Map procedure codes → episode_code                        │
│     - Validate with diagnosis codes                             │
│     - Assign to episode_of_care_definition                      │
│                                                                 │
│  2. Intent Signal Extraction                                    │
│     - 270/271 → clinical_intent_event                          │
│     - 278 → clinical_intent_event                              │
│     - Calculate signal_strength scores                          │
│                                                                 │
│  3. Outcome Event Extraction                                    │
│     - 837 → clinical_outcome_event                             │
│     - Link to prior intent signals                              │
│                                                                 │
│  4. Feature Engineering                                         │
│     - Signal frequency counts                                   │
│     - Recency calculations                                      │
│     - Provider patterns                                         │
│     - Cost aggregations                                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│                    PREDICTION LAYER                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ML Model (per episode_code)                                    │
│     - Input: Intent signals + member features                   │
│     - Output: Probability, predicted date, cost                 │
│     - Store in: prediction_result table                         │
│                                                                 │
│  Batch Scoring (nightly)                                        │
│     - Score all members with active intent signals              │
│     - Refresh predictions older than 7 days                     │
│                                                                 │
│  Real-time Scoring (API)                                        │
│     - On-demand prediction for specific member                  │
│     - Used by care management workflows                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│                     ANALYTICS LAYER                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Dashboard APIs                                                 │
│     - Aggregate predictions by episode                          │
│     - Filter by region/network/plan                             │
│     - Time period comparisons                                   │
│                                                                 │
│  Model Performance Tracking                                     │
│     - Compare predictions vs outcomes                           │
│     - Calculate precision/recall by episode                     │
│     - Store in: episode_performance_metrics                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## SaaS Deployment Model

### Multi-Tenancy Strategy

**Option 1: Schema-per-Tenant** (Recommended for Healthcare)
```sql
-- Each customer gets own schema for data isolation
CREATE SCHEMA customer_acme;
CREATE SCHEMA customer_globex;

-- All tables replicated per schema
CREATE TABLE customer_acme.member (...);
CREATE TABLE customer_acme.clinical_intent_event (...);
CREATE TABLE customer_acme.prediction_result (...);
```

**Benefits**:
- HIPAA compliance easier (data isolation)
- Easier to backup/restore per customer
- Customer-specific customizations possible

**Option 2: Tenant ID Column** (More scalable)
```sql
-- Single shared schema with tenant_id column
ALTER TABLE member ADD COLUMN tenant_id VARCHAR(50);
ALTER TABLE clinical_intent_event ADD COLUMN tenant_id VARCHAR(50);

-- Row-level security
CREATE POLICY member_isolation ON member
    USING (tenant_id = current_setting('app.current_tenant')::VARCHAR);
```

---

## EDI Data Source Options

### Option 1: Direct Clearinghouse Integration (Best)
**Providers**: Change Healthcare, Availity, Waystar, Relay Health

**Pros**:
- Aggregates data from thousands of providers
- Already handles EDI parsing
- Real-time access to 270/271/278
- Claims data via 837

**Cons**:
- Requires business partnership
- May have data sharing restrictions

**Implementation**:
```javascript
// Example: Change Healthcare API
const response = await fetch('https://api.changehealthcare.com/edi/v1/270', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${apiKey}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    transaction_type: '270',
    date_range: { start: '2024-01-01', end: '2024-12-31' }
  })
});
```

### Option 2: Direct from Payer EDI Gateway (Custom)
**For each payer customer**:
- Connect to their EDI processing system
- Extract 837/270/271/278 transactions
- Parse and load into forecasting engine

**Pros**:
- Complete data access
- No third-party dependencies
- Customer controls data sharing

**Cons**:
- Custom integration per customer
- Need EDI parsing infrastructure

### Option 3: CMS Data for Medicare (Public but Limited)
**Use CMS SynPUFs for**:
- 837 claims data (historical outcomes)
- Training baseline models

**Generate synthetic**:
- 270/271 eligibility inquiries
- 278 prior auth requests

**Pros**:
- Free access
- Great for POC/demo

**Cons**:
- No real-time intent signals
- Medicare-only (no commercial payers)

---

## Next Steps for MVP

### Phase 1: Proof of Concept (Now)
✅ Multi-episode data schema
✅ EDI-compatible table structure
✅ Dashboard with episode selector
⏳ Use synthetic/mock data

### Phase 2: Single Customer Pilot
- Partner with 1 health plan
- Connect to their EDI gateway
- Load 6-12 months of historical 837 claims
- Generate synthetic 270/271/278 signals
- Train episode-specific models
- Deploy dashboard for their care management team

### Phase 3: Clearinghouse Integration
- Partner with Change Healthcare or Availity
- Access aggregated EDI transactions
- Scale to multiple payers
- Build multi-tenant SaaS infrastructure

### Phase 4: Full SaaS Launch
- Multi-episode support (10+ episodes)
- Real-time predictions
- Care management workflows
- Model performance monitoring
- Self-service onboarding

---

## Technical Stack Recommendation

```
Data Ingestion:    Node.js + EDI parser library (x12-parser, node-edifact)
Database:          PostgreSQL (or Supabase for managed)
ETL Orchestration: Airflow or Dagster
ML Pipeline:       Python (scikit-learn, XGBoost) + MLflow
API Layer:         Next.js API routes
Frontend:          Next.js + React + Recharts
Deployment:        Vercel (frontend) + AWS/GCP (data pipeline)
```

---

## Conclusion

**✅ EDI is the correct choice** for building a portable, payor-agnostic SaaS solution.

**Key Advantages**:
1. Universal standard (HIPAA-mandated)
2. Works with all payers and providers
3. Comprehensive data coverage (claims + intent signals)
4. Scalable via clearinghouse partnerships
5. No vendor lock-in

**Critical Success Factors**:
1. Start with 1-2 high-value episodes (TKA, THA)
2. Secure pilot customer with EDI access
3. Build robust episode classification logic
4. Prove ROI (cost savings, improved care management)
5. Scale via clearinghouse partnership

**This architecture positions you to build a true healthcare data platform.**
