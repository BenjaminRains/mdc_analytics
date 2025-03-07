/*
 * Claim Denial Patterns Raw Data Query
 * 
 * Purpose: Extract raw claim data for analysis in pandas with data quality checks
 * 
 * Note on Data Quality:
 * Several data quality issues are better handled in pandas post-extraction:
 * 1. Date Handling
 *    - Future DateService values (2025)
 *    - NULL DateEntry values
 *    - DateCP range validation
 *    Example:
 *    df['DateService'] = pd.to_datetime(df['DateService'])
 *    df.loc[df['DateService'].dt.year > 2024, 'DateService'] = None
 * 
 * 2. Processing Time Calculations
 *    - Large values (739000+ days) due to date validation
 *    - Negative processing times
 *    Example:
 *    df['processing_time'] = (df['DateCP'] - df['DateEntry']).dt.days
 *    df.loc[df['processing_time'] < 0, 'processing_time'] = None
 * 
 * 3. Status Analysis
 *    - All claims currently "Pending/Not Sent"
 *    - Stale claims analysis
 *    Example:
 *    df['days_pending'] = (pd.Timestamp.now() - df['DateCP']).dt.days
 *    df['is_stale'] = df['days_pending'] > 30
 * 
 * 4. Financial Analysis
 *    - Payment patterns and outliers
 *    - Carrier/procedure aggregations
 *    - Deductible analysis
 *    Best handled with pandas groupby operations
 * 
 * Analysis Questions:
 * 1. Claim Status Patterns
 *    - What is the distribution of claim statuses across carriers?
 *    - How do status patterns vary by procedure type?
 *    - What is the average time between status changes?
 *    Note: Status Codes Observed:
 *    - 0: Pending/Not Sent
 *    - 1: Received by Carrier
 *    - 4: Other
 * 
 * 2. Financial Analysis
 *    - What is the average payment amount by carrier and procedure?
 *    - How do deductibles vary across carriers?
 *    - What procedures have the highest write-off rates?
 *    - Is there a correlation between claim status and payment amounts?
 * 
 * 3. Procedure Analysis
 *    - Which procedures are most commonly denied/delayed?
 *    - Are certain procedures more likely to be approved by specific carriers?
 *    - What is the average number of procedures per claim by carrier?
 * 
 * 4. Temporal Patterns
 *    - Are there seasonal patterns in claim submissions or approvals?
 *    - How do processing times vary by carrier and procedure type?
 *    - What is the typical lifecycle of a claim from submission to resolution?
 * 
 * 5. Carrier Analysis
 *    - Which carriers have the highest/lowest approval rates?
 *    - How do processing times compare across carriers?
 *    - Are there carriers with unusual denial patterns?
 * 
 * 6. Denial Code Analysis
 *    - What are the most common denial codes?
 *    - Do certain carriers use specific denial codes more frequently?
 *    - Are particular procedures associated with specific denial codes?
 * 
 * 7. Patient Impact
 *    - What is the average out-of-pocket cost by procedure?
 *    - Which carriers have the highest patient cost burden?
 *    - Are certain patient groups experiencing higher denial rates?
 */
 -- Date Range @start_date to @end_date
 -- Dependent CTEs: date_range.sql

