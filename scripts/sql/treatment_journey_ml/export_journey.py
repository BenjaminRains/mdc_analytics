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
from tqdm import tqdm
import pyarrow as pa
import pyarrow.parquet as pq

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

def export_to_parquet(database_name: str, output_path: str = None, chunksize: int = 10000):
    """
    Export query results to parquet file using chunked reading
    
    Args:
        database_name: Name of the database to query
        output_path: Path to save parquet file (optional)
        chunksize: Number of rows to read per chunk
    """
    logger = setup_logging()
    
    if output_path is None:
        output_path = Path(__file__).parent / f'treatment_journey_{database_name}.parquet'
    
    try:
        conn = ConnectionFactory.create_connection(
            connection_type='local_mariadb',
            database=database_name
        ).connect()
        
        logger.info("Reading SQL query...")
        query = read_sql_file()
        
        # Get total rows for progress bar
        count_query = """
            SELECT COUNT(DISTINCT pl.ProcNum) as total_rows
            FROM procedurelog pl
            WHERE pl.ProcDate >= '2023-01-01'
                AND pl.ProcDate < '2024-01-01'
                AND pl.ProcStatus IN (1, 2, 6)
                AND pl.ProcFee > 0
        """
        total_rows = pd.read_sql(count_query, conn).iloc[0]['total_rows']
        logger.info(f"Total rows to process: {total_rows}")
        
        # Get schema from first chunk
        logger.info("Getting schema from first chunk...")
        first_chunk = next(pd.read_sql(query, conn, chunksize=1))
        
        # Convert all monetary columns to float
        monetary_columns = [
            'ActualInsurancePayment', 
            'EstimatedInsurancePayment',
            'TotalAdjustments'
        ]
        for col in monetary_columns:
            first_chunk[col] = pd.to_numeric(first_chunk[col], errors='coerce')
        
        # Replace None/null with appropriate values based on dtype
        for col in first_chunk.columns:
            if pd.api.types.is_numeric_dtype(first_chunk[col]):
                first_chunk[col] = first_chunk[col].fillna(0)
            else:
                first_chunk[col] = first_chunk[col].fillna('')
                
        schema = pa.Schema.from_pandas(first_chunk)
        
        # Stream to parquet with consistent schema
        logger.info("Starting export...")
        with pq.ParquetWriter(output_path, schema) as writer:
            with tqdm(total=total_rows, desc="Exporting data") as pbar:
                # Reset connection for full read
                conn.close()
                conn = ConnectionFactory.create_connection(
                    connection_type='local_mariadb',
                    database=database_name
                ).connect()
                
                for chunk_df in pd.read_sql(query, conn, chunksize=chunksize):
                    # Convert monetary columns to float
                    for col in monetary_columns:
                        chunk_df[col] = pd.to_numeric(chunk_df[col], errors='coerce')
                    
                    # Handle null values
                    for col in chunk_df.columns:
                        if pd.api.types.is_numeric_dtype(chunk_df[col]):
                            chunk_df[col] = chunk_df[col].fillna(0)
                        else:
                            chunk_df[col] = chunk_df[col].fillna('')
                    
                    # Ensure consistent dtypes
                    for col in chunk_df.columns:
                        chunk_df[col] = chunk_df[col].astype(first_chunk[col].dtype)
                    
                    # Write chunk
                    table = pa.Table.from_pandas(chunk_df, schema=schema)
                    writer.write_table(table)
                    
                    pbar.update(len(chunk_df))
        
        logger.info("Export complete!")
        logger.info(f"Data saved to: {output_path}")
        
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
    parser.add_argument('--chunksize', type=int, default=10000, help='Chunk size for reading (optional)')
    
    args = parser.parse_args()
    
    export_to_parquet(args.database_name, args.output, args.chunksize) 