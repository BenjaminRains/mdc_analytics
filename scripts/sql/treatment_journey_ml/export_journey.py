"""
Export Treatment Journey Query Results to Parquet

This script:
1. Executes the treatment journey SQL query
2. Streams results to a pandas DataFrame
3. Saves the data in Parquet format
"""

import pandas as pd
from pathlib import Path
from src.connections.factory import ConnectionFactory
import logging

def setup_logging():
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    return logging.getLogger(__name__)

def read_sql_file():
    """Read the treatment journey SQL query from file"""
    sql_path = Path(__file__).parent / 'treatment_journey_ml.sql'
    with open(sql_path, 'r') as f:
        return f.read()

def export_to_parquet(database_name: str, output_path: str = None):
    """
    Export query results to parquet file
    
    Args:
        database_name: Name of the database to query
        output_path: Path to save parquet file (optional)
    """
    logger = setup_logging()
    
    if output_path is None:
        output_path = Path(__file__).parent / f'treatment_journey_{database_name}.parquet'
    
    try:
        # Create database connection
        conn = ConnectionFactory.create_connection(
            connection_type='local_mariadb',
            database=database_name
        ).connect()
        
        logger.info("Reading SQL query...")
        query = read_sql_file()
        
        logger.info("Executing query and loading to DataFrame...")
        # Add error handling for division by zero
        query = query.replace('/ COUNT', '/ NULLIF(COUNT')
        query = query.replace('/ NULLIF', ', 0)')
        
        df = pd.read_sql(query, conn)
        
        logger.info(f"Query returned {len(df)} rows")
        
        logger.info(f"Saving to {output_path}")
        df.to_parquet(output_path, index=False)
        
        logger.info("Export complete!")
        logger.info(f"DataFrame shape: {df.shape}")
        logger.info(f"Memory usage: {df.memory_usage().sum() / 1024**2:.2f} MB")
        
    except Exception as e:
        logger.error(f"Error during export: {str(e)}")
        raise
    finally:
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Export treatment journey data to parquet')
    parser.add_argument('database_name', help='Name of the database to query')
    parser.add_argument('--output', help='Output path for parquet file (optional)')
    
    args = parser.parse_args()
    
    export_to_parquet(args.database_name, args.output) 