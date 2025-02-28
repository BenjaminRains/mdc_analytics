/*
 * Claim Denial Patterns and Processing Times Analysis
 *
 * Purpose: Analyze patterns in claim denials, processing times, and resubmission outcomes
 * with detailed breakdowns by denial code, procedure type, and temporal patterns
 *
 * Output columns:
 * - DenialMetrics: Various denial-related statistics
 * - ProcessingTimes: Time-based analysis of claim lifecycle
 * - ResubmissionOutcomes: Results of claim resubmissions
 * - CarrierPatterns: Carrier-specific denial patterns
 * - DenialCodeAnalysis: Specific denial code patterns and resolutions
 * - ProcedureImpact: Procedure-specific denial patterns
 * - TemporalTrends: Time-based comparison of denial patterns
 */

WITH 
ClaimDenialHistory AS (
    SELECT 
        c.ClaimNum,
        c.PatNum,
        c.PlanNum,
        i.CarrierNum,
        cp.ProcNum,
        cp.Status as claim_status,
        cp.DateCP,
        cp.DateEntry,
        c.DateService,
        cp.WriteOff,
        cp.InsPayAmt,
        cp.DedApplied,
        cp.ClaimNote,
        cp.ReasonCode as denial_code,
        -- Track claim versions
        ROW_NUMBER() OVER (PARTITION BY c.ClaimNum ORDER BY cp.DateCP) as submission_attempt,
        COUNT(*) OVER (PARTITION BY c.ClaimNum) as total_submissions,
        -- Time calculations
        DATEDIFF(DAY, c.DateService, cp.DateEntry) as days_to_submission,
        DATEDIFF(DAY, cp.DateEntry, cp.DateCP) as processing_duration,
        DATEDIFF(DAY, c.DateService, cp.DateCP) as total_resolution_time
    FROM claim c
    JOIN claimproc cp ON c.ClaimNum = cp.ClaimNum
    JOIN insplan i ON c.PlanNum = i.PlanNum
    WHERE c.DateService BETWEEN '2024-01-01' AND '2024-12-31'
        AND cp.Status IN (6, 7, 8) -- Focus on denied, rejected, or pending claims
),
DenialReasonAnalysis AS (
    SELECT 
        cdh.CarrierNum,
        cdh.denial_code,
        COUNT(DISTINCT cdh.ClaimNum) as denied_claims,
        AVG(cdh.processing_duration) as avg_processing_time,
        SUM(CASE WHEN cdh.total_submissions > 1 THEN 1 ELSE 0 END) as resubmitted_claims,
        SUM(CASE 
            WHEN cdh.submission_attempt > 1 
            AND cdh.Status = 1 -- Successfully paid after resubmission
            THEN 1 ELSE 0 END) as successful_resubmissions,
        AVG(cdh.total_resolution_time) as avg_total_resolution_time,
        STRING_AGG(DISTINCT SUBSTRING(cdh.ClaimNote, 1, 100), '|') as common_notes
    FROM ClaimDenialHistory cdh
    GROUP BY 
        cdh.CarrierNum,
        cdh.denial_code
),
ProcessingTimeAnalysis AS (
    SELECT 
        cdh.CarrierNum,
        AVG(cdh.days_to_submission) as avg_submission_delay,
        AVG(cdh.processing_duration) as avg_processing_time,
        MIN(cdh.processing_duration) as fastest_processing,
        MAX(cdh.processing_duration) as slowest_processing,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY cdh.processing_duration) as median_processing_time,
        COUNT(DISTINCT cdh.ClaimNum) as total_claims,
        COUNT(DISTINCT CASE 
            WHEN cdh.processing_duration > 30 
            THEN cdh.ClaimNum END) as delayed_claims
    FROM ClaimDenialHistory cdh
    GROUP BY cdh.CarrierNum
),
DenialCodeResolutionAnalysis AS (
    SELECT 
        cdh.CarrierNum,
        cdh.denial_code,
        -- Denial frequency
        COUNT(DISTINCT cdh.ClaimNum) as denial_count,
        -- Resolution success
        SUM(CASE 
            WHEN cdh.submission_attempt > 1 AND cdh.Status = 1 
            THEN 1 ELSE 0 END) * 100.0 / 
            NULLIF(COUNT(*), 0) as resolution_success_rate,
        -- Average attempts needed
        AVG(CAST(cdh.total_submissions AS FLOAT)) as avg_submissions_needed,
        -- Time to resolution
        AVG(cdh.total_resolution_time) as avg_days_to_resolve,
        -- Financial impact
        AVG(cdh.InsPayAmt) as avg_payment_when_resolved,
        -- Common resolution paths
        STRING_AGG(
            DISTINCT CASE 
                WHEN cdh.submission_attempt > 1 AND cdh.Status = 1 
                THEN SUBSTRING(cdh.ClaimNote, 1, 100)
            END,
            ' | '
        ) as successful_resolution_notes
    FROM ClaimDenialHistory cdh
    GROUP BY 
        cdh.CarrierNum,
        cdh.denial_code
),
ProcedureTypeAnalysis AS (
    SELECT 
        cdh.CarrierNum,
        p.ProcCode,
        p.Descript as procedure_description,
        COUNT(DISTINCT cdh.ClaimNum) as total_denials,
        -- Denial rate for this procedure
        COUNT(DISTINCT cdh.ClaimNum) * 100.0 / 
            NULLIF(COUNT(DISTINCT p.ProcNum), 0) as procedure_denial_rate,
        -- Most common denial reasons
        STRING_AGG(
            DISTINCT CONCAT(
                cdh.denial_code, ': ',
                COUNT(*), ' denials'
            ),
            '; '
        ) as common_denial_reasons,
        -- Resolution success by procedure
        SUM(CASE 
            WHEN cdh.submission_attempt > 1 AND cdh.Status = 1 
            THEN 1 ELSE 0 END) * 100.0 / 
            NULLIF(COUNT(*), 0) as procedure_resolution_rate,
        -- Average processing time
        AVG(cdh.processing_duration) as avg_processing_days
    FROM ClaimDenialHistory cdh
    JOIN procedurelog p ON cdh.ProcNum = p.ProcNum
    GROUP BY 
        cdh.CarrierNum,
        p.ProcCode,
        p.Descript
),
TemporalDenialAnalysis AS (
    SELECT 
        cdh.CarrierNum,
        -- Time period buckets
        DATEADD(MONTH, DATEDIFF(MONTH, 0, cdh.DateService), 0) as service_month,
        COUNT(DISTINCT cdh.ClaimNum) as monthly_denials,
        -- Denial rate trends
        COUNT(DISTINCT cdh.ClaimNum) * 100.0 / 
            NULLIF(COUNT(DISTINCT c.ClaimNum), 0) as monthly_denial_rate,
        -- Processing time trends
        AVG(cdh.processing_duration) as avg_processing_time,
        -- Resolution rate trends
        SUM(CASE 
            WHEN cdh.submission_attempt > 1 AND cdh.Status = 1 
            THEN 1 ELSE 0 END) * 100.0 / 
            NULLIF(COUNT(*), 0) as monthly_resolution_rate,
        -- Common denial reasons by month
        STRING_AGG(
            DISTINCT CONCAT(
                cdh.denial_code, ': ',
                COUNT(*), ' denials'
            ),
            '; '
        ) as monthly_denial_reasons
    FROM ClaimDenialHistory cdh
    JOIN claim c ON cdh.ClaimNum = c.ClaimNum
    GROUP BY 
        cdh.CarrierNum,
        service_month
)

