-- ProblemPayments: Pre-filter payments flagged as problematic for detailed analysis.
-- depends on: PaymentFilterDiagnostics
-- Date filter: Uses @start_date to @end_date
ProblemPayments AS (
    SELECT *
    FROM PaymentFilterDiagnostics
    WHERE filter_reason != 'Normal Payment'
)