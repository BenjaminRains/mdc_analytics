import pandas as pd
from src.connections.factory import ConnectionFactory
from src.file_paths import DataPaths
from pathlib import Path
from typing import List, Dict
import logging

def read_sql_file(path: Path) -> str:
    """Read SQL from file"""
    with open(path, 'r') as f:
        return f.read()

def setup_indexes(conn, indexes: Dict[str, List[str]]) -> None:
    """Setup required indexes"""
    cursor = conn.cursor()
    for table, table_indexes in indexes.items():
        for idx in table_indexes:
            try:
                cursor.execute(f"CREATE INDEX IF NOT EXISTS {idx} ON {table}")
            except Exception as e:
                logging.warning(f"Failed to create index {idx}: {e}")

def extract_data(database_name: str, query_path: Path, indexes: Dict[str, List[str]]) -> pd.DataFrame:
    """Extract data using SQL query"""
    conn = ConnectionFactory.create_connection('local_mariadb', database_name)
    
    try:
        # Setup indexes
        setup_indexes(conn, indexes)
        
        # Read and execute query
        query = read_sql_file(query_path)
        return pd.read_sql(query, conn.get_connection())
    finally:
        conn.close()