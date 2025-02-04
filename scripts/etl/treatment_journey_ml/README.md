# Treatment Journey ETL

## Overview
This ETL job processes dental treatment data to create a comprehensive dataset for treatment journey analysis and machine learning. It supports both MySQL and MariaDB data sources.

## Directory Structure
```
treatment_journey_ml/
├── __init__.py
├── config.py          # Feature definitions and validation rules
├── extract.py         # Data extraction with chunking support
├── load.py           # Multi-format data saving utilities
├── main.py           # ETL job implementation
├── transform.py      # Data transformation and validation
└── README.md         # Documentation
```

## Features
The ETL job processes these feature groups:
- **Patient Demographics**
  - Age (with age group buckets)
  - Gender
  - Insurance status
- **Procedure Information**
  - Procedure codes
  - Categories
  - Treatment areas
  - Treatment complexity
- **Insurance Details**
  - Estimated payments
  - Actual payments
  - Payment accuracy
  - Claim status
  - Coverage ratio
- **Payment Targets**
  - 30-day payment status
  - Full payment status

## Usage

### Basic Usage
```python
from scripts.etl.treatment_journey_ml.main import main

# For MariaDB source
output_path = main(
    database_name="opendental_analytics_opendentalbackup_01_03_2025",
    connection_type="local_mariadb"
)

# For MySQL source
output_path = main(
    database_name="mdc_analytics_opendentalbackup_01_03_2025",
    connection_type="local_mysql"
)
```

### Output Files
The ETL job produces separate files for each database connection:
```
# MariaDB output
{base_dir}/processed/treatment_journey_ml/treatment_journey_local_mariadb.parquet

# MySQL output
{base_dir}/processed/treatment_journey_ml/treatment_journey_local_mysql.parquet
```

### Multiple Format Support
```python
from scripts.etl.treatment_journey_ml.load import save_data

# Save in multiple formats
saved_paths = save_data(
    df=transformed_data,
    prefix="treatment_journey",
    output_dir=output_dir,
    connection_type="local_mariadb",
    formats=['parquet', 'csv'],
    compression='snappy'
)

# Access saved file paths
parquet_path = saved_paths['parquet']
csv_path = saved_paths['csv']
```

## Data Processing Steps

1. **Setup**
   - Validates database connection
   - Creates required indexes for performance
   - Ensures output directories exist

2. **Extract**
   - Processes data in 10,000 row chunks
   - Supports large datasets
   - Handles both MySQL and MariaDB connections
   - Ensures proper connection cleanup

3. **Transform**
   - Validates data against rules
   - Creates derived features:
     - Age groups
     - Treatment complexity
     - Insurance coverage ratio
   - Handles missing values
   - Converts data types
   - Calculates key metrics

4. **Load**
   - Creates separate files for each database connection
   - Supports multiple output formats (Parquet, CSV)
   - Uses snappy compression
   - Creates output directories if needed
   - Returns dictionary of saved file paths

## Configuration

### Feature Groups
```python
FEATURE_GROUPS = {
    'patient': ['PatientAge', 'Gender', 'HasInsurance'],
    'procedure': ['ProcCode', 'ProcCat', 'TreatArea'],
    'insurance': [
        'EstimatedInsurancePayment', 
        'ActualInsurancePayment',
        'InsurancePaymentAccuracy',
        'ClaimStatus'
    ],
    'payment': ['target_paid_30d', 'target_fully_paid']
}
```

### Validation Rules
```python
VALIDATION_RULES = {
    'PatientAge': {'min': 0, 'max': 120},
    'ProcFee': {'min': 0},
    'InsurancePaymentAccuracy': {'min': 0, 'max': 100}
}
```

## Dependencies
- pandas: Data processing
- pyarrow: Parquet file handling
- mysql-connector-python: Database connectivity

## Required Files
Place SQL files in `{base_dir}/sql/treatment_journey_ml/`:
- `query.sql`: Main extraction query
- `indexes.sql`: Index definitions

## Error Handling
- Comprehensive logging at each step
- Data validation warnings
- Proper resource cleanup
- Exception handling with detailed error messages

## Metrics
The ETL job calculates and logs:
- Total procedures processed
- Average procedure fee
- 30-day payment rate
- Insurance payment accuracy

## Performance
- Chunked data processing
- Efficient database indexes
- Compressed file output
- Connection pooling support

## File Naming Convention
Output files follow this pattern:
```
treatment_journey_{connection_type}.{format}

Examples:
- treatment_journey_local_mariadb.parquet
- treatment_journey_local_mariadb.csv
- treatment_journey_local_mysql.parquet
- treatment_journey_local_mysql.csv
```

## Testing
Run the test script to verify ETL functionality:
```bash
python -m scripts.etl.treatment_journey_ml.test_etl
```

The test script will:
1. Run ETL for both MariaDB and MySQL
2. Verify data quality
3. Check file outputs
4. Display basic statistics

## Metrics
The ETL job calculates and logs:
- Total procedures processed
- Average procedure fee
- 30-day payment rate
- Insurance payment accuracy

## Performance
- Chunked data processing
- Efficient database indexes
- Compressed file output
- Connection pooling support 