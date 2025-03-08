#!/usr/bin/env python3
"""
Test database connection and query execution for payment validation.

This script tests:
1. Database connection
2. Basic table access
3. Simple CTE query with date parameters
"""

import os
import sys
import logging
from pathlib import Path
import pandas as pd

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

# Add base directory to path for imports
script_dir = Path(__file__).parent
base_dir = script_dir.parent.parent.parent
sys.path.append(str(base_dir))

# Load environment variables
from dotenv import load_dotenv
env_path = base_dir / 'src' / '.env'
load_dotenv(dotenv_path=env_path)
logging.info(f"Loaded environment variables from {env_path}")

# Import connection factory
from src.connections.factory import ConnectionFactory, get_valid_databases

def test_connection(connection_type, database):
    """Test database connection."""
    logging.info(f"Testing connection to {database} with {connection_type}")
    
    try:
        # Create connection and test simple query
        connection = ConnectionFactory.create_connection(connection_type, database)
        conn = connection.connect()
        
        with conn.cursor() as cursor:
            cursor.execute("SELECT 1 as test")
            result = cursor.fetchone()
            logging.info(f"Query result: {result}")
        
        connection.disconnect()
        return True
    except Exception as e:
        logging.error(f"Connection error: {str(e)}")
        return False

def test_table_access(connection_type, database):
    """Test access to important tables."""
    connection = ConnectionFactory.create_connection(connection_type, database)
    conn = connection.connect()
    
    tables_to_check = ['payment', 'paysplit', 'procedurelog']
    results = {}
    
    try:
        with conn.cursor() as cursor:
            for table in tables_to_check:
                try:
                    # Get row count
                    cursor.execute(f"SELECT COUNT(*) FROM {table}")
                    count = cursor.fetchone()[0]
                    
                    # Get sample columns
                    cursor.execute(f"SELECT * FROM {table} LIMIT 1")
                    sample = cursor.fetchone()
                    column_count = len(sample) if sample else 0
                    
                    results[table] = {
                        'count': count,
                        'columns': column_count
                    }
                    
                    logging.info(f"Table {table}: {count} rows, {column_count} columns")
                except Exception as e:
                    logging.error(f"Error checking table {table}: {str(e)}")
    finally:
        connection.disconnect()
    
    return results

def test_simple_cte_query(connection_type, database):
    """Test a simple CTE query with date parameters."""
    connection = ConnectionFactory.create_connection(connection_type, database)
    conn = connection.connect()
    
    try:
        with conn.cursor() as cursor:
            # Set date parameters
            cursor.execute("SET @start_date = '2024-01-01';")
            cursor.execute("SET @end_date = '2025-02-28';")
            
            # Run query
            cte_query = """
            WITH payment_counts AS (
                SELECT 
                    COUNT(*) as payment_count,
                    MIN(PayDate) as min_date,
                    MAX(PayDate) as max_date
                FROM payment
                WHERE PayDate BETWEEN @start_date AND @end_date
            )
            SELECT * FROM payment_counts;
            """
            
            cursor.execute(cte_query)
            result = cursor.fetchall()
            logging.info(f"CTE query result: {result}")
            
            # Export to CSV
            if result:
                # Create output directory if it doesn't exist
                output_dir = script_dir / 'output'
                output_dir.mkdir(exist_ok=True)
                
                # Create CSV with timestamp
                from datetime import datetime
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                output_file = output_dir / f"test_payment_data_{timestamp}.csv"
                
                # Convert to dataframe and save
                df = pd.DataFrame(result, columns=['payment_count', 'min_date', 'max_date'])
                df.to_csv(output_file, index=False)
                logging.info(f"Results saved to {output_file}")
    finally:
        connection.disconnect()

def main():
    """Main execution function."""
    
    # Get connection parameters
    connection_type = 'local_mariadb'
    database = os.environ.get('MARIADB_DATABASE', 'opendental_analytics_opendentalbackup_02_28_2025')
    
    logging.info(f"Testing with {connection_type} database: {database}")
    
    # Run tests
    if test_connection(connection_type, database):
        test_table_access(connection_type, database)
        test_simple_cte_query(connection_type, database)
    else:
        logging.error("Skipping further tests due to connection failure")
    
    logging.info("All tests completed")

if __name__ == "__main__":
    main() 