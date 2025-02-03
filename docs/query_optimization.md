# Query Optimization Guide

## Overview
This guide covers query optimization strategies for working with OpenDental databases, particularly when dealing with large backup databases and analytics queries.

## Understanding Query Performance

### EXPLAIN Command
The EXPLAIN command is essential for understanding how MySQL/MariaDB executes your queries:

```sql
EXPLAIN SELECT * FROM procedurelog 
WHERE ProcDate >= '2023-01-01';
```

Key information:
- `type`: How tables are joined
- `possible_keys`: Indexes that could be used
- `key`: Index actually used
- `rows`: Estimated number of rows examined
- `Extra`: Additional information

### Types of Table Scans
From worst to best performance:
1. **ALL**: Full table scan (avoid)
2. **INDEX**: Full index scan
3. **RANGE**: Index range scan
4. **REF**: Index lookup
5. **eq_ref**: Unique index lookup
6. **const**: Constant lookup (best)

## Common OpenDental Query Patterns

### 1. Patient Treatment History
```sql
-- Before optimization
SELECT proc.ProcNum, proc.ProcDate
FROM procedurelog proc
WHERE proc.ProcDate >= '2023-01-01';

-- After optimization
SELECT proc.ProcNum, proc.ProcDate
FROM procedurelog proc
FORCE INDEX (idx_proc_date)
WHERE proc.ProcDate >= '2023-01-01';
```

### 2. Financial Analysis
```sql
-- Use covering indexes for financial queries
CREATE INDEX idx_proc_financial ON procedurelog 
(ProcDate, ProcFee, ProcStatus);

SELECT 
    DATE(ProcDate) as service_date,
    SUM(ProcFee) as daily_production
FROM procedurelog
WHERE ProcDate >= '2023-01-01'
GROUP BY DATE(ProcDate);
```

### 3. Appointment Analysis
```sql
-- Optimize appointment lookups
CREATE INDEX idx_apt_provider ON appointment 
(ProvNum, AptDateTime);

SELECT 
    ProvNum,
    COUNT(*) as appointment_count
FROM appointment
WHERE AptDateTime BETWEEN '2023-01-01' AND '2023-12-31'
GROUP BY ProvNum;
```

## Index Design Principles

### 1. Column Selection
- Index columns used in WHERE clauses
- Index columns used in JOIN conditions
- Index columns used in ORDER BY
- Consider covering indexes for analytics queries

### 2. Multi-Column Indexes
- Order matters! Most selective first
- Consider query patterns
- Left-most prefix rule applies

### 3. Our Common Indexes
```sql
-- For date range filters
CREATE INDEX idx_proc_date ON procedurelog 
(ProcDate, ProcStatus);

-- For patient history
CREATE INDEX idx_proc_patient ON procedurelog 
(PatNum, ProcDate);

-- For financial analysis
CREATE INDEX idx_proc_financial ON procedurelog 
(ProcDate, ProcFee, ProcStatus);
```

## Performance Optimization Strategies

### 1. Use Temporary Tables
```sql
-- Create temporary table for complex analysis
CREATE TEMPORARY TABLE temp_patient_metrics AS
SELECT 
    PatNum,
    COUNT(DISTINCT ProcNum) as procedure_count,
    SUM(ProcFee) as total_fees
FROM procedurelog
WHERE ProcDate >= '2023-01-01'
GROUP BY PatNum;
```

### 2. Batch Processing
```sql
-- Process large datasets in batches
SET @batch_size = 10000;
SET @offset = 0;

REPEAT
    UPDATE procedurelog
    SET ProcStatus = 2
    WHERE ProcNum > @offset
    LIMIT @batch_size;
    
    SET @offset = @offset + @batch_size;
UNTIL ROW_COUNT() = 0 END REPEAT;
```

### 3. Partitioning Strategy
Consider partitioning large tables by date:
```sql
ALTER TABLE procedurelog
PARTITION BY RANGE (YEAR(ProcDate)) (
    PARTITION p2021 VALUES LESS THAN (2022),
    PARTITION p2022 VALUES LESS THAN (2023),
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);
```

## Monitoring Query Performance

### 1. Slow Query Log
```sql
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 2;
```

### 2. Performance Schema
```sql
SELECT 
    digest_text,
    count_star,
    avg_timer_wait
FROM performance_schema.events_statements_summary_by_digest
WHERE digest_text LIKE '%procedurelog%'
ORDER BY avg_timer_wait DESC;
```

### 3. Buffer Pool Monitoring
```sql
SHOW GLOBAL STATUS LIKE 'innodb_buffer_pool_%';
```

## Best Practices

1. **Always Test First**
   - Use EXPLAIN
   - Test with representative data volume
   - Monitor execution time

2. **Consider Data Volume**
   - Use LIMIT for testing
   - Implement pagination
   - Process large updates in batches

3. **Index Management**
   - Regular ANALYZE TABLE
   - Monitor index usage
   - Remove unused indexes

4. **Query Structure**
   - Use specific columns instead of SELECT *
   - Leverage covering indexes
   - Consider materialized views for complex analytics

## Related Documentation
- [OpenDental Schema Guide](opendental_schemas/README.md)
- [Connection Management](connections/README.md)
- [ETL Process](etl_process.md) 