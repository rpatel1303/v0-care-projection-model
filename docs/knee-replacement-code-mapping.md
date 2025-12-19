# Knee Replacement Episode - Clinical Code Mapping

## Overview
This document details how clinical codes (ICD-10 diagnosis codes and CPT procedure codes) map to the **Total Knee Replacement (TKA)** episode of care in our forecasting system.

## Episode Definition

| Field | Value |
|-------|-------|
| **Episode ID** | `TKA` |
| **Episode Name** | Total Knee Replacement |
| **Category** | Orthopedic |
| **Average Cost** | $45,000 - $55,000 |
| **Typical LOS** | 2-3 days (inpatient) or same-day (outpatient) |

---

## Procedure Code Mapping (CPT Codes)

### Primary Procedure Code
| CPT Code | Description | Episode Role |
|----------|-------------|--------------|
| **27447** | **Total Knee Arthroplasty** | Primary (defines the episode) |

### Related Procedure Codes
| CPT Code | Description | Episode Role |
|----------|-------------|--------------|
| 27446 | Knee arthroplasty with prosthetic replacement | Secondary |

### Database Schema
```sql
episode_procedure_map
├── episode_id: 'TKA'
├── procedure_code: '27447'
├── code_type: 'CPT'
├── is_primary: TRUE
└── procedure_description: 'Total Knee Arthroplasty'
```

---

## Diagnosis Code Mapping (ICD-10 Codes)

### Primary Diagnosis Codes
| ICD-10 Code | Description | Laterality | Episode Role |
|-------------|-------------|------------|--------------|
| **M17.11** | Unilateral primary osteoarthritis, right knee | Right | Primary |
| **M17.12** | Unilateral primary osteoarthritis, left knee | Left | Primary |

### Secondary Diagnosis Codes
| ICD-10 Code | Description | Episode Role |
|-------------|-------------|--------------|
| M17.0 | Bilateral primary osteoarthritis of knee | Secondary |
| M25.561 | Pain in right knee | Supporting |
| M25.562 | Pain in left knee | Supporting |
| Z96.651 | Presence of right artificial knee joint | Post-op/History |
| Z96.652 | Presence of left artificial knee joint | Post-op/History |

### Database Schema
```sql
episode_diagnosis_map
├── episode_id: 'TKA'
├── diagnosis_code: 'M17.11' | 'M17.12' | 'M17.0'
├── code_type: 'ICD10'
├── is_primary: TRUE/FALSE
└── diagnosis_description: 'Osteoarthritis of knee'
```

---

## How Episode Classification Works

### 1. **Claims (837 EDI)**
When a claim arrives, the system looks up the procedure code:

```sql
SELECT episode_id 
FROM episode_procedure_map 
WHERE procedure_code = '27447'
-- Returns: 'TKA'
```

**Classification Logic:**
- If claim line contains CPT **27447** → Episode = **TKA**
- Creates `clinical_outcome_event` (actual procedure occurred)

### 2. **Prior Authorization (278 EDI)**
When a PA request arrives:

```sql
SELECT episode_id 
FROM episode_procedure_map 
WHERE procedure_code = '27447'
-- Returns: 'TKA'
```

**Classification Logic:**
- If 278 contains CPT **27447** and status = 'approved' → High intent signal (90%)
- Creates `clinical_intent_event` with signal_strength = 90.0

### 3. **Eligibility Inquiry (270/271 EDI)**
When checking benefits:

```sql
SELECT episode_id 
FROM episode_procedure_map 
WHERE procedure_code = '27447'
-- Returns: 'TKA'
```

**Classification Logic:**
- If 270 inquires about CPT **27447** → Moderate intent signal (60-75%)
- Creates `clinical_intent_event` with signal_strength = 60-75

### 4. **Referral (278 EDI - Referral Type)**
When PCP refers to orthopedic surgeon:

```sql
-- Referral uses diagnosis code if no procedure code present
SELECT episode_id, relevance_score
FROM episode_diagnosis_map
WHERE diagnosis_code = 'M17.11'
ORDER BY relevance_score DESC
-- Returns: 'TKA'
```

**Classification Logic:**
- If 278 referral contains diagnosis **M17.11** + referred_provider_specialty = 'Orthopedic Surgery' → Moderate signal (70%)
- Creates `clinical_intent_event` with event_type = 'Referral'

### 5. **Rx Benefit Check (NCPDP/proprietary)**
When member checks coverage for knee-related medications:

```sql
-- Map drug class to episode
CASE 
  WHEN drug_class IN ('NSAID', 'Opioid', 'Viscosupplement') THEN 'TKA'
END
```

**Classification Logic:**
- If checking coverage for **Synvisc** (hyaluronic acid injection) → High signal (80%)
- If checking coverage for **Celebrex** (NSAID) → Moderate signal (50%)
- Creates `clinical_intent_event` with event_type = 'Rx_Benefit_Check'

---

