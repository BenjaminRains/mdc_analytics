import logging
import os
from pathlib import Path
import pandas as pd

from scripts.etl.treatment_journey_ml.main import TreatmentJourneyETL, main

def setup_logging():
    """Configure logging with timestamp"""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    return logging.getLogger(__name__)

def get_output_dir() -> Path:
    """Get the output directory path"""
    etl_job = TreatmentJourneyETL(
        database_name="test_db",
        connection_type="local_mariadb"
    )
    return etl_job.output_dir

def test_mariadb_etl():
    """Test ETL with MariaDB connection"""
    logger = setup_logging()
    logger.info("Testing MariaDB ETL...")
    
    try:
        # Using the ETL class directly
        etl_job = TreatmentJourneyETL(
            database_name="opendental_analytics_opendentalbackup_01_03_2025",
            connection_type="local_mariadb"
        )
        
        # Run individual steps
        logger.info("Running ETL steps individually...")
        etl_job.setup()
        df = etl_job.extract()
        logger.info(f"Extracted {len(df):,} rows")
        
        df = etl_job.transform(df)
        logger.info(f"Transformed data shape: {df.shape}")
        
        output_path = etl_job.load(df)
        logger.info(f"Data saved to: {output_path}")
        
        # Verify output
        df_loaded = pd.read_parquet(output_path)
        logger.info(f"Successfully loaded output file with {len(df_loaded):,} rows")
        
        return output_path
        
    except Exception as e:
        logger.error(f"MariaDB ETL test failed: {str(e)}")
        raise

def test_mysql_etl():
    """Test ETL with MySQL connection"""
    logger = setup_logging()
    logger.info("Testing MySQL ETL...")
    
    try:
        # Using the convenience function
        output_path = main(
            database_name="mdc_analytics_opendentalbackup_01_03_2025",
            connection_type="local_mysql"
        )
        
        if output_path and output_path.exists():
            df = pd.read_parquet(output_path)
            logger.info(f"MySQL ETL completed successfully with {len(df):,} rows")
            return output_path
        else:
            raise ValueError("ETL completed but output file not found")
            
    except Exception as e:
        logger.error(f"MySQL ETL test failed: {str(e)}")
        raise

def verify_output(path: Path):
    """Verify the output data"""
    logger = setup_logging()
    
    try:
        df = pd.read_parquet(path)
        
        # Check data quality
        logger.info("\nData Quality Checks:")
        logger.info(f"Total rows: {len(df):,}")
        logger.info(f"Columns: {', '.join(df.columns)}")
        logger.info(f"Missing values: {df.isnull().sum().sum():,}")
        
        # Check key features
        required_columns = [
            'PatientAge', 'Gender', 'ProcCode', 
            'ProcFee', 'InsurancePaymentAccuracy'
        ]
        
        missing_columns = [col for col in required_columns if col not in df.columns]
        if missing_columns:
            raise ValueError(f"Missing required columns: {missing_columns}")
            
        logger.info("\nFeature Statistics:")
        logger.info(f"Age range: {df['PatientAge'].min()} - {df['PatientAge'].max()}")
        logger.info(f"Average procedure fee: ${df['ProcFee'].mean():.2f}")
        logger.info(f"Insurance accuracy: {df['InsurancePaymentAccuracy'].mean():.1f}%")
        
        return True
        
    except Exception as e:
        logger.error(f"Output verification failed: {str(e)}")
        raise

if __name__ == "__main__":
    logger = setup_logging()
    
    try:
        # Test MariaDB ETL
        logger.info("\n=== Testing MariaDB ETL ===")
        mariadb_output = test_mariadb_etl()
        verify_output(mariadb_output)
        
        # Test MySQL ETL
        logger.info("\n=== Testing MySQL ETL ===")
        mysql_output = test_mysql_etl()
        verify_output(mysql_output)
        
        logger.info("\nAll tests completed successfully!")
        
    except Exception as e:
        logger.error(f"\nTest suite failed: {str(e)}")
        raise 