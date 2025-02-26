-- CTEs used: provider_base.sql, provider_volume.sql, procedure_categories.sql, hygiene_metrics.sql, payment_metrics.sql, appt_durations.sql, appt_production.sql, productivity_metrics.sql
/*
Query: Provider Performance Analysis with Appointment Time Calculation
-------------------------------------------------------------------------------

Description:
This query aggregates provider performance metrics from the Open Dental system,
combining data from multiple tables (provider, appointment, procedurelog, and
procedurecode) to produce a comprehensive provider report.
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
