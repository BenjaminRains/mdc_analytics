-- BasePayments: Pre-filter base payments based on the defined date range.
-- Date filter: @start_date to @end_date
-- Dependencies: @start_date and @end_date variables

BasePayments AS (
    SELECT PayNum, PayDate, PayAmt, PayType
    FROM payment 
    WHERE PayDate >= @start_date AND PayDate < @end_date
)