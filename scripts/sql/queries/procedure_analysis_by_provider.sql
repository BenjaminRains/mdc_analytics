-- Procedure Analysis by Provider Report
-- Shows detailed statistics for completed procedures including counts, fees, and percentages
-- Parameters are month, year, and provider abbreviation

-- Set report parameters
SET @Month = 4;           -- Analysis month
SET @Year = 2024;        -- Analysis year
SET @Provider = 'Doc';    -- Provider abbreviation

-- Calculate provider totals for the year and month
SELECT 
    SUM(pl.ProcFee * (pl.UnitQty + pl.BaseUnits)) AS YearProvFee,
    SUM(CASE 
        WHEN MONTH(pl.ProcDate) = @Month THEN pl.ProcFee * (pl.UnitQty + pl.BaseUnits) 
    END) AS MonthProvFee
INTO @YearProvFee, @MonthProvFee
FROM procedurelog pl 
INNER JOIN provider prov ON prov.ProvNum = pl.ProvNum 
    AND prov.Abbr = @Provider
WHERE pl.ProcStatus = 2  -- Completed procedures only
    AND YEAR(pl.ProcDate) = @Year;

-- Main report query
SELECT 
    display.Provider,
    -- Hide category name for spacer rows
    CASE WHEN display.ItemOrder = 3 THEN '' ELSE display.Category END AS 'Category',
    display.ProcCode,
    LEFT(display.Descript, 20) AS 'Description',
    -- Monthly statistics
    display.MthCount AS 'Month Count',
    display.MthUnits AS 'Month Units',
    display.MthFees AS 'Month Fees',
    display.MonthPercent AS 'Month %',
    -- Yearly statistics
    display.YrCount AS 'Year Count',
    display.YrUnits AS 'Year Units',
    display.YrFees AS 'Year Fees',
    display.YearPercent AS 'Year %'
FROM (
    -- Individual procedure statistics
    SELECT 
        1 AS ItemOrder,
        COALESCE(main.Provider, @Provider) AS Provider,
        main.ProcCode,
        main.Descript,
        main.Category,
        -- Monthly metrics
        main.MthCount,
        main.MthUnits,
        FORMAT(ROUND(COALESCE(main.MonthFee/percat.MonthCatFee*100, 0), 2), 2) AS MonthPercent,
        FORMAT(ROUND(COALESCE(main.MonthFee, 0), 2), 2) AS MthFees,
        -- Yearly metrics
        main.YrCount,
        main.YrUnits,
        FORMAT(ROUND(COALESCE(main.YearFee/percat.YearCatFee*100, 0), 2), 2) AS YearPercent,
        FORMAT(ROUND(COALESCE(main.YearFee, 0), 2), 2) AS YrFees
    FROM (
        -- Base procedure data
        SELECT 
            percode.Provider,
            pc.ProcCode,
            df.ItemName AS Category,
            CASE WHEN pc.LaymanTerm = '' THEN pc.AbbrDesc ELSE pc.LaymanTerm END AS Descript,
            -- Calculate monthly totals
            SUM(CASE 
                WHEN MONTH(percode.ProcDate) = @Month THEN percode.ProcFee * percode.Units 
                ELSE 0 
            END) AS MonthFee,
            -- Calculate yearly totals
            SUM(percode.ProcFee * percode.Units) AS YearFee,
            -- Units calculations
            COALESCE(SUM(CASE 
                WHEN MONTH(percode.ProcDate) = @Month THEN percode.Units 
            END), 0) AS MthUnits,
            COALESCE(SUM(percode.Units), 0) AS YrUnits,
            -- Count calculations
            COUNT(CASE 
                WHEN MONTH(percode.ProcDate) = @Month THEN percode.ProcNum 
            END) AS MthCount,
            COUNT(percode.ProcNum) AS YrCount
        FROM (
            -- Get completed procedures
            SELECT 
                pl.ProcFee,
                pl.UnitQty + pl.BaseUnits AS Units,
                prov.Abbr AS Provider,
                pl.CodeNum,
                pl.ProcNum,
                pl.ProcDate
            FROM procedurelog pl
            INNER JOIN provider prov ON prov.ProvNum = pl.ProvNum 
                AND prov.Abbr = @Provider
            WHERE pl.ProcStatus = 2  -- Completed procedures only
                AND YEAR(pl.ProcDate) = @Year 
        ) percode
        INNER JOIN procedurecode pc ON pc.CodeNum = percode.CodeNum        
        INNER JOIN definition df ON df.DefNum = pc.ProcCat
        GROUP BY pc.ProcCode
    ) main
    LEFT JOIN (
        -- Category totals for percentage calculations
        SELECT 
            SUM(pl.ProcFee * (pl.UnitQty + pl.BaseUnits)) AS YearCatFee,
            SUM(CASE 
                WHEN MONTH(pl.ProcDate) = @Month THEN pl.ProcFee * (pl.UnitQty + pl.BaseUnits) 
            END) AS MonthCatFee,
            df.ItemName AS Category
        FROM procedurelog pl 
        INNER JOIN procedurecode pc ON pc.CodeNum = pl.CodeNum
        INNER JOIN definition df ON df.DefNum = pc.ProcCat
        INNER JOIN provider prov ON prov.ProvNum = pl.ProvNum 
            AND prov.Abbr = @Provider
        WHERE pl.ProcStatus = 2
            AND YEAR(pl.ProcDate) = @Year
        GROUP BY df.DefNum
    ) percat ON percat.Category = main.Category
    GROUP BY main.ProcCode

    UNION ALL

    -- Category totals
    SELECT 
        2 AS ItemOrder,
        COALESCE(main.Provider, @Provider),
        '',
        'Total:',
        main.Category,
        SUM(main.MthCount),
        SUM(main.MthUnits),
        FORMAT(ROUND(COALESCE(SUM(main.MonthFee) / @MonthProvFee*100, 0), 2), 2),
        FORMAT(ROUND(COALESCE(SUM(main.MonthFee), 0), 2), 2),
        SUM(main.YrCount),
        SUM(main.YrUnits),
        FORMAT(ROUND(COALESCE(SUM(main.YearFee)/@YearProvFee*100, 0), 2), 2),
        FORMAT(ROUND(COALESCE(SUM(main.YearFee), 0), 2), 2)
    FROM /* Same subquery as above */ main
    GROUP BY main.Category

    UNION ALL

    -- Spacer rows between categories
    SELECT 
        3 AS ItemOrder,
        '', '', '',
        df.ItemName,
        '', '', '', '',
        '', '', '', ''
    FROM definition df
    WHERE df.DefNum IN (
        SELECT DISTINCT pc.ProcCat
        FROM procedurelog pl
        INNER JOIN procedurecode pc ON pc.CodeNum = pl.CodeNum
        INNER JOIN provider prov ON prov.ProvNum = pl.ProvNum 
            AND prov.Abbr = @Provider
        WHERE pl.ProcStatus = 2
            AND YEAR(pl.ProcDate) = @Year
    )
) display
ORDER BY display.Category, display.ItemOrder, display.ProcCode; 