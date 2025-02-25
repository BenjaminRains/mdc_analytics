-- Fee Validation Query
-- Analyzes procedure fees across different ranges, categories, and relationships
-- to fee schedules and adjustments

-- Define excluded codes that are exempt from payment validation
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

-- Base procedure set (filtered by date range)
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
    WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2024-12-31'  -- Fixed date range for testing
),

-- Standard Fee information (from fee table)
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
        AND f.FeeSched = 55  -- Primary fee schedule, adjust if needed
        AND f.ClinicNum = 0  -- Default clinic, adjust if needed
    LEFT JOIN feesched fs ON f.FeeSched = fs.FeeSchedNum
),

-- Adjustment information
ProcedureAdjustments AS (
    SELECT
        bp.ProcNum,
        bp.ProcFee,
        COUNT(a.AdjNum) AS adjustment_count,
        COALESCE(SUM(a.AdjAmt), 0) AS total_adjustments,
        bp.ProcFee + COALESCE(SUM(a.AdjAmt), 0) AS adjusted_fee  -- Adjustments are typically negative
    FROM BaseProcedures bp
    LEFT JOIN adjustment a ON bp.ProcNum = a.ProcNum
    GROUP BY bp.ProcNum, bp.ProcFee
),

-- Payment information for procedures
PaymentActivity AS (
    SELECT 
        pl.ProcNum,
        pl.ProcFee,
        COALESCE(SUM(cp.InsPayAmt), 0) AS insurance_paid,
        COALESCE(SUM(ps.SplitAmt), 0) AS direct_paid,
        COALESCE(SUM(cp.InsPayAmt), 0) + COALESCE(SUM(ps.SplitAmt), 0) AS total_paid
    FROM BaseProcedures pl
    LEFT JOIN claimproc cp ON pl.ProcNum = cp.ProcNum AND cp.InsPayAmt > 0
    LEFT JOIN paysplit ps ON pl.ProcNum = ps.ProcNum AND ps.SplitAmt > 0
    GROUP BY pl.ProcNum, pl.ProcFee
),

-- Patient responsibility calculation
PatientResponsibility AS (
    SELECT
        bp.ProcNum,
        bp.ProcFee,
        pa.total_paid,
        adj.total_adjustments,
        bp.ProcFee - (pa.total_paid + ABS(adj.total_adjustments)) AS patient_responsibility,
        CASE 
            WHEN bp.ProcFee = 0 THEN 'Zero Fee'
            WHEN bp.ProcFee - (pa.total_paid + ABS(adj.total_adjustments)) <= 0 THEN 'Fully Covered'
            WHEN bp.ProcFee - (pa.total_paid + ABS(adj.total_adjustments)) < bp.ProcFee * 0.2 THEN 'Mostly Covered'
            WHEN bp.ProcFee - (pa.total_paid + ABS(adj.total_adjustments)) < bp.ProcFee * 0.5 THEN 'Partially Covered'
            ELSE 'Primarily Patient Responsibility'
        END AS responsibility_category
    FROM BaseProcedures bp
    LEFT JOIN PaymentActivity pa ON bp.ProcNum = pa.ProcNum
    LEFT JOIN ProcedureAdjustments adj ON bp.ProcNum = adj.ProcNum
),

-- Fee ranges for analysis
FeeRanges AS (
    SELECT
        bp.ProcNum,
        bp.ProcFee,
        bp.ProcCode,
        bp.ProcStatus,
        bp.CodeCategory,
        sf.fee_relationship,
        pr.responsibility_category,
        CASE
            WHEN bp.ProcFee = 0 THEN 'Zero Fee'
            WHEN bp.ProcFee < 100 THEN 'Under $100'
            WHEN bp.ProcFee < 250 THEN '$100-$249'
            WHEN bp.ProcFee < 500 THEN '$250-$499'
            WHEN bp.ProcFee < 1000 THEN '$500-$999'
            WHEN bp.ProcFee < 2000 THEN '$1000-$1999'
            ELSE '$2000+'
        END AS fee_range
    FROM BaseProcedures bp
    JOIN StandardFees sf ON bp.ProcNum = sf.ProcNum
    JOIN PatientResponsibility pr ON bp.ProcNum = pr.ProcNum
)

-- Analysis by fee range
SELECT
    fee_range,
    COUNT(*) AS procedure_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS percentage,
    MIN(ProcFee) AS min_fee,
    MAX(ProcFee) AS max_fee,
    ROUND(AVG(ProcFee), 2) AS avg_fee,
    COUNT(DISTINCT ProcCode) AS unique_codes,
    -- Status breakdown
    SUM(CASE WHEN ProcStatus = 2 THEN 1 ELSE 0 END) AS completed_count,
    SUM(CASE WHEN ProcStatus = 1 THEN 1 ELSE 0 END) AS planned_count,
    -- Excluded codes metrics
    SUM(CASE WHEN CodeCategory = 'Excluded' THEN 1 ELSE 0 END) AS excluded_count,
    ROUND(100.0 * SUM(CASE WHEN CodeCategory = 'Excluded' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS excluded_pct,
    -- Fee relationship to standard
    SUM(CASE WHEN fee_relationship = 'Matches Standard' THEN 1 ELSE 0 END) AS standard_fee_count,
    ROUND(100.0 * SUM(CASE WHEN fee_relationship = 'Matches Standard' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS standard_pct,
    -- Patient responsibility
    SUM(CASE WHEN responsibility_category = 'Fully Covered' THEN 1 ELSE 0 END) AS fully_covered_count,
    ROUND(100.0 * SUM(CASE WHEN responsibility_category = 'Fully Covered' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS fully_covered_pct
FROM FeeRanges
GROUP BY fee_range
ORDER BY 
    CASE fee_range
        WHEN 'Zero Fee' THEN 1
        WHEN 'Under $100' THEN 2
        WHEN '$100-$249' THEN 3
        WHEN '$250-$499' THEN 4
        WHEN '$500-$999' THEN 5
        WHEN '$1000-$1999' THEN 6
        WHEN '$2000+' THEN 7
    END;
