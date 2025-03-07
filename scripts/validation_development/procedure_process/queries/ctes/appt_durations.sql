-- Calculate the duration of appointments in hours
-- Dependent CTEs:
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
)