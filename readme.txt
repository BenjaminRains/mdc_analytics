OpenDental Data Export Tools
===========================

Overview
--------
These scripts export data from OpenDental databases to CSV files for analysis. Data can be exported from either:
- MDC server backup databases
- Local OpenDental database

The exports are configured to:
- Pull the last 4 years of data
- Process large tables in chunks
- Mask sensitive information
- Save to standardized CSV files

Available Scripts
---------------

1. Export from MDC Server Backups (export_backup_data.py)
2. Export from Local OpenDental Database (export_local_data.py)


Directory Structure
-----------------
mdc_analytics/
├── raw_data/ # CSV output directory
├── scripts/
│ └── export/
│ ├── sql/ # SQL query files
│ ├── export_backup_data.py
│ └── export_local_data.py
└── src/
├── db_config.py # Database configurations
└── file_paths.py # File path mappings


Configured Tables
---------------
Clinical Data:
- appointment, appointmenttype, apptfield
- procedurelog, procedurecode, procnote, proctp
- perioexam, periomeasure
- treatplan

Financial Data:
- adjustment, payment, payplan, paysplit
- claim, claimpayment, claimproc
- fee, insbluebook, insbluebooklog

Reference Data:
- carrier, definition, referral
- schedule, recall

Important Notes
-------------
1. Never use the live "opendental" database
2. Large tables are processed in chunks (default: 10,000 rows)
3. Exports limited to past 4 years
4. Sensitive data (SSN, etc.) is masked
5. All data saved to: C:\Users\rains\mdc_analytics\raw_data\

Requirements
-----------
- requirements.txt file contains all dependencies
- Python 3.x
- MySQL Connector
- Database access credentials