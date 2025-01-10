-- create a temp table of procedurelog from past 4 years

DROP TEMPORARY TABLE IF EXISTS temp_procedurelog;

CREATE temporary table temp_procedurelog AS
SELECT
	pl.ProcNum,
    pl.PatNum,
    pl.AptNum,
    pl.OldCode,
    pl.ProcDate,
    pl.ProcFee,
    pl.Surf,
    pl.ToothNum,
    pl.ToothRange,
    pl.Priority,
    pl.ProcStatus, -- (1= , 2=complete, 3= , 4= , 5= , 6= )
    pl.ProvNum,
    pl.CodeNum
FROM procedurelog pl
WHERE pl.ProcDate >= DATE_SUB(CURDATE(), INTERVAL 4 YEAR);
