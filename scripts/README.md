# Scripts Directory Structure

## Overview
This directory contains various scripts for data processing, ETL operations, and SQL queries.

### Directory Structure
- `/base`
  - `index_manager.py`: Database index optimization and management

- `/etl`
  - `/base`
    - `etl_base.py`: Abstract ETL job framework
    - `__init__.py`: Package initialization
  - `/treatment_journey_ml`
    - `config.py`: Configuration settings
    - `extract.py`: Data extraction
    - `load.py`: Data loading
    - `transform.py`: Data transformation
    - `main.py`: Main execution script
    - `__init__.py`: Package initialization

- `/export`
  - `export_missing_teeth_followup.py`: Missing teeth analysis
  - `export_unscheduled_patients.py`: Patient scheduling analysis
  - `__init__.py`: Package initialization

- `/sql`
  - `/database_setup`
    - `index_configs.py`: Index configuration settings
  - `/patient_journey_ml`
    - `indexes.sql`: Index definitions
    - `query.sql`: Analysis queries
  - `/treatment_journey_ml`
    - `indexes.sql`: Index definitions
    - `query.sql`: Analysis queries
  - `/validation`
    - `adjustment_analysis_report.sql`
    - `adjustment_validation.sql`
    - `procedurelog_ProcStatus_validation.sql`
    - `procedurelog_validation.sql`
    - `treatment_journey_validation.sql`

### Usage
- ETL scripts inherit from `etl_base.py`
- SQL queries are organized by domain
- Validation ensures data quality

### Best Practices
1. Keep business logic in appropriate domains
2. Use consistent logging patterns
3. Follow established connection management
4. Document all functions and SQL queries 