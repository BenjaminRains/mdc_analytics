# MDC Analytics Project:

## Overview
The MDC Analytics Project bridges operational (OLTP) and analytical (OLAP) workflows for dental practices using OpenDental. It uses dbt (data build tool) for data transformation and validation, integrated with machine learning models to enhance patient care, optimize financial performance, and streamline operational efficiency.

## Project Architecture and Workflow

The project consists of two main components:

### 1. Data Transformation & Validation (dbt)

Located in `dbt_dental_practice/`, this framework handles data validation and modeling:

```
dbt_dental_practice/
├── models/
│   ├── staging/          # Initial data validation and cleaning
│   │   └── opendental/   # Source-specific models
│   ├── intermediate/     # Business logic transformations
│   └── marts/           # Business-specific data marts
├── tests/               # Data quality tests
│   └── staging/         # Source-specific validations
├── docs/               # Documentation
│   └── validation_logs/ # Test results and data quality metrics
├── macros/            # Reusable SQL transformations
└── seeds/             # Static reference data
```

Key validation areas:
- Payment Processing (`stg_opendental__payment`)
  - Validates payment types, amounts, and dates
  - Ensures data quality through automated tests
  - Documents patterns and business rules
- Insurance (coming soon)
- Patient, Appointment, and Communication (coming soon)
- Procedures (coming soon)

### 2. Machine Learning (`scripts/machine_learning`)

This directory leverages validated data from dbt models to build predictive models addressing critical business questions:

- **Patient Behavior Prediction**: Forecasting patient appointment adherence, treatment acceptance, and engagement.
- **Insurance Scoring**: Evaluating insurance carriers based on payment payment accuracy and claim processing efficiency.

## Data Transformation Framework

The project uses dbt for data transformation and validation:

- **Sources**: Raw data from OpenDental
- **Staging Models**: Initial validation and cleaning
  - Data type enforcement
  - Business rule validation
  - Pattern documentation
- **Intermediate Models**: Business logic implementation
- **Marts**: Business-specific analytical views

## Data Quality and Testing

Comprehensive testing strategy:
- **Unique and Not Null**: Key field validation
- **Accepted Values**: Domain validation
- **Custom Tests**: Business rule enforcement
- **Documentation**: Test results and data patterns

## Success Metrics and Outcomes

Success is measured through:
- **Data Quality**: Automated test coverage and success rates
- **Business Alignment**: Validated business rules and patterns
- **Model Stability**: Reliable transformations with documented outcomes

## Getting Started

1. Install dependencies:
```bash
# Install Python dependencies using pipenv
pipenv install

# Activate virtual environment
pipenv shell

# Install dbt packages
dbt deps
```

2. Run models:
```bash
# Run all models
dbt run

# Run specific model
dbt run --select stg_opendental__payment
```

3. Test data quality:
```bash
# Run all tests
dbt test

# Test specific model
dbt test --select stg_opendental__payment
```

4. View documentation:
```bash
# Generate docs
dbt docs generate

# Serve docs locally
dbt docs serve

## Conclusion

The MDC Analytics Project combines dbt's robust data transformation capabilities with advanced analytics, providing a reliable foundation for dental practice analytics and machine learning applications. 