import logging
import pandas as pd
from pathlib import Path
from src.db_config import connect_to_mysql_localhost
import mysql.connector

def generate_treatment_journey_dataset(local_db_name: str):
    """
    Generates treatment journey dataset from local database and saves to parquet.
    Requires indexes to be set up first for optimal performance.
    """
    logging.info(f"Starting dataset generation from {local_db_name}...")
    
    # Read SQL query
    query_path = Path('scripts/query/treatment_journey_ml.sql')
    logging.info(f"Reading query from {query_path}")
    
    if not query_path.exists():
        raise FileNotFoundError(f"SQL query file not found at {query_path}")
    
    with open(query_path, 'r') as file:
        query = file.read()
    
    # Replace database name in query if needed
    query = query.replace('USE opendentalbackup_01_03_2025', f'USE {local_db_name}')
    logging.info("SQL query prepared with correct database name")
    
    try:
        # Connect to the local database
        conn = connect_to_mysql_localhost(local_db_name)
        
        # Execute query with progress updates
        chunks = []
        with conn.cursor(dictionary=True) as cursor:
            cursor.execute(query)
            total_rows = 0
            while True:
                chunk = cursor.fetchmany(10000)
                if not chunk:
                    break
                chunks.append(pd.DataFrame(chunk))
                total_rows += len(chunk)
                logging.info(f"Processed {total_rows:,} rows...")
        
        logging.info("Query complete, combining chunks...")
        df = pd.concat(chunks, ignore_index=True)
        
        # Save to parquet
        output_dir = Path("data/processed")
        output_dir.mkdir(parents=True, exist_ok=True)
        
        output_path = output_dir / f"treatment_journey_{local_db_name}.parquet"
        logging.info(f"Saving dataset to {output_path}")
        
        df.to_parquet(
            output_path,
            engine='pyarrow',
            compression='snappy',
            index=False
        )
        
        logging.info(f"Dataset saved successfully. Total rows: {len(df):,}")
        return output_path
        
    except mysql.connector.Error as e:
        logging.error(f"Database error: {str(e)}")
        if e.errno == 1049:  # Unknown database
            logging.error(f"Database '{local_db_name}' does not exist")
        raise
    finally:
        if 'conn' in locals() and conn.is_connected():
            conn.close()

if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler("logs/dataset_generation.log"),
            logging.StreamHandler()
        ]
    )
    
    try:
        # Manually input the database name
        database_name = input("Enter the database name: ")
        
        output_path = generate_treatment_journey_dataset(database_name)
        print(f"Dataset generated successfully at: {output_path}")
    except Exception as e:
        logging.error(f"Dataset generation failed: {str(e)}")
        raise 