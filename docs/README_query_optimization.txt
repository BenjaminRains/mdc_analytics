## Understanding Query Performance

### 1. EXPLAIN Command
The EXPLAIN command shows how MySQL executes a query:


EXPLAIN SELECT * FROM procedurelog WHERE ProcDate >= '2023-01-01';
```
Key information:
- type: How tables are joined
- possible_keys: Indexes that could be used
- key: Index actually used
- rows: Estimated number of rows examined
- Extra: Additional information


EXPLAIN SELECT * FROM procedurelog WHERE ProcDate >= '2023-01-01';
```
Key information:
- type: How tables are joined
- possible_keys: Indexes that could be used
- key: Index actually used
- rows: Estimated number of rows examined
- Extra: Additional information

### 2. Types of Table Scans (from worst to best)
- ALL: Full table scan (slowest)
- INDEX: Full index scan
- RANGE: Index range scan
- REF: Index lookup
- eq_ref: Unique index lookup
- const: Constant lookup (fastest)

### 3. Our Treatment Journey Query Optimization

Before Indexing:
```sql


EXPLAIN SELECT proc.ProcNum, proc.ProcDate
FROM procedurelog proc
WHERE proc.ProcDate >= '2023-01-01'
```
Result:
- type: ALL
- rows: 1000000
- Extra: Using where
Time: ~30 minutes

After Indexing:
```sql
CREATE INDEX idx_proc_date ON procedurelog (ProcDate, ProcStatus);
```
Result:
- type: RANGE
- rows: 50000
- Extra: Using index
Time: ~5 minutes

### 4. Index Design Principles
1. Column Selection:
   - Index columns used in WHERE clauses
   - Index columns used in JOIN conditions
   - Index columns used in ORDER BY
   - Include covering indexes when possible

2. Multi-Column Indexes:
   - Order matters! Most selective first
   - Consider query patterns
   - Left-most prefix rule applies

3. Our Index Strategy:
```sql
-- For date range filters and status
CREATE INDEX idx_proc_date ON procedurelog (ProcDate, ProcStatus);

-- For patient joins and history
CREATE INDEX idx_proc_patient ON procedurelog (PatNum, ProcDate);

-- For payment lookups
CREATE INDEX idx_paysplit_proc ON paysplit (ProcNum, SplitAmt);
```

### 5. Performance Impact Examples

Original Query Pattern:
```sql
SELECT * FROM procedurelog 
WHERE ProcDate >= '2023-01-01' 
AND ProcStatus = 2;
```
- Full table scan
- Examines every row
- High I/O cost

Optimized Query Pattern:
```sql
SELECT proc.* FROM procedurelog proc
FORCE INDEX (idx_proc_date)
WHERE proc.ProcDate >= '2023-01-01' 
AND proc.ProcStatus = 2;
```
- Uses index
- Examines only relevant rows
- Reduced I/O

### 6. Memory and Buffer Pool
- InnoDB buffer pool caches data and indexes
- Properly sized buffer pool reduces disk I/O
- Monitor buffer pool hit rate:
```sql
SHOW GLOBAL STATUS LIKE 'innodb_buffer_pool_%';
```

### 7. Best Practices
1. Use EXPLAIN to analyze queries
2. Create indexes based on query patterns
3. Monitor index usage:
```sql
SELECT * FROM performance_schema.table_io_waits_summary_by_index_usage;
```
4. Remove unused indexes
5. Consider maintenance window for index creation
6. Regular ANALYZE TABLE to update statistics

### 8. Common Pitfalls
1. Over-indexing (too many indexes)
2. Under-indexing (missing crucial indexes)
3. Wrong column order in compound indexes
4. Not considering maintenance overhead
5. Ignoring cardinality

### 9. Monitoring Query Performance
```sql
-- Slow query log
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 2;

-- Performance schema
SELECT * FROM performance_schema.events_statements_summary_by_digest
WHERE DIGEST_TEXT LIKE '%procedurelog%'
ORDER BY SUM_TIMER_WAIT DESC;
```

Remember: Optimization is an iterative process. Always measure, optimize, and validate improvements."""