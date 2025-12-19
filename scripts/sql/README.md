# SQL Scripts

Database schema and seed data scripts for the Clinical Forecasting Engine.

## Execution Order

Run these scripts in order to set up your database:

### 1. Create Tables
```bash
psql -d clinical_forecasting -f 01-create-tables-multi-episode.sql
```

Creates all base tables:
- `member` - Member demographics
- `eligibility_inquiry_event` - 270/271 EDI transactions
- `prior_auth_request` - 278 prior authorization data  
- `claim_header` & `claim_line` - 837 claims data
- `clinical_intent_event` - Unified intent signals
- `clinical_outcome_event` - Ground truth outcomes
- `episode_definition` - Episode of care definitions
- `procedure_code_map` & `diagnosis_code_map` - Code mappings
- `prediction_result` - ML model predictions

### 2. Seed Episode Definitions
```bash
psql -d clinical_forecasting -f 02-seed-episode-definitions.sql
```

Loads 23+ episodes of care with their associated CPT and ICD-10 codes:
- Orthopedic (TKA, THA, Spinal Fusion)
- Cardiac (CABG, PCI, Valve Replacement)
- Oncology (Mastectomy, Prostatectomy, Colorectal)
- Bariatric (Gastric Bypass, Sleeve Gastrectomy)
- And more...

### 3. Create EDI Loader Functions
```bash
psql -d clinical_forecasting -f 05-create-edi-loader-functions.sql
```

Creates PostgreSQL functions to parse and load EDI data:
- `load_270_271_batch()` - Parse 270/271 eligibility data
- `load_278_batch()` - Parse 278 prior auth data
- `load_837_batch()` - Parse 837 claims data
- `classify_episode()` - Auto-classify episodes from codes

## Schema Design

- **Source Tables**: Raw EDI data (270/271, 278, 837)
- **Canonical Layer**: Unified intent/outcome events
- **Analytics Layer**: Predictions and risk scores
- **Reference Tables**: Episodes, codes, members

## Data Flow

```
EDI Files → Source Tables → Clinical Intent/Outcome → ML Model → Predictions → Dashboard
