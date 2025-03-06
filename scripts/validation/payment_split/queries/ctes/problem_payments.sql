-- ProblemPayments: Pre-filter payments flagged as problematic for detailed analysis.
-- Date filter: Uses @start_date to @end_date
-- Include dependent CTE
<<include:payment_filter_diagnostics.sql>>

ProblemPayments AS (
    SELECT *
    FROM PaymentFilterDiagnostics
    WHERE filter_reason != 'Normal Payment'
)