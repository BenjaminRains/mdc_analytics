/*
 * Insurance Verification Status Analysis
 *
 * Purpose: Track and analyze insurance verification status, claim validity, 
 * and payment accuracy across carriers and plans
 *
 * Output columns:
 * - VerificationMetrics: Insurance verification tracking
 * - ClaimValidity: Active insurance validation
 * - PaymentAccuracy: Payment matching and balance analysis
 * - CarrierMetrics: Carrier-level performance indicators
 *
 * Analysis Categories:
 * - Verification Status: Current vs outdated verification
 * - Claim Validity: Match with active insurance periods
 * - Payment Accuracy: Balance and write-off analysis
 * - Carrier Performance: Aggregated metrics by carrier
 */
-- Date range: @start_date to @end_date

WITH 
InsuranceVerificationStatus AS (
    SELECT 
        p.PatNum,
        i.PlanNum,
        i.CarrierNum,
        iv.DateLastVerified,
        DATEDIFF(DAY, iv.DateLastVerified, CURRENT_TIMESTAMP) as days_since_verification,
        CASE 
            WHEN iv.DateLastVerified IS NULL THEN 'Never Verified'
            WHEN DATEDIFF(DAY, iv.DateLastVerified, CURRENT_TIMESTAMP) > 365 THEN 'Outdated'
            ELSE 'Current'
        END as verification_status,
        COUNT(DISTINCT c.ClaimNum) as associated_claims,
        SUM(cp.InsPayAmt) as total_payments,
        MAX(c.DateService) as latest_service_date
    FROM patient p
    JOIN insplan i ON p.PatNum = i.Subscriber
    LEFT JOIN insverify iv ON iv.FKey = p.PatNum
    LEFT JOIN claim c ON i.PlanNum = c.PlanNum
    LEFT JOIN claimproc cp ON c.ClaimNum = cp.ClaimNum
    WHERE c.DateService BETWEEN @start_date AND @end_date
    GROUP BY 
        p.PatNum,
        i.PlanNum,
        i.CarrierNum,
        iv.DateLastVerified,
        verification_status
),
ActiveInsuranceValidation AS (
    SELECT 
        c.ClaimNum,
        p.PatNum,
        i.PlanNum,
        i.CarrierNum,
        s.DateEffective,
        s.DateTerm,
        c.DateService,
        CASE 
            WHEN c.DateService BETWEEN s.DateEffective 
                AND COALESCE(NULLIF(s.DateTerm, '0001-01-01'), '9999-12-31')
            THEN 'Valid'
            ELSE 'Invalid'
        END as coverage_status,
        cp.InsPayAmt,
        cp.WriteOff,
        cp.DedApplied
    FROM claim c
    JOIN patient p ON c.PatNum = p.PatNum
    JOIN inssub s ON c.PlanNum = s.PlanNum
    JOIN insplan i ON s.PlanNum = i.PlanNum
    LEFT JOIN claimproc cp ON c.ClaimNum = cp.ClaimNum
    WHERE c.DateService BETWEEN @start_date AND @end_date
),
PaymentAccuracyAnalysis AS (
    SELECT 
        c.ClaimNum,
        c.PlanNum,
        pl.ProcFee as original_fee,
        cp.InsPayAmt,
        cp.WriteOff,
        cp.DedApplied,
        (cp.InsPayAmt + cp.WriteOff + cp.DedApplied) as total_accounted,
        (pl.ProcFee - (cp.InsPayAmt + cp.WriteOff + cp.DedApplied)) as balance_difference,
        CASE 
            WHEN pl.ProcFee = (cp.InsPayAmt + cp.WriteOff + cp.DedApplied) THEN 'Balanced'
            WHEN pl.ProcFee > (cp.InsPayAmt + cp.WriteOff + cp.DedApplied) THEN 'Underpaid'
            ELSE 'Overpaid'
        END as balance_status
    FROM claim c
    JOIN claimproc cp ON c.ClaimNum = cp.ClaimNum
    JOIN procedurelog pl ON cp.ProcNum = pl.ProcNum
    WHERE c.DateService BETWEEN @start_date AND @end_date
)

SELECT 
    c.CarrierName,
    c.ElectID,
    
    -- Verification Metrics
    COUNT(DISTINCT CASE WHEN ivs.verification_status = 'Current' THEN ivs.PatNum END) as verified_patients,
    COUNT(DISTINCT CASE WHEN ivs.verification_status = 'Outdated' THEN ivs.PatNum END) as outdated_verifications,
    COUNT(DISTINCT CASE WHEN ivs.verification_status = 'Never Verified' THEN ivs.PatNum END) as never_verified,
    AVG(ivs.days_since_verification) as avg_days_since_verification,
    
    -- Coverage Validation
    COUNT(DISTINCT CASE WHEN aiv.coverage_status = 'Valid' THEN aiv.ClaimNum END) as valid_claims,
    COUNT(DISTINCT CASE WHEN aiv.coverage_status = 'Invalid' THEN aiv.ClaimNum END) as invalid_claims,
    SUM(CASE WHEN aiv.coverage_status = 'Invalid' THEN aiv.InsPayAmt ELSE 0 END) as payments_on_invalid_claims,
    
    -- Payment Accuracy
    COUNT(DISTINCT CASE WHEN pa.balance_status = 'Balanced' THEN pa.ClaimNum END) as balanced_claims,
    COUNT(DISTINCT CASE WHEN pa.balance_status = 'Underpaid' THEN pa.ClaimNum END) as underpaid_claims,
    COUNT(DISTINCT CASE WHEN pa.balance_status = 'Overpaid' THEN pa.ClaimNum END) as overpaid_claims,
    SUM(pa.balance_difference) as total_balance_difference,
    
    -- Aggregated Metrics
    COUNT(DISTINCT aiv.ClaimNum) as total_claims,
    SUM(aiv.InsPayAmt) as total_payments,
    SUM(aiv.WriteOff) as total_writeoffs,
    SUM(aiv.DedApplied) as total_deductibles,
    
    -- Verification Patterns
    STRING_AGG(
        DISTINCT CONCAT(
            FORMAT(DATEADD(MONTH, DATEDIFF(MONTH, 0, ivs.DateLastVerified), 0), 'yyyy-MM'), ':',
            COUNT(DISTINCT ivs.PatNum), ' verifications'
        ),
        ', '
    ) as monthly_verification_patterns

FROM carrier c
LEFT JOIN InsuranceVerificationStatus ivs ON c.CarrierNum = ivs.CarrierNum
LEFT JOIN ActiveInsuranceValidation aiv ON c.CarrierNum = aiv.CarrierNum
LEFT JOIN PaymentAccuracyAnalysis pa ON aiv.ClaimNum = pa.ClaimNum
WHERE NOT c.IsHidden
GROUP BY 
    c.CarrierNum,
    c.CarrierName,
    c.ElectID
HAVING COUNT(DISTINCT aiv.ClaimNum) > 0
ORDER BY 
    total_payments DESC,
    CarrierName; 