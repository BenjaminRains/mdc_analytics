from pathlib import Path
from typing import Dict, List, Union

# Feature groups for documentation and validation
FEATURE_GROUPS: Dict[str, List[str]] = {
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
VALIDATION_RULES: Dict[str, Dict[str, int]] = {
    'PatientAge': {'min': 0, 'max': 120},
    'ProcFee': {'min': 0},
    'InsurancePaymentAccuracy': {'min': 0, 'max': 100}
}