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

### Database Indexes
The ETL job automatically sets up required indexes for optimal performance:

```python
# Treatment Journey specific indexes
TREATMENT_JOURNEY_INDEXES = [
    # Patient demographics
    "CREATE INDEX idx_pat_ml_core ON patient (PatNum, PatStatus, Gender, BirthDate)",
    "CREATE INDEX idx_pat_ml_insurance ON patient (HasIns, InsCarrier)",
    
    # Procedure tracking
    "CREATE INDEX idx_proc_ml_core ON procedurelog (PatNum, ProcDate, ProcStatus, ProcFee)",
    "CREATE INDEX idx_proc_ml_codes ON procedurelog (CodeNum, ProcStatus, ProcFee)",
    
    # Insurance and payments
    "CREATE INDEX idx_claim_ml_core ON claim (PatNum, DateService, ClaimStatus)",
    "CREATE INDEX idx_payment_ml_core ON payment (PatNum, PayDate, PayAmt, PayType)"
]
```

These indexes support:
- Fast patient demographic lookups
- Efficient procedure history access
- Optimized insurance claim processing
- Quick payment tracking

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
   - Creates required ML-specific indexes
   - Ensures output directories exist
   - Verifies SQL file locations

2. **Extract**
   - Uses optimized indexes for faster queries
   - Processes data in 10,000 row chunks
   - Supports large datasets
   - Handles both MySQL and MariaDB
   - Ensures proper cleanup

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

## Required Files and Paths
```
{base_dir}/
├── sql/
│   └── treatment_journey_ml/
│       ├── query.sql          # Main extraction query
│       └── index_configs.py   # Index definitions
└── processed/
    └── treatment_journey_ml/  # Output directory
```

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

## Performance Optimization
- **Indexes**: ML-specific indexes for faster queries
- **Chunking**: Processes large datasets in manageable chunks
- **Compression**: Uses snappy compression for output files
- **Connection**: Pooling support for better database performance
- **Memory**: Efficient memory usage with chunked processing

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

The test script:
1. Verifies database connections
2. Checks index creation
3. Runs ETL for both MariaDB and MySQL
4. Validates output data quality
5. Displays performance metrics
6. Ensures proper file creation

Example test output:
```
=== Testing MariaDB ETL ===
Setting up indexes...
Created index: idx_pat_ml_core
Created index: idx_proc_ml_core
Extracted 50,000 rows
Transformed data shape: (50000, 15)
Data saved to: .../treatment_journey_local_mariadb.parquet

Data Quality Checks:
Total rows: 50,000
Missing values: 123
Age range: 0 - 98
Average procedure fee: $234.56
Insurance accuracy: 92.3%

=== Testing MySQL ETL ===
[Similar output for MySQL...] 