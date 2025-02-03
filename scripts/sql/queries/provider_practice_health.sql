-- Provider Practice Health Analysis
-- Tracks daily, MTD, and YTD metrics for providers and practice totals

-- Parameters
SET @AsOf = '2023-09-05';           -- Analysis date
SET @HygieneCodes = 'D1110,D1120,D4910,D4341,D4342,D4346,D4355,D1125,D1101';  -- Hygiene procedure codes

-- Main metrics tracked:
SELECT 
    display.Provider,
    -- New Patient Metrics
    display.DailyNP AS 'Daily New Patients',
    display.MTDNP AS 'MTD New Patients',
    
    -- Hygiene Metrics
    display.DailyHP AS 'Daily Hygiene Patients',
    display.MTDHP AS 'MTD Hygiene Patients',
    
    -- Production Metrics
    display.DailyProd AS 'Daily Production',
    display.DailyAdj AS 'Daily Adjustments',
    display.DailyWo AS 'Daily Writeoffs',
    display.DailyNetProd AS 'Daily Net Production',
    display.ProductionMTD AS 'MTD Production',
    display.ProductionYTD AS 'YTD Production',
    
    -- Income Metrics
    display.DailyDeposits AS 'Daily Income',
    display.MTDDeposits AS 'MTD Income',
    display.YTDDeposits AS 'YTD Income'
FROM /* Complex calculations */ 