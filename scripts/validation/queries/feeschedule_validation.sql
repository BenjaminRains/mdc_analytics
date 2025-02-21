/*
 * Fee Schedule and Payment Validation Query
 * 
 * Purpose: 
 * - Validate fee schedule usage and payment patterns
 * - Analyze insurance carrier relationships
 * - Track historical payments vs expected fees
 * - Monitor fee schedule groups and clinic patterns
 * 
 * Time period: 2024 calendar year
 * Output file: /validation/data/feeschedule_validation_2024.csv
 * 
 * Analysis Components:
 * 1. Fee Schedule Usage:
 *    - Active vs inactive schedules
 *    - Procedure mix and volumes
 *    - Fee adjustments and trends
 * 
 * 2. Insurance Relationships:
 *    - Carrier-specific fee schedules
 *    - Payment patterns by carrier
 *    - Expected vs actual payments
 * 
 * 3. Clinic/Provider Patterns:
 *    - Fee schedule groups
 *    - Provider-specific adjustments
 *    - Location-based variations
 */

WITH DateRange AS (
    SELECT '2024-01-01' as start_date,
           '2025-01-01' as end_date
),

-- Analyze carrier relationships first
CarrierFeeSchedules AS (
    SELECT 
        c.CarrierNum,
        c.CarrierName,
        i.FeeSched,
        fs.Description as FeeSchedDesc,
        COUNT(DISTINCT i.PlanNum) as NumPlans,
        COUNT(DISTINCT fsg.FeeSchedNum) as NumFeeScheduleGroups
    FROM carrier c
    JOIN insplan i ON c.CarrierNum = i.CarrierNum
    LEFT JOIN feesched fs ON i.FeeSched = fs.FeeSchedNum
    LEFT JOIN feeschedgroup fsg ON i.FeeSched = fsg.FeeSchedNum
    WHERE i.FeeSched IS NOT NULL
    GROUP BY c.CarrierNum, c.CarrierName, i.FeeSched, fs.Description
),

-- Analyze actual usage patterns
FeeScheduleUsage AS (
    SELECT 
        f.FeeSched,
        fs.Description as FeeSchedDesc,
        COUNT(DISTINCT pl.ProcNum) as ProcCount,
        COUNT(DISTINCT pl.PatNum) as PatientCount,
        MIN(pl.ProcDate) as FirstUsed,
        MAX(pl.ProcDate) as LastUsed,
        AVG(pl.ProcFee) as AvgFee,
        AVG(cp.InsPayAmt) as AvgInsPayment,
        AVG(cp.WriteOff) as AvgWriteOff,
        CASE 
            WHEN MAX(pl.ProcDate) >= DATE_SUB(CURRENT_DATE, INTERVAL 6 MONTH) THEN 'Active'
            WHEN MAX(pl.ProcDate) >= DATE_SUB(CURRENT_DATE, INTERVAL 1 YEAR) THEN 'Semi-Active'
            ELSE 'Inactive'
        END as UsageStatus
    FROM procedurelog pl
    JOIN fee f ON pl.CodeNum = f.CodeNum
    JOIN feesched fs ON f.FeeSched = fs.FeeSchedNum
    LEFT JOIN claimproc cp ON pl.ProcNum = cp.ProcNum
    WHERE pl.ProcStatus = 2
        AND pl.ProcDate >= '2024-01-01'
        AND pl.ProcDate < '2025-01-01'
    GROUP BY f.FeeSched, fs.Description
    HAVING ProcCount > 10
),

-- Analyze clinic/provider patterns
ProviderFeePatterns AS (
    SELECT 
        pl.ProvNum,
        f.FeeSched,
        COUNT(DISTINCT pl.ProcNum) as ProcCount,
        AVG(pl.ProcFee) as AvgFee,
        AVG(f.Amount) as AvgScheduledFee,
        AVG(pl.ProcFee - f.Amount) as AvgAdjustment
    FROM procedurelog pl
    JOIN fee f ON pl.CodeNum = f.CodeNum
    WHERE pl.ProcDate >= '2024-01-01'
        AND pl.ProcDate < '2025-01-01'
    GROUP BY pl.ProvNum, f.FeeSched
)

-- Output combined analysis
SELECT 
    fsu.FeeSched,
    fsu.FeeSchedDesc,
    fsu.UsageStatus,
    fsu.ProcCount,
    fsu.PatientCount,
    ROUND(fsu.AvgFee, 2) as AvgFee,
    ROUND(fsu.AvgInsPayment, 2) as AvgInsPayment,
    ROUND(fsu.AvgWriteOff, 2) as AvgWriteOff,
    cfs.CarrierName,
    cfs.NumPlans as CarrierPlans,
    cfs.NumFeeScheduleGroups,
    COUNT(DISTINCT pfp.ProvNum) as ProvidersUsing,
    ROUND(AVG(pfp.AvgAdjustment), 2) as AvgProviderAdjustment
FROM FeeScheduleUsage fsu
LEFT JOIN CarrierFeeSchedules cfs ON fsu.FeeSched = cfs.FeeSched
LEFT JOIN ProviderFeePatterns pfp ON fsu.FeeSched = pfp.FeeSched
GROUP BY 
    fsu.FeeSched,
    fsu.FeeSchedDesc,
    fsu.UsageStatus,
    fsu.ProcCount,
    fsu.PatientCount,
    fsu.AvgFee,
    fsu.AvgInsPayment,
    fsu.AvgWriteOff,
    cfs.CarrierName,
    cfs.NumPlans,
    cfs.NumFeeScheduleGroups
ORDER BY 
    fsu.ProcCount DESC,
    fsu.FeeSched;