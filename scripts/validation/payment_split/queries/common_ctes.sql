/*
===============================================================================
Payment Split Validation CTEs
===============================================================================
Purpose:
  This file defines common table expressions (CTEs) used for payment split 
  validation queries. These CTEs extract and compute metrics related to 
  payment splits, procedures, and insurance relationships. They are intended 
  to be loaded by an export script that appends them to each query before 
  execution.

Usage:
  Include the contents of this file at the start of any query that requires these
  common expressions. The export script automatically loads this file and adds its 
  contents to each query configuration before exporting the results.

CTE Dependency Order:
  1. BasePayments: Pre-filter base payments by date.
  2. BaseSplits: Pre-aggregate split details for base payments.
  3. PaymentSummary: Compute basic payment metrics and flags.
  4. PaymentMethodAnalysis: Detailed analysis by payment type.
  5. PaymentSourceCategories: Categorize payments by source.
  6. PaymentSourceSummary: Summarize payment counts and amounts by source.
  7. TotalPayments: Calculate total payment counts and amounts across all sources.
  8. InsurancePaymentAnalysis: Compute insurance-specific metrics.
  9. ProcedurePayments: Extract procedure-level payment details.
 10. SplitPatternAnalysis: Analyze and categorize payment split patterns.
 11. PaymentBaseCounts: Compute overall payment volume metrics.
 12. PaymentJoinDiagnostics: Validate relationships between payments, splits, and procedures.
 13. PaymentFilterDiagnostics: Categorize and filter payments based on diagnostics.
 14. JoinStageCounts: Analyze payment progression through join stages.
 15. SuspiciousSplitAnalysis: Identify suspicious or abnormal split patterns.
 16. PaymentDetailsBase: Base payment and split information for detailed analysis.
 17. PaymentDetailsMetrics: Compute detailed metrics per payment.
 18. PaymentDailyDetails: Extract daily payment patterns and metrics.
 19. FilterStats: Compute summary statistics for each payment filter category.
 20. ProblemPayments: Pre-filter payments flagged as problematic.
 21. ClaimMetrics: Analyze claim relationships for payment split analysis.
 22. ProblemClaimDetails: Detailed analysis of known problematic claims.
===============================================================================
*/

,

,


