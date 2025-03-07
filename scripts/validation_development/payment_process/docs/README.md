# Payment Split Analysis Scripts

This directory contains scripts for analyzing various financial aspects of the OpenDental payment system, particularly focusing on three important financial areas:

1. **Payment Split Validation** - Analyzing payment distribution and detecting issues
2. **Income Transfer Indicators** - Tracking provider assignment issues in financial transactions
3. **Unearned Income Analysis** - Monitoring prepayments, deposits, and other unearned income

## Key Components

- SQL queries in the `queries/` directory
- Python export scripts in this directory
- Shared utilities in the `utils/` directory
- Output data in the `output/` directory
- Logs in the `logs/` directory

## Scripts Overview

### 1. Payment Split Validation (`export_payment_split_validation.py`)

**Purpose:** Analyze payment splits and identify potential issues or patterns in payment distribution.

**Use Case:** Finance teams use this to validate payment splits and detect problems in payment applications.

**Key Features:**
- Common Table Expression (CTE) dependency management with topological sorting
- SQL syntax validation with MariaDB-specific checks
- Execution plan analysis for performance optimization
- CTE dependency visualization (requires GraphViz)
- SQL content caching for improved performance

**Usage:**
```
python export_payment_split_validation.py --start-date YYYY-MM-DD --end-date YYYY-MM-DD --database DB_NAME --connection-type CONNECTION_TYPE [--queries QUERY_NAMES] [--generate-dependency-graph]
```

**Optional Parameters:**
- `--queries`: Specific query names to run (default: all)
- `--output-dir`: Custom output directory
- `--log-level`: Logging level (DEBUG, INFO, WARNING, ERROR)
- `--generate-dependency-graph`: Generate visualization of CTE dependencies

**Dependency Visualization:**
The `--generate-dependency-graph` option creates a visualization showing relationships between Common Table Expressions (CTEs) to help understand query structure and dependencies. This requires:

1. Python GraphViz library: `pip install graphviz`
2. System GraphViz installation:
   - Windows: Download from https://graphviz.org/download/ and add to PATH
   - Mac: `brew install graphviz`
   - Linux: `apt-get install graphviz` or `yum install graphviz`

The visualization output is saved as both `.dot` (text) and `.png` (image) files in the `output/dependencies/` directory.

### 2. Income Transfer Indicators (`export_income_transfer_indicators.py`)

**Purpose:** Identify and analyze transactions with provider assignment issues (ProvNum = 0).

**Use Case:** Operations teams use this to identify which providers should be assigned to income transactions, improving billing accuracy and provider compensation.

**Key Metrics:**
- Transactions by unassigned provider
- Payment types associated with unassigned transactions
- Correlations with patient appointments and procedures

**Usage:**
```
python export_income_transfer_indicators.py [--from-date YYYY-MM-DD] [--to-date YYYY-MM-DD] [--database DB_NAME]
```

### 3. Unearned Income Data (`export_unearned_income_data.py`)

**Purpose:** Analyze prepayments, deposits, and other unearned income that hasn't yet been applied to services.

**Use Case:** Financial accounting teams use this to monitor unearned income balances, aging, and reconciliation needs.

**Key Metrics:**
- Unearned income aging analysis
- Distribution by unearned type (prepayment, gift card, etc.)
- Payment type summary
- Patient-level unearned balance details

**Usage:**
```
python export_unearned_income_data.py [--from-date YYYY-MM-DD] [--to-date YYYY-MM-DD] [--database DB_NAME]
```

## Key Differences Between Scripts

While all scripts analyze financial data from the payment and payment_split tables, they focus on different areas:

| Aspect | Payment Split Validation | Income Transfer Indicators | Unearned Income Data |
|--------|--------------------------|---------------------------|---------------------|
| Focus | Payment split analysis and validation | Provider assignment (ProvNum = 0) | UnearnedType accounting classification |
| Primary Users | Finance/Analysts | Operations staff | Finance/Accounting staff |
| Key SQL Features | Complex CTE structure and SQL optimization | Provider attribution | Balance reconciliation |
| Output Purpose | Data validation | Workflow improvement | Financial reporting |
| Critical Issues | Split distribution accuracy | Provider attribution | Balance verification |

## Shared Utilities

The scripts use common utilities from `utils/sql_export_utils.py` for:
- Date parameter handling
- SQL query extraction
- CSV export
- Summary reporting

## Requirements

- Python 3.8+
- pandas
- mysql-connector-python
- graphviz (optional, for dependency visualization)
- Valid database credentials in `.env` file

## Output Files

Data files are exported to the `output/` directory with:
- Consistent naming conventions
- Standardized CSV format
- Descriptive filename prefixes
- Date range subdirectories

## Maintenance

When making changes to the scripts:
1. Ensure shared utilities are used for common functionality
2. Maintain consistent documentation of the different use cases
3. Test with all scripts to ensure compatibility
4. Keep SQL queries modular with proper dependency management 