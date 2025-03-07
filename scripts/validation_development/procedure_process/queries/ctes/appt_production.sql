-- Sum the procedure fees per appointment (production)
-- Date filter: 2024-01-01 to 2025-01-01
-- Dependent CTEs:
appt_production AS (
  SELECT 
    AptNum,
    ProvNum,
    SUM(ProcFee) AS appt_production
  FROM procedurelog
  WHERE ProcDate >= '{{START_DATE}}' AND ProcDate < '{{END_DATE}}'
    AND ProcStatus = 2
  GROUP BY AptNum, ProvNum
)