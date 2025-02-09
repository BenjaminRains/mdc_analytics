-- create temp tables, window functions, CTEs, views, etc. in order to understand higher
-- level relationships and business logic. 


-- Query 1: Verify fee population logic in procedurelog and it's relationship with fee, procedurecode, and definition
-- business logic: this is the clinic fee before insurance, adjustments, discounts, write-offs.
-- this query is only looking at completed procedures. (treatment acceptance) 
-- Name the query results as proclog_fee_acceptance_details in validation/data/*
-- Limit results to the past 4 years and fetch no more than 1 million records
-- NOTE: pl.ProcFee is sometimes 0 and f.Amount is >0. Investigate.
SELECT 
    pl.ProcNum,
    pl.CodeNum,
    pl.ProcFee,
    pl.PatNum,
    pl.ProcDate,
    f.Amount AS clinic_fee,
    f.OldCode AS fee_old_code,
    f.FeeNum AS fee_number,
    pc.Descript AS procedure_description,
    pc.CodeNum AS procedure_code_number
FROM 
    procedurelog pl
LEFT JOIN 
    fee f ON pl.CodeNum = f.CodeNum
LEFT JOIN 
    procedurecode pc ON pl.CodeNum = pc.CodeNum
WHERE 
    pl.ProcStatus = 2
    AND CAST(pl.ProcDate AS DATE) >= DATE_SUB(CURRENT_DATE, INTERVAL 4 YEAR)
LIMIT 1000000; 


-- Query 2 to understand discount application in adjustment table
-- business logic: this is the provider or clinic discount applied to the acceptedfee before insurance. 
-- Name the query results as adjustment_discount_application in validation/data/*
-- NOTE: look at d.ItemName for the type of discount.
-- Limit results to the past 4 years
-- NOTE: adjustments are linked to procedurelog via a.ProcNum = pl.ProcNum

SELECT 
    a.AdjNum,
    a.AdjAmt,
    a.AdjType,
    a.ProvNum,
    a.PatNum,  
    a.AdjDate, 
    a.AdjNote,
    a.ProcNum,
    d.ItemName AS adjustment_type_name
FROM 
    adjustment a
JOIN 
    definition d ON a.AdjType = d.DefNum
WHERE 
    a.AdjDate >= DATE_SUB(CURRENT_DATE, INTERVAL 4 YEAR); 
LIMIT 1000000; 


-- Query 3: Expanded Query to investigate how insurance documents the fee and the process of insurance payment.
-- NOTE: insbluebook and insbluebooklog are not populated for all procedures. 
-- NOTE: This is the clinic's way to document the ins fee and ins fee payment.
-- NOTE: insbluebook.InsPayAmt and insbluebooklog.AllowedFee are the insurance's estimated 
-- fee and the allowed fee from the insurance carrier.
-- Name query results as insurance_claim_fee_process in validation/data/*
-- this query can be used to understand how insurance fees are documented and processed. 

SELECT 
    cp.ClaimNum,
    cp.FeeBilled,
    cp.InsPayEst,
    cp.InsPayAmt,
    cp.WriteOff,
    c.DateService, 
    c.PlanNum,
    c.PatNum,
    fs.Description AS fee_schedule_description,
    fs.FeeSchedType,
    ip.GroupName AS insurance_group_name,
    ip.PlanType AS insurance_plan_type,
    ibb.InsPayAmt AS bluebook_ins_pay_amt,
    ibb.AllowedOverride AS bluebook_allowed_override,
    ibbl.AllowedFee AS bluebook_log_allowed_fee,
    ibbl.Description AS bluebook_log_description
FROM 
    claimproc cp
JOIN 
    claim c ON cp.ClaimNum = c.ClaimNum
JOIN 
    insplan ip ON c.PlanNum = ip.PlanNum
JOIN 
    feesched fs ON ip.FeeSched = fs.FeeSchedNum
LEFT JOIN 
    insbluebook ibb ON cp.ProcNum = ibb.ProcNum AND c.PlanNum = ibb.PlanNum
LEFT JOIN 
    insbluebooklog ibbl ON cp.ClaimProcNum = ibbl.ClaimProcNum
WHERE 
    cp.Status IN (1, 2) 
    AND c.DateService >= DATE_SUB(CURRENT_DATE, INTERVAL 4 YEAR)
LIMIT 1000000;


-- Query 4 to check patient and insurance payment records in payment and paysplit
-- Name query results as patient_insurance_payment_records in validation/data/*
-- Can verify if the procedure was paid 
-- Can f.amount be checked against p.PayAmt or ps.SplitAmt?
-- p.PayType can be linked to definition.DefNum and d.Descript and can be used along with p.PayNote to understand the payment type and method.

SELECT 
    p.PayNum,
    p.PayAmt,
    p.PayNote,
    p.PatNum,
    ps.SplitAmt,
    ps.ProcNum,
    ps.UnearnedType, -- linked to definition.DefNum
    d.Descript,
    d.DefNum
FROM 
    payment p
JOIN 
    paysplit ps ON p.PayNum = ps.PayNum
JOIN 
    definition d ON ps.UnearnedType = d.DefNum -- Join with definition table
WHERE 
    p.PayAmt <> 0
    AND p.PayDate >= DATE_SUB(CURRENT_DATE, INTERVAL 4 YEAR)
LIMIT 1000000;

-- Notes on claimpayment links:
-- 1. The claimpayment table contains fields such as ClaimPaymentNum, CheckAmt, and CheckDate.
-- 2. Currently, there is no direct link between claimpayment and the payment or paysplit tables.
-- 3. Potential indirect links could involve fields like ClinicNum or DepositNum, but these require further investigation.
-- 4. Business logic or application code might provide additional context for linking these tables.
-- 5. For now, claimpayment is excluded from this query until a clear relationship is established.


