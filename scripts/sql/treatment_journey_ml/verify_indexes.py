"""
Remove deprecated idx_ indexes
"""

import logging
from scripts.base.index_manager import IndexManager
from src.connections.factory import ConnectionFactory
import mysql.connector

def main():
    # Configure logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    logger = logging.getLogger(__name__)
    
    # Initialize index manager with correct database name
    database_name = "opendental_analytics_opendentalbackup_01_03_2025"
    manager = IndexManager(database_name)
    
    try:
        # Connect to database
        conn = manager.connection.connect()
        cursor = conn.cursor()
        
        # Tables that might have deprecated indexes
        tables = [
            'procedurelog', 'patient', 'fee', 'feesched', 'provider',
            'claim', 'claimproc', 'payment', 'appointment', 'adjustment',
            'procedurecode', 'claimpayment', 'paysplit',
            'commlog', 'famaging'
        ]
        
        # Drop only lowercase idx_ indexes
        logger.info("Starting removal of deprecated 'idx_' indexes...")
        for table in tables:
            try:
                cursor.execute(f"SHOW INDEX FROM {table}")
                indexes = cursor.fetchall()
                
                # Find indexes that start with lowercase 'idx_' only
                deprecated_indexes = [
                    idx[2] for idx in indexes 
                    if idx[2].startswith('idx_') and not idx[2].startswith('IDX_')
                ]
                
                if deprecated_indexes:
                    logger.info(f"\nFound {len(deprecated_indexes)} deprecated indexes in {table}:")
                    for index_name in deprecated_indexes:
                        try:
                            # Check index metadata before attempting to drop
                            cursor.execute(f"""
                                SELECT 
                                    INDEX_NAME,
                                    NON_UNIQUE,  -- 0 for UNIQUE indexes
                                    COLUMN_NAME,
                                    INDEX_COMMENT
                                FROM INFORMATION_SCHEMA.STATISTICS 
                                WHERE TABLE_SCHEMA = DATABASE()
                                AND TABLE_NAME = '{table}'
                                AND INDEX_NAME = '{index_name}'
                                AND INDEX_NAME LIKE 'idx_%'  -- lowercase only
                                -- Exclude primary keys
                                AND INDEX_NAME != 'PRIMARY'
                                -- Exclude foreign key constraints (they start with specific prefixes)
                                AND NOT EXISTS (
                                    SELECT 1 
                                    FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE k 
                                    WHERE k.TABLE_SCHEMA = DATABASE()
                                    AND k.TABLE_NAME = '{table}'
                                    AND k.COLUMN_NAME = STATISTICS.COLUMN_NAME
                                    AND k.REFERENCED_TABLE_NAME IS NOT NULL
                                )
                            """)
                            
                            index_info = cursor.fetchall()
                            if not index_info:
                                logger.info(f"Skipping {index_name} - appears to be a system index or constraint")
                                continue
                                
                            # Safe to drop - this is a custom index
                            cursor.execute(f"DROP INDEX {index_name} ON {table}")
                            logger.info(f"Successfully dropped custom index: {index_name}")
                            
                        except mysql.connector.Error as err:
                            logger.error(f"Error checking/dropping {index_name} on {table}: {err.errno} - {err.msg}")
                else:
                    logger.info(f"\nNo deprecated indexes found in {table}")
                    
            except Exception as e:
                logger.error(f"Error processing table {table}: {str(e)}")
                continue
                
        logger.info("\nIndex removal complete")
        
    except Exception as e:
        logger.error(f"Error during index removal: {str(e)}")
        raise
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    main() 