# Treatment Journey Dataset

## ETL Architecture

### Directory Structure
```
scripts/
├── base/
│   └── index_manager.py          # Core index management
├── etl/
│   ├── base/
│   │   └── etl_base.py          # Base ETL class
│   └── treatment_journey_ml/     # Treatment journey ETL
│       ├── __init__.py
│       ├── config.py            # ETL configuration
│       ├── extract.py           # Data extraction
│       ├── load.py             # Data loading
│       ├── main.py             # ETL orchestration
│       └── transform.py         # Data transformations
└── sql/
    └── treatment_journey_ml/     # SQL definitions
        ├── index_configs.py      # Index configurations
        ├── indexes.sql          # Index SQL statements
        └── query.sql           # Main data extraction query
```

### ETL Workflow
1. **Setup Phase**
   - Initialize database connection
   - Setup required indexes using `index_manager.py`
   - Load configurations from `index_configs.py`
   - Validate SQL files and database state

2. **Extract Phase**
   - Execute main query from `query.sql`
   - Process data in chunks for memory efficiency
   - Monitor extraction progress
   - Validate row counts and data integrity

3. **Transform Phase**
   - Clean and standardize data
   - Convert data types
   - Generate derived features
   - Handle missing values
   - Apply business rules

4. **Load Phase**
   - Save versioned Parquet files
   - Generate dataset statistics
   - Log transformation metrics
   - Create data quality reports

## Table Relationships

### Core Tables
```
procedurelog
- ProcNum (PK)      -- Unique identifier for each procedure instance
- CodeNum (FK)      -- Links to procedurecode table
- ProcFee           -- The planned fee
- ProcStatus        -- Status of procedure (1,2,3,4,5,6,7,8)
- ProcDate          -- When procedure was performed
- PatNum (FK)       -- Links to patient table

procedurecode
- CodeNum (PK)      -- Unique identifier for procedure type
- ProcCode          -- Standard procedure code (like D0120)
- Descript          -- Description of the procedure
- ProcCat           -- Category ID from definition table
- IsHygiene         -- Flag for hygiene procedures
- TreatArea         -- Treatment area code
- IsMultiVisit      -- Flag for multi-visit procedures

patient
- PatNum (PK)       -- Unique identifier for patient
- Birthdate         -- Patient birthdate (watch for '0001-01-01')
- Gender            -- Patient gender
- HasIns            -- Insurance status
- Guarantor         -- Links family members
```

### Financial Tables
```
paysplit
- SplitAmt          -- Payment amount
- ProcNum (FK)      -- Links to procedurelog
- PayNum (FK)       -- Links to payment

payment
- PayNum (PK)       -- Unique identifier for payment
- PayDate           -- Date of payment

claimproc
- InsPayAmt         -- Insurance payment amount
- ProcNum (FK)      -- Links to procedurelog
- Status            -- Status of insurance claim
- InsPayEst         -- Estimated insurance payment
- DateCP            -- Date of insurance payment

adjustment
- AdjAmt            -- Adjustment amount
- ProcNum (FK)      -- Links to procedurelog
```

## Database Indexes
Key indexes for query optimization:
```sql
-- Core indexes
idx_proc_date_status ON procedurelog (ProcDate, ProcStatus)
idx_proc_patient ON procedurelog (PatNum, ProcDate)
idx_proc_code ON procedurelog (CodeNum)
idx_proc_clinic ON procedurelog (ClinicNum)

-- Patient indexes
idx_pat_birth ON patient (Birthdate)
idx_pat_insurance ON patient (HasIns)
idx_pat_feesched ON patient (FeeSched)

-- Insurance indexes
idx_claimproc_proc ON claimproc (ProcNum, Status, InsPayEst, InsPayAmt)
idx_claimproc_dates ON claimproc (DateCP, ProcDate)

-- Payment indexes
idx_claimpayment_check ON claimpayment (ClaimPaymentNum, CheckAmt, IsPartial)
idx_payment_date ON payment (PayDate)

-- Compound indexes
idx_proc_patient_status_date ON procedurelog (PatNum, ProcStatus, ProcDate, ProcFee)
```

## Dataset Generation

### Running the ETL Job
```bash
# Setup indexes first
python -m scripts.base.index_manager my_database --dataset treatment_journey

# Run the ETL process
python -m scripts.etl.treatment_journey_ml.main

# Enter database name when prompted
Enter database name: opendentalbackup_01_03_2025
```

### Output Files
```
data/
└── processed/
    └── treatment_journey_{database_name}_{timestamp}.parquet
```

### Logging
```
logs/
└── treatment_journey_etl.log
```

## Key Filters
- Date Range: 2023-01-01 to 2023-12-31
- ProcStatus IN (1, 2, 5, 6)

## Target Variables
1. target_fully_paid: Full payment received
2. target_paid_30d: Payment received within 30 days
3. target_insurance_accurate: Insurance estimate accuracy

## Feature Groups
1. Patient Demographics
   - Age
   - Gender
   - Insurance Status

2. Financial Features
   - Standard Fee
   - Fee Ratio
   - Insurance Estimates

3. Insurance Features
   - Estimated Payments
   - Actual Payments
   - Claim Processing Time

4. Procedure Details
   - Procedure Type
   - Treatment Area
   - Multi-Visit Status

## Data Quality Checks
- Valid procedure dates
- Non-null patient identifiers
- Valid procedure statuses
- Consistent financial amounts
- Insurance claim integrity
- Payment timeline validation

## Versioning
- Datasets versioned by timestamp
- Parquet format for efficient storage
- Full ETL process logging
- Index setup tracking

