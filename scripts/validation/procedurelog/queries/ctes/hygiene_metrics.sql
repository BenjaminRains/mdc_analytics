-- HYGIENE METRICS
-- Tracks hygiene vs non-hygiene procedures and associated fees
-- Dependent CTEs: base_procedures.sql
HygieneMetrics AS (
    SELECT 
        bp.ProvNum,
        -- Hygiene procedure counts
        SUM(CASE 
            WHEN pc.ProcCode LIKE 'D11%'  -- Dental prophylaxis
             OR pc.ProcCode LIKE 'D43%'   -- Periodontal procedures
            THEN 1 ELSE 0 
        END) AS HygieneProcCount,
        
        -- Non-hygiene procedure counts
        SUM(CASE 
            WHEN pc.ProcCode NOT LIKE 'D11%' 
             AND pc.ProcCode NOT LIKE 'D43%'
            THEN 1 ELSE 0 
        END) AS NonHygieneProcCount,
        
        -- Calculate percentage
        ROUND(100.0 * 
            SUM(CASE 
                WHEN pc.ProcCode LIKE 'D11%' 
                 OR pc.ProcCode LIKE 'D43%'
                THEN 1 ELSE 0 
            END) / NULLIF(COUNT(*), 0), 1
        ) AS HygieneProcPct,
        
        -- Associated fees
        SUM(CASE 
            WHEN pc.ProcCode LIKE 'D11%' 
             OR pc.ProcCode LIKE 'D43%'
            THEN bp.ProcFee ELSE 0 
        END) AS HygieneFees,
        
        SUM(CASE 
            WHEN pc.ProcCode NOT LIKE 'D11%' 
             AND pc.ProcCode NOT LIKE 'D43%'
            THEN bp.ProcFee ELSE 0 
        END) AS NonHygieneFees
    FROM BaseProcedures bp
    JOIN procedurecode pc ON bp.CodeNum = pc.CodeNum
    WHERE bp.ProvNum > 0
      AND bp.ProcStatus = 2  -- Only count completed procedures
    GROUP BY bp.ProvNum
) 