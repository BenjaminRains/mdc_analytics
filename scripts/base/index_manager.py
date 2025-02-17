"""
Index Manager for ML Pipeline

A comprehensive tool for managing database indexes:
- Create new indexes
- Remove existing indexes
- Update indexes
- Monitor index usage

Usage:
    python index_manager.py database_name [--action {create,drop,update,show,show-custom,restore-system}] [--table table_name]
"""

import logging
import sys
import argparse
from typing import List, Optional
from scripts.sql.treatment_journey_ml.ml_index_configs import TREATMENT_JOURNEY_INDEXES, SYSTEM_INDEXES
from src.connections.factory import ConnectionFactory, VALID_DATABASES

class IndexManager:
    """Manages database indexes for ML pipeline"""
    
    def __init__(self, database_name: str):
        if database_name not in VALID_DATABASES:
            raise ValueError(f"Invalid database name. Must be one of: {', '.join(VALID_DATABASES)}")
        self.database_name = database_name
        self.logger = self._setup_logging()
        self.connection = self._create_connection()
    
    def _setup_logging(self) -> logging.Logger:
        """Configure logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        return logging.getLogger(self.__class__.__name__)
    
    def _create_connection(self):
        """Create MariaDB connection using factory"""
        try:
            conn = ConnectionFactory.create_connection(
                connection_type='local_mariadb',
                database=self.database_name,
                use_root=True  # Need root privileges for index management
            )
            return conn.connect()
        except Exception as err:
            self.logger.error(f"Failed to connect to database: {err}")
            raise
    
    def show_indexes(self, table_name: Optional[str] = None) -> None:
        """Display existing indexes"""
        try:
            cursor = self.connection.cursor()
            
            query = """
                SELECT 
                    TABLE_NAME,
                    INDEX_NAME,
                    GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) as COLUMNS
                FROM INFORMATION_SCHEMA.STATISTICS 
                WHERE TABLE_SCHEMA = DATABASE()
            """
            
            if table_name:
                query += f" AND TABLE_NAME = '{table_name}'"
            
            query += " GROUP BY TABLE_NAME, INDEX_NAME ORDER BY TABLE_NAME, INDEX_NAME"
            
            cursor.execute(query)
            indexes = cursor.fetchall()
            
            for table, index, columns in indexes:
                self.logger.info(f"Table: {table}, Index: {index}, Columns: {columns}")
                
        except Exception as err:
            self.logger.error(f"Error showing indexes: {err}")
        finally:
            if 'cursor' in locals():
                cursor.close()
    
    def drop_indexes(self, pattern: str = 'idx_%') -> None:
        """Drop indexes matching pattern (only lowercase idx_ prefixes)"""
        try:
            cursor = self.connection.cursor()
            
            # Find all matching indexes - using BINARY for case-sensitive matching
            cursor.execute("""
                SELECT 
                    TABLE_NAME,
                    INDEX_NAME 
                FROM INFORMATION_SCHEMA.STATISTICS 
                WHERE TABLE_SCHEMA = DATABASE()
                AND BINARY INDEX_NAME LIKE 'idx_%'  -- Case-sensitive match
                GROUP BY TABLE_NAME, INDEX_NAME
            """)
            
            existing_indexes = cursor.fetchall()
            
            # Drop each index
            for table_name, index_name in existing_indexes:
                try:
                    self.logger.info(f"Dropping index {index_name} from {table_name}")
                    cursor.execute(f"DROP INDEX {index_name} ON {table_name}")
                except Exception as err:
                    self.logger.error(f"Failed to drop index {index_name}: {err}")
            
        finally:
            if 'cursor' in locals():
                cursor.close()
    
    def create_indexes(self, indexes: List[str]) -> None:
        """Create new indexes"""
        try:
            cursor = self.connection.cursor()
            
            for index_sql in indexes:
                try:
                    self.logger.info(f"Creating index: {index_sql}")
                    cursor.execute(index_sql)
                except Exception as err:
                    if err.errno == 1061:  # Duplicate key name
                        self.logger.info(f"Index already exists: {index_sql}")
                    else:
                        self.logger.error(f"Failed to create index: {err}")
            
        finally:
            if 'cursor' in locals():
                cursor.close()
    
    def restore_system_indexes(self) -> None:
        """Restore system indexes that were accidentally dropped"""
        self.logger.info("Restoring system indexes...")
        self.create_indexes(SYSTEM_INDEXES)
        self.logger.info("System indexes restored")

    def show_custom_indexes(self, table_name: Optional[str] = None) -> None:
        """Display only custom indexes (lowercase idx_ prefix)"""
        try:
            cursor = self.connection.cursor()
            
            query = """
                SELECT 
                    TABLE_NAME,
                    INDEX_NAME,
                    GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) as COLUMNS
                FROM INFORMATION_SCHEMA.STATISTICS 
                WHERE TABLE_SCHEMA = DATABASE()
                AND BINARY INDEX_NAME LIKE 'idx_%'  -- Case-sensitive match for lowercase
            """
            
            if table_name:
                query += f" AND TABLE_NAME = '{table_name}'"
            
            query += " GROUP BY TABLE_NAME, INDEX_NAME ORDER BY TABLE_NAME, INDEX_NAME"
            
            cursor.execute(query)
            indexes = cursor.fetchall()
            
            if not indexes:
                self.logger.info("No custom indexes found")
                return
            
            self.logger.info("Custom indexes (idx_ prefix):")
            for table, index, columns in indexes:
                self.logger.info(f"  - Table: {table}, Index: {index}, Columns: {columns}")
                
        except Exception as err:
            self.logger.error(f"Error showing custom indexes: {err}")
        finally:
            if 'cursor' in locals():
                cursor.close()

def main():
    parser = argparse.ArgumentParser(description='Manage database indexes for ML pipeline')
    parser.add_argument('database_name', help=f'Name of the database. Valid options: {", ".join(VALID_DATABASES)}')
    parser.add_argument('--action', 
                       choices=['create', 'drop', 'show', 'show-custom', 'restore-system'],
                       default='show', 
                       help='Action to perform')
    parser.add_argument('--table', help='Specific table to show indexes for')
    
    args = parser.parse_args()
    
    try:
        manager = IndexManager(args.database_name)
        
        if args.action == 'show':
            manager.show_indexes(args.table)
        elif args.action == 'show-custom':
            manager.show_custom_indexes(args.table)
        elif args.action == 'drop':
            manager.drop_indexes()
        elif args.action == 'create':
            manager.create_indexes(TREATMENT_JOURNEY_INDEXES)
        elif args.action == 'restore-system':
            manager.restore_system_indexes()
            
    except Exception as e:
        logging.error(f"Error during index management: {str(e)}")
        sys.exit(1)
    finally:
        if 'manager' in locals() and hasattr(manager, 'connection'):
            manager.connection.close()

if __name__ == "__main__":
    main() 