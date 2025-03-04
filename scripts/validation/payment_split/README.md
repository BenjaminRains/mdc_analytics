# Payment Split Analysis Scripts

This directory contains scripts for analyzing various financial aspects of the OpenDental payment system, particularly focusing on two important financial areas:

1. **Income Transfer Indicators** - Tracking provider assignment issues in financial transactions
2. **Unearned Income Analysis** - Monitoring prepayments, deposits, and other unearned income

## Key Components

- SQL queries in the `queries/` directory
- Python export scripts in this directory
- Shared utilities in the `utils/` directory
- Output data in the `data/` directory
- Logs in the `logs/` directory

## Scripts Overview

### 1. Income Transfer Indicators (`export_income_transfer_indicators.py`)

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

### 2. Unearned Income Data (`export_unearned_income_data.py`)

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

While both scripts analyze financial data from the payment_split table, they focus on different areas:

| Aspect | Income Transfer Indicators | Unearned Income Data |
|--------|---------------------------|---------------------|
| Focus | Provider assignment (ProvNum = 0) | UnearnedType accounting classification |
| Primary Users | Operations staff | Finance/Accounting staff |
| Key SQL Filters | `ProvNum = 0` | `UnearnedType > 0` |
| Output Purpose | Workflow improvement | Financial reporting |
| Critical Issues | Provider attribution | Balance verification |

## Shared Utilities

Both scripts use common utilities from `utils/sql_export_utils.py` for:
- Date parameter handling
- SQL query extraction
- CSV export
- Summary reporting

## Requirements

- Python 3.8+
- pandas
- mysql-connector-python
- Valid database credentials in `.env` file

## Output Files

Data files are exported to the `data/` directory with:
- Consistent naming conventions
- Standardized CSV format
- Descriptive filename prefixes

## Maintenance

When making changes to either script:
1. Ensure shared utilities are used for common functionality
2. Maintain consistent documentation of the different use cases
3. Test with both scripts to ensure compatibility 