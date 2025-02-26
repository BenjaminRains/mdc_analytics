-- Sum the procedure fees per appointment (production)
appt_production AS (
  SELECT 
    AptNum,
    ProvNum,
    SUM(ProcFee) AS appt_production
  FROM procedurelog
  WHERE ProcDate >= '2024-01-01' AND ProcDate < '2025-01-01'
    AND ProcStatus = 2
  GROUP BY AptNum, ProvNum
)