-- create a temp table of commlog from the past 4 years

DROP TEMPORARY TABLE IF EXISTS 'temp_commlog';

CREATE TEMPORARY TABLE 'temp_commlog' AS

SELECT 
        c.PatNum,
        c.CommlogNum,
        c.CommDateTime,
        c.CommType,
        c.Note
    FROM 
        commlog c
    WHERE 
        c.CommDateTime >= DATE_SUB(CURDATE(), INTERVAL 4 YEAR);
