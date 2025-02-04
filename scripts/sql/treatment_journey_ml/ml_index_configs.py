"""
Treatment Journey ML Index Configurations

This module defines specialized indexes for ML operations:
1. Feature extraction optimization
2. Training data queries
3. Prediction serving
4. Model validation

Note: Core business indexes are defined in database_setup/base_index_configs.py
"""

TREATMENT_JOURNEY_INDEXES = [
    # Patient demographics
    "CREATE INDEX IF NOT EXISTS idx_ml_pat_guarantor ON patient (Guarantor)",
    "CREATE INDEX IF NOT EXISTS idx_ml_pat_birth ON patient (Birthdate)",
    "CREATE INDEX IF NOT EXISTS idx_ml_pat_insurance ON patient (HasIns)",
    "CREATE INDEX IF NOT EXISTS idx_ml_pat_feesched ON patient (FeeSched)",
    
    # Procedure tracking
    "CREATE INDEX IF NOT EXISTS idx_ml_proc_date_status ON procedurelog (ProcDate, ProcStatus)",
    "CREATE INDEX IF NOT EXISTS idx_ml_proc_patient ON procedurelog (PatNum, ProcDate)",
    "CREATE INDEX IF NOT EXISTS idx_ml_proc_code ON procedurelog (CodeNum)",
    "CREATE INDEX IF NOT EXISTS idx_ml_proc_clinic ON procedurelog (ClinicNum)",
    "CREATE INDEX IF NOT EXISTS idx_ml_proc_patient_status ON procedurelog (PatNum, ProcStatus, ProcDate, ProcFee)",
    "CREATE INDEX IF NOT EXISTS idx_ml_proc_date_fee ON procedurelog (ProcDate, ProcStatus, ProcFee)",
    "CREATE INDEX IF NOT EXISTS idx_ml_proc_provider_fee ON procedurelog (ProvNum, ProcDate, ProcStatus, ProcFee)",
    "CREATE INDEX IF NOT EXISTS idx_ml_proc_clinic_fee ON procedurelog (ClinicNum, ProcDate, ProcStatus, ProcFee)",
    
    # Fee Schedule related
    "CREATE INDEX IF NOT EXISTS idx_ml_fee_lookup ON fee (FeeSched, CodeNum, ClinicNum, ProvNum, Amount)",
    "CREATE INDEX IF NOT EXISTS idx_ml_feesched_core ON feesched (FeeSchedNum, FeeSchedType, IsHidden)",
    "CREATE INDEX IF NOT EXISTS idx_ml_provider_feesched ON provider (ProvNum, FeeSched)",
    
    # Insurance claims
    "CREATE INDEX IF NOT EXISTS idx_ml_claim_dates ON claim (DateSent, DateReceived, ClaimStatus)",
    "CREATE INDEX IF NOT EXISTS idx_ml_claim_status ON claim (ClaimStatus, ClaimNum)",
    "CREATE INDEX IF NOT EXISTS idx_ml_claimproc_proc ON claimproc (ProcNum, Status, InsPayEst, InsPayAmt)",
    "CREATE INDEX IF NOT EXISTS idx_ml_claimproc_patient ON claimproc (PatNum, ProcDate, Status)",
    "CREATE INDEX IF NOT EXISTS idx_ml_claimproc_payment ON claimproc (ClaimPaymentNum)",
    "CREATE INDEX IF NOT EXISTS idx_ml_claimproc_dates ON claimproc (DateCP, ProcDate)",
    
    # Payment tracking
    "CREATE INDEX IF NOT EXISTS idx_ml_claimpayment ON claimpayment (ClaimPaymentNum, CheckAmt, IsPartial)",
    "CREATE INDEX IF NOT EXISTS idx_ml_paysplit_proc ON paysplit (ProcNum, PayNum, SplitAmt)",
    "CREATE INDEX IF NOT EXISTS idx_ml_payment_date ON payment (PayDate)",
    
    # Other
    "CREATE INDEX IF NOT EXISTS idx_ml_appt_patient ON appointment (PatNum, AptDateTime)",
    "CREATE INDEX IF NOT EXISTS idx_ml_adj_proc ON adjustment (ProcNum, AdjAmt)",
    "CREATE INDEX IF NOT EXISTS idx_ml_proccode_cat ON procedurecode (ProcCat, CodeNum)"
]

# Documentation for ML-specific indexes
INDEX_DOCUMENTATION = {
    "idx_ml_pat_insurance": "Insurance status tracking",
    "idx_ml_pat_feesched": "Patient fee schedule lookups",
    "idx_ml_proc_date_status": "Procedure date and status lookups",
    "idx_ml_proc_patient": "Procedure patient lookups",
    "idx_ml_proc_code": "Procedure code lookups",
    "idx_ml_proc_clinic": "Procedure clinic lookups",
    "idx_ml_proc_patient_status": "Procedure patient status lookups",
    "idx_ml_proc_date_fee": "Procedure date and fee lookups",
    "idx_ml_proc_provider_fee": "Procedure provider fee lookups",
    "idx_ml_proc_clinic_fee": "Procedure clinic fee lookups",
    "idx_ml_fee_lookup": "Fee schedule amount lookups",
    "idx_ml_feesched_core": "Fee schedule type filtering",
    "idx_ml_provider_feesched": "Provider fee schedule assignments",
    "idx_ml_claim_dates": "Insurance claim dates tracking",
    "idx_ml_claim_status": "Insurance claim status tracking",
    "idx_ml_claimproc_proc": "Insurance claim procedure tracking",
    "idx_ml_claimproc_patient": "Insurance claim patient tracking",
    "idx_ml_claimproc_payment": "Insurance claim payment tracking",
    "idx_ml_claimproc_dates": "Insurance claim dates tracking",
    "idx_ml_claimpayment": "Insurance claim payment tracking",
    "idx_ml_paysplit_proc": "Payment split procedure tracking",
    "idx_ml_payment_date": "Payment date tracking",
    "idx_ml_appt_patient": "Appointment patient tracking",
    "idx_ml_adj_proc": "Adjustment procedure tracking",
    "idx_ml_proccode_cat": "Procedure code category tracking"
} 