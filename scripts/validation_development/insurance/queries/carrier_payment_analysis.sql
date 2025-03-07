/*
 * Carrier Payment Analysis
 *
 * Purpose: Analyze insurance carrier payment patterns, efficiency, and fee schedule adherence
 *
 * Output columns:
 * - CarrierName: Name of the insurance carrier
 * - TotalProcedures: Total procedures submitted to this carrier
 * - TotalPayments: Total amount paid by carrier
 * - AvgPaymentRatio: Average ratio of payment to billed amount
 * - AvgDaysToPayment: Average days from procedure to payment
 * - WriteOffPercent: Percentage of billed amount written off
 * - BlueBookAdherence: Percentage of payments matching BlueBook amounts
 * - FeeScheduleVariance: Average variance from fee schedule
 * - ClaimEfficiency: Percentage of claims paid without rejection
 * - TopProcedureCodes: Most common procedures by carrier
 *
 * Analysis Categories:
 * - Payment Efficiency: How quickly and reliably the carrier pays
 * - Fee Schedule Adherence: How well payments match expected amounts
 * - Claim Processing: Success rate of claim submissions
 * - Financial Impact: Overall financial performance with the carrier
 */
-- Date range: @start_date to @end_date
-- Dependencies: date_range.sql, procedure_payment_journey.sql, insurance_fee_schedules.sql, payment_timing_stats.sql
WITH DateRange AS (
    SELECT 
        @start_date as start_date,
        @end_date as end_date
),
ProcedurePaymentJourney AS (
    SELECT 
        pl.ProcNum,
        pl.PatNum,
        pl.ProcDate,
        pl.ProcFee,
        pl.ProcStatus,
        pl.CodeNum,
        cp.ClaimNum,
        cp.PlanNum,
        cp.InsPayEst,
        cp.InsPayAmt,
        cp.WriteOff,
        cp.DedApplied,
        cp.Status as ClaimStatus,
        cp.DateCP as ClaimPaymentDate,
        cpt.ClaimPaymentNum,
        cpt.CheckNum,
        cpt.CheckAmt,
        ps.SplitNum,
        ps.SplitAmt,
        p.PayNum,
        p.PayDate,
        p.PayAmt as TotalPaymentAmount,
        -- BlueBook tracking
        ibb.InsPayAmt as BlueBookPayAmt,
        ibb.AllowedOverride as BlueBookAllowed,
        ibbl.AllowedFee as LoggedAllowedFee,
        -- Payment analysis
        COALESCE(cp.InsPayAmt, 0) + COALESCE(cp.WriteOff, 0) + COALESCE(cp.DedApplied, 0) as total_insurance_handled,
        pl.ProcFee - (COALESCE(cp.InsPayAmt, 0) + COALESCE(cp.WriteOff, 0) + COALESCE(cp.DedApplied, 0)) as remaining_patient_portion,
        CASE 
            WHEN cp.Status IN (1, 4, 5) THEN 'Paid'
            WHEN cp.Status = 6 THEN 'Rejected'
            WHEN cp.Status = 2 THEN 'Sent'
            WHEN cp.Status = 3 THEN 'Pending'
            ELSE 'Other'
        END as payment_status,
        CASE 
            WHEN cp.DateCP IS NOT NULL AND cp.DateCP >= pl.ProcDate 
            THEN DATEDIFF(cp.DateCP, pl.ProcDate)
            ELSE NULL
        END as days_to_payment
    FROM procedurelog pl FORCE INDEX (idx_ml_proc_core)
    LEFT JOIN claimproc cp FORCE INDEX (idx_ml_claimproc_core) 
        ON pl.ProcNum = cp.ProcNum
    LEFT JOIN claimpayment cpt 
        ON cp.ClaimPaymentNum = cpt.ClaimPaymentNum
    LEFT JOIN paysplit ps FORCE INDEX (idx_ml_paysplit_payment)
        ON pl.ProcNum = ps.ProcNum
    LEFT JOIN payment p FORCE INDEX (idx_ml_payment_core)
        ON ps.PayNum = p.PayNum
    LEFT JOIN insbluebook ibb 
        ON pl.ProcNum = ibb.ProcNum
    LEFT JOIN insbluebooklog ibbl 
        ON cp.ClaimProcNum = ibbl.ClaimProcNum
    CROSS JOIN DateRange d
    WHERE pl.ProcDate BETWEEN d.start_date AND d.end_date
        AND pl.ProcStatus = 2 -- Complete
        AND (cp.ClaimNum IS NULL OR cp.Status != 7) -- Exclude reversed claims
),
InsuranceFeeSchedules AS (
    SELECT 
        ip.PlanNum,
        ip.CarrierNum,
        ip.FeeSched as PlanFeeSched,
        ip.AllowedFeeSched,
        ip.CopayFeeSched,
        fs.Description as FeeSchedDesc,
        fs.FeeSchedType,
        f.CodeNum,
        f.Amount as FeeAmount,
        f.UseDefaultFee,
        f.ClinicNum,
        COALESCE(fsg.Description, 'No Group') as FeeSchedGroupDesc,
        COUNT(DISTINCT cp.ClaimProcNum) as times_used_in_claims,
        AVG(CASE 
            WHEN cp.Status IN (1, 4, 5) -- Received statuses
            THEN cp.InsPayAmt / NULLIF(cp.FeeBilled, 0) 
            END) as avg_payment_ratio,
        SUM(CASE 
            WHEN cp.Status IN (1, 4, 5) 
            THEN cp.InsPayAmt 
            END) as total_payments,
        COUNT(DISTINCT CASE 
            WHEN cp.Status IN (1, 4, 5) 
            THEN cp.ClaimProcNum 
            END) as paid_claim_count
    FROM insplan ip
    JOIN feesched fs ON ip.FeeSched = fs.FeeSchedNum
    LEFT JOIN fee f FORCE INDEX (idx_ml_fee_core)
        ON fs.FeeSchedNum = f.FeeSched
    LEFT JOIN feeschedgroup fsg 
        ON fs.FeeSchedNum = fsg.FeeSchedNum
    LEFT JOIN claimproc cp FORCE INDEX (idx_ml_claimproc_core)
        ON ip.PlanNum = cp.PlanNum
    LEFT JOIN procedurelog pl FORCE INDEX (idx_ml_proc_core)
        ON cp.ProcNum = pl.ProcNum 
        AND f.CodeNum = pl.CodeNum
    CROSS JOIN DateRange d
    WHERE pl.ProcDate BETWEEN d.start_date AND d.end_date
    GROUP BY 
        ip.PlanNum,
        ip.CarrierNum,
        ip.FeeSched,
        ip.AllowedFeeSched,
        ip.CopayFeeSched,
        fs.Description,
        fs.FeeSchedType,
        f.CodeNum,
        f.Amount,
        f.UseDefaultFee,
        f.ClinicNum,
        COALESCE(fsg.Description, 'No Group')
),
PaymentTimingStats AS (
    SELECT 
        PlanNum,
        AVG(sorted_days) as median_days_to_payment
    FROM (
        SELECT 
            PlanNum,
            days_to_payment as sorted_days,
            ROW_NUMBER() OVER (PARTITION BY PlanNum ORDER BY days_to_payment) as row_num,
            COUNT(*) OVER (PARTITION BY PlanNum) as total_rows
        FROM ProcedurePaymentJourney
        WHERE days_to_payment IS NOT NULL
            AND days_to_payment >= 0    -- Exclude negative values
            AND days_to_payment <= 365  -- Exclude unreasonable values
    ) ranked
    WHERE row_num BETWEEN (total_rows + 1)/2 AND (total_rows + 2)/2
    GROUP BY PlanNum
),
ProcedureStats AS (
    SELECT 
        c.CarrierNum,
        ppj.CodeNum,
        COUNT(DISTINCT ppj.ProcNum) as proc_count,
        ROUND(AVG(ppj.InsPayAmt / NULLIF(ppj.ProcFee, 0)) * 100, 1) as payment_ratio
    FROM carrier c
    LEFT JOIN insplan ip ON c.CarrierNum = ip.CarrierNum
    LEFT JOIN ProcedurePaymentJourney ppj ON ip.PlanNum = ppj.PlanNum
    WHERE NOT c.IsHidden
        AND ppj.ProcNum IS NOT NULL
    GROUP BY 
        c.CarrierNum,
        ppj.CodeNum
    HAVING proc_count >= 5
),
CarrierStats AS (
    SELECT 
        TRIM(REGEXP_REPLACE(UPPER(c.CarrierName), '\\s+', ' ')) as NormalizedCarrierName,
        c.CarrierNum,
        c.CarrierName as OriginalCarrierName,
        c.ElectID,
        COUNT(DISTINCT ppj.ProcNum) as TotalProcedures,
        COUNT(DISTINCT ppj.ClaimNum) as TotalClaims,
        COUNT(DISTINCT CASE WHEN ppj.payment_status = 'Paid' THEN ppj.ClaimNum END) as PaidClaims,
        SUM(ppj.ProcFee) as TotalBilled,
        SUM(ppj.InsPayAmt) as TotalPayments,
        SUM(ppj.WriteOff) as TotalWriteoffs,
        SUM(ppj.DedApplied) as TotalDeductibles,
        ROUND(AVG(CASE 
            WHEN ppj.days_to_payment IS NOT NULL 
            AND ppj.days_to_payment >= 0 
            AND ppj.days_to_payment <= 365 
            THEN ppj.days_to_payment 
        END), 1) as AvgDaysToPayment,
        ROUND(AVG(pts.median_days_to_payment), 1) as MedianDaysToPayment,
        ROUND(AVG(ppj.InsPayAmt / NULLIF(ppj.ProcFee, 0)) * 100, 2) as AvgPaymentRatio,
        ROUND(AVG(CASE 
            WHEN ifs.FeeAmount > 0 
            THEN ABS(ppj.InsPayAmt - ifs.FeeAmount) / ifs.FeeAmount * 100
            END), 2) as AvgFeeScheduleVariance,
        COUNT(DISTINCT CASE WHEN ppj.BlueBookPayAmt IS NOT NULL THEN ppj.ProcNum END) as BlueBookProcedures,
        ROUND(AVG(CASE 
            WHEN ppj.BlueBookPayAmt IS NOT NULL AND ppj.BlueBookPayAmt > 0
            THEN ABS(ppj.InsPayAmt - ppj.BlueBookPayAmt) / ppj.BlueBookPayAmt * 100
            END), 2) as BlueBookVariance,
        ROUND(COUNT(DISTINCT CASE 
            WHEN ppj.payment_status = 'Rejected' 
            THEN ppj.ClaimNum 
            END) * 100.0 / NULLIF(COUNT(DISTINCT ppj.ClaimNum), 0), 2) as RejectionRate,
        ROUND(AVG(CASE 
            WHEN ppj.payment_status = 'Paid' 
            THEN ppj.total_insurance_handled / NULLIF(ppj.ProcFee, 0) * 100
            END), 2) as AvgCoverageRate,
        ROUND(SUM(ppj.WriteOff) * 100.0 / NULLIF(SUM(ppj.ProcFee), 0), 2) as WriteOffPercent,
        ROUND(SUM(ppj.InsPayAmt) * 100.0 / NULLIF(SUM(ppj.ProcFee), 0), 2) as PaymentPercent,
        ROUND(SUM(ppj.DedApplied) * 100.0 / NULLIF(SUM(ppj.ProcFee), 0), 2) as DeductiblePercent,
        (
            SELECT GROUP_CONCAT(
                CONCAT(
                    ps.CodeNum, ':', 
                    ps.proc_count, ' procs,',
                    ps.payment_ratio, '% paid'
                )
                ORDER BY ps.proc_count DESC
                SEPARATOR '; '
            )
            FROM ProcedureStats ps
            WHERE ps.CarrierNum = c.CarrierNum
        ) as TopProcedureCodes
    FROM carrier c
    LEFT JOIN insplan ip ON c.CarrierNum = ip.CarrierNum
    LEFT JOIN ProcedurePaymentJourney ppj ON ip.PlanNum = ppj.PlanNum
    LEFT JOIN InsuranceFeeSchedules ifs ON ip.PlanNum = ifs.PlanNum
        AND ppj.CodeNum = ifs.CodeNum
    LEFT JOIN PaymentTimingStats pts ON ppj.PlanNum = pts.PlanNum
    WHERE NOT c.IsHidden
    GROUP BY 
        TRIM(REGEXP_REPLACE(UPPER(c.CarrierName), '\\s+', ' ')),
        c.CarrierNum,
        c.CarrierName,
        c.ElectID
    HAVING COUNT(DISTINCT ppj.ProcNum) > 0
)

SELECT 
    cs.OriginalCarrierName as CarrierName,
    cs.ElectID,
    cs.TotalProcedures,
    cs.TotalClaims,
    cs.PaidClaims,
    cs.TotalBilled,
    cs.TotalPayments,
    cs.TotalWriteoffs,
    cs.TotalDeductibles,
    cs.AvgPaymentRatio,
    cs.AvgDaysToPayment,
    cs.MedianDaysToPayment,
    cs.AvgFeeScheduleVariance,
    cs.BlueBookProcedures,
    cs.BlueBookVariance,
    cs.RejectionRate,
    cs.AvgCoverageRate,
    cs.WriteOffPercent,
    cs.PaymentPercent,
    cs.DeductiblePercent,
    cs.TopProcedureCodes
FROM CarrierStats cs
ORDER BY 
    cs.TotalPayments DESC,
    cs.OriginalCarrierName
LIMIT 200; 