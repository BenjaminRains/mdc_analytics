"""
Update Treatment Journey ML Indexes

This script updates the indexes needed for the treatment journey ML dataset
without running the full ETL job.

Usage:
    python update_indexes.py database_name
"""

import logging
import sys
from pathlib import Path
from scripts.base.index_manager import IndexManager

def setup_logging():
    """Configure logging for index updates"""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    return logging.getLogger(__name__)

def update_treatment_journey_indexes(database_name: str, logger: logging.Logger):
    """Update indexes specific to treatment journey analysis"""
    try:
        logger.info(f"Initializing index update for database: {database_name}")
        
        # Initialize index manager
        manager = IndexManager(database_name)
        
        # Update treatment journey indexes
        logger.info("Updating treatment journey indexes...")
        manager.setup_treatment_journey_indexes()
        
        logger.info("Index update completed successfully")
        
    except Exception as e:
        logger.error(f"Error updating indexes: {str(e)}")
        raise

if __name__ == "__main__":
    # Setup argument parsing
    if len(sys.argv) != 2:
        print("Usage: python update_indexes.py database_name")
        sys.exit(1)
    
    database_name = sys.argv[1]
    logger = setup_logging()
    
    try:
        update_treatment_journey_indexes(database_name, logger)
    except Exception as e:
        logger.error(f"Failed to update indexes: {str(e)}")
        sys.exit(1) 