-- Dependent CTEs: excluded_codes.sql, provider_base.sql, appt_durations.sql, appt_production.sql, BaseProcedures.sql, productivity_metrics.sql, ProcedureCategories.sql, ProviderVolume.sql, HygieneMetrics.sql, PaymentMetrics.sql

-- Date filter: 2024-01-01 to 2025-01-01

/*
Appointment Time Calculation:
---------------------------
Pattern field interpretation:
- "/" = 10 minutes of non-provider time
- "X" = 10 minutes of provider time

Duration calculation:
- Provider time = count of "X" × 10
- Non-provider time = max(count of leading "/", count of trailing "/") × 10
- Total duration (hours) = (left non-provider + provider time + right non-provider) ÷ 60
*/

SET SESSION group_concat_max_len = 4096;  -- Prevent category truncation

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
  
  -- Volume metrics
  COALESCE(pv.TotalProcedures, 0) AS TotalProcedures,
  COALESCE(pv.TotalProcFees, 0) AS TotalProcFees,
  COALESCE(pv.UniquePatients, 0) AS UniquePatients,
  COALESCE(pv.DaysWithActivity, 0) AS DaysWithActivity,
  COALESCE(pv.UniqueProcCodes, 0) AS UniqueProcCodes,
  
  -- Status metrics
  COALESCE(pv.StatusTreatmentPlanned, 0) AS StatusTreatmentPlanned,
  COALESCE(pv.StatusComplete, 0) AS StatusComplete,
  COALESCE(pv.StatusInProgress, 0) AS StatusInProgress,
  COALESCE(pv.StatusDeleted, 0) AS StatusDeleted,
  COALESCE(pv.StatusRejected, 0) AS StatusRejected,
  COALESCE(pv.StatusCondPlanned, 0) AS StatusCondPlanned,
  COALESCE(pv.StatusNeedToDo, 0) AS StatusNeedToDo,
  COALESCE(pv.PlannedToCompletedRatio, 0) AS PlannedToCompletedRatio,
  
  -- Appointment metrics
  COALESCE(pv.ProcsWithAppointment, 0) AS ProcsWithAppointment,
  COALESCE(pv.PctWithAppointment, 0) AS PctWithAppointment,
  
  -- Hygiene metrics
  COALESCE(hm.HygieneProcCount, 0) AS HygieneProcCount,
  COALESCE(hm.NonHygieneProcCount, 0) AS NonHygieneProcCount,
  COALESCE(hm.HygieneProcPct, 0) AS HygieneProcPct,
  COALESCE(hm.HygieneFees, 0) AS HygieneFees,
  COALESCE(hm.NonHygieneFees, 0) AS NonHygieneFees,
  
  -- Payment metrics
  COALESCE(pm.TotalBilled, 0) AS TotalBilled,
  COALESCE(pm.TotalInsurancePaid, 0) AS TotalInsurancePaid,
  COALESCE(pm.TotalPatientPaid, 0) AS TotalPatientPaid,
  COALESCE(pm.TotalPaid, 0) AS TotalPaid,
  COALESCE(pm.AdjustedCollectionRate, 0) AS AdjustedCollectionRate,
  
  -- Aging buckets
  COALESCE(pm.Fees0to30Days, 0) AS Fees0to30Days,
  COALESCE(pm.Fees31to60Days, 0) AS Fees31to60Days,
  COALESCE(pm.Fees61to90Days, 0) AS Fees61to90Days,
  COALESCE(pm.FeesOver90Days, 0) AS FeesOver90Days,
  
  -- Productivity metrics
  COALESCE(ppm.AppointmentCount, 0) AS AppointmentCount,
  COALESCE(ppm.ScheduledHours, 0) AS ScheduledHours,
  COALESCE(ppm.TotalProduction, 0) AS CompletedProduction,
  COALESCE(ppm.HourlyProduction, 0) AS HourlyProduction,
  COALESCE(ppm.AvgProcsPerAppt, 0) AS AvgProcsPerAppt,
  COALESCE(ppm.AvgFeePerAppt, 0) AS AvgFeePerAppt,
  COALESCE(ppm.PctApptWithProviderTime, 0) AS PctApptWithProviderTime,
  
  -- Production goals
  CASE 
    WHEN ppm.HourlyProduction IS NOT NULL AND pb.HourlyProdGoalAmt > 0 
    THEN ROUND((ppm.HourlyProduction / pb.HourlyProdGoalAmt) * 100, 1)
    ELSE NULL
  END AS PctOfHourlyGoal,
  
  -- Date anomalies
  COALESCE(pv.FutureDateCompleteCount, 0) AS FutureDateCompleteCount,
  COALESCE(pv.CompletedNoDateCount, 0) AS CompletedNoDateCount,
  
  -- Procedure categories
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