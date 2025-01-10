-- create a temp table with all appointments in the past 4 years.

-- Drop the existing temporary table if it exists
DROP TEMPORARY TABLE IF EXISTS temp_appointment;

CREATE temporary table temp_appointment AS
SELECT
	a.AptNum,
    a.PatNum,
    a.AptStatus, -- (scheduled, confirmed, cancelled, broken)
    a.Confirmed,
    a.Note,
    a.ProvNum,
    a.ProvHyg,
    a.AptDateTime, -- appointment creation date
    a.IsHygiene,
    a.InsPlan1,
    a.InsPlan2
FROM appointment a
WHERE a.AptDateTime >= DATE_SUB(CURDATE(), INTERVAL 4 YEAR);
