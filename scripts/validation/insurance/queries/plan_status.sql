/*
 * Insurance Plan Status Analysis
 * 
 * Purpose: Analyze the current status and activity of insurance plans
 * 
 * Output columns:
 * - CarrierName: Name of the insurance carrier
 * - PlanCategory: Category based on plan activity and dates
 * - TotalPlans: Number of plans in this category
 * - ActiveSubscribers: Number of active subscribers
 * - TotalSubscribers: Total number of subscribers (active and inactive)
 * - AvgDaysToPayment: Average days from service to payment
 * - ClaimCount: Total number of claims
 * - PaidClaimCount: Number of paid claims
 * - RejectedClaimCount: Number of rejected claims
 * - TotalPayments: Sum of insurance payments
 * - TotalWriteoffs: Sum of write-offs
 *
 * Categories:
 * - Active: Plans with current subscribers
 * - Inactive: Plans with no current subscribers but historical claims
 * - New: Plans created within analysis period
 * - Terminated: Plans with all subscribers terminated
 * - Dormant: Plans with no activity in analysis period
 */
-- Date range: @start_date to @end_date
-- Dependent CTEs: active_plans.sql, claim_status.sql

WITH ActivePlans, ClaimStatus

SELECT 
    ap.CarrierName,
    CASE 
        WHEN ap.active_subscriber_count > 0 THEN 'Active'
        WHEN ap.earliest_effective_date >= @start_date THEN 'New'
        WHEN ap.latest_term_date < @start_date THEN 'Terminated'
        WHEN cs.ClaimNum IS NULL THEN 'Dormant'
        ELSE 'Inactive'
    END as PlanCategory,
    COUNT(DISTINCT ap.PlanNum) as TotalPlans,
    SUM(ap.active_subscriber_count) as ActiveSubscribers,
    SUM(ap.subscriber_count) as TotalSubscribers,
    AVG(cs.days_to_finalize) as AvgDaysToPayment,
    COUNT(DISTINCT cs.ClaimNum) as ClaimCount,
    COUNT(DISTINCT CASE WHEN cs.status_category = 'Received' THEN cs.ClaimNum END) as PaidClaimCount,
    COUNT(DISTINCT CASE WHEN cs.status_category = 'Rejected' THEN cs.ClaimNum END) as RejectedClaimCount,
    SUM(cs.InsPayAmt) as TotalPayments,
    SUM(cs.WriteOff) as TotalWriteoffs
FROM ActivePlans ap
LEFT JOIN ClaimStatus cs ON ap.PlanNum = cs.PlanNum
    AND cs.tracking_rank = 1 -- Get most recent tracking status
GROUP BY 
    ap.CarrierName,
    CASE 
        WHEN ap.active_subscriber_count > 0 THEN 'Active'
        WHEN ap.earliest_effective_date >= @start_date THEN 'New'
        WHEN ap.latest_term_date < @start_date THEN 'Terminated'
        WHEN cs.ClaimNum IS NULL THEN 'Dormant'
        ELSE 'Inactive'
    END
ORDER BY 
    ap.CarrierName,
    PlanCategory; 