import pandas as pd
import numpy as np
from typing import Dict, List

class TreatmentJourneyFeatures:
    """Feature engineering for treatment journey prediction."""
    
    def __init__(self):
        # Define category groupings based on CDT (Current Dental Terminology) codes
        self.urgent_categories = ['D7', 'D9']  # Oral surgery and emergency services
        self.scheduled_categories = ['D1', 'D4']  # Preventive and periodontal procedures
        self.high_coverage_categories = ['D0', 'D1', 'D4']  # Diagnostic, preventive, and periodontal procedures
        
        # Define procedure status mappings
        self.completed_status = 2
        self.planned_status = 1
        self.cancelled_codes = [626, 627]

    def create_timing_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """Create features related to procedure timing."""
        df = df.copy()
        
        # Category-based timing features
        df['is_urgent_category'] = df['proc_category'].isin(self.urgent_categories)
        df['is_scheduled_category'] = df['proc_category'].isin(self.scheduled_categories)
        
        # Normalize days from plan within each category
        df['days_from_plan_normalized'] = df.groupby('proc_category')['DaysFromPlanToProc'].transform(
            lambda x: (x - x.median()) / (x.std() + 1e-6)
        )
        
        # Same day treatment patterns
        df['category_same_day_rate'] = df.groupby('proc_category')['SameDayTreatment'].transform('mean')
        
        # Time of year seasonality
        df['month'] = pd.to_datetime(df['ProcDate']).dt.month
        df['is_year_end'] = df['month'].isin([11, 12])  # Insurance benefits expiring
        
        return df

    def create_financial_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """Create features related to financial aspects."""
        df = df.copy()
        
        # Insurance coverage expectations
        df['expected_high_coverage'] = df['proc_category'].isin(self.high_coverage_categories)
        
        # Fee analysis
        df['fee_vs_historical'] = df['OriginalFee'] / df['Avg_Historical_Fee']
        df['fee_vs_ucr'] = df['OriginalFee'] / df['UCR_Fee']
        
        # Insurance and adjustment patterns
        df['has_insurance_estimate'] = df['EstimatedInsurancePayment'] > 0
        df['expected_patient_portion'] = (
            df['OriginalFee'] - df['EstimatedInsurancePayment']
        ).clip(lower=0)
        
        return df

    def create_patient_history_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """Create features based on patient history."""
        df = df.copy()
        
        # Reliability score based on past appointments
        df['patient_reliability'] = 1 - (
            df['PriorMissedOrCancelledAppts'] / 
            (df['CompletedCount'] + df['PriorMissedOrCancelledAppts'] + 1)
        )
        
        # Category-specific patient history
        df['patient_category_completion_rate'] = (
            df.groupby(['PatNum', 'proc_category'])['CompletedCount']
            .transform('sum') / 
            (df.groupby(['PatNum', 'proc_category'])['PlannedCount'].transform('sum') + 1)
        )
        
        return df

    def create_procedure_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """Create features specific to procedure types."""
        df = df.copy()
        
        # Category success rates
        df['category_success_rate'] = df.groupby('proc_category')['target_journey_success'].transform('mean')
        
        # Provider experience with procedure
        df['provider_procedure_volume'] = df.groupby(['ProvNum', 'proc_category'])['ProcNum'].transform('count')
        
        # Procedure complexity indicators
        df['is_multi_visit'] = df['IsMultiVisit'] == 1
        df['has_prerequisites'] = df['DaysFromPlanToProc'] > 0
        
        return df

    def engineer_features(self, df: pd.DataFrame) -> pd.DataFrame:
        """Main feature engineering pipeline."""
        df = df.copy()
        
        # Create base features
        df = self.create_timing_features(df)
        df = self.create_financial_features(df)
        df = self.create_patient_history_features(df)
        df = self.create_procedure_features(df)
        
        # Handle missing values
        df = df.fillna({
            'fee_vs_historical': 1.0,
            'fee_vs_ucr': 1.0,
            'patient_category_completion_rate': 0.0,
            'provider_procedure_volume': 0
        })
        
        return df

    def get_feature_names(self) -> List[str]:
        """Return list of engineered feature names."""
        return [
            'is_urgent_category',
            'is_scheduled_category',
            'days_from_plan_normalized',
            'category_same_day_rate',
            'is_year_end',
            'expected_high_coverage',
            'fee_vs_historical',
            'fee_vs_ucr',
            'has_insurance_estimate',
            'expected_patient_portion',
            'patient_reliability',
            'patient_category_completion_rate',
            'category_success_rate',
            'provider_procedure_volume',
            'is_multi_visit',
            'has_prerequisites'
        ]

"""
Treatment Journey Feature Engineering

This module implements feature engineering for predicting treatment journey success.
Features are organized into four main categories:

1. Timing Features
   - is_urgent_category: Identifies procedures that typically require immediate attention (D7, D9)
     Importance: High - Urgent procedures have different completion patterns
   - is_scheduled_category: Identifies procedures typically scheduled in advance (D1, D4)
     Importance: Medium - Helps identify standard scheduling patterns
   - days_from_plan_normalized: Normalized wait time within each procedure category
     Importance: High - Long delays may indicate patient hesitation
   - is_year_end: Captures insurance benefit expiration effects
     Importance: Medium - Patients often complete treatment before benefits expire

2. Financial Features
   - expected_high_coverage: Identifies procedures with typically high insurance coverage
     Importance: High - Financial burden affects completion rates
   - fee_vs_historical: Compares fee to historical averages
     Importance: Medium - Unusual fees may indicate complexity
   - fee_vs_ucr: Compares fee to usual and customary rates
     Importance: Medium - Fee competitiveness affects acceptance
   - expected_patient_portion: Estimated out-of-pocket cost
     Importance: High - Direct indicator of patient financial burden

3. Patient History Features
   - patient_reliability: Score based on past appointment adherence
     Importance: Very High - Strong predictor of future behavior
   - patient_category_completion_rate: Category-specific completion history
     Importance: High - Patients may have category-specific preferences

4. Procedure Features
   - category_success_rate: Historical success rate for procedure category
     Importance: High - Baseline predictor for procedure type
   - provider_procedure_volume: Provider's experience with procedure
     Importance: Medium - Experience may affect outcomes
   - is_multi_visit: Identifies procedures requiring multiple visits
     Importance: Medium - Complexity indicator
   - has_prerequisites: Identifies procedures with preparation requirements
     Importance: Medium - Additional steps may affect completion

Feature Selection Rationale:
- Focus on predictive factors identified in dental practice research
- Emphasis on patient history and financial indicators
- Inclusion of provider experience and procedure complexity
- Consideration of timing and scheduling patterns

Usage:
    features = TreatmentJourneyFeatures()
    df_with_features = features.engineer_features(df) 
"""