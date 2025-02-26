-- Fee Relationship Analysis
-- Examines how procedure fees compare to standard fee schedules
-- CTEs used: ExcludedCodes, BaseProcedures, StandardFees

WITH ExcludedCodes AS (
    SELECT CodeNum 
    FROM procedurecode 
    WHERE ProcCode IN (
      '~GRP~', 'D9987', 'D9986', 'Watch', 'Ztoth', 'D0350',
      '00040', 'D2919', '00051',
      'D9992', 'D9995', 'D9996',
      'D0190', 'D0171', 'D0140', 'D9430', 'D0120'
    )
),

-- Base procedure set
BaseProcedures AS (
    SELECT 
        pl.ProcNum,
        pl.PatNum,
        pl.ProvNum,
        pl.ProcDate,
        pl.ProcStatus,
        pl.ProcFee,
        pl.CodeNum,
        pl.AptNum,
        pl.DateComplete,
        pc.ProcCode,
        pc.Descript,
        CASE WHEN ec.CodeNum IS NOT NULL THEN 'Excluded' ELSE 'Standard' END AS CodeCategory
    FROM procedurelog pl
    JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
    LEFT JOIN ExcludedCodes ec ON pl.CodeNum = ec.CodeNum
    WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2024-12-31'
),

-- Standard Fee information
StandardFees AS (
    SELECT 
        bp.ProcNum,
        bp.CodeNum,
        bp.ProcFee AS recorded_fee,
        f.Amount AS standard_fee,
        f.FeeSched,
        fs.Description AS fee_schedule_desc,
        CASE 
            WHEN f.Amount = 0 THEN 'Zero Standard Fee'
            WHEN bp.ProcFee = 0 AND f.Amount > 0 THEN 'Zero Fee Override'
            WHEN bp.ProcFee > f.Amount THEN 'Above Standard'
            WHEN bp.ProcFee < f.Amount THEN 'Below Standard'
            WHEN bp.ProcFee = f.Amount THEN 'Matches Standard'
            ELSE 'Fee Missing'
        END AS fee_relationship
    FROM BaseProcedures bp
    LEFT JOIN fee f ON bp.CodeNum = f.CodeNum 
        AND f.FeeSched = 55
        AND f.ClinicNum = 0
    LEFT JOIN feesched fs ON f.FeeSched = fs.FeeSchedNum
)

-- Analysis of fee relationships
SELECT
    fee_relationship,
    COUNT(*) AS procedure_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS percentage,
    MIN(recorded_fee) AS min_fee,
    MAX(recorded_fee) AS max_fee,
    ROUND(AVG(recorded_fee), 2) AS avg_fee,
    COUNT(DISTINCT CodeNum) AS unique_codes
FROM StandardFees
GROUP BY fee_relationship
ORDER BY procedure_count DESC; 