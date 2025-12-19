# Clinical Forecasting Engine - Data Schema

## Overview
This document outlines the complete data schema required to build the Clinical Forecasting Engine. The system predicts future clinical utilization (specifically Total Knee Arthroplasty/TKA procedures) using pre-claim intent signals.

---

## Core Tables

### 1. Members Table
Stores patient/member information for the health plan.

\`\`\`sql
CREATE TABLE members (
  member_id VARCHAR(50) PRIMARY KEY,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  date_of_birth DATE NOT NULL,
  gender VARCHAR(10),
  subscriber_id VARCHAR(50),
  group_number VARCHAR(50),
  plan_type VARCHAR(50), -- e.g., 'HMO', 'PPO', 'Medicare Advantage'
  enrollment_date DATE NOT NULL,
  termination_date DATE,
  address_line1 VARCHAR(200),
  address_line2 VARCHAR(200),
  city VARCHAR(100),
  state VARCHAR(2),
  zip_code VARCHAR(10),
  phone_number VARCHAR(20),
  email VARCHAR(100),
  primary_care_physician_id VARCHAR(50),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_members_subscriber ON members(subscriber_id);
CREATE INDEX idx_members_enrollment ON members(enrollment_date);
CREATE INDEX idx_members_active ON members(is_active);
\`\`\`

**Sample Data:**
\`\`\`json
{
  "member_id": "M-2024-789456",
  "first_name": "Sarah",
  "last_name": "Martinez",
  "date_of_birth": "1958-03-15",
  "gender": "F",
  "plan_type": "Medicare Advantage",
  "enrollment_date": "2023-01-01",
  "is_active": true
}
\`\`\`

---

### 2. Intent Signals Table
Captures all pre-claim intent signals from various EDI transactions.

\`\`\`sql
CREATE TABLE intent_signals (
  signal_id VARCHAR(50) PRIMARY KEY,
  member_id VARCHAR(50) NOT NULL REFERENCES members(member_id),
  signal_type VARCHAR(50) NOT NULL, -- '270_271', '278', 'REFERRAL', 'PHARMACY'
  signal_date TIMESTAMP NOT NULL,
  transaction_id VARCHAR(100),
  
  -- Procedure/Service Information
  procedure_code VARCHAR(20), -- CPT/HCPCS code
  procedure_description TEXT,
  diagnosis_codes TEXT[], -- Array of ICD-10 codes
  
  -- Provider Information
  requesting_provider_id VARCHAR(50),
  servicing_provider_id VARCHAR(50),
  facility_id VARCHAR(50),
  
  -- Signal Specific Details
  service_type_code VARCHAR(10), -- e.g., '35' for Surgery
  eligibility_status VARCHAR(50), -- 'ACTIVE', 'INACTIVE', 'ELIGIBLE'
  prior_auth_status VARCHAR(50), -- 'APPROVED', 'PENDING', 'DENIED'
  prior_auth_number VARCHAR(50),
  referral_type VARCHAR(50), -- 'SPECIALIST', 'SURGICAL'
  
  -- Temporal Information
  requested_service_date DATE,
  authorization_date DATE,
  authorization_end_date DATE,
  
  -- Clinical Context
  medical_necessity_text TEXT,
  clinical_notes TEXT,
  
  -- Metadata
  raw_transaction_data JSONB, -- Full EDI transaction
  processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_signals_member ON intent_signals(member_id);
CREATE INDEX idx_signals_type ON intent_signals(signal_type);
CREATE INDEX idx_signals_date ON intent_signals(signal_date);
CREATE INDEX idx_signals_procedure ON intent_signals(procedure_code);
CREATE INDEX idx_signals_service_date ON intent_signals(requested_service_date);
\`\`\`

**Sample Data:**
\`\`\`json
{
  "signal_id": "SIG-2024-123456",
  "member_id": "M-2024-789456",
  "signal_type": "270_271",
  "signal_date": "2024-11-15T10:30:00Z",
  "procedure_code": "27447",
  "procedure_description": "Total knee arthroplasty",
  "diagnosis_codes": ["M17.11", "M25.561"],
  "service_type_code": "35",
  "eligibility_status": "ACTIVE",
  "requested_service_date": "2025-01-20"
}
\`\`\`

---

### 3. Claims Table
Historical claims data for training models and validation.

\`\`\`sql
CREATE TABLE claims (
  claim_id VARCHAR(50) PRIMARY KEY,
  member_id VARCHAR(50) NOT NULL REFERENCES members(member_id),
  claim_type VARCHAR(20) NOT NULL, -- 'MEDICAL', 'PHARMACY', 'DENTAL'
  claim_status VARCHAR(20) NOT NULL, -- 'PAID', 'DENIED', 'PENDING'
  
  -- Service Information
  service_date DATE NOT NULL,
  admission_date DATE,
  discharge_date DATE,
  procedure_codes TEXT[], -- Array of CPT codes
  primary_procedure_code VARCHAR(20),
  diagnosis_codes TEXT[], -- Array of ICD-10 codes
  primary_diagnosis_code VARCHAR(20),
  drg_code VARCHAR(10), -- Diagnosis Related Group
  
  -- Provider Information
  billing_provider_id VARCHAR(50),
  servicing_provider_id VARCHAR(50),
  facility_id VARCHAR(50),
  place_of_service VARCHAR(10),
  
  -- Financial Information
  billed_amount DECIMAL(12, 2),
  allowed_amount DECIMAL(12, 2),
  paid_amount DECIMAL(12, 2),
  member_responsibility DECIMAL(12, 2),
  deductible_amount DECIMAL(12, 2),
  copay_amount DECIMAL(12, 2),
  coinsurance_amount DECIMAL(12, 2),
  
  -- Metadata
  received_date DATE NOT NULL,
  processed_date DATE,
  paid_date DATE,
  claim_line_number INTEGER,
  is_adjustment BOOLEAN DEFAULT false,
  original_claim_id VARCHAR(50),
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_claims_member ON claims(member_id);
CREATE INDEX idx_claims_service_date ON claims(service_date);
CREATE INDEX idx_claims_primary_procedure ON claims(primary_procedure_code);
CREATE INDEX idx_claims_status ON claims(claim_status);
CREATE INDEX idx_claims_received ON claims(received_date);
\`\`\`

**Sample Data:**
\`\`\`json
{
  "claim_id": "CLM-2024-987654",
  "member_id": "M-2024-789456",
  "claim_type": "MEDICAL",
  "claim_status": "PAID",
  "service_date": "2025-01-22",
  "primary_procedure_code": "27447",
  "diagnosis_codes": ["M17.11", "M25.561"],
  "billed_amount": 45000.00,
  "allowed_amount": 35000.00,
  "paid_amount": 28000.00,
  "received_date": "2025-02-05"
}
\`\`\`

---

### 4. Predictions Table
ML model predictions for future procedures.

\`\`\`sql
CREATE TABLE predictions (
  prediction_id VARCHAR(50) PRIMARY KEY,
  member_id VARCHAR(50) NOT NULL REFERENCES members(member_id),
  prediction_date TIMESTAMP NOT NULL,
  model_version VARCHAR(20) NOT NULL,
  
  -- Prediction Details
  procedure_code VARCHAR(20) NOT NULL,
  procedure_category VARCHAR(50), -- 'TKA', 'HIP_REPLACEMENT', 'CARDIAC'
  predicted_service_window_start DATE NOT NULL,
  predicted_service_window_end DATE NOT NULL,
  
  -- Probability and Confidence
  probability_score DECIMAL(5, 4) NOT NULL, -- 0.0000 to 1.0000
  confidence_level VARCHAR(20), -- 'HIGH', 'MEDIUM', 'LOW'
  risk_tier VARCHAR(20), -- 'TIER_1', 'TIER_2', 'TIER_3'
  
  -- Cost Estimation
  estimated_total_cost DECIMAL(12, 2),
  estimated_plan_cost DECIMAL(12, 2),
  estimated_member_cost DECIMAL(12, 2),
  cost_confidence_interval_low DECIMAL(12, 2),
  cost_confidence_interval_high DECIMAL(12, 2),
  
  -- Contributing Signals
  signal_count INTEGER,
  signal_ids TEXT[], -- Array of signal_id references
  primary_signal_type VARCHAR(50),
  days_since_first_signal INTEGER,
  
  -- Model Features (for explainability)
  feature_importance JSONB,
  model_metadata JSONB,
  
  -- Outcome Tracking
  actual_claim_id VARCHAR(50),
  actual_service_date DATE,
  prediction_outcome VARCHAR(20), -- 'TRUE_POSITIVE', 'FALSE_POSITIVE', 'PENDING'
  outcome_recorded_at TIMESTAMP,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_predictions_member ON predictions(member_id);
CREATE INDEX idx_predictions_probability ON predictions(probability_score DESC);
CREATE INDEX idx_predictions_window ON predictions(predicted_service_window_start, predicted_service_window_end);
CREATE INDEX idx_predictions_category ON predictions(procedure_category);
CREATE INDEX idx_predictions_outcome ON predictions(prediction_outcome);
\`\`\`

**Sample Data:**
\`\`\`json
{
  "prediction_id": "PRED-2024-555123",
  "member_id": "M-2024-789456",
  "prediction_date": "2024-11-20T08:00:00Z",
  "model_version": "v2.3",
  "procedure_code": "27447",
  "procedure_category": "TKA",
  "predicted_service_window_start": "2025-01-15",
  "predicted_service_window_end": "2025-02-15",
  "probability_score": 0.8750,
  "confidence_level": "HIGH",
  "estimated_total_cost": 35000.00,
  "signal_count": 4,
  "signal_ids": ["SIG-2024-123456", "SIG-2024-123457"],
  "days_since_first_signal": 45
}
\`\`\`

---

### 5. Procedures Reference Table
Master table for procedure codes and details.

\`\`\`sql
CREATE TABLE procedures_reference (
  procedure_code VARCHAR(20) PRIMARY KEY,
  procedure_type VARCHAR(10), -- 'CPT', 'HCPCS', 'ICD'
  short_description VARCHAR(200) NOT NULL,
  long_description TEXT,
  procedure_category VARCHAR(50), -- 'TKA', 'HIP_REPLACEMENT', 'CARDIAC'
  specialty VARCHAR(100),
  
  -- Cost Information
  average_allowed_amount DECIMAL(12, 2),
  average_paid_amount DECIMAL(12, 2),
  median_allowed_amount DECIMAL(12, 2),
  cost_range_low DECIMAL(12, 2),
  cost_range_high DECIMAL(12, 2),
  
  -- Clinical Information
  typical_diagnosis_codes TEXT[],
  requires_prior_auth BOOLEAN DEFAULT false,
  typical_length_of_stay INTEGER, -- in days
  is_inpatient BOOLEAN,
  is_surgical BOOLEAN,
  
  -- Metadata
  effective_date DATE,
  termination_date DATE,
  is_active BOOLEAN DEFAULT true,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_procedures_category ON procedures_reference(procedure_category);
CREATE INDEX idx_procedures_active ON procedures_reference(is_active);
\`\`\`

**Sample Data:**
\`\`\`json
{
  "procedure_code": "27447",
  "procedure_type": "CPT",
  "short_description": "Total knee arthroplasty",
  "procedure_category": "TKA",
  "specialty": "Orthopedic Surgery",
  "average_allowed_amount": 35000.00,
  "requires_prior_auth": true,
  "typical_length_of_stay": 2,
  "is_inpatient": true,
  "is_surgical": true
}
\`\`\`

---

### 6. Providers Table
Healthcare provider information.

\`\`\`sql
CREATE TABLE providers (
  provider_id VARCHAR(50) PRIMARY KEY,
  npi VARCHAR(10) UNIQUE NOT NULL,
  tax_id VARCHAR(20),
  
  -- Provider Details
  provider_type VARCHAR(50), -- 'INDIVIDUAL', 'ORGANIZATION'
  first_name VARCHAR(100),
  last_name VARCHAR(100),
  organization_name VARCHAR(200),
  specialty_primary VARCHAR(100),
  specialty_secondary VARCHAR(100),
  
  -- Location
  address_line1 VARCHAR(200),
  address_line2 VARCHAR(200),
  city VARCHAR(100),
  state VARCHAR(2),
  zip_code VARCHAR(10),
  county VARCHAR(100),
  phone_number VARCHAR(20),
  
  -- Network Information
  network_status VARCHAR(20), -- 'IN_NETWORK', 'OUT_OF_NETWORK'
  tier VARCHAR(20), -- 'TIER_1', 'TIER_2', 'TIER_3'
  accepting_new_patients BOOLEAN,
  
  -- Quality Metrics
  quality_score DECIMAL(3, 2),
  total_procedures_performed INTEGER,
  complication_rate DECIMAL(5, 4),
  
  -- Metadata
  effective_date DATE,
  termination_date DATE,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_providers_npi ON providers(npi);
CREATE INDEX idx_providers_specialty ON providers(specialty_primary);
CREATE INDEX idx_providers_network ON providers(network_status);
\`\`\`

---

### 7. Risk Scores Table
Historical risk scores for members over time.

\`\`\`sql
CREATE TABLE risk_scores (
  risk_score_id VARCHAR(50) PRIMARY KEY,
  member_id VARCHAR(50) NOT NULL REFERENCES members(member_id),
  score_date DATE NOT NULL,
  score_type VARCHAR(50), -- 'TKA_RISK', 'OVERALL_UTILIZATION', 'READMISSION'
  
  -- Score Values
  risk_score DECIMAL(5, 4) NOT NULL, -- 0.0000 to 1.0000
  risk_category VARCHAR(20), -- 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'
  percentile INTEGER, -- 1-100
  
  -- Contributing Factors
  contributing_factors JSONB,
  chronic_conditions TEXT[],
  recent_signals_count INTEGER,
  recent_claims_count INTEGER,
  
  -- Clinical Indicators
  has_diagnosis_history BOOLEAN,
  has_failed_conservative_treatment BOOLEAN,
  age_at_score INTEGER,
  bmi DECIMAL(5, 2),
  comorbidity_count INTEGER,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_risk_scores_member ON risk_scores(member_id);
CREATE INDEX idx_risk_scores_date ON risk_scores(score_date);
CREATE INDEX idx_risk_scores_score ON risk_scores(risk_score DESC);
CREATE INDEX idx_risk_scores_category ON risk_scores(risk_category);
\`\`\`

---

### 8. Care Management Actions Table
Track interventions and outreach to high-risk members.

\`\`\`sql
CREATE TABLE care_management_actions (
  action_id VARCHAR(50) PRIMARY KEY,
  member_id VARCHAR(50) NOT NULL REFERENCES members(member_id),
  prediction_id VARCHAR(50) REFERENCES predictions(prediction_id),
  
  -- Action Details
  action_type VARCHAR(50) NOT NULL, -- 'OUTREACH', 'CARE_COORDINATION', 'PRE_OP_EDUCATION'
  action_date DATE NOT NULL,
  assigned_to VARCHAR(100), -- Care manager name/ID
  priority VARCHAR(20), -- 'HIGH', 'MEDIUM', 'LOW'
  
  -- Contact Information
  contact_method VARCHAR(50), -- 'PHONE', 'EMAIL', 'MAIL', 'PORTAL'
  contact_outcome VARCHAR(50), -- 'COMPLETED', 'NO_ANSWER', 'SCHEDULED'
  contact_notes TEXT,
  
  -- Intervention Details
  intervention_type VARCHAR(100),
  resources_provided TEXT[],
  next_steps TEXT,
  follow_up_date DATE,
  
  -- Outcomes
  status VARCHAR(20), -- 'OPEN', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'
  completion_date DATE,
  outcome_notes TEXT,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_actions_member ON care_management_actions(member_id);
CREATE INDEX idx_actions_prediction ON care_management_actions(prediction_id);
CREATE INDEX idx_actions_status ON care_management_actions(status);
CREATE INDEX idx_actions_date ON care_management_actions(action_date);
\`\`\`

---

## Supporting Tables

### 9. Signal Processing Log
Tracks the processing of raw EDI transactions.

\`\`\`sql
CREATE TABLE signal_processing_log (
  log_id VARCHAR(50) PRIMARY KEY,
  transaction_id VARCHAR(100) NOT NULL,
  transaction_type VARCHAR(10), -- '270', '271', '278', etc.
  
  -- Processing Status
  processing_status VARCHAR(20), -- 'SUCCESS', 'FAILED', 'PARTIAL'
  received_at TIMESTAMP NOT NULL,
  processed_at TIMESTAMP,
  
  -- Data Quality
  data_quality_score DECIMAL(3, 2),
  validation_errors JSONB,
  missing_fields TEXT[],
  
  -- Results
  signals_created INTEGER DEFAULT 0,
  signal_ids TEXT[],
  error_message TEXT,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_processing_transaction ON signal_processing_log(transaction_id);
CREATE INDEX idx_processing_status ON signal_processing_log(processing_status);
CREATE INDEX idx_processing_received ON signal_processing_log(received_at);
\`\`\`

---

### 10. Model Performance Metrics
Track ML model performance over time.

\`\`\`sql
CREATE TABLE model_performance_metrics (
  metric_id VARCHAR(50) PRIMARY KEY,
  model_version VARCHAR(20) NOT NULL,
  evaluation_date DATE NOT NULL,
  evaluation_period_start DATE NOT NULL,
  evaluation_period_end DATE NOT NULL,
  
  -- Performance Metrics
  accuracy DECIMAL(5, 4),
  precision DECIMAL(5, 4),
  recall DECIMAL(5, 4),
  f1_score DECIMAL(5, 4),
  auc_roc DECIMAL(5, 4),
  
  -- Prediction Quality
  true_positives INTEGER,
  false_positives INTEGER,
  true_negatives INTEGER,
  false_negatives INTEGER,
  total_predictions INTEGER,
  
  -- Business Metrics
  cost_prediction_accuracy DECIMAL(5, 4),
  timing_accuracy_days DECIMAL(5, 2),
  intervention_success_rate DECIMAL(5, 4),
  
  -- Metadata
  training_data_size INTEGER,
  feature_count INTEGER,
  notes TEXT,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_metrics_model ON model_performance_metrics(model_version);
CREATE INDEX idx_metrics_date ON model_performance_metrics(evaluation_date);
\`\`\`

---

## Data Relationships

\`\`\`
members (1) ←→ (M) intent_signals
members (1) ←→ (M) claims
members (1) ←→ (M) predictions
members (1) ←→ (M) risk_scores
members (1) ←→ (M) care_management_actions

predictions (1) ←→ (M) care_management_actions
predictions (M) ←→ (1) claims (via actual_claim_id)

intent_signals (M) ←→ (1) providers (requesting_provider_id)
intent_signals (M) ←→ (1) providers (servicing_provider_id)
claims (M) ←→ (1) providers (billing_provider_id)
claims (M) ←→ (1) providers (servicing_provider_id)

intent_signals (M) ←→ (1) procedures_reference (procedure_code)
claims (M) ←→ (1) procedures_reference (primary_procedure_code)
predictions (M) ←→ (1) procedures_reference (procedure_code)
\`\`\`

---

## Data Flow

### 1. Signal Ingestion Pipeline
\`\`\`
EDI Transaction (270/271, 278, etc.)
  ↓
signal_processing_log (received)
  ↓
Parse & Validate
  ↓
intent_signals (created)
  ↓
signal_processing_log (completed)
\`\`\`

### 2. Prediction Generation Pipeline
\`\`\`
Aggregated Intent Signals (by member)
  +
Historical Claims Data
  +
Member Demographics
  +
Risk Scores
  ↓
ML Model Processing
  ↓
predictions (created)
  ↓
High Probability Predictions (> 0.75)
  ↓
care_management_actions (created)
\`\`\`

### 3. Outcome Validation Pipeline
\`\`\`
New Claim Received
  ↓
Match to Existing Predictions
  ↓
Update prediction.actual_claim_id
  ↓
Update prediction.prediction_outcome
  ↓
model_performance_metrics (aggregated)
\`\`\`

---

## API Endpoints Structure

### GET /api/members/{memberId}/signals
Returns all intent signals for a member.

**Response:**
\`\`\`json
{
  "member_id": "M-2024-789456",
  "signals": [
    {
      "signal_id": "SIG-2024-123456",
      "signal_type": "270_271",
      "signal_date": "2024-11-15T10:30:00Z",
      "procedure_code": "27447",
      "requested_service_date": "2025-01-20"
    }
  ],
  "total_count": 4
}
\`\`\`

### GET /api/predictions/high-risk
Returns high-probability predictions for upcoming procedures.

**Query Parameters:**
- `procedure_category`: Filter by category (e.g., 'TKA')
- `min_probability`: Minimum probability score (default: 0.75)
- `window_start`: Start of service window
- `window_end`: End of service window
- `page`: Page number
- `limit`: Results per page

**Response:**
\`\`\`json
{
  "predictions": [
    {
      "prediction_id": "PRED-2024-555123",
      "member": {
        "member_id": "M-2024-789456",
        "name": "Sarah Martinez",
        "age": 66
      },
      "procedure": "Total knee arthroplasty",
      "probability_score": 0.8750,
      "predicted_window": "2025-01-15 to 2025-02-15",
      "estimated_cost": 35000.00,
      "signal_count": 4,
      "days_since_first_signal": 45
    }
  ],
  "total_count": 247,
  "page": 1,
  "limit": 20
}
\`\`\`

### GET /api/dashboard/volume-forecast
Returns procedure volume forecast data.

**Query Parameters:**
- `procedure_category`: e.g., 'TKA'
- `months`: Number of months to forecast (default: 12)

**Response:**
\`\`\`json
{
  "procedure_category": "TKA",
  "forecast": [
    {
      "month": "2024-11",
      "actual_volume": 45,
      "predicted_volume": null,
      "actual_cost": 1575000.00
    },
    {
      "month": "2024-12",
      "actual_volume": null,
      "predicted_volume": 52,
      "predicted_cost": 1820000.00,
      "confidence_low": 48,
      "confidence_high": 56
    }
  ]
}
\`\`\`

### GET /api/dashboard/intent-signals-summary
Returns aggregated intent signal metrics.

**Response:**
\`\`\`json
{
  "period": "last_90_days",
  "signals": [
    {
      "signal_type": "270_271",
      "display_name": "Eligibility Queries",
      "total_count": 1247,
      "unique_members": 892,
      "trending": "up",
      "trend_percentage": 15.3
    },
    {
      "signal_type": "278",
      "display_name": "Prior Authorizations",
      "total_count": 386,
      "unique_members": 342,
      "trending": "up",
      "trend_percentage": 8.7
    }
  ]
}
\`\`\`

### POST /api/care-management/actions
Creates a care management action for a member.

**Request:**
\`\`\`json
{
  "member_id": "M-2024-789456",
  "prediction_id": "PRED-2024-555123",
  "action_type": "OUTREACH",
  "priority": "HIGH",
  "assigned_to": "care.manager@healthplan.com",
  "contact_method": "PHONE",
  "intervention_type": "Pre-operative education",
  "notes": "Schedule call to discuss surgery prep and recovery"
}
\`\`\`

---

## Data Sources

### Primary Data Sources

1. **EDI 270/271 Transactions** (Eligibility Inquiry/Response)
   - Source: Clearinghouse or direct from providers
   - Frequency: Real-time
   - Volume: ~1000-5000/day
   - Key fields: Member ID, service type, procedure codes, service dates

2. **EDI 278 Transactions** (Prior Authorization)
   - Source: Utilization management system
   - Frequency: Real-time
   - Volume: ~200-1000/day
   - Key fields: Member ID, procedure codes, authorization status, clinical notes

3. **Referral Data**
   - Source: Provider portal, EHR integrations
   - Frequency: Daily batch
   - Volume: ~500-2000/day
   - Key fields: Member ID, referring provider, specialist, referral reason

4. **Pharmacy Benefit Data**
   - Source: PBM (Pharmacy Benefit Manager)
   - Frequency: Daily batch
   - Volume: ~10000-50000/day
   - Key fields: Member ID, NDC codes, prescribing provider, fill dates

5. **Claims Data**
   - Source: Claims adjudication system
   - Frequency: Daily batch
   - Volume: ~5000-25000/day
   - Key fields: All claim detail fields (see claims table)

### Reference Data Sources

1. **Provider Directory**
   - Source: Network management system
   - Frequency: Weekly updates
   - Fields: NPI, specialty, network status, quality metrics

2. **Procedure Code Master**
   - Source: CMS, AMA (CPT codes)
   - Frequency: Annual updates (October)
   - Fields: Code descriptions, average costs, clinical details

---

## Data Quality Requirements

### Minimum Required Fields

**For Intent Signals:**
- member_id (must exist in members table)
- signal_type
- signal_date
- procedure_code OR diagnosis_codes (at least one)

**For Predictions:**
- member_id
- procedure_code
- probability_score
- predicted_service_window_start/end
- signal_count (must be > 0)

### Data Validation Rules

1. **Member ID Validation**
   - Must be active member
   - Must have valid enrollment dates
   - Must match format: M-YYYY-XXXXXX

2. **Date Consistency**
   - service_date <= claim received_date
   - predicted_service_window_start > prediction_date
   - signal_date <= requested_service_date

3. **Code Validation**
   - Procedure codes must exist in procedures_reference
   - Diagnosis codes must be valid ICD-10
   - Provider NPIs must be 10 digits

4. **Financial Validation**
   - allowed_amount >= paid_amount
   - billed_amount >= allowed_amount
   - paid_amount + member_responsibility = allowed_amount

---

## Performance Considerations

### Recommended Indexes (Already included above)

### Partitioning Strategy

\`\`\`sql
-- Partition large tables by date
-- intent_signals: partition by signal_date (monthly)
-- claims: partition by service_date (monthly)
-- predictions: partition by prediction_date (monthly)

-- Example for PostgreSQL
CREATE TABLE intent_signals (
  -- columns as defined above
) PARTITION BY RANGE (signal_date);

CREATE TABLE intent_signals_2024_11 PARTITION OF intent_signals
  FOR VALUES FROM ('2024-11-01') TO ('2024-12-01');
\`\`\`

### Data Retention Policy

- **intent_signals**: Keep 3 years
- **claims**: Keep 7 years (compliance requirement)
- **predictions**: Keep 2 years
- **care_management_actions**: Keep 5 years
- **signal_processing_log**: Keep 1 year

---

## Environment Variables Required

\`\`\`env
# Database
DATABASE_URL=postgresql://user:password@host:5432/clinical_forecasting
DATABASE_POOL_SIZE=20

# API Keys (if using external services)
EDI_CLEARINGHOUSE_API_KEY=xxx
PBM_API_KEY=xxx

# ML Model
MODEL_VERSION=v2.3
MODEL_API_ENDPOINT=https://ml-api.example.com
MODEL_CONFIDENCE_THRESHOLD=0.75

# Feature Flags
ENABLE_REAL_TIME_SCORING=true
ENABLE_CARE_MANAGEMENT_INTEGRATION=true
\`\`\`

---

## Initial Data Seeding

To populate the prototype with realistic data, you'll need:

1. **100-1000 sample members** with realistic demographics
2. **10-50 intent signals per high-risk member** over the past 90 days
3. **Historical claims data** for the past 12 months
4. **Procedure reference data** for common orthopedic procedures
5. **Provider directory** with 50-100 providers

Sample seeding scripts can be created in the `/scripts` folder using SQL or Python.

---

## Next Steps

1. Set up database integration (Supabase or Neon)
2. Create SQL migration scripts for all tables
3. Develop data seeding scripts
4. Build API routes for each endpoint
5. Connect frontend components to real data
6. Implement ML model integration (if available)
7. Set up data pipeline for intent signal ingestion

Would you like me to proceed with any of these steps?
