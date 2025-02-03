# MDC Analytics Project

## Overview
The MDC Analytics Project bridges operational (OLTP) and analytical (OLAP) data workflows for dental practices using OpenDental. By maintaining two distinct databases, this project enables efficient capture and transformation of data, ultimately empowering advanced analytics such as machine learning, dashboard reporting, and financial analysis.

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

### Connection Management (src/connections/)
- Factory Pattern: Creates and manages database connections
- Connection Types:
  - OLTP (OpenDental)
  - OLAP (Analytics)
  - Read replicas
- Features:
  - Connection pooling
  - Retry logic
  - Error handling
  - Credential management

### Index Management (scripts/base/index_manager.py)
- Purpose: Optimizes query performance
- Features:
  - Automated index creation
  - Index maintenance
  - Performance monitoring
  - SQL query optimization

### ETL Framework (scripts/etl/)
- Base Class: Abstract ETL job definition
- Components:
  - Setup (environment preparation)
  - Extract (data acquisition)
  - Transform (data processing)
  - Load (data storage)
- Features:
  - Chunked processing
  - Data validation
  - Metric tracking
  - Error handling

## Supporting Documentation
- Query Optimization Guide
- Schema Documentation
- ETL Documentation
- Data Dictionary

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