/*
Query: Provider Performance Analysis with Appointment Time Calculation
-------------------------------------------------------------------------------

Description:
This query aggregates provider performance metrics from the Open Dental system,
combining data from multiple tables (provider, appointment, procedurelog, and
procedurecode) to produce a comprehensive provider report.

-- CTEs used: provider_base, provider_volume, procedure_categories, hygiene_metrics, payment_metrics, appt_durations, appt_production, productivity_metrics

Metrics Calculated:
1. Provider Basic Information
   - Provider number, abbreviation, name, specialty, status
   - Hourly production goal

2. Procedure Volume Metrics
   - Total procedures
   - Total procedure fees
   - Unique patients
   - Days with activity
   - Unique procedure codes
   - Procedure counts by status (treatment planned, complete, in progress, etc.)

3. Procedure Category Distribution
   - Count and percentage by category

4. Hygiene Metrics
   - Count and percentages of hygiene vs. non-hygiene procedures
   - Associated fees

5. Payment Metrics
   - Total billed
   - Total insurance paid
   - Total patient paid
   - Total paid
   - Collection rate

6. Productivity Metrics
   - Appointment count
   - Scheduled hours
   - Total production
   - Hourly production

Appointment Time Calculation:
---------------------------
Pattern field interpretation (VARCHAR):
- "/" = 10 minutes of non-provider time
- "X" = 10 minutes of provider time

Multiple procedures calculation:
- Provider time = count of "X" characters × 10
- Non-provider time = max(count of leading "/", count of trailing "/") × 10
- Total duration (hours) = (left non-provider + provider time + right non-provider) ÷ 60

Tables Used:
-----------
- provider: Provider information
- appointment: Appointment details and patterns
- procedurelog: Procedure details, fees, and status
- procedurecode: Procedure category information

Note: Date range defaults to '2023-01-01' to '2023-12-31'. Adjust as needed.
*/


