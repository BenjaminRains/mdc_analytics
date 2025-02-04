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
from scripts.sql.treatment_journey_ml.ml_index_configs import TREATMENT_JOURNEY_INDEXES

def setup_logging():
    """Configure logging for index updates"""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    return logging.getLogger(__name__)

def extract_index_info(index_sql: str) -> tuple[str, str]:
    """Extract table name and index name from CREATE INDEX statement"""
    # Match pattern: CREATE INDEX [IF NOT EXISTS] idx_ml_NAME ON TABLE
    parts = index_sql.upper().split()
    try:
        table_idx = parts.index('ON') + 1
        table_name = parts[table_idx].strip()
        
        # Get index name after idx_ml_
        index_parts = [p for p in parts if p.startswith('IDX_ML_')]
        if not index_parts:
            raise ValueError("No idx_ml_ index name found")
        index_name = index_parts[0].split('IDX_ML_')[1]
        
        return table_name, index_name
    except (IndexError, ValueError) as e:
        raise ValueError(f"Invalid index SQL format: {e}")

def update_treatment_journey_indexes(database_name: str, logger: logging.Logger):
    """Update indexes specific to treatment journey analysis"""
    try:
        logger.info(f"Initializing index update for database: {database_name}")
        
        # Count total indexes to be created
        total_indexes = len(TREATMENT_JOURNEY_INDEXES)
        logger.info(f"Found {total_indexes} indexes to create")
        
        # Initialize counters
        successful_creates = 0
        failed_creates = 0
        already_exists = 0
        
        # Initialize index manager
        manager = IndexManager(database_name)
        
        # Update treatment journey indexes
        logger.info("Starting treatment journey index creation...")
        
        # Create connection for verification
        conn = manager.connection.connect()
        cursor = conn.cursor()
        
        for index_sql in TREATMENT_JOURNEY_INDEXES:
            try:
                table_name, index_name = extract_index_info(index_sql)
                
                # Check if index already exists
                cursor.execute(f"""
                    SELECT COUNT(*) 
                    FROM INFORMATION_SCHEMA.STATISTICS 
                    WHERE table_schema = DATABASE()
                    AND table_name = '{table_name}'
                    AND index_name = 'idx_ml_{index_name}'
                """)
                if cursor.fetchone()[0] > 0:
                    logger.info(f"Index idx_ml_{index_name} already exists on {table_name}")
                    already_exists += 1
                    continue
                
                # Create the index
                cursor.execute(index_sql)
                successful_creates += 1
                logger.info(f"Successfully created index idx_ml_{index_name} on {table_name}")
                
            except Exception as e:
                failed_creates += 1
                logger.error(f"Failed to create index: {str(e)}")
        
        # Final verification
        logger.info("\nIndex Creation Summary:")
        logger.info(f"Total indexes in queue: {total_indexes}")
        logger.info(f"Successfully created: {successful_creates}")
        logger.info(f"Already existed: {already_exists}")
        logger.info(f"Failed to create: {failed_creates}")
        
        if failed_creates == 0:
            logger.info("\nAll indexes were created successfully!")
        else:
            logger.warning(f"\nWarning: {failed_creates} indexes failed to create")
        
    except Exception as e:
        logger.error(f"Error updating indexes: {str(e)}")
        raise
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()

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