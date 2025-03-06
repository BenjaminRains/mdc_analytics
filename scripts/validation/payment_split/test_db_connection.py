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
from datetime import datetime, date
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

# Try to load environment variables from .env file
try:
    from dotenv import load_dotenv
    env_path = base_dir / 'src' / '.env'
    load_dotenv(dotenv_path=env_path)
    logging.info(f"Loaded environment variables from {env_path}")
except ImportError:
    logging.warning("dotenv package not found, skipping .env file loading")
except Exception as e:
    logging.warning(f"Error loading .env file: {str(e)}")

# Try to import ConnectionFactory from different possible locations
ConnectionFactory = None
get_valid_databases = None

# First try from src.connections
try:
    from src.connections.factory import ConnectionFactory, get_valid_databases
    logging.info("Successfully imported ConnectionFactory from src.connections.factory")
except ImportError:
    logging.warning("Failed to import ConnectionFactory from src.connections.factory")

# Try other possible locations
if ConnectionFactory is None:
    potential_paths = [
        'scripts.base.connection_factory',
        'src.connections.connection_factory',
        'base.connection_factory',
    ]
    
    for path in potential_paths:
        try:
            module = __import__(path, fromlist=['ConnectionFactory', 'get_valid_databases'])
            ConnectionFactory = getattr(module, 'ConnectionFactory')
            get_valid_databases = getattr(module, 'get_valid_databases', None)
            if ConnectionFactory:
                logging.info(f"Successfully imported ConnectionFactory from {path}")
                break
        except (ImportError, AttributeError):
            logging.warning(f"Failed to import ConnectionFactory from {path}")

# Check if we found ConnectionFactory
if ConnectionFactory is None:
    logging.error("Failed to import ConnectionFactory from any location")
    sys.exit(1)

def check_environment():
    """Log the environment variables that are loaded."""
    mariadb_vars = {
        'MARIADB_HOST': os.environ.get('MARIADB_HOST', 'Not set'),
        'MARIADB_PORT': os.environ.get('MARIADB_PORT', 'Not set'),
        'MARIADB_USER': os.environ.get('MARIADB_USER', 'Not set'),
        'MARIADB_PASSWORD': '****' if os.environ.get('MARIADB_PASSWORD') else 'Not set',
        'MARIADB_DATABASE': os.environ.get('MARIADB_DATABASE', 'Not set')
    }
    
    logging.info(f"MariaDB environment variables: {mariadb_vars}")
    
    # Check valid databases
    if get_valid_databases:
        valid_dbs = get_valid_databases('LOCAL_VALID_DATABASES')
        logging.info(f"Valid databases: {valid_dbs}")

def test_connection(connection_type, database):
    """Test database connection."""
    logging.info(f"Testing connection to {database} with {connection_type}")
    
    try:
        # Use ConnectionFactory as designed - it will automatically use environment variables
        connection = ConnectionFactory.create_connection(connection_type, database)
        logging.info(f"Connection object type: {type(connection).__name__}")
        
        # Connect
        mysql_connection = connection.connect()
        logging.info(f"MySQL connection object type: {type(mysql_connection).__name__}")
        
        # Check connection attributes
        for attr in ['cursor', 'close', 'disconnect']:
            if hasattr(mysql_connection, attr):
                logging.info(f"MySQL connection has {attr} method")
            else:
                logging.warning(f"MySQL connection DOES NOT have {attr} method")
        
        # Check if connection is working
        logging.info("Testing simple query...")
        with mysql_connection.cursor() as cursor:
            cursor.execute("SELECT 1 as test")
            result = cursor.fetchone()
            logging.info(f"Simple query result: {result}")
        
        # Close connection
        try:
            if hasattr(mysql_connection, 'close'):
                mysql_connection.close()
                logging.info("Successfully closed mysql_connection with close()")
            elif hasattr(connection, 'disconnect'):
                connection.disconnect()
                logging.info("Successfully closed connection with disconnect()")
            else:
                logging.warning("Could not find appropriate method to close connection")
        except Exception as e:
            logging.error(f"Error closing connection: {str(e)}")
        
        return mysql_connection
    except Exception as e:
        logging.error(f"Error creating connection: {str(e)}")
        return None

