"""Treatment Journey ML Index Configurations"""

TREATMENT_JOURNEY_INDEXES = [
    # Patient demographics
    "CREATE INDEX idx_pat_ml_core ON patient (PatNum, PatStatus, Gender, BirthDate)",
    "CREATE INDEX idx_pat_ml_insurance ON patient (HasIns, InsCarrier)",
    
    # Procedure tracking
    "CREATE INDEX idx_proc_ml_core ON procedurelog (PatNum, ProcDate, ProcStatus, ProcFee)",
    "CREATE INDEX idx_proc_ml_codes ON procedurelog (CodeNum, ProcStatus, ProcFee)",
    
    # Insurance claims
    "CREATE INDEX idx_claim_ml_core ON claim (PatNum, DateService, ClaimStatus)",
    "CREATE INDEX idx_claimproc_ml_tracking ON claimproc (ProcNum, Status, InsPayAmt, WriteOff)",
    
    # Payment tracking
    "CREATE INDEX idx_payment_ml_core ON payment (PatNum, PayDate, PayAmt, PayType)",
    "CREATE INDEX idx_famaging_ml_core ON famaging (PatNum, BalTotal, InsEst)"
] 