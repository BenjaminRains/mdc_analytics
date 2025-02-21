/*
 * Fee and Payment Process Validation
 *
 * Purpose:
 * - Track complete payment lifecycle for each procedure
 * - Validate fee population and adjustments
 * - Monitor insurance claim processing
 * - Analyze payment patterns and splits
 * - Track insurance fee schedules and bluebook data
 *
 * Time period: 2024 calendar year (with 4-year lookback)
 * Output file: /validation/data/payment_lifecycle_2024.csv
 *
 * Output Dataset Fields:
 * Base Fee Data:
 *    - ProcNum, CodeNum: Identifiers
 *    - ProcFee: Actual charged fee
 *    - clinic_fee: Standard fee amount
 *    - fee_old_code, fee_number: Fee references
 *    - procedure_description: Procedure name
 *
 * Adjustment Data:
 *    - adjustment_count: Number of adjustments
 *    - total_adj_amt: Total adjustment amount
 *    - adjustment_types: List of adjustment categories
 *
 * Insurance Claims:
 *    - claim_count: Number of claims
 *    - total_fee_billed: Amount billed to insurance
 *    - total_ins_pay_est/amt: Expected vs actual payments
 *    - total_writeoff: Total writeoff amount
 *    - insurance_plan_type: Type of insurance plan
 *    - fee_schedule_description: Fee schedule name
 *    - fee_sched_type: Type of fee schedule
 *
 * Payment Records:
 *    - payment_count: Number of payments
 *    - total_pay_amt: Total payment amount
 *    - total_split_amt: Total split amount
 *    - payment_types: List of payment categories
 *
 * Bluebook Information:
 *    - avg_bluebook_ins_pay_amt: Average insurance payment
 *    - avg_bluebook_allowed_override: Average allowed override
 *    - bluebook_claim_types: Types of claims
 *    - avg_bluebook_log_allowed_fee: Average allowed fee
 *    - bluebook_log_descriptions: Log descriptions
 */

