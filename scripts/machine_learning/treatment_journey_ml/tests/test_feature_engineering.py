import pandas as pd
import numpy as np
import pytest
from ..feature_engineering import TreatmentJourneyFeatures
from src.connections.factory import ConnectionFactory

@pytest.fixture
def db_connection():
    """Create MariaDB connection for testing."""
    return ConnectionFactory.create_connection(
        connection_type='local_mariadb',
        database='opendental_analytics_opendentalbackup_01_03_2025'
    )

@pytest.fixture
def sample_data(db_connection):
    """Get real data from MariaDB for testing."""
    # Read the SQL query from file
    with open('scripts/sql/treatment_journey_ml/treatment_journey_ml.sql', 'r') as file:
        query = file.read()
    
    # Get the actual connection object
    with db_connection.get_connection() as conn:
        return pd.read_sql(query, conn)

class TestTreatmentJourneyFeatures:
    def test_timing_features(self, sample_data):
        """Test creation of timing features."""
        features = TreatmentJourneyFeatures()
        result = features.create_timing_features(sample_data)
        
        # Test urgent category identification
        assert result.loc[2, 'is_urgent_category']  # D7 should be urgent
        assert result.loc[4, 'is_urgent_category']  # D9 should be urgent
        assert not result.loc[0, 'is_urgent_category']  # D0 should not be urgent
        
        # Test year-end identification
        assert result.loc[1, 'is_year_end']  # November
        assert result.loc[3, 'is_year_end']  # December
        assert not result.loc[0, 'is_year_end']  # January

    def test_financial_features(self, sample_data):
        """Test creation of financial features."""
        features = TreatmentJourneyFeatures()
        result = features.create_financial_features(sample_data)
        
        # Test insurance coverage expectations
        assert result.loc[0, 'expected_high_coverage']  # D0 should have high coverage
        assert not result.loc[2, 'expected_high_coverage']  # D7 should not have high coverage
        
        # Test fee ratios
        assert abs(result.loc[0, 'fee_vs_historical'] - (100/90)) < 0.01
        assert abs(result.loc[0, 'fee_vs_ucr'] - (100/110)) < 0.01

    def test_patient_history_features(self, sample_data):
        """Test creation of patient history features."""
        features = TreatmentJourneyFeatures()
        result = features.create_patient_history_features(sample_data)
        
        # Test reliability score
        expected_reliability = 1 - (0 / (5 + 0 + 1))
        assert abs(result.loc[0, 'patient_reliability'] - expected_reliability) < 0.01

    def test_procedure_features(self, sample_data):
        """Test creation of procedure features."""
        features = TreatmentJourneyFeatures()
        result = features.create_procedure_features(sample_data)
        
        # Test provider procedure volume
        assert result.loc[0, 'provider_procedure_volume'] == 2  # ProvNum 201 has 2 procedures
        
        # Test complexity indicators
        assert result.loc[1, 'is_multi_visit']
        assert not result.loc[0, 'is_multi_visit']

    def test_missing_value_handling(self, sample_data):
        """Test handling of missing values."""
        sample_data.loc[0, 'Avg_Historical_Fee'] = np.nan
        sample_data.loc[1, 'UCR_Fee'] = np.nan
        
        features = TreatmentJourneyFeatures()
        result = features.engineer_features(sample_data)
        
        assert result['fee_vs_historical'].isna().sum() == 0
        assert result['fee_vs_ucr'].isna().sum() == 0 