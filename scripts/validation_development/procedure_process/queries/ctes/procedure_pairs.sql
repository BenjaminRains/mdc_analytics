-- PROCEDURE PAIRS
-- Identifies pairs of procedures performed on the same patient on the same day
-- Used for analyzing common procedure combinations and bundling patterns
-- Dependent CTEs: base_procedures.sql
ProcedurePairs AS (
    SELECT 
        p1.PatNum,
        p1.ProcDate,
        p1.ProcNum AS proc1_num,
        p1.ProcCode AS proc1_code,
        p1.ProcFee AS proc1_fee,
        p2.ProcNum AS proc2_num,
        p2.ProcCode AS proc2_code,
        p2.ProcFee AS proc2_fee,
        p1.ProcFee + p2.ProcFee AS combined_fee
    FROM BaseProcedures p1
    JOIN BaseProcedures p2 
        ON  p1.PatNum = p2.PatNum 
        AND p1.ProcDate = p2.ProcDate
        AND p1.ProcNum < p2.ProcNum -- Ensures each pair is counted only once
)