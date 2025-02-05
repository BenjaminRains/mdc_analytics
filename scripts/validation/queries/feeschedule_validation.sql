/*
Fee Schedule Validation Query
Purpose: Comprehensive fee schedule analysis including historical trends,
         procedure mix, adjustment patterns, and comparisons
Tables: procedurelog, fee, feesched, procedurecode
*/

WITH DateRange AS (
    SELECT '2022-01-01' as start_date,
           '2025-01-01' as end_date
),
BaseProcedures AS (
    -- First filter procedures to reduce JOIN size
    SELECT 
        pl.CodeNum,
        pl.ProcFee,
        pl.PatNum,
        pl.ProcNum,
        pl.ProcDate,
        f.Amount as ScheduledFee,
        f.FeeSched,
        fs.Description as FeeSchedDesc,
        pc.Descript as ProcedureDesc,
        DATE_FORMAT(pl.ProcDate, '%Y-%m') as YearMonth,
        YEAR(pl.ProcDate) as YearOf,
        MONTH(pl.ProcDate) as MonthOf
    FROM procedurelog pl
    JOIN fee f ON pl.CodeNum = f.CodeNum
    JOIN feesched fs ON f.FeeSched = fs.FeeSchedNum
    JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum, 
    DateRange d
    WHERE pl.ProcStatus = 2
        AND pl.ProcDate >= d.start_date
        AND pl.ProcDate < d.end_date
        AND f.FeeSched IN (55, 54, 8278, 8274, 8286, 8291)
),
FeeAnalysis AS (
    -- Historical trends and basic metrics
    SELECT 
        FeeSched,
        FeeSchedDesc,
        YearOf,
        MonthOf,
        COUNT(DISTINCT ProcNum) as ProcCount,
        COUNT(DISTINCT PatNum) as PatientCount,
        ROUND(AVG(ProcFee), 2) as AvgProcFee,
        ROUND(MIN(ProcFee), 2) as MinFee,
        ROUND(MAX(ProcFee), 2) as MaxFee,
        ROUND(AVG(CASE 
            WHEN ProcFee = ScheduledFee THEN 0
            WHEN ProcFee > ScheduledFee THEN ProcFee - ScheduledFee
            ELSE ScheduledFee - ProcFee
        END), 2) as AvgAdjustment,
        COUNT(CASE WHEN ProcFee > ScheduledFee THEN 1 END) as IncreasedCount,
        COUNT(CASE WHEN ProcFee < ScheduledFee THEN 1 END) as ReducedCount,
        COUNT(CASE WHEN ProcFee = ScheduledFee THEN 1 END) as NoAdjustmentCount
    FROM BaseProcedures
    GROUP BY 
        FeeSched,
        FeeSchedDesc,
        YearOf,
        MonthOf
),
ProcedureMix AS (
    -- Procedure type analysis
    SELECT 
        FeeSched,
        FeeSchedDesc,
        CodeNum,
        ProcedureDesc,
        COUNT(*) as ProcedureCount,
        ROUND(AVG(ProcFee), 2) as AvgProcFee,
        ROUND(MIN(ProcFee), 2) as MinFee,
        ROUND(MAX(ProcFee), 2) as MaxFee
    FROM BaseProcedures
    GROUP BY 
        FeeSched,
        FeeSchedDesc,
        CodeNum,
        ProcedureDesc
    HAVING ProcedureCount > 10
)
-- Output combined analysis
SELECT 
    fa.FeeSched,
    fa.FeeSchedDesc,
    fa.YearOf,
    fa.MonthOf,
    fa.ProcCount,
    fa.PatientCount,
    fa.AvgProcFee,
    fa.MinFee,
    fa.MaxFee,
    fa.AvgAdjustment,
    fa.IncreasedCount,
    fa.ReducedCount,
    fa.NoAdjustmentCount,
    pm.ProcedureCount as TopProcedureCount,
    pm.ProcedureDesc as TopProcedure
FROM FeeAnalysis fa
LEFT JOIN (
    SELECT 
        FeeSched,
        ProcedureDesc,
        ProcedureCount,
        ROW_NUMBER() OVER (PARTITION BY FeeSched ORDER BY ProcedureCount DESC) as rn
    FROM ProcedureMix
) pm ON fa.FeeSched = pm.FeeSched AND pm.rn = 1
ORDER BY 
    fa.FeeSched,
    fa.YearOf,
    fa.MonthOf;