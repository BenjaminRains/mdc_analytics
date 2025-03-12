/* DEVELOPMENT

Create Fee Exploration Model:

Develop a separate intermediate model specifically for exploring fee calculations
Join procedurelog, fee, feesched, and adjustment to trace the complete fee history


Fee System Documentation:

Document the observed patterns in how fees flow through the system
Create a diagram showing how base fees are set and modified

Fee Storage vs. Applied Fees:

The fee and feesched tables seem to store the reference fee amounts - essentially defining what "should" be charged for each procedure code
As you noted, the actual fee that gets charged is stored in procedurelog.ProcFee
The fee application process likely involves selecting the appropriate fee from the reference tables based on business rules


Fee Modification System:

After the base ProcFee is established, it appears to be modified through:

Adjustments (tracked in the adjustment table)
Insurance write-offs (likely tracked both in adjustment and claimproc)
Discounts (various types captured in adjustment.AdjType)
*/

-- This query explores the relationship between reference fees and applied fees
WITH proc_fees AS (
    SELECT 
        pl.ProcNum as procedure_id,
        pl.PatNum as patient_id,
        pl.ProcCode as procedure_code,
        pl.ProcFee as applied_fee,
        pl.ProcDate as procedure_date,
        pl.ProvNum as provider_id,
        pl.ClinicNum as clinic_id
    FROM procedurelog pl
    WHERE pl.ProcDate >= '2022-01-01'
),

reference_fees AS (
    SELECT 
        f.ProcCode as procedure_code,
        f.FeeSchedNum as fee_schedule_id,
        fs.Description as fee_schedule_name,
        f.Amount as reference_fee_amount,
        f.ClinicNum as clinic_id,
        f.ProvNum as provider_id
    FROM fee f
    JOIN feesched fs ON f.FeeSchedNum = fs.FeeSchedNum
),

fee_adjustments AS (
    SELECT
        a.ProcNum as procedure_id,
        SUM(a.AdjAmt) as total_adjustments,
        COUNT(*) as adjustment_count
    FROM adjustment a
    WHERE a.ProcNum > 0
    AND a.AdjDate >= '2022-01-01'
    GROUP BY a.ProcNum
)

SELECT
    pf.procedure_id,
    pf.patient_id,
    pf.procedure_code,
    pf.applied_fee,
    rf.reference_fee_amount,
    -- Calculate difference between reference and applied fee
    pf.applied_fee - COALESCE(rf.reference_fee_amount, 0) as fee_difference,
    -- Include adjustments
    COALESCE(fa.total_adjustments, 0) as adjustments,
    -- Calculate final effective fee
    pf.applied_fee + COALESCE(fa.total_adjustments, 0) as effective_fee,
    pf.procedure_date,
    rf.fee_schedule_name
FROM proc_fees pf
LEFT JOIN reference_fees rf 
    ON pf.procedure_code = rf.procedure_code
    AND (pf.clinic_id = rf.clinic_id OR rf.clinic_id IS NULL)
    AND (pf.provider_id = rf.provider_id OR rf.provider_id IS NULL)
LEFT JOIN fee_adjustments fa ON pf.procedure_id = fa.procedure_id
-- Limit to a sample for exploration
LIMIT 1000;