# MDC Analytics Project: Unified Narrative

## Overview
The MDC Analytics Project bridges operational (OLTP) and analytical (OLAP) workflows for dental practices using OpenDental. It integrates robust database validation processes with advanced machine learning models to enhance patient care, optimize financial performance, and streamline operational efficiency.

## Project Architecture and Workflow

The project is structured around two primary directories within the `scripts` directory:

### 1. Validation Development (`scripts/validation_development`)

This directory systematically validates and analyzes historical data from the OpenDental operational database. It is divided into four main business processing areas:

- Insurance
- Patient, Appointment, and Communication (`patient_appt_comm`)
- Payment Activity (`payment_split`)
- Procedures (`procedurelog`)

Each area contains standardized subdirectories:
- `data`: Raw and processed data files.
- `docs`: Documentation of business logic and analysis strategies.
- `logs`: Logs from validation runs.
- `notebooks`: Jupyter notebooks for exploratory analysis.
- `output`: Results from validation scripts.
- `queries`: SQL queries and CTEs.
- `reports`: Summarized validation findings.
- `export scripts`: Python scripts for data extraction and processing.

### 2. Machine Learning (`scripts/machine_learning`)

This directory leverages validated historical data to build predictive models addressing critical business questions:

- **Patient Behavior Prediction**: Forecasting patient appointment adherence, treatment acceptance, and engagement.
- **Insurance Scoring**: Evaluating insurance carriers based on payment accuracy and claim processing efficiency.

## ETL Framework

The project employs a structured ETL (Extract, Transform, Load) framework:

- **Extract**: Data extraction from OpenDental.
- **Transform**: Data cleaning, validation, and feature engineering.
- **Load**: Storing data in analytical databases or optimized file formats.

## Data Flow and Integration

Data flow is clearly defined:

- **Operational Data (OLTP)**: Captured from daily operations.
- **Validation and ETL Processes**: Data validation, transformation, and export.

## Success Metrics and Outcomes

Success is measured through:

- **Data Quality**: Comprehensive coverage and consistent success rates.
- **Business Alignment**: Analytics outcomes aligned with operational goals.
- **Model Stability**: Reliable predictive models with actionable insights.

## Conclusion

The MDC Analytics Project bridges operational data with advanced analytics, empowering dental practices to optimize financial performance and enhance patient care. 