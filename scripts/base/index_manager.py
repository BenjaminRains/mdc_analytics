import logging
from pathlib import Path
from typing import List, Dict, Union
import mysql.connector
from src.connections.factory import ConnectionFactory

# Optional import for treatment journey indexes
try:
    from scripts.sql.treatment_journey_ml.ml_index_configs import TREATMENT_JOURNEY_INDEXES
except ImportError:
    TREATMENT_JOURNEY_INDEXES = []

class IndexManager:
    """Manages database indexes for ETL jobs and ML configuration"""
    
    def __init__(self, database_name: str):
        self.database_name = database_name
        self.logger = logging.getLogger(self.__class__.__name__)
        # Create connection factory instance
        self.connection = ConnectionFactory.create_connection(
            connection_type='local_mariadb',
            database=database_name
        )
    
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
        """Drops custom indexes (those that start with 'idx_ml_' or lowercase 'idx_')"""
        try:
            cursor.execute(f"SHOW INDEX FROM {table}")
            indexes = cursor.fetchall()
            
            # Get list of custom index names (ML indexes and lowercase idx_)
            custom_indexes = [
                idx[2] for idx in indexes 
                if (idx[2].startswith('idx_ml_') or  # ML indexes
                    (idx[2].startswith('idx_') and   # Lowercase indexes
                     not idx[2].startswith('IDX_'))) # Exclude system indexes
            ]
            
            if custom_indexes:
                self.logger.info(f"Found {len(custom_indexes)} custom indexes in {table}")
                for index_name in custom_indexes:
                    try:
                        cursor.execute(f"DROP INDEX {index_name} ON {table}")
                        self.logger.info(f"Dropped custom index {index_name} from {table}")
                    except mysql.connector.Error as err:
                        self.logger.warning(f"Error dropping custom index {index_name}: {err}")
            else:
                self.logger.info(f"No custom indexes found in {table}")
                    
        except mysql.connector.Error as err:
            self.logger.error(f"Error getting indexes for {table}: {err}")

    def is_ml_index(self, index_name: str) -> bool:
        """Check if an index is an ML-specific index"""
        return index_name.lower().startswith('idx_ml_')
    
    def setup_indexes(self, indexes: Union[Path, List[str]]) -> None:
        """Sets up provided index statements or reads from file"""
        self.logger.info(f"Setting up indexes for {self.database_name}")
        
        try:
            # If indexes is a Path, read the file
            if isinstance(indexes, Path):
                index_statements = self.read_index_file(indexes)
            else:
                index_statements = indexes
            
            conn = self.connection.connect()
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
            if 'conn' in locals():
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

    def show_table_indexes(self, table_name: str) -> None:
        """Display all indexes for a given table"""
        try:
            conn = self.connection.connect()
            cursor = conn.cursor()
            
            cursor.execute(f"SHOW INDEX FROM {table_name}")
            indexes = cursor.fetchall()
            
            self.logger.info(f"\nIndexes for table {table_name}:")
            for idx in indexes:
                self.logger.info(f"Index: {idx[2]}, Columns: {idx[4]}")
                
        except mysql.connector.Error as err:
            self.logger.error(f"Error showing indexes: {err}")
        finally:
            if 'cursor' in locals():
                cursor.close()
            if 'conn' in locals():
                conn.close()

    def drop_deprecated_indexes(self, cursor, table: str) -> None:
        """Drops deprecated indexes (those that start with lowercase 'idx_')"""
        try:
            cursor.execute(f"SHOW INDEX FROM {table}")
            indexes = cursor.fetchall()
            
            # Get list of deprecated index names (lowercase idx_)
            # System indexes use uppercase IDX_ so they won't be affected
            deprecated_indexes = [
                idx[2] for idx in indexes 
                if (idx[2].startswith('idx_') and 
                    not idx[2].startswith('idx_ml_') and
                    not idx[2].startswith('IDX_'))  # Exclude system indexes
            ]
            
            if deprecated_indexes:
                self.logger.info(f"Found {len(deprecated_indexes)} deprecated indexes in {table}")
                for index_name in deprecated_indexes:
                    try:
                        cursor.execute(f"DROP INDEX {index_name} ON {table}")
                        self.logger.info(f"Dropped deprecated index {index_name} from {table}")
                    except mysql.connector.Error as err:
                        self.logger.warning(f"Error dropping deprecated index {index_name}: {err}")
            else:
                self.logger.info(f"No deprecated indexes found in {table}")
                    
        except mysql.connector.Error as err:
            self.logger.error(f"Error getting indexes for {table}: {err}")

    def setup_treatment_journey_indexes(self) -> None:
        """Setup indexes specific to treatment journey dataset"""
        try:
            # Use the connection from factory
            conn = self.connection.connect()
            cursor = conn.cursor()
            
            # Get list of tables that need ML indexes
            tables = ['procedurelog', 'patient', 'fee', 'feesched', 'provider', 
                     'claim', 'claimproc', 'payment', 'appointment', 'adjustment',
                     'procedurecode', 'claimpayment', 'paysplit']
            
            # First drop deprecated indexes
            self.logger.info("Dropping deprecated indexes...")
            for table in tables:
                self.drop_deprecated_indexes(cursor, table)
            
            # Then drop any existing ML indexes
            self.logger.info("Dropping existing ML indexes...")
            for table in tables:
                self.drop_custom_indexes(cursor, table)
            
            # Create new ML indexes
            self.logger.info("Creating new ML indexes...")
            for index in TREATMENT_JOURNEY_INDEXES:
                try:
                    cursor.execute(index)
                    conn.commit()
                    self.logger.info(f"Created index: {index}")
                except mysql.connector.Error as err:
                    if err.errno == 1061:  # Duplicate key name
                        self.logger.info(f"Index already exists: {index}")
                    else:
                        self.logger.error(f"Error creating index: {err}")
                        
            # Verify final index state
            self.logger.info("\nFinal index state:")
            for table in tables:
                self.show_table_indexes(table)
                
        except Exception as e:
            self.logger.error(f"Error during index setup: {str(e)}")
            raise
        finally:
            if 'cursor' in locals():
                cursor.close()
            if 'conn' in locals():
                conn.close()

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
    