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
WHERE pl.ProcDate >= '2021-01-01';

-- create temp procedurelog table

