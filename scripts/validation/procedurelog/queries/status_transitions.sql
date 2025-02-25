-- Status Transitions Query
-- Validates the status transitions of procedures and identifies potential issues

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

-- Payment information for procedures
PaymentActivity AS (
    SELECT 
        pl.ProcNum,
        pl.ProcFee,
        COALESCE(SUM(cp.InsPayAmt), 0) AS insurance_paid,
        COALESCE(SUM(ps.SplitAmt), 0) AS direct_paid,
        COALESCE(SUM(cp.InsPayAmt), 0) + COALESCE(SUM(ps.SplitAmt), 0) AS total_paid,
        CASE 
            WHEN pl.ProcFee > 0 THEN 
                (COALESCE(SUM(cp.InsPayAmt), 0) + COALESCE(SUM(ps.SplitAmt), 0)) / pl.ProcFee 
            ELSE NULL 
        END AS payment_ratio
    FROM BaseProcedures pl
    LEFT JOIN claimproc cp ON pl.ProcNum = cp.ProcNum AND cp.InsPayAmt > 0
    LEFT JOIN paysplit ps ON pl.ProcNum = ps.ProcNum AND ps.SplitAmt > 0
    GROUP BY pl.ProcNum, pl.ProcFee
),

-- Success criteria evaluation
SuccessCriteria AS (
    SELECT
        bp.ProcNum,
        bp.ProcStatus,
        bp.ProcFee,
        bp.CodeCategory,
        pa.total_paid,
        pa.payment_ratio,
        CASE
            -- Case 1: Completed procedure with zero fee (not excluded)
            WHEN bp.ProcStatus = 2 AND bp.ProcFee = 0 AND bp.CodeCategory = 'Standard' THEN TRUE
            -- Case 2: Completed procedure with fee >= 95% paid
            WHEN bp.ProcStatus = 2 AND bp.ProcFee > 0 AND pa.payment_ratio >= 0.95 THEN TRUE
            -- All other cases are not successful
            ELSE FALSE
        END AS is_successful
    FROM BaseProcedures bp
    LEFT JOIN PaymentActivity pa ON bp.ProcNum = pa.ProcNum
),

-- Find procedures with status change history
StatusHistory AS (
    SELECT 
        pl.ProcNum,
        pl.ProcStatus,
        pl.ProcDate,
        pl.DateComplete,
        pl.AptNum,
        pl.ProcFee,
        pc.ProcCode,
        pc.Descript,
        CASE pl.ProcStatus
            WHEN 1 THEN 'Treatment Planned'
            WHEN 2 THEN 'Completed'
            WHEN 3 THEN 'Existing Current'
            WHEN 4 THEN 'Existing Other'
            WHEN 5 THEN 'Referred'
            WHEN 6 THEN 'Deleted'
            WHEN 7 THEN 'Condition'
            WHEN 8 THEN 'Invalid'
            ELSE 'Unknown'
        END AS status_description,
        -- Time in current status - FIXED with DATEDIFF for MariaDB compatibility
        CASE 
            WHEN pl.DateComplete IS NOT NULL THEN 
                DATEDIFF(CURRENT_DATE, pl.DateComplete) 
            ELSE 
                DATEDIFF(CURRENT_DATE, pl.ProcDate)
        END AS days_in_status,
        -- Identify expected transition patterns
        CASE
            -- Valid normal transitions
            WHEN pl.ProcStatus = 2 AND pl.DateComplete IS NOT NULL THEN 'Completed with date'
            WHEN pl.ProcStatus = 2 AND pl.DateComplete IS NULL THEN 'Completed missing date'
            WHEN pl.ProcStatus = 1 AND pl.DateComplete IS NULL THEN 'Planned (normal)'
            WHEN pl.ProcStatus = 1 AND pl.DateComplete IS NOT NULL THEN 'Planned with completion date'
            WHEN pl.ProcStatus = 6 AND pl.ProcFee = 0 THEN 'Deleted zero-fee'
            WHEN pl.ProcStatus = 6 AND pl.ProcFee > 0 THEN 'Deleted with fee'
            -- Terminal states
            WHEN pl.ProcStatus IN (3, 4, 5, 7) THEN 'Terminal status'
            ELSE 'Other pattern'
        END AS transition_pattern
    FROM BaseProcedures pl
    JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
),

-- Analyze procedures by status and transition pattern
TransitionAnalysis AS (
    SELECT
        status_description,
        transition_pattern,
        COUNT(*) AS procedure_count,
        MIN(days_in_status) AS min_days,
        MAX(days_in_status) AS max_days,
        ROUND(AVG(days_in_status), 1) AS avg_days,
        SUM(ProcFee) AS total_fees,
        COUNT(CASE WHEN ProcFee > 0 THEN 1 END) AS with_fee_count,
        COUNT(CASE WHEN AptNum IS NOT NULL THEN 1 END) AS with_appointment
    FROM StatusHistory
    GROUP BY status_description, transition_pattern
)

-- Main results
SELECT
    status_description,
    transition_pattern,
    procedure_count,
    ROUND(100.0 * procedure_count / SUM(procedure_count) OVER (PARTITION BY status_description), 2) AS pct_of_status,
    with_fee_count,
    ROUND(100.0 * with_fee_count / procedure_count, 2) AS with_fee_pct,
    with_appointment,
    ROUND(100.0 * with_appointment / procedure_count, 2) AS with_appt_pct,
    min_days,
    avg_days,
    max_days,
    total_fees
FROM TransitionAnalysis
ORDER BY status_description, procedure_count DESC; 