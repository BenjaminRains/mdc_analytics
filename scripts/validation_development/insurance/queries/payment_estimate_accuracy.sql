/*
 * Insurance Payment Estimate Accuracy Analysis
 *
 * Purpose: Analyze how accurately insurance carriers pay compared to estimates
 * Focus on identifying carriers with consistent and predictable payment patterns
 *
 * Key Metrics:
 * - Estimate vs. Actual Payment Variance
 * - Payment Consistency Score
 * - Procedure-specific Payment Accuracy
 * - Time-based Payment Patterns
 */
-- Date range: @start_date to @end_date
WITH 
PaymentAccuracyByProc AS (
    SELECT 
        i.CarrierNum,
        i.PlanNum,
        pl.ProcNum,
        pl.ProcCode,
        pl.ProcFee as original_fee,
        cp.InsPayEst as estimated_payment,
        SUM(ps.SplitAmt) as actual_payment,
        -- Accuracy calculations
        ABS(cp.InsPayEst - SUM(ps.SplitAmt)) as payment_variance,
        CASE 
            WHEN cp.InsPayEst = 0 THEN 0  -- Avoid division by zero
            ELSE (SUM(ps.SplitAmt) / NULLIF(cp.InsPayEst, 0)) * 100 
        END as payment_accuracy_percentage,
        -- Timing analysis
        DATEDIFF(DAY, pl.ProcDate, ps.DatePay) as days_to_payment,
        pl.ProcDate,
        ps.DatePay
    FROM insplan i
    JOIN claim c ON i.PlanNum = c.PlanNum
    JOIN claimproc cp ON c.ClaimNum = cp.ClaimNum
    JOIN procedurelog pl ON cp.ProcNum = pl.ProcNum
    JOIN paysplit ps ON pl.ProcNum = ps.ProcNum
        AND ps.IsDiscount = 0  -- Exclude discounts
    WHERE pl.ProcDate BETWEEN @start_date AND @end_date
        AND cp.InsPayEst > 0  -- Only include procedures with estimates
    GROUP BY 
        i.CarrierNum,
        i.PlanNum,
        pl.ProcNum,
        pl.ProcCode,
        pl.ProcFee,
        cp.InsPayEst,
        pl.ProcDate,
        ps.DatePay
),
CarrierAccuracyMetrics AS (
    SELECT 
        i.CarrierNum,
        COUNT(DISTINCT pap.ProcNum) as total_procedures,
        -- Overall accuracy
        AVG(pap.payment_accuracy_percentage) as avg_payment_accuracy,
        STDEV(pap.payment_accuracy_percentage) as accuracy_std_dev,
        -- Payment patterns
        AVG(pap.payment_variance) as avg_payment_variance,
        AVG(pap.days_to_payment) as avg_days_to_payment,
        -- Consistency metrics
        COUNT(DISTINCT CASE 
            WHEN pap.payment_accuracy_percentage BETWEEN 90 AND 110 
            THEN pap.ProcNum 
        END) * 100.0 / 
        NULLIF(COUNT(DISTINCT pap.ProcNum), 0) as consistent_payment_rate,
        -- Financial impact
        SUM(pap.estimated_payment) as total_estimated,
        SUM(pap.actual_payment) as total_actual,
        -- Procedure type analysis
        STRING_AGG(
            DISTINCT CONCAT(
                pap.ProcCode, ': ',
                CAST(ROUND(AVG(pap.payment_accuracy_percentage), 1) AS VARCHAR), '%'
            ),
            '; '
        ) as procedure_accuracy
    FROM insplan i
    JOIN PaymentAccuracyByProc pap ON i.CarrierNum = pap.CarrierNum
    GROUP BY i.CarrierNum
)

