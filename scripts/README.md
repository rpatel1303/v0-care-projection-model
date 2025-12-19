# Scripts Directory

This directory contains all database and data loading scripts for the Clinical Forecasting Engine.

## Directory Structure

```
scripts/
├── sql/                    # All SQL database scripts
│   ├── 01-create-tables-multi-episode.sql
│   ├── 02-seed-episode-definitions.sql
│   └── 05-create-edi-loader-functions.sql
├── edi_loader/            # EDI data loading pipeline
│   ├── load_edi_data.py   # Main orchestrator
│   ├── parsers/           # EDI format parsers
│   │   ├── __init__.py
│   │   ├── parse_270_271.py
│   │   ├── parse_278.py
│   │   └── parse_837.py
│   └── README.md
└── README.md
```

## Quick Start

### 1. Setup Database Schema
```bash
# Run SQL scripts in order
psql -d your_database -f scripts/sql/01-create-tables-multi-episode.sql
psql -d your_database -f scripts/sql/02-seed-episode-definitions.sql
psql -d your_database -f scripts/sql/05-create-edi-loader-functions.sql
```

### 2. Load EDI Sample Data
```bash
# Run Python loader
cd scripts/edi_loader
python3 load_edi_data.py
```

See individual README files in each directory for detailed documentation.
