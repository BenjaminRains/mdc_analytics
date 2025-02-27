-- HYGIENE METRICS
-- Tracks hygiene vs non-hygiene procedures and associated fees
-- Date filter: 2024-01-01 to 2025-01-01
-- Dependent CTEs: base_procedures.sql
HygieneMetrics AS (
    SELECT 
        bp.ProvNum,
        -- Hygiene procedure counts
        SUM(CASE 
            WHEN pc.ProcCode LIKE 'D01%'   -- Exams
             OR pc.ProcCode LIKE 'D02%'    -- X-rays
             OR pc.ProcCode LIKE 'D11%'    -- Dental prophylaxis
             OR pc.ProcCode LIKE 'D43%'    -- Periodontal procedures
             OR pc.ProcCode LIKE 'D04%'    -- Cleanings
             OR (pc.ProcCode LIKE 'D00%' AND pc.Descript LIKE '%exam%')  -- Catch other exam codes
            THEN 1 ELSE 0 
        END) AS HygieneProcCount,
        
        -- Non-hygiene procedure counts
        SUM(CASE 
            WHEN pc.ProcCode NOT LIKE 'D01%'
             AND pc.ProcCode NOT LIKE 'D02%'
             AND pc.ProcCode NOT LIKE 'D11%'
             AND pc.ProcCode NOT LIKE 'D43%'
             AND pc.ProcCode NOT LIKE 'D04%'
             AND NOT (pc.ProcCode LIKE 'D00%' AND pc.Descript LIKE '%exam%')
            THEN 1 ELSE 0 
        END) AS NonHygieneProcCount,
        
        -- Calculate percentage
        ROUND(100.0 * 
            SUM(CASE 
                WHEN pc.ProcCode LIKE 'D01%'
                 OR pc.ProcCode LIKE 'D02%'
                 OR pc.ProcCode LIKE 'D11%'
                 OR pc.ProcCode LIKE 'D43%'
                 OR pc.ProcCode LIKE 'D04%'
                 OR (pc.ProcCode LIKE 'D00%' AND pc.Descript LIKE '%exam%')
                THEN 1 ELSE 0 
            END) / NULLIF(COUNT(*), 0), 1
        ) AS HygieneProcPct,
        
        -- Associated fees
        SUM(CASE 
            WHEN pc.ProcCode LIKE 'D01%'
             OR pc.ProcCode LIKE 'D02%'
             OR pc.ProcCode LIKE 'D11%'
             OR pc.ProcCode LIKE 'D43%'
             OR pc.ProcCode LIKE 'D04%'
             OR (pc.ProcCode LIKE 'D00%' AND pc.Descript LIKE '%exam%')
            THEN bp.ProcFee ELSE 0 
        END) AS HygieneFees,
        
        SUM(CASE 
            WHEN pc.ProcCode NOT LIKE 'D01%'
             AND pc.ProcCode NOT LIKE 'D02%'
             AND pc.ProcCode NOT LIKE 'D11%'
             AND pc.ProcCode NOT LIKE 'D43%'
             AND pc.ProcCode NOT LIKE 'D04%'
             AND NOT (pc.ProcCode LIKE 'D00%' AND pc.Descript LIKE '%exam%')
            THEN bp.ProcFee ELSE 0 
        END) AS NonHygieneFees
    FROM BaseProcedures bp
    JOIN procedurecode pc ON bp.CodeNum = pc.CodeNum
    WHERE bp.ProvNum > 0
      AND bp.ProcStatus = 2  -- Only count completed procedures
    GROUP BY bp.ProvNum
)