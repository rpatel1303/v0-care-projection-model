# EDI Data Loader

Python-based pipeline for parsing and loading HIPAA EDI X12 transactions into Supabase for the Clinical Forecasting Engine.

## Overview

This loader processes three EDI transaction types:
- **270/271** - Eligibility Inquiry/Response
- **278** - Prior Authorization Request/Response  
- **837** - Healthcare Claims (I=Institutional, P=Professional)

## Architecture

```
load_to_supabase.py (orchestrator)
├── parsers/parse_270_271.py
├── parsers/parse_278.py
└── parsers/parse_837.py
```

## Prerequisites

### 1. Install Dependencies
```bash
pip install supabase python-dotenv
```

### 2. Set Up Environment Variables

Create a `.env.local` file in the project root with:
```env
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

### 3. Create Database Schema

Run the SQL schema creation script in Supabase:
```bash
# v0 can run this directly, or you can run it manually
psql -h db.your-project.supabase.co -U postgres -d postgres -f scripts/sql/01-create-supabase-schema.sql
```

## Usage

### Basic Usage (Recommended)
```bash
cd scripts/edi_loader
python3 load_to_supabase.py --env-file ../../.env.local
```

This will:
1. Load member demographics from JSON
2. Parse and load 270/271 eligibility inquiries
3. Parse and load 278 prior authorizations
4. Parse and load 837 claims
5. Generate clinical intent events
6. Generate prediction results

## Sample Data

Sample files are located in `sample-data/`:
- `members.json` - Member demographics (JSON format, must load first)
- `270-eligibility-requests.edi` - Eligibility inquiries
- `278-prior-auth-requests.edi` - Prior authorization requests
- `837I-institutional-claims.edi` - Institutional claims

## Referential Integrity

The loader processes files in this order to maintain referential integrity:

1. **Members** - Load member demographics first (from JSON)
2. **Eligibility (270/271)** - References members
3. **Prior Auth (278)** - References members  
4. **Claims (837)** - References members
5. **Intent Events** - Derived from eligibility + PA
6. **Predictions** - Derived from intent signals

## Data Flow

```
EDI Files → Parsers → JSON → Supabase Client → PostgreSQL Tables
```

Each parser outputs clean JSON that maps to the canonical Supabase schema.

## Error Handling

- Validates EDI format before parsing
- Logs all errors with context
- Uses upsert for idempotent loading
- Reports summary at completion

## Extension

To add new EDI transaction types:

1. Create parser in `parsers/parse_XXX.py`
2. Implement `parse()` method returning list of dicts
3. Add to `load_to_supabase.py` orchestrator
4. Ensure proper table references in schema

## Production Deployment

For production, consider:
- **Scheduled runs** - Cron job or Airflow DAG
- **Incremental loading** - Process only new files
- **Error notifications** - Alert on failures
- **Data quality checks** - Validate before loading
- **Audit logging** - Track all data changes
