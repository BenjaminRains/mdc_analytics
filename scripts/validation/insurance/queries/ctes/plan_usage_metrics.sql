-- Description: This CTE calculates usage metrics for each plan and carrier such as total claims, patients, payments, writeoffs, deductibles, average payment, and claim dates.
-- date range: 2024-01-01 to 2025-01-01
-- Dependent CTEs: date_range.sql

PlanUsageMetrics AS (
    SELECT 
        i.PlanNum,
        i.CarrierNum,
        COUNT(DISTINCT c.ClaimNum) as total_claims,
        COUNT(DISTINCT c.PatNum) as total_patients,
        SUM(cp.InsPayAmt) as total_payments,
        SUM(cp.WriteOff) as total_writeoffs,
        SUM(cp.DedApplied) as total_deductibles,
        AVG(cp.InsPayAmt) as avg_payment,
        MAX(c.DateService) as last_claim_date,
        MIN(c.DateService) as first_claim_date
    FROM insplan i
    JOIN claim c ON i.PlanNum = c.PlanNum
    JOIN claimproc cp ON c.ClaimNum = cp.ClaimNum
    CROSS JOIN DateRange dr
    WHERE c.DateService BETWEEN dr.start_date AND dr.end_date
    GROUP BY i.PlanNum, i.CarrierNum
)