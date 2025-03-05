-- BasePayments: Pre-filter base payments based on the defined date range.
-- Date filter: @start_date to @end_date
SET @start_date = '2023-01-01'; -- Example start date, will be replaced by script
SET @end_date = '2023-12-31';   -- Example end date, will be replaced by script

BasePayments AS (
    SELECT PayNum, PayDate, PayAmt, PayType
    FROM payment 
    WHERE PayDate >= @start_date AND PayDate < @end_date
)