WITH DateRange AS (
    SELECT 
        @start_date AS start_date,
        @end_date AS end_date
)
SELECT 
    -- Carrier Information
    c.CarrierNum,
    c.CarrierName,
    c.ElectID,
    
    -- Claim Details
    cl.ClaimNum,
    cl.PatNum,
    cp.ProcNum,
    cp.Status AS claim_status,
    
    -- Dates with Enhanced Validation
    CASE 
        WHEN cp.DateCP = '0001-01-01' OR cp.DateCP > CURRENT_DATE() THEN NULL
        WHEN cp.DateCP < dr.start_date THEN NULL
        ELSE cp.DateCP 
    END AS DateCP,
    CASE 
        WHEN cp.DateEntry = '0001-01-01' OR cp.DateEntry > CURRENT_DATE() THEN NULL
        WHEN cp.DateEntry < dr.start_date THEN NULL
        ELSE cp.DateEntry 
    END AS DateEntry,
    CASE 
        WHEN cl.DateService = '0001-01-01' OR cl.DateService > CURRENT_DATE() THEN NULL
        WHEN cl.DateService < dr.start_date THEN NULL
        ELSE cl.DateService
    END AS DateService,
    
    -- Enhanced Data Quality Flags
    CASE 
        WHEN cl.DateService > CURRENT_DATE() THEN 'Future Service Date'
        WHEN cp.DateCP > CURRENT_DATE() THEN 'Future Processing Date'
        WHEN cp.DateEntry > CURRENT_DATE() THEN 'Future Entry Date'
        WHEN cp.DateCP = '0001-01-01' AND cp.DateEntry = '0001-01-01' AND cl.DateService = '0001-01-01' THEN 'All Dates Missing'
        WHEN cp.DateCP = '0001-01-01' THEN 'Missing DateCP'
        WHEN cp.DateEntry = '0001-01-01' THEN 'Missing DateEntry'
        WHEN cl.DateService = '0001-01-01' THEN 'Missing DateService'
        WHEN cp.DateCP < cp.DateEntry THEN 'CP before Entry'
        WHEN cl.DateService > cp.DateCP AND cp.DateCP IS NOT NULL THEN 'Service After Processing'
        WHEN cp.Status = 0 AND cp.DateCP IS NOT NULL 
             AND DATEDIFF(CURRENT_DATE(), cp.DateCP) > 30 THEN 'Stale Pending'
        ELSE 'Valid'
    END AS date_validation,
    
    -- Processing Times (Only for Valid Non-Future Dates)
    CASE 
        WHEN cp.DateCP IS NOT NULL 
             AND cp.DateCP <= CURRENT_DATE()
             AND cl.DateService IS NOT NULL 
             AND cl.DateService <= CURRENT_DATE()
             AND cl.DateService <= cp.DateCP
        THEN DATEDIFF(cp.DateCP, cl.DateService)
        ELSE NULL
    END AS days_to_completion,
    
    CASE 
        WHEN cp.DateCP IS NOT NULL 
             AND cp.DateCP <= CURRENT_DATE()
             AND cp.DateEntry IS NOT NULL 
             AND cp.DateEntry <= CURRENT_DATE()
             AND cp.DateEntry <= cp.DateCP
        THEN DATEDIFF(cp.DateCP, cp.DateEntry)
        ELSE NULL
    END AS processing_time,
    
    -- Financial Information with Enhanced Validation
    cp.WriteOff,
    cp.InsPayAmt,
    cp.DedApplied,
    (COALESCE(cp.WriteOff, 0) + COALESCE(cp.DedApplied, 0)) AS patient_responsibility,
    CASE 
        WHEN cp.Status = 0 AND (cp.InsPayAmt > 0 OR cp.WriteOff > 0) THEN 'Pending with Payment'
        WHEN cp.Status != 0 AND cp.InsPayAmt = 0 AND cp.WriteOff = 0 AND cp.DedApplied = 0 THEN 'Processed without Payment'
        WHEN cp.DedApplied > 0 AND cp.Status = 0 THEN 'Pending with Deductible'
        WHEN cp.Status = 0 AND cp.DateCP <= CURRENT_DATE() 
             AND DATEDIFF(CURRENT_DATE(), cp.DateCP) > 30 THEN 'Stale Pending'
        ELSE 'Valid'
    END AS financial_validation,
    
    -- Status and Denial Information
    NULLIF(cp.Remarks, '') AS Remarks,
    NULLIF(cp.ClaimAdjReasonCodes, '') AS denial_code,
    CASE 
        WHEN cp.Status = 0 THEN 'Pending/Not Sent'
        WHEN cp.Status = 1 THEN 'Received'
        WHEN cp.Status = 4 THEN 'Other'
        ELSE 'Unknown'
    END AS status_description,
    
    -- Procedure Information
    pc.ProcCode,
    pc.Descript AS procedure_description,
    
    -- Claim Grouping with Date Validation
    COUNT(*) OVER (PARTITION BY cl.ClaimNum) AS procedures_in_claim,
    ROW_NUMBER() OVER (PARTITION BY cl.ClaimNum, cp.ProcNum ORDER BY 
        CASE 
            WHEN cp.DateCP > CURRENT_DATE() THEN NULL 
            ELSE cp.DateCP 
        END DESC,
        CASE 
            WHEN cp.DateEntry > CURRENT_DATE() THEN NULL
            ELSE cp.DateEntry 
        END DESC
    ) AS proc_version,
    
    -- Additional Metrics with Date Validation
    MONTH(COALESCE(
        CASE WHEN cl.DateService <= CURRENT_DATE() THEN cl.DateService END,
        CASE WHEN cp.DateEntry <= CURRENT_DATE() THEN cp.DateEntry END
    )) AS service_month,
    DAYNAME(COALESCE(
        CASE WHEN cl.DateService <= CURRENT_DATE() THEN cl.DateService END,
        CASE WHEN cp.DateEntry <= CURRENT_DATE() THEN cp.DateEntry END
    )) AS service_day,
    CASE WHEN cp.InsPayAmt > 0 THEN 1 ELSE 0 END AS is_paid,
    CASE WHEN cp.ClaimAdjReasonCodes IS NOT NULL AND cp.ClaimAdjReasonCodes != '' THEN 1 ELSE 0 END AS is_denied

FROM DateRange dr
CROSS JOIN carrier c
JOIN claim cl ON cl.PlanNum IN (
    SELECT PlanNum 
    FROM insplan 
    WHERE CarrierNum = c.CarrierNum
)
JOIN claimproc cp ON cl.ClaimNum = cp.ClaimNum
JOIN insplan i ON cl.PlanNum = i.PlanNum
LEFT JOIN procedurelog pl ON cp.ProcNum = pl.ProcNum
LEFT JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
WHERE NOT c.IsHidden
    AND (
        -- Include claims with valid dates in range
        (cp.DateCP BETWEEN dr.start_date AND CURRENT_DATE())
        OR (cp.Status = 0 AND cl.DateService BETWEEN dr.start_date AND CURRENT_DATE())
    )
ORDER BY 
    COALESCE(
        CASE WHEN cl.DateService <= CURRENT_DATE() THEN cl.DateService END,
        CASE WHEN cp.DateCP <= CURRENT_DATE() THEN cp.DateCP END,
        CASE WHEN cp.DateEntry <= CURRENT_DATE() THEN cp.DateEntry END
    ) DESC,
    cl.ClaimNum,
    cp.ProcNum;
