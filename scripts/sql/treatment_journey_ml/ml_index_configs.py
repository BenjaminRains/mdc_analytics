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
    # Core Procedure Analysis Indexes
    "CREATE INDEX IF NOT EXISTS idx_ml_proc_core ON procedurelog (ProcDate, ProcStatus, ProcFee, CodeNum, ProvNum)",
    "CREATE INDEX IF NOT EXISTS idx_ml_proc_historical ON procedurelog (CodeNum, ProvNum, ProcDate, ProcFee)",
    
    # Fee Analysis
    "CREATE INDEX IF NOT EXISTS idx_ml_fee_core ON fee (CodeNum, Amount)",
    
    # Insurance Processing
    "CREATE INDEX IF NOT EXISTS idx_ml_claimproc_core ON claimproc (ProcNum, InsPayAmt, InsPayEst, Status, ClaimNum)",
    
    # Payment Analysis
    "CREATE INDEX IF NOT EXISTS idx_ml_paysplit_payment ON paysplit (ProcNum, PayNum, SplitAmt)",
    "CREATE INDEX IF NOT EXISTS idx_ml_payment_core ON payment (PayNum, PayDate)",
    "CREATE INDEX IF NOT EXISTS idx_ml_payment_window ON payment (PayDate)",
    
    # Adjustment Tracking
    "CREATE INDEX IF NOT EXISTS idx_ml_adj_core ON adjustment (ProcNum, DateEntry, AdjAmt)",
    "CREATE INDEX IF NOT EXISTS idx_ml_adj_type ON adjustment (ProcNum, AdjType)",
    
    # Supporting Lookups
    "CREATE INDEX IF NOT EXISTS idx_ml_proccode_lookup ON procedurecode (CodeNum, ProcCat)",
    "CREATE INDEX IF NOT EXISTS idx_ml_proccode_category ON procedurecode (CodeNum, ProcCode)",
    "CREATE INDEX IF NOT EXISTS idx_ml_patient_core ON patient (PatNum, Birthdate, Gender, HasIns)",
    "CREATE INDEX IF NOT EXISTS idx_ml_definition_lookup ON definition (DefNum, ItemName)",
    "CREATE INDEX IF NOT EXISTS idx_ml_claim_lookup ON claim (ClaimNum)",
    
    # Treatment Plan and History Analysis
    "CREATE INDEX IF NOT EXISTS idx_ml_proc_tp ON procedurelog (DateTP, ProcDate, ProcFee)",
    "CREATE INDEX IF NOT EXISTS idx_ml_proc_patient_hist ON procedurelog (PatNum, ProcDate, CodeNum, ProcStatus)",
    "CREATE INDEX IF NOT EXISTS idx_ml_proc_code_hist ON procedurelog (CodeNum, ProcDate, ProcStatus, ProcFee)",
    
    # For historical fee analysis
    "CREATE INDEX IF NOT EXISTS idx_ml_proc_fee_hist ON procedurelog (CodeNum, ProcDate, ProcFee, ProvNum)",
    
    # For appointment history
    "CREATE INDEX IF NOT EXISTS idx_ml_proc_appt_hist ON procedurelog (PatNum, ProcDate, CodeNum, ProcStatus)",
    
    # For acceptance rate calculations
    "CREATE INDEX IF NOT EXISTS idx_ml_proc_acceptance ON procedurelog (CodeNum, ProcDate, ProcStatus, DateTP, ProcFee)",
    
    # For payment tracking
    "CREATE INDEX IF NOT EXISTS idx_ml_payment_tracking ON payment (PayDate)",
    "CREATE INDEX IF NOT EXISTS idx_ml_paysplit_proc_pay ON paysplit (ProcNum, PayNum, SplitAmt)"
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

# System indexes that were accidentally dropped and need to be restored
SYSTEM_INDEXES = [
    "CREATE INDEX IDX_TEMPIMAGECONV_PATNUM ON tempimageconv (patnum)",
    "CREATE INDEX IDX_TEMPIMAGECONV2_FILENAME ON tempimageconv2 (filename)",
    "CREATE INDEX IDX_TEMPIMAGECONV2_ISDELETED ON tempimageconv2 (IsDeleted)",
    "CREATE INDEX IDX_TEMPIMAGECONV2_PATNUM ON tempimageconv2 (patnum)"
] 