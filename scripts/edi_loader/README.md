# EDI Data Loader

Python-based pipeline for parsing and loading HIPAA EDI X12 transactions into the Clinical Forecasting Engine database.

## Overview

This loader processes three EDI transaction types:
- **270/271** - Eligibility Inquiry/Response
- **278** - Prior Authorization Request/Response  
- **837** - Healthcare Claims (I=Institutional, P=Professional)

## Architecture

```
load_edi_data.py (orchestrator)
├── parsers/parse_270_271.py
├── parsers/parse_278.py
└── parsers/parse_837.py
```

## Usage

### Basic Usage
```bash
python3 load_edi_data.py
```

### With Custom Database Connection
```bash
export DB_HOST=localhost
export DB_NAME=clinical_forecasting
export DB_USER=your_user
export DB_PASSWORD=your_password

python3 load_edi_data.py
```

### Load Specific EDI Type
```python
from load_edi_data import EDIDataLoader

loader = EDIDataLoader()
loader.load_eligibility_data('sample-data/270-eligibility-requests.edi')
```

## Sample Data

Sample EDI files are located in `sample-data/`:
- `members-master.txt` - Member demographics (must load first)
- `270-eligibility-requests.edi` - Eligibility inquiries
- `278-prior-auth-requests.edi` - Prior authorization requests
- `837I-institutional-claims.edi` - Institutional claims

## Referential Integrity

The loader processes files in this order to maintain referential integrity:

1. **Members** - Load member demographics first
2. **Eligibility (270/271)** - References members
3. **Prior Auth (278)** - References members  
4. **Claims (837)** - References members

## Dependencies

```bash
pip install psycopg2-binary python-dotenv
```

## Database Functions

The loader calls PostgreSQL functions created by `sql/05-create-edi-loader-functions.sql`:
- `load_270_271_batch(jsonb)` - Bulk insert eligibility data
- `load_278_batch(jsonb)` - Bulk insert PA data
- `load_837_batch(jsonb)` - Bulk insert claims data

## Error Handling

- Validates EDI format before parsing
- Logs all errors with line numbers
- Continues processing on non-fatal errors
- Reports summary at completion

## Extension

To add new EDI transaction types:

1. Create parser in `parsers/parse_XXX.py`
2. Implement `parse_XXX(file_path)` function
3. Add to `load_edi_data.py` orchestrator
4. Create corresponding SQL loader function
