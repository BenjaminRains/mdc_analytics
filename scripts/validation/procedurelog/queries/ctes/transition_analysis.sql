-- TRANSITION ANALYSIS
-- Summarizes procedure status transitions and patterns
-- Used for workflow analysis and identifying potential process improvements
TransitionAnalysis AS (
    SELECT
        status_description,
        transition_pattern,
        COUNT(*) AS procedure_count,
        MIN(days_in_status) AS min_days,
        MAX(days_in_status) AS max_days,
        ROUND(AVG(days_in_status), 1) AS avg_days,
        SUM(ProcFee) AS total_fees,
        COUNT(DISTINCT AptNum) AS appointments_count
    FROM StatusHistory
    GROUP BY status_description, transition_pattern
)