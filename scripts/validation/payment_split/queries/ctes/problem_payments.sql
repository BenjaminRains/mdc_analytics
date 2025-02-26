-- ProblemPayments: Pre-filter payments flagged as problematic for detailed analysis.
-- depends on: PaymentFilterDiagnostics
-- Date filter: 2024-01-01 to 2025-01-01
ProblemPayments AS (
    SELECT *
    FROM PaymentFilterDiagnostics
    WHERE filter_reason != 'Normal Payment'
)