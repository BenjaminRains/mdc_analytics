-- PROCEDURE ADJUSTMENTS
-- Aggregates adjustment information for procedures
-- Used for analyzing write-offs, discounts, and adjustment patterns
ProcedureAdjustments AS (
    SELECT
        bp.ProcNum,
        bp.ProcFee,
        COALESCE(SUM(ca.WriteOff), 0) AS insurance_adjustments,
        COALESCE(SUM(
            CASE WHEN a.AdjType IN (1, 2) -- Positive adjustment types
                THEN a.AdjAmt
                ELSE 0
            END), 0) AS positive_adjustments,
        COALESCE(SUM(
            CASE WHEN a.AdjType IN (3, 4) -- Negative adjustment types
                THEN a.AdjAmt
                ELSE 0
            END), 0) AS negative_adjustments,
        COALESCE(SUM(a.AdjAmt), 0) AS total_direct_adjustments,
        COALESCE(SUM(ca.WriteOff), 0) + COALESCE(SUM(a.AdjAmt), 0) AS total_adjustments
    FROM BaseProcedures bp
    LEFT JOIN claimproc ca ON bp.ProcNum = ca.ProcNum AND ca.WriteOff <> 0
    LEFT JOIN adjustment a ON bp.ProcNum = a.ProcNum
    GROUP BY bp.ProcNum, bp.ProcFee
)