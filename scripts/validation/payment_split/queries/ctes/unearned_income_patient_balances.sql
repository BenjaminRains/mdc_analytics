-- CTE for patient balances
-- Purpose: Provides patient account balance information with aging breakdown
-- Dependencies: None
-- Date filter: @end_date

PatientBalances AS (
    SELECT 
        p.PatNum,
        p.Bal AS TotalBalance,
        -- Age brackets using standard 30-day buckets
        -- Current (0-30 days)
        IFNULL(
            (SELECT SUM(CASE 
                WHEN DATEDIFF(@end_date, pl.ProcDate) BETWEEN 0 AND 30 
                THEN pl.Balance 
                ELSE 0 
            END)
            FROM procedurelog pl
            WHERE pl.PatNum = p.PatNum AND pl.Balance > 0),
            0
        ) AS Balance0to30,
        
        -- 31-60 days
        IFNULL(
            (SELECT SUM(CASE 
                WHEN DATEDIFF(@end_date, pl.ProcDate) BETWEEN 31 AND 60 
                THEN pl.Balance 
                ELSE 0 
            END)
            FROM procedurelog pl
            WHERE pl.PatNum = p.PatNum AND pl.Balance > 0),
            0
        ) AS Balance31to60,
        
        -- 61-90 days
        IFNULL(
            (SELECT SUM(CASE 
                WHEN DATEDIFF(@end_date, pl.ProcDate) BETWEEN 61 AND 90 
                THEN pl.Balance 
                ELSE 0 
            END)
            FROM procedurelog pl
            WHERE pl.PatNum = p.PatNum AND pl.Balance > 0),
            0
        ) AS Balance61to90,
        
        -- Over 90 days
        IFNULL(
            (SELECT SUM(CASE 
                WHEN DATEDIFF(@end_date, pl.ProcDate) > 90 
                THEN pl.Balance 
                ELSE 0 
            END)
            FROM procedurelog pl
            WHERE pl.PatNum = p.PatNum AND pl.Balance > 0),
            0
        ) AS BalanceOver90,
        
        -- Insurance estimate if available
        p.InsEst AS InsuranceEstimate,
        
        -- Calculate percentages of total balance in each aging bucket
        CASE WHEN p.Bal = 0 THEN 0 ELSE 
            IFNULL(
                (SELECT SUM(CASE 
                    WHEN DATEDIFF(@end_date, pl.ProcDate) BETWEEN 0 AND 30 
                    THEN pl.Balance 
                    ELSE 0 
                END) / p.Bal * 100
                FROM procedurelog pl
                WHERE pl.PatNum = p.PatNum AND pl.Balance > 0),
                0
            ) 
        END AS PercentCurrent,
        
        CASE WHEN p.Bal = 0 THEN 0 ELSE 
            IFNULL(
                (SELECT SUM(CASE 
                    WHEN DATEDIFF(@end_date, pl.ProcDate) BETWEEN 31 AND 60 
                    THEN pl.Balance 
                    ELSE 0 
                END) / p.Bal * 100
                FROM procedurelog pl
                WHERE pl.PatNum = p.PatNum AND pl.Balance > 0),
                0
            ) 
        END AS Percent31to60,
        
        CASE WHEN p.Bal = 0 THEN 0 ELSE 
            IFNULL(
                (SELECT SUM(CASE 
                    WHEN DATEDIFF(@end_date, pl.ProcDate) BETWEEN 61 AND 90 
                    THEN pl.Balance 
                    ELSE 0 
                END) / p.Bal * 100
                FROM procedurelog pl
                WHERE pl.PatNum = p.PatNum AND pl.Balance > 0),
                0
            ) 
        END AS Percent61to90,
        
        CASE WHEN p.Bal = 0 THEN 0 ELSE 
            IFNULL(
                (SELECT SUM(CASE 
                    WHEN DATEDIFF(@end_date, pl.ProcDate) > 90 
                    THEN pl.Balance 
                    ELSE 0 
                END) / p.Bal * 100
                FROM procedurelog pl
                WHERE pl.PatNum = p.PatNum AND pl.Balance > 0),
                0
            ) 
        END AS PercentOver90
    FROM patient p
    WHERE p.Bal <> 0
) 