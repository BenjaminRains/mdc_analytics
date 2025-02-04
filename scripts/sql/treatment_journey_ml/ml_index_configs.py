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

# Documentation for ML-specific indexes
INDEX_DOCUMENTATION = {
    "idx_pat_ml_core": "Patient demographics for ML features",
    "idx_pat_ml_insurance": "Insurance status tracking",
    "idx_proc_ml_core": "Core procedure data for ML",
    "idx_proc_ml_codes": "Procedure code analysis",
    "idx_claim_ml_core": "Insurance claim tracking",
    "idx_payment_ml_core": "Payment history analysis",
    "idx_famaging_ml_core": "Family aging balances"
} 