SELECT 
    c.CarrierName,
    c.ElectID,
    
    -- Denial Volume Metrics
    COUNT(DISTINCT cdh.ClaimNum) as total_denied_claims,
    COUNT(DISTINCT CASE 
        WHEN cdh.total_submissions > 1 
        THEN cdh.ClaimNum END) as resubmitted_claims,
    
    -- Processing Time Metrics
    pta.avg_submission_delay,
    pta.avg_processing_time,
    pta.median_processing_time,
    pta.delayed_claims,
    
    -- Financial Impact
    SUM(cdh.InsPayAmt) as total_denied_amount,
    SUM(cdh.WriteOff) as total_writeoffs_on_denials,
    SUM(cdh.DedApplied) as total_deductibles_on_denials,
    
    -- Resubmission Success
    CAST(SUM(CASE 
        WHEN cdh.submission_attempt > 1 AND cdh.Status = 1 
        THEN 1 ELSE 0 END) * 100.0 / 
        NULLIF(COUNT(DISTINCT CASE 
            WHEN cdh.total_submissions > 1 
            THEN cdh.ClaimNum END), 0) AS DECIMAL(5,2)) as resubmission_success_rate,
    
    -- Top Denial Reasons
    STRING_AGG(
        DISTINCT CONCAT(
            dra.denial_code, ': ',
            dra.denied_claims, ' claims, ',
            CAST(ROUND(dra.avg_processing_time, 1) AS VARCHAR), ' days avg'
        ),
        '; '
    ) as top_denial_reasons,
    
    -- Processing Time Patterns
    STRING_AGG(
        DISTINCT CONCAT(
            FORMAT(DATEADD(MONTH, DATEDIFF(MONTH, 0, cdh.DateCP), 0), 'yyyy-MM'), ': ',
            COUNT(DISTINCT cdh.ClaimNum), ' denials, ',
            CAST(ROUND(AVG(cdh.processing_duration), 1) AS VARCHAR), ' days avg'
        ),
        '; '
    ) as monthly_denial_patterns,
    
    -- Common Notes Analysis
    STRING_AGG(DISTINCT dra.common_notes, ' | ') as denial_notes,
    
    -- Denial Code Resolution Patterns
    STRING_AGG(
        DISTINCT CONCAT(
            dcra.denial_code, ' (',
            dcra.denial_count, ' denials, ',
            CAST(ROUND(dcra.resolution_success_rate, 1) AS VARCHAR), '% resolved, ',
            CAST(ROUND(dcra.avg_submissions_needed, 1) AS VARCHAR), ' attempts avg)'
        ),
        '; '
    ) as denial_code_patterns,
    
    -- Procedure-Specific Patterns
    STRING_AGG(
        DISTINCT CONCAT(
            pta.ProcCode, ': ',
            pta.total_denials, ' denials, ',
            CAST(ROUND(pta.procedure_denial_rate, 1) AS VARCHAR), '% denial rate, ',
            CAST(ROUND(pta.procedure_resolution_rate, 1) AS VARCHAR), '% resolved'
        ),
        '; '
    ) as procedure_denial_patterns,
    
    -- Temporal Trends
    STRING_AGG(
        DISTINCT CONCAT(
            FORMAT(tda.service_month, 'yyyy-MM'), ': ',
            tda.monthly_denials, ' denials, ',
            CAST(ROUND(tda.monthly_denial_rate, 1) AS VARCHAR), '% denial rate, ',
            CAST(ROUND(tda.monthly_resolution_rate, 1) AS VARCHAR), '% resolved'
        ),
        '; '
    ) as temporal_denial_patterns,
    
    -- Resolution Strategy Summary
    STRING_AGG(
        DISTINCT CASE 
            WHEN dcra.resolution_success_rate >= 50 
            THEN CONCAT(
                dcra.denial_code, ' resolution: ',
                dcra.successful_resolution_notes
            )
        END,
        ' | '
    ) as successful_resolution_strategies

FROM carrier c
LEFT JOIN ClaimDenialHistory cdh ON c.CarrierNum = cdh.CarrierNum
LEFT JOIN DenialReasonAnalysis dra ON c.CarrierNum = dra.CarrierNum
LEFT JOIN ProcessingTimeAnalysis pta ON c.CarrierNum = pta.CarrierNum
LEFT JOIN DenialCodeResolutionAnalysis dcra ON c.CarrierNum = dcra.CarrierNum
LEFT JOIN ProcedureTypeAnalysis pta2 ON c.CarrierNum = pta2.CarrierNum
LEFT JOIN TemporalDenialAnalysis tda ON c.CarrierNum = tda.CarrierNum
WHERE NOT c.IsHidden
GROUP BY 
    c.CarrierNum,
    c.CarrierName,
    c.ElectID,
    pta.avg_submission_delay,
    pta.avg_processing_time,
    pta.median_processing_time,
    pta.delayed_claims
HAVING COUNT(DISTINCT cdh.ClaimNum) > 0
ORDER BY 
    total_denied_claims DESC,
    CarrierName; 