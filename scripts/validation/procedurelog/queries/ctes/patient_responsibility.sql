-- PATIENT RESPONSIBILITY
-- Calculates patient responsibility after payments and adjustments
-- Used for analyzing patient financial burden and collection opportunities
PatientResponsibility AS (
    SELECT
        bp.ProcNum,
        bp.PatNum,
        bp.ProcCode,
        bp.ProcStatus,
        bp.ProcFee,
        pa.insurance_paid,
        pa.direct_paid,
        pa.total_paid,
        adj.total_adjustments,
        bp.ProcFee - COALESCE(pa.total_paid, 0) - COALESCE(adj.total_adjustments, 0) AS remaining_responsibility,
        CASE
            WHEN bp.ProcFee = 0 THEN 'Zero Fee'
            WHEN bp.ProcFee - COALESCE(pa.total_paid, 0) - COALESCE(adj.total_adjustments, 0) <= 0 THEN 'Fully Resolved'
            WHEN pa.insurance_paid > 0 AND bp.ProcFee - COALESCE(pa.total_paid, 0) - COALESCE(adj.total_adjustments, 0) > 0 THEN 'Patient Portion Due'
            WHEN pa.insurance_paid = 0 AND pa.direct_paid = 0 AND adj.total_adjustments = 0 THEN 'No Activity'
            ELSE 'Partial Payment'
        END AS responsibility_status
    FROM BaseProcedures bp
    LEFT JOIN PaymentActivity pa ON bp.ProcNum = pa.ProcNum
    LEFT JOIN ProcedureAdjustments adj ON bp.ProcNum = adj.ProcNum
)