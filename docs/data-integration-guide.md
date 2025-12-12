# Clinical Forecasting Engine - Data Integration Guide

## Overview
This guide explains how to connect the prototype dashboard to your actual healthcare data sources based on the implemented database schema.

## Database Schema Summary

The system uses 9 core tables organized in layers:

### 1. Source System Tables (Raw Data Ingestion)
- **eligibility_inquiry_event** - 270/271 EDI transactions from eligibility gateway
- **prior_auth_request** - PA requests from UM/PA system or 278 EDI stream
- **claim_header** + **claim_line** - Claims from adjudication system

### 2. Canonical Layer (Unified Intent Signals)
- **clinical_intent_event** - All intent signals in standardized format
- **service_category_code_map** - CPT/ICD-10 to service category mappings

### 3. Outcome Layer (Ground Truth)
- **clinical_outcome_event** - Confirmed clinical events derived from claims

### 4. Prediction Layer
- **prediction_result** - Model output with probability scores and risk tiers

## Data Pipeline Flow

\`\`\`
Source Systems → Raw Tables → clinical_intent_event → ML Model → prediction_result → Dashboard
                                      ↓
                              clinical_outcome_event (for training/validation)
\`\`\`

## SQL Queries Used by API Endpoints

### 1. Dashboard Summary (`/api/dashboard/summary`)

\`\`\`sql
-- Predicted Volume
SELECT 
  COUNT(CASE WHEN predicted_event_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 30 THEN 1 END) as next30Days,
  COUNT(CASE WHEN predicted_event_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 60 THEN 1 END) as next60Days,
  COUNT(CASE WHEN predicted_event_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 90 THEN 1 END) as next90Days
FROM prediction_result
WHERE event_type = 'tka' 
  AND probability >= 0.65
  AND prediction_date = CURRENT_DATE;

-- Intent Signals Count
SELECT 
  signal_type,
  COUNT(*) as signal_count
FROM clinical_intent_event
WHERE intent_ts >= CURRENT_DATE - INTERVAL '90 days'
  AND service_category = 'ortho_knee'
GROUP BY signal_type;

-- Model Accuracy (from validation set)
SELECT 
  AVG(CASE WHEN outcome_occurred THEN 1 ELSE 0 END) as accuracy
FROM prediction_validation_results
WHERE prediction_date >= CURRENT_DATE - INTERVAL '180 days';
\`\`\`

### 2. TKA Volume Forecast (`/api/dashboard/forecast`)

\`\`\`sql
-- Historical Actuals (from claims)
SELECT 
  DATE_TRUNC('month', event_date) as month,
  COUNT(*) as actual_count
FROM clinical_outcome_event
WHERE event_type = 'tka'
  AND event_date >= CURRENT_DATE - INTERVAL '6 months'
GROUP BY month
ORDER BY month;

-- Predicted Future (from model)
SELECT 
  DATE_TRUNC('month', predicted_event_date) as month,
  COUNT(*) as predicted_count,
  PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY probability) as lower_confidence,
  PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY probability) as upper_confidence
FROM prediction_result
WHERE event_type = 'tka'
  AND predicted_event_date >= CURRENT_DATE
  AND probability >= 0.65
GROUP BY month
ORDER BY month;
\`\`\`

### 3. High-Risk Members (`/api/dashboard/members`)

\`\`\`sql
SELECT 
  p.member_id,
  m.date_of_birth,
  m.gender,
  p.probability,
  p.predicted_event_date,
  p.risk_tier,
  p.contributing_signals,
  -- Aggregate intent signals
  ARRAY_AGG(
    JSON_BUILD_OBJECT(
      'type', cie.signal_type,
      'date', cie.intent_ts,
      'details', cie.metadata_json->>'details',
      'strength', cie.signal_strength
    ) ORDER BY cie.intent_ts
  ) as signals,
  -- Get latest PA info for diagnosis codes
  (
    SELECT ARRAY_AGG(DISTINCT unnest(diagnosis_codes))
    FROM prior_auth_request pa
    WHERE pa.member_id = p.member_id
      AND pa.request_ts >= CURRENT_DATE - INTERVAL '90 days'
      AND 'ortho_knee' = ANY(
        SELECT service_category 
        FROM service_category_code_map 
        WHERE code = ANY(pa.procedure_codes)
      )
  ) as diagnosis_codes
FROM prediction_result p
JOIN member m ON p.member_id = m.member_id
LEFT JOIN clinical_intent_event cie ON p.member_id = cie.member_id
  AND cie.intent_ts >= CURRENT_DATE - INTERVAL '90 days'
  AND cie.service_category = 'ortho_knee'
WHERE p.event_type = 'tka'
  AND p.risk_tier IN ('very_high', 'high')
  AND p.prediction_date = CURRENT_DATE
GROUP BY p.prediction_id, m.member_id
ORDER BY p.probability DESC
LIMIT 20;
\`\`\`

### 4. Intent Signals Overview (`/api/dashboard/signals`)

\`\`\`sql
-- Signals by Type
SELECT 
  signal_type,
  COUNT(*) as signal_count,
  ROUND(
    100.0 * (COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY MAX(intent_ts))) / 
    LAG(COUNT(*)) OVER (ORDER BY MAX(intent_ts))
  ) as change_percent
FROM clinical_intent_event
WHERE service_category = 'ortho_knee'
  AND intent_ts >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY signal_type;

-- Timeline (weekly aggregation)
SELECT 
  DATE_TRUNC('week', intent_ts) as week,
  COUNT(CASE WHEN signal_type = 'elig' THEN 1 END) as elig_count,
  COUNT(CASE WHEN signal_type = 'pa' THEN 1 END) as pa_count,
  COUNT(CASE WHEN signal_type = 'referral' THEN 1 END) as referral_count
FROM clinical_intent_event
WHERE service_category = 'ortho_knee'
  AND intent_ts >= CURRENT_DATE - INTERVAL '60 days'
GROUP BY week
ORDER BY week;
\`\`\`

## Data Integration Steps

### Step 1: Load Service Category Mappings
\`\`\`bash
# Run the service category mapping script first
psql -h your-db-host -d your-db -f scripts/02-seed-service-category-map.sql
\`\`\`

### Step 2: Set Up ETL Pipelines

#### Eligibility Events Pipeline
\`\`\`sql
-- Example ETL from your EDI gateway to eligibility_inquiry_event
INSERT INTO eligibility_inquiry_event (
  inquiry_ts, source_channel, payer_id, member_id, provider_npi,
  service_type_codes, coverage_status, plan_id
)
SELECT 
  transaction_timestamp,
  'edi_gateway',
  sending_payer_id,
  subscriber_id,
  requesting_provider_npi,
  ARRAY_AGG(service_type_code),
  coverage_status,
  plan_identifier
FROM your_edi_270_271_log
WHERE transaction_date >= CURRENT_DATE - 1
GROUP BY 1,2,3,4,5,7,8;
\`\`\`

#### Prior Auth Pipeline
\`\`\`sql
-- Example ETL from UM system to prior_auth_request
INSERT INTO prior_auth_request (
  request_ts, decision_ts, status, member_id, requesting_provider_npi,
  procedure_codes, diagnosis_codes, service_from_date, clinical_type, plan_id
)
SELECT 
  case_created_date,
  decision_date,
  case_status,
  member_number,
  ordering_provider_npi,
  STRING_TO_ARRAY(requested_cpts, ','),
  STRING_TO_ARRAY(diagnosis_codes, ','),
  requested_service_date,
  service_category,
  member_plan_id
FROM your_um_system.pa_cases
WHERE case_created_date >= CURRENT_DATE - 1;
\`\`\`

#### Claims Pipeline
\`\`\`sql
-- Example ETL from claims warehouse
INSERT INTO claim_header (...)
SELECT ... FROM your_claims_warehouse.paid_claims;

INSERT INTO claim_line (...)
SELECT ... FROM your_claims_warehouse.claim_details;
\`\`\`

### Step 3: Build clinical_intent_event

\`\`\`sql
-- Populate from eligibility events
INSERT INTO clinical_intent_event (
  intent_ts, member_id, provider_npi, signal_type, service_category,
  codes, signal_strength, source_system, source_record_id
)
SELECT 
  e.inquiry_ts,
  e.member_id,
  e.provider_npi,
  'elig',
  m.service_category,
  e.service_type_codes,
  0.35, -- base weight for eligibility queries
  'edi_gateway',
  e.elig_event_id::text
FROM eligibility_inquiry_event e
JOIN service_category_code_map m 
  ON m.code = ANY(e.service_type_codes)
  AND m.code_system = 'X12_STC'
WHERE m.service_category = 'ortho_knee'
  AND e.inquiry_ts >= CURRENT_DATE - 90;

-- Populate from PA requests
INSERT INTO clinical_intent_event (
  intent_ts, member_id, provider_npi, signal_type, service_category,
  codes, signal_strength, source_system, source_record_id
)
SELECT 
  pa.request_ts,
  pa.member_id,
  pa.requesting_provider_npi,
  'pa',
  'ortho_knee',
  pa.procedure_codes || pa.diagnosis_codes,
  CASE pa.status
    WHEN 'approved' THEN 0.95
    WHEN 'pended' THEN 0.75
    WHEN 'requested' THEN 0.65
    ELSE 0.50
  END,
  'pa_system',
  pa.pa_id::text
FROM prior_auth_request pa
WHERE EXISTS (
  SELECT 1 FROM service_category_code_map m
  WHERE m.code = ANY(pa.procedure_codes)
    AND m.service_category = 'ortho_knee'
)
AND pa.request_ts >= CURRENT_DATE - 90;
\`\`\`

### Step 4: Build clinical_outcome_event (Ground Truth)

\`\`\`sql
-- Identify TKA procedures from claims
INSERT INTO clinical_outcome_event (
  member_id, event_type, event_date, confirming_claim_id,
  confirming_codes, allowed_amt, provider_npi
)
SELECT 
  ch.member_id,
  'tka',
  MIN(cl.service_date) as event_date,
  ch.claim_id,
  ARRAY_AGG(DISTINCT cl.procedure_code),
  SUM(cl.allowed_amt),
  ch.rendering_provider_npi
FROM claim_header ch
JOIN claim_line cl ON ch.claim_id = cl.claim_id
JOIN service_category_code_map m 
  ON cl.procedure_code = m.code 
  AND m.service_category = 'ortho_knee'
  AND m.code_system = 'CPT'
WHERE cl.service_date >= CURRENT_DATE - 180
  AND ch.claim_status = 'paid'
GROUP BY ch.member_id, ch.claim_id, ch.rendering_provider_npi;
\`\`\`

### Step 5: Run Prediction Model

\`\`\`python
# Example model scoring script
import pandas as pd
from sklearn.ensemble import GradientBoostingClassifier

# Features from clinical_intent_event
features = pd.read_sql("""
    SELECT 
        member_id,
        COUNT(*) as signal_count,
        MAX(signal_strength) as max_strength,
        AVG(signal_strength) as avg_strength,
        COUNT(DISTINCT signal_type) as signal_variety,
        MAX(CASE WHEN signal_type = 'pa' THEN 1 ELSE 0 END) as has_pa,
        DATEDIFF('day', MAX(intent_ts), CURRENT_DATE) as days_since_last_signal
    FROM clinical_intent_event
    WHERE service_category = 'ortho_knee'
        AND intent_ts >= CURRENT_DATE - 90
    GROUP BY member_id
""", conn)

# Predict
predictions = model.predict_proba(features)[:, 1]

# Write to prediction_result table
for idx, row in features.iterrows():
    cursor.execute("""
        INSERT INTO prediction_result (
            member_id, event_type, prediction_date, predicted_event_date,
            probability, risk_tier, model_version
        ) VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, (
        row['member_id'],
        'tka',
        date.today(),
        date.today() + timedelta(days=45),  # Estimate
        predictions[idx],
        'very_high' if predictions[idx] >= 0.85 else 'high',
        'v1.0'
    ))
\`\`\`

## Connecting to Dashboard API Routes

Update the API routes in `/app/api/dashboard/*` to connect to your database instead of returning mock data:

\`\`\`typescript
// Example: app/api/dashboard/summary/route.ts
import { sql } from '@vercel/postgres' // or your DB client

export async function GET() {
  const { rows } = await sql`
    SELECT 
      COUNT(CASE WHEN predicted_event_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 30 THEN 1 END) as next30,
      COUNT(CASE WHEN predicted_event_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 60 THEN 1 END) as next60,
      COUNT(CASE WHEN predicted_event_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 90 THEN 1 END) as next90
    FROM prediction_result
    WHERE event_type = 'tka' AND probability >= 0.65
  `
  
  return NextResponse.json({
    predictedVolume: {
      next30Days: rows[0].next30,
      next60Days: rows[0].next60,
      next90Days: rows[0].next90
    },
    // ... other fields
  })
}
\`\`\`

## Data Refresh Schedule

Recommended refresh intervals:
- **eligibility_inquiry_event**: Near real-time or hourly
- **prior_auth_request**: Every 15-30 minutes
- **claim_header/line**: Daily batch
- **clinical_intent_event**: Hourly incremental
- **clinical_outcome_event**: Daily
- **prediction_result**: Daily full refresh

## Next Steps

1. Run the 3 SQL schema scripts in order
2. Set up ETL pipelines for your source systems
3. Build the canonical intent event layer
4. Train/deploy your prediction model
5. Update API routes to query your database
6. Deploy the dashboard

For questions or assistance, refer to the schema documentation in `/docs/data-schema.md`.
