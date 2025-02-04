-- Treatment Journey Dataset Indexes
-- These indexes support efficient execution of the treatment journey query
-- Last updated: 2024

-- Note: All ML-specific indexes use idx_ml_ prefix to distinguish from system indexes

-- Procedurelog Indexes
-- Core indexes for main table filtering and joins
CREATE INDEX IF NOT EXISTS idx_ml_proc_date_status ON procedurelog (ProcDate, ProcStatus);
CREATE INDEX IF NOT EXISTS idx_ml_proc_patient ON procedurelog (PatNum, ProcDate);
CREATE INDEX IF NOT EXISTS idx_ml_proc_code ON procedurelog (CodeNum);
CREATE INDEX IF NOT EXISTS idx_ml_proc_clinic ON procedurelog (ClinicNum);

-- Compound indexes for complex conditions
CREATE INDEX IF NOT EXISTS idx_ml_proc_patient_status ON procedurelog (PatNum, ProcStatus, ProcDate, ProcFee);
CREATE INDEX IF NOT EXISTS idx_ml_proc_date_fee ON procedurelog (ProcDate, ProcStatus, ProcFee);

-- Patient Indexes
-- Core indexes for patient lookups and joins
CREATE INDEX IF NOT EXISTS idx_ml_pat_guarantor ON patient (Guarantor);
CREATE INDEX IF NOT EXISTS idx_ml_pat_birth ON patient (Birthdate);
CREATE INDEX IF NOT EXISTS idx_ml_pat_insurance ON patient (HasIns);
CREATE INDEX IF NOT EXISTS idx_ml_pat_feesched ON patient (FeeSched);

-- Fee Schedule Indexes
CREATE INDEX IF NOT EXISTS idx_ml_fee_lookup 
    ON fee (FeeSched, CodeNum, ClinicNum, ProvNum, Amount);
CREATE INDEX IF NOT EXISTS idx_ml_feesched_core 
    ON feesched (FeeSchedNum, FeeSchedType, IsHidden);
CREATE INDEX IF NOT EXISTS idx_ml_provider_feesched 
    ON provider (ProvNum, FeeSched);
CREATE INDEX IF NOT EXISTS idx_ml_pat_feesched_lookup 
    ON patient (PatNum, FeeSched);

-- Updated Procedure Indexes for Fee Schedule Analysis
CREATE INDEX IF NOT EXISTS idx_ml_proc_provider_fee 
    ON procedurelog (ProvNum, ProcDate, ProcStatus, ProcFee);
CREATE INDEX IF NOT EXISTS idx_ml_proc_clinic_fee 
    ON procedurelog (ClinicNum, ProcDate, ProcStatus, ProcFee);

-- Insurance Claim Indexes
CREATE INDEX IF NOT EXISTS idx_ml_claimproc_proc ON claimproc (ProcNum, Status, InsPayEst, InsPayAmt);
CREATE INDEX IF NOT EXISTS idx_ml_claimproc_patient ON claimproc (PatNum, ProcDate, Status);
CREATE INDEX IF NOT EXISTS idx_ml_claimproc_payment ON claimproc (ClaimPaymentNum);
CREATE INDEX IF NOT EXISTS idx_ml_claimproc_dates ON claimproc (DateCP, ProcDate);

-- Claim Status Indexes
CREATE INDEX IF NOT EXISTS idx_ml_claim_dates ON claim (DateSent, DateReceived, ClaimStatus);
CREATE INDEX IF NOT EXISTS idx_ml_claim_status ON claim (ClaimStatus, ClaimNum);

-- Payment Indexes
CREATE INDEX IF NOT EXISTS idx_ml_claimpayment ON claimpayment (ClaimPaymentNum, CheckAmt, IsPartial);
CREATE INDEX IF NOT EXISTS idx_ml_paysplit_proc ON paysplit (ProcNum, PayNum, SplitAmt);
CREATE INDEX IF NOT EXISTS idx_ml_payment_date ON payment (PayDate);

-- Appointment Index
CREATE INDEX IF NOT EXISTS idx_ml_appt_patient ON appointment (PatNum, AptDateTime);

-- Adjustment Index
CREATE INDEX IF NOT EXISTS idx_ml_adj_proc ON adjustment (ProcNum, AdjAmt);

-- Procedurecode Indexes
CREATE INDEX IF NOT EXISTS idx_ml_proccode_cat ON procedurecode (ProcCat, CodeNum);
