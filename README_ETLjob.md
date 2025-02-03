# Treatment Journey ETL Pipeline

## Overview
This ETL pipeline processes OpenDental data to create datasets for treatment plan analysis and ML modeling. It handles patient demographics, procedure details, insurance data, and payment information.

## Components

### Core Classes

#### `ETLJob` Base Class (`etl_base.py`)
- Abstract base class defining ETL workflow
- Methods:
  - `setup()`: Prepare environment and indexes
  - `extract()`: Pull data from source
  - `transform()`: Clean and format data
  - `load()`: Save processed data
  - `run()`: Orchestrate the ETL process

#### `TreatmentJourneyETL` (`treatment_journey_ml/main.py`)
- Implements `ETLJob` for treatment journey analysis
- Features:
  - Chunked data processing
  - Automated index management
  - Metric calculation
  - Data validation

### Supporting Modules

#### Index Management (`index_manager.py`)
- Creates and maintains database indexes
- Reads from `indexes.sql`
- Optimizes query performance

#### Data Transformation (`transform.py`)
- Feature engineering
- Data validation
- Missing value handling
- Metric calculations

#### Configuration (`config.py`)
- Feature group definitions
- Validation rules
- Path management
- Output settings

## Usage

### Basic Execution
```python
from scripts.etl.treatment_journey_ml.main import main

# Run ETL job
output_path = main("database_name")
```

### Output
- Parquet file containing:
  - Patient demographics
  - Procedure information
  - Insurance data
  - Payment history
  - Calculated features
  - Target variables

### Data Dictionary
Key features include:
- `PatientAge`: Patient age at procedure
- `ProcFee`: Procedure fee amount
- `InsuranceCoverageRatio`: Insurance coverage percentage
- `target_paid_30d`: Payment received within 30 days

## Performance Considerations

### Memory Management
- Chunked processing (10,000 rows)
- Efficient data types
- Index optimization

### Database Optimization
- Strategic indexes
- Query optimization
- Connection management

## Error Handling
- Comprehensive logging
- Data validation
- Exception management
- Metric tracking

## Dependencies
- pandas
- pyarrow
- sqlalchemy
- logging

## Related Documentation
- [Query Optimization Guide](docs/query_optimization.md)
- [Schema Documentation](docs/opendental_schemas/README.md)
- [Data Dictionary](docs/data_dictionary.md)