WITH provider_base AS (
  SELECT 
    p.ProvNum,
    p.Abbr AS ProviderAbbr,
    CONCAT(p.FName, ' ', p.LName) AS ProviderName,
    p.Specialty,
    p.IsHidden,
    p.ProvStatus,
    p.HourlyProdGoalAmt,
    CASE 
      WHEN p.DateTerm = '0001-01-01' THEN NULL 
      ELSE p.DateTerm 
    END AS TerminationDate
  FROM provider p
),
provider_volume AS (
  SELECT 
    pl.ProvNum,
    COUNT(*) AS TotalProcedures,
    SUM(pl.ProcFee) AS TotalProcFees,
    COUNT(DISTINCT pl.PatNum) AS UniquePatients,
    COUNT(DISTINCT pl.ProcDate) AS DaysWithActivity,
    COUNT(DISTINCT pl.CodeNum) AS UniqueProcCodes,
    SUM(CASE WHEN pl.ProcStatus = 1 THEN 1 ELSE 0 END) AS StatusTreatmentPlanned,
    SUM(CASE WHEN pl.ProcStatus = 2 THEN 1 ELSE 0 END) AS StatusComplete,
    SUM(CASE WHEN pl.ProcStatus = 3 THEN 1 ELSE 0 END) AS StatusInProgress,
    SUM(CASE WHEN pl.ProcStatus = 4 THEN 1 ELSE 0 END) AS StatusDeleted,
    SUM(CASE WHEN pl.ProcStatus = 5 THEN 1 ELSE 0 END) AS StatusRejected,
    SUM(CASE WHEN pl.ProcStatus = 6 THEN 1 ELSE 0 END) AS StatusCondPlanned,
    SUM(CASE WHEN pl.ProcStatus = 7 THEN 1 ELSE 0 END) AS StatusNeedToDo,
    ROUND(
      SUM(CASE WHEN pl.ProcStatus = 2 THEN 1 ELSE 0 END) * 100.0 / 
      NULLIF(SUM(CASE WHEN pl.ProcStatus IN (1,6) THEN 1 ELSE 0 END), 0),
      1
    ) AS PlannedToCompletedRatio,
    SUM(CASE WHEN pl.AptNum > 0 THEN 1 ELSE 0 END) AS ProcsWithAppointment,
    ROUND(
      SUM(CASE WHEN pl.AptNum > 0 THEN 1 ELSE 0 END) * 100.0 /
      NULLIF(COUNT(*), 0),
      1
    ) AS PctWithAppointment,
    SUM(CASE WHEN pl.DateComplete > CURRENT_DATE THEN 1 ELSE 0 END) AS FutureDateCompleteCount,
    SUM(CASE WHEN pl.ProcStatus = 2 AND pl.DateComplete = '0001-01-01' THEN 1 ELSE 0 END) AS CompletedNoDateCount
  FROM procedurelog pl
  WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2025-01-01'
  GROUP BY pl.ProvNum
),
procedure_categories AS (
  SELECT 
    pl.ProvNum,
    pc.ProcCat,
    COUNT(*) AS CategoryCount,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY pl.ProvNum), 1) AS CategoryPct,
    SUM(pl.ProcFee) AS CategoryFees,
    ROUND(SUM(pl.ProcFee) * 100.0 / SUM(SUM(pl.ProcFee)) OVER (PARTITION BY pl.ProvNum), 1) AS CategoryFeePct
  FROM procedurelog pl
  JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
  WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2025-01-01'
  GROUP BY pl.ProvNum, pc.ProcCat
),
hygiene_metrics AS (
  SELECT 
    pl.ProvNum,
    SUM(CASE WHEN pc.IsHygiene = 1 THEN 1 ELSE 0 END) AS HygieneProcCount,
    SUM(CASE WHEN pc.IsHygiene = 0 THEN 1 ELSE 0 END) AS NonHygieneProcCount,
    ROUND(
      SUM(CASE WHEN pc.IsHygiene = 1 THEN 1 ELSE 0 END) * 100.0 /
      NULLIF(COUNT(*), 0),
      1
    ) AS HygieneProcPct,
    SUM(CASE WHEN pc.IsHygiene = 1 THEN pl.ProcFee ELSE 0 END) AS HygieneFees,
    SUM(CASE WHEN pc.IsHygiene = 0 THEN pl.ProcFee ELSE 0 END) AS NonHygieneFees
  FROM procedurelog pl
  JOIN procedurecode pc ON pl.CodeNum = pc.CodeNum
  WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2025-01-01'
  GROUP BY pl.ProvNum
),
payment_metrics AS (
  SELECT 
    pl.ProvNum,
    SUM(pl.ProcFee) AS TotalBilled,
    SUM(COALESCE(
      (SELECT SUM(cp.InsPayAmt) FROM claimproc cp WHERE cp.ProcNum = pl.ProcNum),
      0
    )) AS TotalInsurancePaid,
    SUM(COALESCE(
      (SELECT SUM(ps.SplitAmt) FROM paysplit ps WHERE ps.ProcNum = pl.ProcNum),
      0
    )) AS TotalPatientPaid,
    SUM(
      COALESCE(
        (SELECT SUM(cp.InsPayAmt) FROM claimproc cp WHERE cp.ProcNum = pl.ProcNum),
        0
      ) + COALESCE(
        (SELECT SUM(ps.SplitAmt) FROM paysplit ps WHERE ps.ProcNum = pl.ProcNum),
        0
      )
    ) AS TotalPaid,
    ROUND(
      SUM(
        COALESCE(
          (SELECT SUM(cp.InsPayAmt) FROM claimproc cp WHERE cp.ProcNum = pl.ProcNum),
          0
        ) + COALESCE(
          (SELECT SUM(ps.SplitAmt) FROM paysplit ps WHERE ps.ProcNum = pl.ProcNum),
          0
        )
      ) * 100.0 / NULLIF(SUM(pl.ProcFee), 0),
      1
    ) AS CollectionRate
  FROM procedurelog pl
  WHERE pl.ProcDate >= '2024-01-01' AND pl.ProcDate < '2025-01-01'
    AND pl.ProcStatus = 2
  GROUP BY pl.ProvNum
),

appt_durations AS (
  SELECT
    AptNum,
    ProvNum,
    CASE 
      WHEN Pattern <> '' THEN 
         ((LENGTH(Pattern) - LENGTH(TRIM(LEADING '/' FROM Pattern))  + 
           (LENGTH(Pattern) - LENGTH(REPLACE(Pattern, 'X', ''))) +
           (LENGTH(Pattern) - LENGTH(TRIM(TRAILING '/' FROM Pattern)))
         ) * 10) / 60.0
      ELSE 0 
    END AS appt_hours
  FROM appointment
  WHERE AptStatus IN (1,2)
),
-- Sum the procedure fees per appointment (production)
appt_production AS (
  SELECT 
    AptNum,
    ProvNum,
    SUM(ProcFee) AS appt_production
  FROM procedurelog
  WHERE ProcDate >= '2024-01-01' AND ProcDate < '2025-01-01'
    AND ProcStatus = 2
  GROUP BY AptNum, ProvNum
),
-- Aggregate appointment durations and production by provider
productivity_metrics AS (
  SELECT 
    ad.ProvNum,
    COUNT(*) AS AppointmentCount,
    SUM(ad.appt_hours) AS ScheduledHours,
    SUM(ap.appt_production) AS TotalProduction,
    SUM(ap.appt_production) / NULLIF(SUM(ad.appt_hours), 0) AS HourlyProduction
  FROM appt_durations ad
  JOIN appt_production ap 
    ON ad.AptNum = ap.AptNum 
   AND ad.ProvNum = ap.ProvNum
  GROUP BY ad.ProvNum
)

