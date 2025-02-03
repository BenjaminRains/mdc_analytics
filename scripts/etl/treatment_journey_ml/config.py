from pathlib import Path
from src.file_paths import DataPaths

# Initialize DataPaths
data_paths = DataPaths()

# Output directories
OUTPUT_DIR = data_paths.base_dir / "processed" / "treatment_journey"

# Feature groups for documentation and validation
FEATURE_GROUPS = {
    'patient': ['PatientAge', 'Gender', 'HasInsurance'],
    'procedure': ['ProcCode', 'ProcCat', 'TreatArea'],
    'insurance': [
        'EstimatedInsurancePayment', 
        'ActualInsurancePayment',
        'InsurancePaymentAccuracy',
        'ClaimStatus'
    ],
    'payment': ['target_paid_30d', 'target_fully_paid']
}

# Data validation rules
VALIDATION_RULES = {
    'PatientAge': {'min': 0, 'max': 120},
    'ProcFee': {'min': 0},
    'InsurancePaymentAccuracy': {'min': 0, 'max': 100}
}