## Complete Code List for TKA Episode

### CPT Procedure Codes
```
27447 - Total Knee Arthroplasty (PRIMARY)
27446 - Knee arthroplasty with prosthetic replacement
```

### ICD-10 Diagnosis Codes
```
Primary:
  M17.11 - Unilateral primary OA, right knee
  M17.12 - Unilateral primary OA, left knee

Secondary:
  M17.0  - Bilateral primary OA of knee
  M25.561 - Pain in right knee
  M25.562 - Pain in left knee
  M23.8X1 - Other internal derangements of right knee
  M23.8X2 - Other internal derangements of left knee
```

### Related Drug Classes (Rx Signals)
```
High Signal (80%):
  - Viscosupplement (Synvisc, Supartz) - hyaluronic acid injections
  - Opioids (Oxycodone, Hydrocodone) - post-surgical pain

Moderate Signal (50%):
  - NSAIDs (Celecoxib/Celebrex, Meloxicam) - pain management
  - Corticosteroids (Methylprednisolone) - inflammation

Low Signal (30%):
  - OTC Pain relievers - general pain
```

---

## Signal Strength Scoring

### Intent Signal Weights by Event Type

| Event Type | Signal Strength | Reasoning |
|------------|-----------------|-----------|
| **Prior Auth Approved** | 90% | Strong commitment - surgery scheduled |
| **Prior Auth Requested** | 85% | High intent - actively pursuing |
| **Rx: Viscosupplement** | 80% | Last conservative treatment before surgery |
| **Prior Auth Pended** | 70% | May require additional documentation |
| **Referral to Ortho** | 70% | Specialty evaluation for surgical candidacy |
| **Eligibility with PA Req** | 75% | Checking benefits + PA noted |
| **Eligibility Covered** | 60% | General benefit inquiry |
| **Rx: Opioid** | 60% | Post-op prescription or chronic pain |
| **Rx: NSAID** | 50% | Conservative pain management |

---

## Database Queries

### Find all members with TKA intent signals
```sql
SELECT 
  m.member_id,
  m.first_name,
  m.last_name,
  ci.event_type,
  ci.event_date,
  ci.signal_strength,
  ci.procedure_code,
  ci.diagnosis_code
FROM clinical_intent_event ci
JOIN member m ON ci.member_id = m.member_id
WHERE ci.episode_id = 'TKA'
ORDER BY ci.signal_strength DESC, ci.event_date DESC;
```

### Find members who had TKA procedure
```sql
SELECT 
  m.member_id,
  m.first_name,
  m.last_name,
  co.procedure_date,
  co.total_cost,
  co.procedure_code
FROM clinical_outcome_event co
JOIN member m ON co.member_id = m.member_id
WHERE co.episode_id = 'TKA'
ORDER BY co.procedure_date DESC;
```

### Calculate member risk score for TKA
```sql
SELECT 
  member_id,
  COUNT(*) as signal_count,
  AVG(signal_strength) as avg_signal_strength,
  MAX(signal_strength) as max_signal_strength,
  STRING_AGG(DISTINCT event_type, ', ') as signal_types
FROM clinical_intent_event
WHERE episode_id = 'TKA'
  AND event_date >= NOW() - INTERVAL '6 months'
GROUP BY member_id
HAVING AVG(signal_strength) > 60
ORDER BY avg_signal_strength DESC;
```

---

## Production Considerations

### Data Quality Rules
1. **Laterality matters**: M17.11 vs M17.12 affects scheduling and inventory
2. **Code recency**: Intent signals older than 12 months decay in strength
3. **Multiple signals**: Stacking (PA + Rx + Referral) increases confidence
4. **Prior history**: Z96.651/652 indicates previous surgery, affects bilateral cases

### Episode Attribution Logic
```python
def classify_episode(procedure_code=None, diagnosis_code=None, drug_class=None):
    """
    Priority order:
    1. Procedure code (most definitive)
    2. Diagnosis code (if no procedure)
    3. Drug class (weakest signal)
    """
    if procedure_code:
        return lookup_procedure_map(procedure_code)
    elif diagnosis_code:
        return lookup_diagnosis_map(diagnosis_code)
    elif drug_class:
        return infer_from_medication(drug_class)
    else:
        return None
```

### Future Enhancements
- Add **CPT 27486** (revision TKA) for tracking revisions
- Include **G-codes** for functional status reporting
- Map **DRG 469/470** (major joint replacement) for bundled payment alignment
- Add **HCPCS codes** for implant tracking (e.g., C1776 - knee implant)

---

## References
- [CMS CPT Code Lookup](https://www.cms.gov/medicare-coverage-database/view/article.aspx?articleid=52423)
- [ICD-10 M17 Osteoarthritis of Knee](https://www.icd10data.com/ICD10CM/Codes/M00-M99/M15-M19/M17-)
- [NCPDP D.0 Standard for Pharmacy Transactions](https://www.ncpdp.org/)
