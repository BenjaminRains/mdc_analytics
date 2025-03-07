-- Description: Calculates the median days to payment for each plan
-- Date range: @start_date to @end_date
-- Dependencies: procedure_payment_journey.sql

PaymentTimingStats AS (
    -- Calculate approximate median using a simplified approach for MariaDB
    SELECT 
        PlanNum,
        AVG(days_to_payment) as median_days_to_payment
    FROM (
        SELECT 
            PlanNum,
            days_to_payment,
            @rownum := @rownum + 1 as row_num,
            @total_rows := @rownum
        FROM ProcedurePaymentJourney
        CROSS JOIN (SELECT @rownum := 0, @total_rows := 0) as vars
        WHERE days_to_payment IS NOT NULL
        ORDER BY PlanNum, days_to_payment
    ) as x
    WHERE 
        row_num > @total_rows/2 - 5 
        AND row_num < @total_rows/2 + 5
    GROUP BY PlanNum
)
