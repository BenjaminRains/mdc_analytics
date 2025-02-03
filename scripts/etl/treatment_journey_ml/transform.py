import pandas as pd
import logging
from typing import Dict, List
from .config import FEATURE_GROUPS, VALIDATION_RULES

def validate_features(df: pd.DataFrame, rules: Dict) -> None:
    """Validate features according to rules"""
    for feature, rule in rules.items():
        if feature not in df.columns:
            continue
            
        if 'min' in rule and df[feature].min() < rule['min']:
            logging.warning(f"{feature} contains values below minimum {rule['min']}")
            
        if 'max' in rule and df[feature].max() > rule['max']:
            logging.warning(f"{feature} contains values above maximum {rule['max']}")

def transform_data(df: pd.DataFrame) -> pd.DataFrame:
    """Apply transformations to the treatment journey dataset"""
    logging.info("Starting data transformation...")
    
    try:
        # 1. Data Validation
        validate_features(df, VALIDATION_RULES)
        
        # 2. Feature Engineering
        # Age buckets
        df['AgeGroup'] = pd.cut(
            df['PatientAge'],
            bins=[0, 18, 35, 50, 65, 120],
            labels=['0-18', '19-35', '36-50', '51-65', '65+']
        )
        
        # Treatment complexity
        df['TreatmentComplexity'] = df.apply(
            lambda x: 'Complex' if x['ProcFee'] > 1000 or x['TreatArea'] == 'Surgical' 
            else 'Simple',
            axis=1
        )
        
        # Insurance coverage ratio
        df['InsuranceCoverageRatio'] = (
            df['EstimatedInsurancePayment'] / df['ProcFee']
        ).fillna(0)
        
        # 3. Missing Value Handling
        for feature_group in FEATURE_GROUPS.values():
            for feature in feature_group:
                if feature in df.columns:
                    if df[feature].dtype in ['int64', 'float64']:
                        df[feature] = df[feature].fillna(0)
                    else:
                        df[feature] = df[feature].fillna('Unknown')
        
        # 4. Data Type Conversions
        date_columns = ['ProcDate', 'PaymentDate', 'ClaimDate']
        for col in date_columns:
            if col in df.columns:
                df[col] = pd.to_datetime(df[col])
        
        logging.info("Data transformation completed successfully")
        return df
        
    except Exception as e:
        logging.error(f"Data transformation failed: {str(e)}")
        raise

def calculate_metrics(df: pd.DataFrame) -> Dict[str, float]:
    """Calculate key metrics from transformed data"""
    metrics = {
        'total_procedures': len(df),
        'avg_procedure_fee': df['ProcFee'].mean(),
        'payment_rate_30d': (df['target_paid_30d'] == 1).mean(),
        'insurance_accuracy': df['InsurancePaymentAccuracy'].mean()
    }
    
    logging.info("Calculated metrics: %s", metrics)
    return metrics