SELECT 
  pb.ProvNum,
  pb.ProviderAbbr,
  pb.ProviderName,
  pb.Specialty,
  CASE 
    WHEN pb.ProvStatus = 0 THEN 'Active'
    WHEN pb.ProvStatus = 1 THEN 'Inactive'
    ELSE 'Unknown'
  END AS ProviderStatus,
  pb.HourlyProdGoalAmt AS HourlyProductionGoal,
  
  COALESCE(pv.TotalProcedures, 0) AS TotalProcedures,
  COALESCE(pv.TotalProcFees, 0) AS TotalProcFees,
  COALESCE(pv.UniquePatients, 0) AS UniquePatients,
  COALESCE(pv.DaysWithActivity, 0) AS DaysWithActivity,
  COALESCE(pv.UniqueProcCodes, 0) AS UniqueProcCodes,
  
  COALESCE(pv.StatusTreatmentPlanned, 0) AS StatusTreatmentPlanned,
  COALESCE(pv.StatusComplete, 0) AS StatusComplete,
  COALESCE(pv.StatusInProgress, 0) AS StatusInProgress,
  COALESCE(pv.StatusDeleted, 0) AS StatusDeleted,
  COALESCE(pv.StatusRejected, 0) AS StatusRejected,
  COALESCE(pv.StatusCondPlanned, 0) AS StatusCondPlanned,
  COALESCE(pv.StatusNeedToDo, 0) AS StatusNeedToDo,
  COALESCE(pv.PlannedToCompletedRatio, 0) AS PlannedToCompletedRatio,
  
  COALESCE(pv.ProcsWithAppointment, 0) AS ProcsWithAppointment,
  COALESCE(pv.PctWithAppointment, 0) AS PctWithAppointment,
  
  COALESCE(hm.HygieneProcCount, 0) AS HygieneProcCount,
  COALESCE(hm.NonHygieneProcCount, 0) AS NonHygieneProcCount,
  COALESCE(hm.HygieneProcPct, 0) AS HygieneProcPct,
  COALESCE(hm.HygieneFees, 0) AS HygieneFees,
  COALESCE(hm.NonHygieneFees, 0) AS NonHygieneFees,
  
  COALESCE(pm.TotalBilled, 0) AS TotalBilled,
  COALESCE(pm.TotalInsurancePaid, 0) AS TotalInsurancePaid,
  COALESCE(pm.TotalPatientPaid, 0) AS TotalPatientPaid,
  COALESCE(pm.TotalPaid, 0) AS TotalPaid,
  COALESCE(pm.CollectionRate, 0) AS CollectionRate,
  
  COALESCE(ppm.AppointmentCount, 0) AS AppointmentCount,
  COALESCE(ppm.ScheduledHours, 0) AS ScheduledHours,
  COALESCE(ppm.TotalProduction, 0) AS CompletedProduction,
  COALESCE(ppm.HourlyProduction, 0) AS HourlyProduction,
  CASE 
    WHEN ppm.HourlyProduction IS NOT NULL AND pb.HourlyProdGoalAmt > 0 
    THEN ROUND((ppm.HourlyProduction / pb.HourlyProdGoalAmt) * 100, 1)
    ELSE NULL
  END AS PctOfHourlyGoal,
  
  COALESCE(pv.FutureDateCompleteCount, 0) AS FutureDateCompleteCount,
  COALESCE(pv.CompletedNoDateCount, 0) AS CompletedNoDateCount,
  
  (SELECT GROUP_CONCAT(
       CONCAT(ProcCat, ':', CategoryCount, ' (', CategoryPct, '%)')
       ORDER BY CategoryCount DESC SEPARATOR '; '
   )
   FROM procedure_categories 
   WHERE ProvNum = pb.ProvNum
   GROUP BY ProvNum
  ) AS TopProcedureCategories
FROM provider_base pb
LEFT JOIN provider_volume pv ON pb.ProvNum = pv.ProvNum
LEFT JOIN hygiene_metrics hm ON pb.ProvNum = hm.ProvNum
LEFT JOIN payment_metrics pm ON pb.ProvNum = pm.ProvNum
LEFT JOIN productivity_metrics ppm ON pb.ProvNum = ppm.ProvNum
ORDER BY COALESCE(pv.TotalProcedures, 0) DESC;
