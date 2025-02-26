-- ProcedurePayments: Extract procedure-level payment details.
-- depends on: none
-- Date filter: 2024-01-01 to 2025-01-01
ProcedurePayments AS (
    SELECT 
        pl.ProcNum,
        pl.ProcFee,
        pl.ProcStatus,
        pl.CodeNum,
        ps.PayNum,
        ps.SplitAmt,
        p.PayAmt,
        p.PayDate,
        pl.ProcDate,
        ps.UnearnedType,
        DATEDIFF(p.PayDate, pl.ProcDate) AS days_to_payment,
        ROW_NUMBER() OVER (PARTITION BY pl.ProcNum ORDER BY p.PayDate) AS payment_sequence,
        CASE 
            WHEN pl.ProcStatus = 1 THEN 'Complete'
            WHEN pl.ProcStatus = 2 THEN 'Existing'
            ELSE 'Other'
        END AS proc_status_desc,
        CASE WHEN ps.UnearnedType = 439 THEN 1 ELSE 0 END as is_prepayment,
        CASE WHEN DATEDIFF(p.PayDate, pl.ProcDate) < 0 THEN 1 ELSE 0 END as is_advance_payment,
        CASE 
            WHEN pl.ProcStatus = 1 AND pl.ProcFee > 1000 THEN 'major'
            WHEN pl.ProcStatus = 1 THEN 'minor'
            WHEN pl.ProcStatus = 2 THEN 'existing'
            ELSE 'other'
        END as procedure_category
    FROM procedurelog pl
    JOIN paysplit ps ON pl.ProcNum = ps.ProcNum
    JOIN payment p ON ps.PayNum = p.PayNum
    WHERE p.PayDate >= '2024-01-01'
      AND p.PayDate < '2025-01-01'
)