WITH 
-- Base fee and procedure data from procedurelog joined to fee and procedurecode.
BaseFee AS (
    SELECT 
       pl.ProcNum,
       pl.CodeNum,
       pl.ProcFee,
       pl.PatNum,
       pl.ProcDate,
       f.Amount AS clinic_fee,
       f.OldCode AS fee_old_code,
       f.FeeNum AS fee_number,
       pc.Descript AS procedure_description
    FROM procedurelog pl
    LEFT JOIN fee f ON pl.CodeNum = f.CodeNum
    LEFT JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
    WHERE pl.ProcStatus = 2
      AND CAST(pl.ProcDate AS DATE) >= DATE_SUB(CURRENT_DATE, INTERVAL 4 YEAR)
),
-- Aggregated discount adjustments (e.g., clinic or provider discounts) by ProcNum.
AdjDiscount AS (
    SELECT 
       a.ProcNum,
       COUNT(*) AS adjustment_count,
       SUM(a.AdjAmt) AS total_adj_amt,
       GROUP_CONCAT(DISTINCT d.ItemName SEPARATOR '; ') AS adjustment_types
    FROM adjustment a
    JOIN definition d ON a.AdjType = d.DefNum
    WHERE a.AdjDate >= DATE_SUB(CURRENT_DATE, INTERVAL 4 YEAR)
    GROUP BY a.ProcNum
),
-- Aggregated insurance claim details from claimproc joined with claim, insplan, and feesched.
InsuranceClaims AS (
    SELECT 
       cp.ProcNum,
       COUNT(*) AS claim_count,
       MAX(cp.ClaimNum) AS last_claim_num,
       SUM(cp.FeeBilled) AS total_fee_billed,
       SUM(cp.InsPayEst) AS total_ins_pay_est,
       SUM(cp.InsPayAmt) AS total_ins_pay_amt,
       SUM(cp.WriteOff) AS total_writeoff,
       MAX(ip.PlanType) AS insurance_plan_type,
       MAX(ip.GroupName) AS insurance_group_name,
       MAX(fs.Description) AS fee_schedule_description,
       MAX(fs.FeeSchedType) AS fee_sched_type,
       GROUP_CONCAT(DISTINCT ip.CarrierNum SEPARATOR '; ') AS carrier_numbers
    FROM claimproc cp
    JOIN claim c ON cp.ClaimNum = c.ClaimNum
    JOIN insplan ip ON c.PlanNum = ip.PlanNum
    JOIN feesched fs ON ip.FeeSched = fs.FeeSchedNum
    WHERE cp.Status IN (1,2)
      AND (cp.InsPayAmt > 0 OR cp.InsPayEst > 0 OR cp.WriteOff > 0)
      AND c.DateService >= DATE_SUB(CURRENT_DATE, INTERVAL 4 YEAR)
      AND EXISTS (
           SELECT 1 FROM claimproc cp2 
           WHERE cp2.ProcNum = cp.ProcNum 
             AND cp2.InsPayAmt <> cp2.InsPayEst
      )
    GROUP BY cp.ProcNum
),
-- Aggregated payment data from payment and paysplit by ProcNum.
PaymentRecords AS (
    SELECT 
       ps.ProcNum,
       COUNT(*) AS payment_count,
       SUM(p.PayAmt) AS total_pay_amt,
       SUM(ps.SplitAmt) AS total_split_amt,
       GROUP_CONCAT(DISTINCT d.ItemName SEPARATOR '; ') AS payment_types
    FROM payment p
    LEFT JOIN paysplit ps ON p.PayNum = ps.PayNum
    LEFT JOIN definition d ON ps.UnearnedType = d.DefNum
    WHERE p.PayAmt <> 0
      AND p.PayDate >= DATE_SUB(CURRENT_DATE, INTERVAL 4 YEAR)
    GROUP BY ps.ProcNum
),
-- Aggregated blue book information from insbluebook and insbluebooklog by ProcNum.
BlueBookInfo AS (
    SELECT 
       cp.ProcNum,
       AVG(ibb.InsPayAmt) AS avg_bluebook_ins_pay_amt,
       AVG(ibb.AllowedOverride) AS avg_bluebook_allowed_override,
       GROUP_CONCAT(DISTINCT ibb.ClaimType SEPARATOR '; ') AS bluebook_claim_types,
       AVG(ibbl.AllowedFee) AS avg_bluebook_log_allowed_fee,
       GROUP_CONCAT(DISTINCT ibbl.Description SEPARATOR '; ') AS bluebook_log_descriptions
    FROM claimproc cp
    LEFT JOIN insbluebook ibb ON cp.ProcNum = ibb.ProcNum
    LEFT JOIN insbluebooklog ibbl ON cp.ClaimProcNum = ibbl.ClaimProcNum
    WHERE cp.Status IN (1,2)
    GROUP BY cp.ProcNum
)
-- Combine all the above components into a single output dataset.
SELECT 
    b.ProcNum,
    b.CodeNum,
    b.ProcFee,
    b.PatNum,
    b.ProcDate,
    b.clinic_fee,
    b.fee_old_code,
    b.fee_number,
    b.procedure_description,
    ad.adjustment_count,
    ad.total_adj_amt,
    ad.adjustment_types,
    ic.claim_count,
    ic.last_claim_num,
    ic.total_fee_billed,
    ic.total_ins_pay_est,
    ic.total_ins_pay_amt,
    ic.total_writeoff,
    ic.insurance_plan_type,
    ic.insurance_group_name,
    ic.fee_schedule_description,
    ic.fee_sched_type,
    ic.carrier_numbers,
    pr.payment_count,
    pr.total_pay_amt,
    pr.total_split_amt,
    pr.payment_types,
    bb.avg_bluebook_ins_pay_amt,
    bb.avg_bluebook_allowed_override,
    bb.bluebook_claim_types,
    bb.avg_bluebook_log_allowed_fee,
    bb.bluebook_log_descriptions
FROM BaseFee b
LEFT JOIN AdjDiscount ad ON b.ProcNum = ad.ProcNum
LEFT JOIN InsuranceClaims ic ON b.ProcNum = ic.ProcNum
LEFT JOIN PaymentRecords pr ON b.ProcNum = pr.ProcNum
LEFT JOIN BlueBookInfo bb ON b.ProcNum = bb.ProcNum
ORDER BY b.ProcNum
LIMIT 1000000;