def test_table_access(connection_type, database):
    """Test access to important tables."""
    try:
        # Use ConnectionFactory as designed - it will automatically use environment variables
        connection = ConnectionFactory.create_connection(connection_type, database)
        mysql_connection = connection.connect()
        
        tables_to_check = ['payment', 'paysplit', 'procedurelog']
        results = {}
        
        try:
            with mysql_connection.cursor() as cursor:
                for table in tables_to_check:
                    try:
                        # Get row count
                        cursor.execute(f"SELECT COUNT(*) FROM {table}")
                        count_result = cursor.fetchone()
                        total_count = count_result[0] if count_result else 0
                        
                        # Get sample records
                        cursor.execute(f"SELECT * FROM {table} LIMIT 2")
                        sample = cursor.fetchall()
                        
                        results[table] = {
                            'total_count': total_count,
                            'has_sample_data': len(sample) > 0,
                            'sample_columns': len(sample[0]) if sample and sample[0] else 0
                        }
                        
                        logging.info(f"Table {table}: {results[table]}")
                    except Exception as e:
                        logging.error(f"Error checking table {table}: {str(e)}")
                        results[table] = {'error': str(e)}
        finally:
            if hasattr(mysql_connection, 'close'):
                mysql_connection.close()
        
        return results
    except Exception as e:
        logging.error(f"Error setting up connection for table access: {str(e)}")
        return {}

def test_simple_cte_query(connection_type, database):
    """Test a simple CTE query with date parameters."""
    try:
        # Use ConnectionFactory as designed - it will automatically use environment variables
        connection = ConnectionFactory.create_connection(connection_type, database)
        mysql_connection = connection.connect()
        
        # Set date parameters
        start_date = '2024-01-01'
        end_date = '2025-02-28'
        
        # Simple CTE query
        query = """
        -- First set date parameters explicitly
        SET @start_date = '2024-01-01';
        SET @end_date = '2025-02-28';
        
        -- Now run the CTE query
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
        
        try:
            # Method 1: Try with separate statements
            with mysql_connection.cursor() as cursor:
                logging.info("Method 1: Testing with separate statements")
                cursor.execute("SET @start_date = '2024-01-01';")
                cursor.execute("SET @end_date = '2025-02-28';")
                
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
                logging.info(f"Method 1 result: {result}")
                
            # Close and reopen connection for next test
            mysql_connection.close()
            mysql_connection = connection.connect()
                
            # Method 2: Try executing statements separately but parse them from the string
            with mysql_connection.cursor() as cursor:
                logging.info("Method 2: Testing with parsed statements")
                statements = [stmt.strip() for stmt in query.split(';') if stmt.strip()]
                
                for i, stmt in enumerate(statements):
                    if stmt.strip():
                        logging.info(f"Executing statement {i+1}: {stmt[:50]}...")
                        cursor.execute(stmt)
                        
                        # Only fetch results from the last statement (the actual query)
                        if i == len(statements) - 1:
                            result = cursor.fetchall()
                            logging.info(f"Method 2 result: {result}")
                
            # Export to CSV
            if result:
                df = pd.DataFrame(result)
                output_file = str(script_dir / 'test_query_result.csv')
                df.to_csv(output_file, index=False)
                logging.info(f"Saved results to {output_file}")
        except Exception as e:
            logging.exception(f"Error executing CTE query: {str(e)}")
        finally:
            if hasattr(mysql_connection, 'close'):
                mysql_connection.close()
    except Exception as e:
        logging.error(f"Error setting up connection for CTE query: {str(e)}")

def main():
    """Main execution function."""
    # Check environment variables
    check_environment()
    
    # Connection parameters (will use environment variables automatically)
    connection_type = 'local_mariadb'
    database = os.environ.get('MARIADB_DATABASE', 'opendental_analytics_opendentalbackup_02_28_2025')
    
    logging.info(f"Testing with database: {database}")
    
    # Test database connection
    logging.info("=== Testing Database Connection ===")
    mysql_connection = test_connection(connection_type, database)
    
    if mysql_connection is not None:
        # Test table access
        logging.info("=== Testing Table Access ===")
        table_results = test_table_access(connection_type, database)
        
        # Test CTE query
        logging.info("=== Testing CTE Query ===")
        test_simple_cte_query(connection_type, database)
    else:
        logging.error("Skipping further tests due to connection failure")
    
    logging.info("All tests completed")

if __name__ == "__main__":
    main() 