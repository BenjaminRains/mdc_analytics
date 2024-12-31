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
WHERE a.AptDateTime > '2021-01-01 00:00:00';

-- select all appointments within the past 4 years

