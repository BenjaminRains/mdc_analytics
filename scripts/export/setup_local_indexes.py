import logging
from src.db_config import connect_to_mysql_localhost
import mysql.connector

def setup_indexes(database_name: str):
    """
    Sets up indexes on the local database for better query performance.
    These indexes are specifically optimized for treatment journey queries.
    """
    logging.info(f"Setting up indexes for {database_name}...")
    
    # Connect to database
    conn = connect_to_mysql_localhost(database=database_name)
    cursor = conn.cursor()
    
    try:
        # Define indexes for treatment journey analysis
        indexes = [
            "CREATE INDEX idx_proc_date ON procedurelog (ProcDate, ProcStatus)",
            "CREATE INDEX idx_proc_patient ON procedurelog (PatNum, ProcDate)",
            "CREATE INDEX idx_proc_code ON procedurelog (CodeNum)",
            "CREATE INDEX idx_pat_guarantor ON patient (Guarantor)",
            "CREATE INDEX idx_pat_birth ON patient (Birthdate)",
            "CREATE INDEX idx_paysplit_proc ON paysplit (ProcNum, SplitAmt)",
            "CREATE INDEX idx_claimproc_proc ON claimproc (ProcNum, Status, InsPayAmt)",
            "CREATE INDEX idx_adj_proc ON adjustment (ProcNum, AdjAmt)"
        ]
        
        # Create indexes
        for index in indexes:
            try:
                cursor.execute(index)
                conn.commit()
                logging.info(f"Created index: {index}")
            except mysql.connector.Error as err:
                # Ignore if index already exists
                if err.errno == 1061:  # Error code for duplicate key name
                    logging.info(f"Index already exists: {index}")
                else:
                    logging.warning(f"Error creating index: {err}")
        
        # Analyze tables for query optimization
        tables = ["procedurelog", "patient", "paysplit", "claimproc", "adjustment"]
        for table in tables:
            try:
                cursor.execute(f"ANALYZE TABLE {table}")
                results = cursor.fetchall()
                logging.info(f"Analyzed table: {table}")
            except mysql.connector.Error as err:
                logging.warning(f"Error analyzing table {table}: {err}")
                
    except Exception as e:
        logging.error(f"Error during index setup: {str(e)}")
        raise
        
    finally:
        cursor.close()
        conn.close()
        logging.info("Index setup complete")

if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        print("Usage: python setup_local_indexes.py <local_db_name>")
        sys.exit(1)
    
    setup_indexes(sys.argv[1]) 