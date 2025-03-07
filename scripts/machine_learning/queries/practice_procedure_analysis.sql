-- Practice-wide Procedure Analysis Report
-- Analyzes completed procedures across all providers and categories
-- Shows counts, fees, units, and percentages for both monthly and yearly periods

-- Set report parameters
SET @Month = MONTH(CURRENT_DATE());
SET @Year = YEAR(CURRENT_DATE());

-- Calculate practice-wide totals
SELECT 
    SUM(pl.ProcFee * (pl.UnitQty + pl.BaseUnits)) AS YearPracFee,
    SUM(CASE 
        WHEN MONTH(pl.ProcDate) = @Month 
        THEN pl.ProcFee * (pl.UnitQty + pl.BaseUnits) 
    END) AS MonthPracFee
INTO @YearPracFee, @MonthPracFee
FROM procedurelog pl 
WHERE pl.ProcStatus = 2  -- Completed procedures only
    AND YEAR(pl.ProcDate) = @Year;

-- Main report query
SELECT 
    C.Provider,
    -- Monthly statistics
    C.MthCount AS 'Month Count',
    C.MthUnits AS 'Month Units',
    C.MthFees AS 'Month Fees',
    C.MonthPercent AS 'Month%',
    -- Yearly statistics
    C.YrCount AS 'Year Count',
    C.YrUnits AS 'Year Units',
    C.YrFees AS 'Year Fees',
    C.YearPercent AS 'Year%'
FROM (
    -- Provider-level statistics
    SELECT 
        1 AS ItemOrder,
        A.Provider,
        A.MthCount,
        A.MthUnits,
        FORMAT(ROUND(COALESCE(A.MonthFee/@MonthPracFee*100, 0), 2), 2) AS MonthPercent,
        FORMAT(ROUND(COALESCE(A.MonthFee, 0), 2), 2) AS MthFees,
        A.YrCount,
        A.YrUnits,
        FORMAT(ROUND(COALESCE(A.YearFee/@YearPracFee*100, 0), 2), 2) AS YearPercent,
        FORMAT(ROUND(COALESCE(A.YearFee, 0), 2), 2) AS YrFees
    FROM /* Provider details subquery */ 

    UNION ALL

    -- Practice totals
    SELECT 
        2 AS ItemOrder,
        'Grand Total' AS Provider,
        /* Practice-wide totals calculation */

    UNION ALL

    -- Blank row separator
    SELECT 4 AS ItemOrder, '', '', '', '', '', '', '', '', ''

    UNION ALL

    -- Category-level statistics
    SELECT 
        5 AS ItemOrder,
        A.Category,
        /* Category totals calculation */

    UNION ALL

    -- Practice totals (repeated)
    SELECT 
        6 AS ItemOrder,
        'Grand Total' AS Provider,
        /* Practice-wide totals calculation */
) C
ORDER BY C.ItemOrder, C.Provider; 