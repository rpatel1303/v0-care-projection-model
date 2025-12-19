# SQL Scripts

Database schema and seed data scripts for the Clinical Forecasting Engine.

## Execution Order

**IMPORTANT: Run scripts in this exact order:**

### Step 1: Create All Tables and Functions
```bash
# In Supabase SQL Editor or psql:
psql -d your_database -f 00-consolidated-schema.sql
```

This single script creates:
- All 12 tables with correct column names
- All indexes (without IMMUTABLE function issues)
- All EDI loader functions
- Intent/outcome event generator functions
- New episode_code_mapping table for database-driven rules

### Step 2: Seed Episode Definitions
```bash
psql -d your_database -f 02-seed-episode-definitions.sql
```

Loads 8 episodes of care (TKA, THA, Spinal Fusion, CABG, PCI, Bariatric, Colorectal, Mastectomy).

### Step 3: Seed Code Mappings
```bash
psql -d your_database -f 03-seed-code-mappings.sql
```

Loads CPT, ICD-10, and NDC code mappings for episode classification. Must run AFTER step 2.

### Step 4: Load Sample Data
```bash
psql -d your_database -f 04-load-sample-data.sql
```

Loads sample member data, clinical intent events, and predictions for testing. This provides realistic data for the dashboard without requiring EDI file parsing.

### Step 5: Load Sample EDI Data (Optional - Advanced)
```bash
cd ../edi_loader
python load_to_supabase.py
```

Parses sample EDI files and populates tables. Use this for full EDI integration testing.

## Fixed Issues

- ✅ Consolidated conflicting schemas (01-create-tables.sql and 01-create-supabase-schema.sql)
- ✅ Fixed column name: `inquiry_ts` → `inquiry_date`
- ✅ Added missing `enrollment_status` column to member table
- ✅ Fixed GET DIAGNOSTICS syntax: `= ROW_COUNT` → `:= ROW_COUNT`
- ✅ Removed IMMUTABLE function issues from partial indexes
- ✅ All functions now reference correct column names
- ✅ Added episode_code_mapping table for database-driven business rules

## Schema Design

- **Source Tables**: Raw EDI data (270/271, 278, 837, Rx benefit checks)
- **Canonical Layer**: Unified intent/outcome events
- **Analytics Layer**: Predictions and risk scores
- **Reference Tables**: Episodes, codes, members
- **Rules Engine**: episode_code_mapping for flexible code classification

## Data Flow

```
EDI Files → Source Tables → Clinical Intent/Outcome → ML Model → Predictions → Dashboard