SELECT 
    c.CarrierName,
    c.ElectID,
    cam.total_procedures,
    
    -- Accuracy Metrics
    CAST(ROUND(cam.avg_payment_accuracy, 1) AS VARCHAR) + '%' as avg_payment_accuracy,
    CAST(ROUND(cam.consistent_payment_rate, 1) AS VARCHAR) + '%' as consistent_payment_rate,
    FORMAT(cam.avg_payment_variance, 'C') as avg_payment_variance,
    
    -- Payment Patterns
    cam.avg_days_to_payment as avg_days_to_payment,
    
    -- Financial Summary
    FORMAT(cam.total_estimated, 'C') as total_estimated,
    FORMAT(cam.total_actual, 'C') as total_actual,
    CAST(ROUND((cam.total_actual / NULLIF(cam.total_estimated, 0)) * 100, 1) AS VARCHAR) + '%' as overall_payment_ratio,
    
    -- Consistency Score (0-100)
    CAST(ROUND(
        (CASE 
            WHEN cam.avg_payment_accuracy BETWEEN 95 AND 105 THEN 40
            WHEN cam.avg_payment_accuracy BETWEEN 90 AND 110 THEN 30
            WHEN cam.avg_payment_accuracy BETWEEN 85 AND 115 THEN 20
            ELSE 10
        END) +
        (CASE 
            WHEN cam.accuracy_std_dev <= 5 THEN 30
            WHEN cam.accuracy_std_dev <= 10 THEN 20
            WHEN cam.accuracy_std_dev <= 15 THEN 10
            ELSE 0
        END) +
        (CASE 
            WHEN cam.consistent_payment_rate >= 90 THEN 30
            WHEN cam.consistent_payment_rate >= 80 THEN 20
            WHEN cam.consistent_payment_rate >= 70 THEN 10
            ELSE 0
        END)
    , 0) AS INT) as consistency_score,
    
    -- Monthly Trends
    STRING_AGG(
        DISTINCT CONCAT(
            FORMAT(pap.ProcDate, 'yyyy-MM'), ': ',
            CAST(ROUND(AVG(pap.payment_accuracy_percentage), 1) AS VARCHAR), '% accuracy, ',
            CAST(COUNT(DISTINCT pap.ProcNum) AS VARCHAR), ' procedures'
        ),
        '; '
    ) as monthly_accuracy_trends,
    
    -- Procedure-specific Analysis
    cam.procedure_accuracy as procedure_payment_accuracy,
    
    -- Predictability Indicators
    CASE 
        WHEN cam.avg_payment_accuracy BETWEEN 95 AND 105 
        AND cam.consistent_payment_rate >= 80 
        AND cam.avg_days_to_payment <= 30
        THEN 'Highly Predictable'
        WHEN cam.avg_payment_accuracy BETWEEN 90 AND 110 
        AND cam.consistent_payment_rate >= 70
        THEN 'Moderately Predictable'
        ELSE 'Variable'
    END as predictability_rating,
    
    -- Payment Timing Distribution
    STRING_AGG(
        DISTINCT CONCAT(
            CASE 
                WHEN pap.days_to_payment <= 15 THEN '0-15 days'
                WHEN pap.days_to_payment <= 30 THEN '16-30 days'
                WHEN pap.days_to_payment <= 45 THEN '31-45 days'
                ELSE '45+ days'
            END,
            ': ',
            CAST(COUNT(*) * 100 / NULLIF(cam.total_procedures, 0) AS VARCHAR), '%'
        ),
        '; '
    ) as payment_timing_distribution

FROM carrier c
JOIN CarrierAccuracyMetrics cam ON c.CarrierNum = cam.CarrierNum
JOIN PaymentAccuracyByProc pap ON c.CarrierNum = pap.CarrierNum
WHERE NOT c.IsHidden
GROUP BY 
    c.CarrierNum,
    c.CarrierName,
    c.ElectID,
    cam.total_procedures,
    cam.avg_payment_accuracy,
    cam.consistent_payment_rate,
    cam.avg_payment_variance,
    cam.avg_days_to_payment,
    cam.total_estimated,
    cam.total_actual,
    cam.accuracy_std_dev,
    cam.procedure_accuracy
HAVING cam.total_procedures >= 10  -- Minimum procedures for meaningful analysis
ORDER BY 
    consistency_score DESC,
    cam.avg_payment_accuracy DESC; 