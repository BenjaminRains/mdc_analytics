# MDC Analytics Project

## Overview
The MDC Analytics Project bridges operational (OLTP) and analytical (OLAP) data workflows for dental practices using OpenDental. 
By maintaining two distinct databases, this project enables efficient capture and transformation of data, ultimately 
empowering advanced analytics such as machine learning, dashboard reporting, and financial analysis.

## Architecture

### OLTP Database
- **Purpose**: Day-to-day operations of the dental practice
  - Scheduling
  - Patient records
  - Real-time transaction logging
- **Characteristics**: 
  - Highly transactional
  - Frequently updated during business hours
  - Optimized for write operations

### OLAP Database
- **Purpose**: Data warehousing and analytical queries
  - Patient behavior modeling
  - Resource management
  - Financial reporting
- **Characteristics**:
  - Heavily indexed
  - Optimized for read performance
  - Denormalized for analytical queries

## Core Components

### Connection Management (`src/connections/`)
- **Factory Pattern**: Creates and manages database connections
- **Connection Types**:
  - OLTP (OpenDental)
  - OLAP (Analytics)
  - Read replicas
- **Features**:
  - Connection pooling
  - Retry logic
  - Error handling
  - Credential management

### Index Management (`scripts/base/index_manager.py`)
- **Purpose**: Optimizes query performance
- **Features**:
  - Automated index creation
  - Index maintenance
  - Performance monitoring
  - SQL query optimization

### ETL Framework (`scripts/etl/`)
- **Base Class**: Abstract ETL job definition
- **Components**:
  - Setup (environment preparation)
  - Extract (data acquisition)
  - Transform (data processing)
  - Load (data storage)
- **Features**:
  - Chunked processing
  - Data validation
  - Metric tracking
  - Error handling

## Data Pipeline Components

### Treatment Journey ETL
- **Purpose**: Analyze patient treatment patterns
- **Features**:
  - Patient demographics
  - Treatment history
  - Payment patterns
  - Insurance interactions
- **Documentation**: [Treatment Journey ETL Guide](docs/README_ETLjob.md)

### Machine Learning Models

#### 1. Patient Behavior Prediction
- Predicts:
  - Appointment attendance
  - Treatment plan acceptance
  - Payment compliance
  - Future dental needs
- Features:
  - Historical patterns
  - Demographics
  - Treatment history
  - Payment behavior

#### 2. Patient Scoring System
- Metrics:
  - Appointment reliability
  - Treatment plan acceptance
  - Payment history
  - Overall engagement
  - Family/household patterns

#### 3. Procedure Acceptance Prediction
- Analyzes:
  - Procedure type and cost
  - Insurance coverage
  - Patient history
  - Demographic factors
  - Family treatment history

## Analytics Components

### 1. Patient-Level Analytics
- Demographic analysis
- Treatment history patterns
- Payment behavior
- Appointment reliability
- Family/household influences
- Risk assessments

### 2. Procedure-Level Analytics
- Acceptance rates
- Payment patterns
- Insurance coverage impact
- Seasonal trends
- Provider-specific patterns

### 3. Practice-Level Insights
- Patient demographics
- Treatment mix
- Financial performance
- Resource utilization
- Scheduling optimization

## Supporting Documentation
- [Query Optimization Guide](docs/query_optimization.md)
- [Schema Documentation](docs/opendental_schemas/README.md)
- [ETL Documentation](docs/README_ETLjob.md)
- [Data Dictionary](docs/data_dictionary.md)

## Dependencies
- Python 3.8+
- pandas
- SQLAlchemy
- PyArrow
- MySQL/MariaDB

## Getting Started
1. Set up database connections
2. Configure environment variables
3. Run ETL pipelines
4. Access analytics dashboards

For detailed setup instructions, see [Setup Guide](docs/setup.md)
