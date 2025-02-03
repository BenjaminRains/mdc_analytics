-- Treatment Journey Dataset Indexes
-- These indexes support efficient execution of the treatment journey query
-- Last updated: 2024

-- Note: Some indexes may already exist. CREATE INDEX IF NOT EXISTS is used to prevent errors.

-- Procedurelog Indexes
-- Core indexes for main table filtering and joins
CREATE INDEX IF NOT EXISTS idx_proc_date_status ON procedurelog (ProcDate, ProcStatus);
CREATE INDEX IF NOT EXISTS idx_proc_patient ON procedurelog (PatNum, ProcDate);
CREATE INDEX IF NOT EXISTS idx_proc_code ON procedurelog (CodeNum);
CREATE INDEX IF NOT EXISTS idx_proc_clinic ON procedurelog (ClinicNum);

-- Compound indexes for complex conditions
CREATE INDEX IF NOT EXISTS idx_proc_patient_status_date ON procedurelog (PatNum, ProcStatus, ProcDate, ProcFee);
CREATE INDEX IF NOT EXISTS idx_proc_date_status_fee ON procedurelog (ProcDate, ProcStatus, ProcFee);

-- Patient Indexes
-- Core indexes for patient lookups and joins
CREATE INDEX IF NOT EXISTS idx_pat_guarantor ON patient (Guarantor);
CREATE INDEX IF NOT EXISTS idx_pat_birth ON patient (Birthdate);
CREATE INDEX IF NOT EXISTS idx_pat_insurance ON patient (HasIns);
CREATE INDEX IF NOT EXISTS idx_pat_feesched ON patient (FeeSched);

-- Fee Schedule Indexes
CREATE INDEX IF NOT EXISTS idx_fee_schedule_code ON fee (FeeSched, CodeNum, ClinicNum, Amount);
CREATE INDEX IF NOT EXISTS idx_feesched_type ON feesched (FeeSchedType, FeeSchedNum);

-- Insurance Claim Indexes (NEW)
CREATE INDEX IF NOT EXISTS idx_claimproc_proc ON claimproc (ProcNum, Status, InsPayEst, InsPayAmt);
CREATE INDEX IF NOT EXISTS idx_claimproc_patient_date ON claimproc (PatNum, ProcDate, Status);
CREATE INDEX IF NOT EXISTS idx_claimproc_payment ON claimproc (ClaimPaymentNum);
CREATE INDEX IF NOT EXISTS idx_claimproc_dates ON claimproc (DateCP, ProcDate);

-- Claim Status Indexes (NEW)
CREATE INDEX IF NOT EXISTS idx_claim_dates ON claim (DateSent, DateReceived, ClaimStatus);
CREATE INDEX IF NOT EXISTS idx_claim_status ON claim (ClaimStatus, ClaimNum);

-- Payment Indexes (NEW)
CREATE INDEX IF NOT EXISTS idx_claimpayment_check ON claimpayment (ClaimPaymentNum, CheckAmt, IsPartial);
CREATE INDEX IF NOT EXISTS idx_paysplit_proc_payment ON paysplit (ProcNum, PayNum, SplitAmt);
CREATE INDEX IF NOT EXISTS idx_payment_date ON payment (PayDate);

-- Appointment Index
CREATE INDEX IF NOT EXISTS idx_appt_patient_date ON appointment (PatNum, AptDateTime);

-- Adjustment Index
CREATE INDEX IF NOT EXISTS idx_adj_proc ON adjustment (ProcNum, AdjAmt);

-- Procedurecode Indexes
-- Support procedure code lookups
CREATE INDEX IF NOT EXISTS idx_proccode_category ON procedurecode (ProcCat, CodeNum);
