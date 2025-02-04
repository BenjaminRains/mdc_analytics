import logging
from pathlib import Path
from typing import List, Dict, Union
import mysql.connector
from src.db_config import connect_to_mariadb

# Import base indexes
from scripts.sql.database_setup.base_index_configs import BASE_INDEXES

# Optional import for treatment journey indexes
try:
    from scripts.sql.treatment_journey_ml.ml_index_configs import TREATMENT_JOURNEY_INDEXES
except ImportError:
    TREATMENT_JOURNEY_INDEXES = []

class IndexManager:
    """Manages database indexes for ETL jobs and base configuration"""
    
    def __init__(self, database_name: str):
        self.database_name = database_name
        self.logger = logging.getLogger(self.__class__.__name__)
    
    def read_index_file(self, index_path: Path) -> List[str]:
        """Read index definitions from SQL file"""
        if not index_path.exists():
            raise FileNotFoundError(f"Index file not found: {index_path}")
            
        with open(index_path, 'r') as f:
            content = f.read()
            # Split on CREATE INDEX, filter empty strings, and add CREATE INDEX back
            indexes = [f"CREATE INDEX {stmt.strip()}" 
                      for stmt in content.split('CREATE INDEX')
                      if stmt.strip()]
            return indexes
    
    def drop_custom_indexes(self, cursor, table: str) -> None:
        """Drops all indexes that start with 'idx_' from a table"""
        try:
            cursor.execute(f"SHOW INDEX FROM {table}")
            indexes = cursor.fetchall()
            
            # Get list of custom index names (starting with 'idx_')
            custom_indexes = [idx[2] for idx in indexes if idx[2].startswith('idx_')]
            
            for index_name in custom_indexes:
                try:
                    cursor.execute(f"DROP INDEX {index_name} ON {table}")
                    self.logger.info(f"Dropped index {index_name} from {table}")
                except mysql.connector.Error as err:
                    self.logger.warning(f"Error dropping index {index_name}: {err}")
                    
        except mysql.connector.Error as err:
            self.logger.error(f"Error getting indexes for {table}: {err}")
    
    def setup_indexes(self, indexes: Union[Path, List[str]]) -> None:
        """Sets up provided index statements or reads from file"""
        self.logger.info(f"Setting up indexes for {self.database_name}")
        
        try:
            # If indexes is a Path, read the file
            if isinstance(indexes, Path):
                index_statements = self.read_index_file(indexes)
            else:
                index_statements = indexes
            
            conn = connect_to_mariadb()
            cursor = conn.cursor()
            
            # Select the database
            cursor.execute(f"USE {self.database_name}")
            
            # Create indexes
            for index in index_statements:
                try:
                    cursor.execute(index)
                    conn.commit()
                    self.logger.info(f"Created index: {index}")
                except mysql.connector.Error as err:
                    if err.errno == 1061:  # Duplicate key name
                        self.logger.info(f"Index already exists: {index}")
                    else:
                        self.logger.warning(f"Error creating index: {err}")
        
        except Exception as e:
            self.logger.error(f"Error during index setup: {str(e)}")
            raise
        
        finally:
            if 'cursor' in locals():
                cursor.close()
            if 'conn' in locals() and conn.is_connected():
                conn.close()
            self.logger.info("Index setup complete")
    
    def setup_indexes_from_file(self, index_path: Path) -> None:
        """Sets up indexes from SQL file"""
        indexes = self.read_index_file(index_path)
        self.setup_indexes(indexes)
    
    def setup_base_indexes(self) -> None:
        """Setup comprehensive base indexes for the database"""
        self.logger.info("Setting up base indexes...")
        self.setup_indexes(BASE_INDEXES)

    def setup_treatment_journey_indexes(self) -> None:
        """Setup indexes specific to treatment journey dataset"""
        self.setup_indexes(TREATMENT_JOURNEY_INDEXES)

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Setup database indexes')
    parser.add_argument('database_name', help='Name of the database')
    parser.add_argument('--index-file', type=Path, help='Path to index SQL file')
    parser.add_argument('--dataset', choices=['base', 'treatment_journey'], 
                       help='Predefined dataset indexes')
    args = parser.parse_args()
    
    # Configure logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    # Setup indexes
    manager = IndexManager(args.database_name)
    if args.index_file:
        manager.setup_indexes_from_file(args.index_file)
    elif args.dataset == 'base':
        manager.setup_base_indexes()
    elif args.dataset == 'treatment_journey':
        manager.setup_treatment_journey_indexes()
    else:
        parser.error("Either --index-file or --dataset must be specified") 
    