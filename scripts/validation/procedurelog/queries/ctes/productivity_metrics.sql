-- Aggregate appointment durations and production by provider
-- Used for analyzing provider productivity and efficiency
-- Dependent CTEs: appt_durations.sql, appt_production.sql
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