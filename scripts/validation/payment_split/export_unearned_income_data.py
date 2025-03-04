#!/usr/bin/env python
"""
Export Unearned Income Data Script

This script executes all queries in the unearned income report SQL file and exports 
the results of each query to separate CSV files for further analysis in pandas.

Features:
- Command-line arguments to specify date range and database
- Special handling for temporary tables in SQL queries
- Detailed logging and summary reports

Usage:
    python export_unearned_income_data.py [--from-date YYYY-MM-DD] [--to-date YYYY-MM-DD] [--database DB_NAME]

Requirements:
    - .env file must be set up in the project root with MariaDB configuration:
        MARIADB_HOST=localhost
        MARIADB_PORT=3307
        MARIADB_USER=your_username
        MARIADB_PASSWORD=your_password
        MARIADB_DATABASE=your_database
        LOCAL_VALID_DATABASES=comma,separated,list,of,valid,databases
"""

import os
import sys
import re
import logging
import pandas as pd
import mysql.connector
import argparse
from datetime import datetime, date
from pathlib import Path
from typing import Optional, Tuple, List, Dict, NamedTuple
from dotenv import load_dotenv

# Add the src directory to the path to import project modules
src_path = Path(__file__).resolve().parents[3]
sys.path.append(str(src_path))

# Import the ConnectionFactory from the correct module
from src.connections.factory import ConnectionFactory, get_valid_databases

# Load environment variables from src/.env
env_path = src_path / "src" / ".env"
load_dotenv(dotenv_path=env_path)
logger = logging.getLogger('unearned_income_export')
logger.info(f"Loading environment from: {env_path}")

from scripts.base.index_manager import sanitize_table_name

# Define constant paths
SCRIPT_DIR = Path(__file__).parent
DATA_DIR = SCRIPT_DIR / "data"
LOGS_DIR = SCRIPT_DIR / "logs"
QUERY_PATH = SCRIPT_DIR / "queries" / "unearned_income_report.sql"

# Create directories if they don't exist
os.makedirs(DATA_DIR, exist_ok=True)
os.makedirs(LOGS_DIR, exist_ok=True)

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(LOGS_DIR / f'unearned_income_export_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log')
    ]
)

# Get the list of valid databases from environment
valid_databases = get_valid_databases('LOCAL_VALID_DATABASES')

# Get default database from environment
default_database = os.getenv('MARIADB_DATABASE')
if not default_database and valid_databases:
    default_database = valid_databases[0]  # Use first valid database as default if available

class DateRange(NamedTuple):
    """Represents a date range for filtering data in queries."""
    start_date: date
    end_date: date

    @classmethod
    def from_strings(cls, start: str, end: str) -> 'DateRange':
        """Create a DateRange from string dates, with validation."""
        try:
            start_date = datetime.strptime(start, '%Y-%m-%d').date()
            end_date = datetime.strptime(end, '%Y-%m-%d').date()
            
            if end_date < start_date:
                raise ValueError(f"End date {end_date} must be after start date {start_date}")
                
            return cls(start_date, end_date)
        except ValueError as e:
            logging.error(f"Date parsing error: {e}")
            raise

def apply_date_parameters(sql: str, date_range: DateRange) -> str:
    """Apply date range parameters to SQL query by replacing SET statements"""
    # Replace the date parameters in SET statements
    sql = re.sub(
        r"SET @FromDate = '\d{4}-\d{2}-\d{2}';", 
        f"SET @FromDate = '{date_range.start_date}';", 
        sql
    )
    sql = re.sub(
        r"SET @ToDate = '\d{4}-\d{2}-\d{2}';", 
        f"SET @ToDate = '{date_range.end_date}';", 
        sql
    )
    return sql

def read_sql_file(file_path: Path) -> str:
    """Read SQL query from a file."""
    try:
        with open(file_path, 'r') as f:
            return f.read()
    except Exception as e:
        logger.error(f"Error reading SQL file: {e}")
        raise

def extract_all_queries(full_sql: str, date_range: DateRange) -> Dict[str, str]:
    """
    Extract all distinct queries from the SQL file.
    Returns a dictionary with query name as key and query text as value.
    
    Args:
        full_sql (str): The full SQL content from the file
        date_range (DateRange): Date range to apply to queries
        
    Returns:
        Dict[str, str]: Dictionary of query names and their SQL text
    """
    # Extract the date parameters section (shared by all queries)
    date_params_pattern = r"(-- Set date parameters.*?SET @ToDate = '\d{4}-\d{2}-\d{2}';)"
    date_params_match = re.search(date_params_pattern, full_sql, re.DOTALL)
    date_params = date_params_match.group(1) if date_params_match else ""
    
    # Update date parameters to use provided dates
    date_params = apply_date_parameters(date_params, date_range)
    
    # Initialize dictionary to store all queries
    queries = {}
    
    # Extract the main CTE query
    cte_pattern = r"(?:-- Common Table Expressions|WITH).*?(WITH.*?ORDER BY ps\.DatePay;)"
    cte_match = re.search(cte_pattern, full_sql, re.DOTALL)
    if cte_match:
        main_query = cte_match.group(1)
        queries["main_transactions"] = f"{date_params}\n\n{main_query}"
        logger.debug(f"Found main_transactions query with {len(main_query)} characters")
    
    # Extract the patient balance report query (after temporary tables)
    temp_tables_pattern = r"-- (Step 1|Optimized Patient Balance Report).*?CREATE TEMPORARY TABLE.*?(SELECT.*?ORDER BY.*?DESC;)"
    temp_tables_match = re.search(temp_tables_pattern, full_sql, re.DOTALL)
    if temp_tables_match:
        # Get everything from the temp table creation to the final SELECT
        full_temp_section = full_sql[temp_tables_match.start():temp_tables_match.end()]
        
        # Find the final SELECT statement for patient balance
        balance_pattern = r"(SELECT.*?FROM temp_patient_balances.*?ORDER BY.*?DESC;)"
        balance_match = re.search(balance_pattern, full_temp_section, re.DOTALL)
        
        if balance_match:
            queries["patient_balance_report"] = f"{date_params}\n\n{full_temp_section}"
            logger.debug(f"Found patient_balance_report query with {len(full_temp_section)} characters")
    
    # Extract the monthly trend analysis query
    monthly_pattern = r"-- Monthly trend.*?unearned income\s*(SELECT.*?GROUP BY.*?ORDER BY.*?month;)"
    monthly_match = re.search(monthly_pattern, full_sql, re.DOTALL)
    if monthly_match:
        monthly_query = monthly_match.group(1)
        queries["monthly_trends"] = f"{date_params}\n\n{monthly_query}"
        logger.debug(f"Found monthly_trends query with {len(monthly_query)} characters")
    
    # Extract the aging analysis query
    aging_pattern = r"-- Aging analysis of unearned income\s*(SELECT.*?END;)"
    aging_match = re.search(aging_pattern, full_sql, re.DOTALL)
    if aging_match:
        aging_query = aging_match.group(1)
        queries["aging_analysis"] = f"{date_params}\n\n{aging_query}"
        logger.debug(f"Found aging_analysis query with {len(aging_query)} characters")
    
    # Extract the summary by unearned type query
    summary_pattern = r"-- Summary.*?unearned type\s*(SELECT.*?ORDER BY COUNT\(\*\) DESC;)"
    summary_match = re.search(summary_pattern, full_sql, re.DOTALL)
    if summary_match:
        summary_query = summary_match.group(1)
        queries["unearned_type_summary"] = f"{date_params}\n\n{summary_query}"
        logger.debug(f"Found unearned_type_summary query with {len(summary_query)} characters")
    
    # Extract payment type summary
    payment_type_pattern = r"-- Summary statistics by payment type\s*(SELECT.*?ORDER BY SUM\(ps\.SplitAmt\) DESC;)"
    payment_type_match = re.search(payment_type_pattern, full_sql, re.DOTALL)
    if payment_type_match:
        payment_type_query = payment_type_match.group(1)
        queries["payment_type_summary"] = f"{date_params}\n\n{payment_type_query}"
        logger.debug(f"Found payment_type_summary query with {len(payment_type_query)} characters")
    
    # Extract negative prepayments query
    negative_pattern = r"-- Negative prepayments.*?\s*(SELECT.*?ORDER BY ps\.SplitAmt;)"
    negative_match = re.search(negative_pattern, full_sql, re.DOTALL)
    if negative_match:
        negative_query = negative_match.group(1)
        queries["negative_prepayments"] = f"{date_params}\n\n{negative_query}"
        logger.debug(f"Found negative_prepayments query with {len(negative_query)} characters")
    
    # Extract top patients query
    top_patients_pattern = r"-- Top patients with unearned income\s*(SELECT.*?LIMIT \d+;)"
    top_patients_match = re.search(top_patients_pattern, full_sql, re.DOTALL)
    if top_patients_match:
        top_patients_query = top_patients_match.group(1)
        queries["top_patients"] = f"{date_params}\n\n{top_patients_query}"
        logger.debug(f"Found top_patients query with {len(top_patients_query)} characters")
    
    if not queries:
        logger.error("Failed to extract any queries from SQL file")
        raise ValueError("Could not extract queries from SQL file")
        
    logger.info(f"Successfully extracted {len(queries)} queries from SQL file")
    for query_name in queries.keys():
        logger.info(f"Found query: {query_name}")
        
    return queries

def extract_sql_query(query_text):
    """Extract the actual SQL query from the comment header"""
    # Remove any comment lines at the beginning
    lines = query_text.split('\n')
    sql_lines = []
    
    for line in lines:
        line = line.strip()
        if line and not line.startswith('--'):
            sql_lines.append(line)
    
    return '\n'.join(sql_lines)

def extract_final_select(query_text):
    """
    Extract the final SELECT statement from a query with multiple statements.
    This is particularly useful for queries with temporary tables where we want
    the last SELECT that retrieves data.
    """
    # Strip comments and empty lines
    cleaned_lines = []
    for line in query_text.split('\n'):
        line = line.strip()
        if line and not line.startswith('--'):
            cleaned_lines.append(line)
    
    cleaned_query = '\n'.join(cleaned_lines)
    
    # Split into statements
    statements = re.split(r';(?=\s*(?:[^\']*\'[^\']*\')*[^\']*$)', cleaned_query)
    statements = [stmt.strip() for stmt in statements if stmt.strip()]
    
    # Find the last SELECT statement
    select_statements = [stmt for stmt in statements if stmt.upper().startswith('SELECT')]
    
    if select_statements:
        return select_statements[-1]
    else:
        return None

def execute_query(connection, db_name, query_name, query, output_dir=None):
    """
    Execute a query and return the resulting dataframe
    
    Args:
        connection: The database connection
        db_name: Name of the database to connect to
        query_name: Name of the query (for logging)
        query: SQL query to execute
        output_dir: Directory to save CSV output (optional)
        
    Returns:
        tuple: (DataFrame with results, path to CSV file if saved)
    """
    # Extract the actual SQL without comment headers
    query_without_headers = extract_sql_query(query)
    
    # Check if this query contains temporary tables or date parameters or CTE
    contains_temp_tables = 'CREATE TEMPORARY TABLE' in query_without_headers.upper() or 'DROP TEMPORARY TABLE' in query_without_headers.upper()
    contains_date_params = 'SET @FromDate' in query_without_headers or 'SET @ToDate' in query_without_headers
    contains_cte = 'WITH ' in query_without_headers.upper() and ' AS (' in query_without_headers.upper()
    
    # Use multi-statement execution for temp tables OR queries with date parameters
    use_multi_statement = contains_temp_tables or contains_date_params
    
    rows = []
    df = None
    
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)
    
    try:
        # If we need multi-statement execution
        if use_multi_statement:
            if contains_temp_tables:
                logging.info(f"Query '{query_name}' contains temporary tables. Using special handling.")
            elif contains_cte:
                logging.info(f"Query '{query_name}' contains CTE. Using special handling for WITH clause.")
            else:
                logging.info(f"Query '{query_name}' contains date parameters. Using multi-statement execution.")
            
            try:
                # Create a fresh connection for multi-statement execution
                # Close the existing connection first to avoid resource issues
                if connection:
                    try:
                        connection.close()
                    except:
                        pass
                    
                # Create a fresh connection with the ConnectionFactory
                temp_connection = ConnectionFactory.create_connection('local_mariadb', database=db_name)
                conn = temp_connection.get_connection()
                
                logging.debug(f"Created fresh connection for multi-statement execution")
                
                # Get a cursor
                cursor = conn.cursor(dictionary=True)
                
                # Clean the query - remove comment lines, empty lines, and trim whitespace
                cleaned_query = extract_sql_query(query)
                
                # Log the query length for debugging
                logging.debug(f"Executing cleaned query for {query_name}: {len(cleaned_query)} characters")
                
                try:
                    # Split into statements
                    statements = re.split(r';(?=\s*(?:[^\']*\'[^\']*\')*[^\']*$)', cleaned_query)
                    statements = [stmt.strip() for stmt in statements if stmt.strip()]
                    
                    # Handle CTE queries specially (main_transactions)
                    if contains_cte:
                        # First, execute any SET statements for date parameters
                        for i, stmt in enumerate(statements):
                            if stmt.upper().startswith('SET @'):
                                logging.debug(f"Executing date parameter {i+1}: {stmt}")
                                cursor.execute(stmt)
                                # Important: Consume any results
                                try:
                                    cursor.fetchall()
                                except:
                                    pass
                                conn.commit()
                        
                        # Now find the CTE statement (typically the last statement)
                        cte_statement = None
                        for stmt in statements:
                            if 'WITH ' in stmt.upper() and ' AS (' in stmt.upper():
                                cte_statement = stmt
                                break
                        
                        if cte_statement:
                            logging.debug(f"Executing CTE statement: {cte_statement[:100]}...")
                            cursor.execute(cte_statement)
                            rows = cursor.fetchall()
                            logging.info(f"Retrieved {len(rows)} rows from CTE query in {query_name}")
                        else:
                            logging.warning(f"No CTE statement found in {query_name}")
                    # For queries with temporary tables
                    elif contains_temp_tables:
                        for i, stmt in enumerate(statements):
                            if not stmt:
                                continue
                                
                            # Check if this is a DROP TEMPORARY TABLE statement
                            is_drop_temp = 'DROP TEMPORARY TABLE' in stmt.upper()
                            is_date_param = stmt.upper().startswith('SET @')
                            
                            try:
                                if is_date_param:
                                    # Date parameter statement
                                    logging.debug(f"Executing date parameter {i+1}/{len(statements)}: {stmt}")
                                    cursor.execute(stmt)
                                    # Consume any results
                                    try:
                                        cursor.fetchall()
                                    except:
                                        pass
                                    conn.commit()
                                elif i < len(statements) - 1 or not stmt.upper().startswith('SELECT'):
                                    # Execute all non-SELECT statements or statements before the final SELECT
                                    logging.debug(f"Executing statement {i+1}/{len(statements)}: {stmt[:50]}...")
                                    cursor.execute(stmt)
                                    # Consume any results
                                    if not is_drop_temp:
                                        try:
                                            cursor.fetchall()
                                        except:
                                            pass
                                    conn.commit()
                            except Exception as e:
                                # Ignore "unknown table" errors when dropping temporary tables
                                if is_drop_temp and "1051" in str(e):  # MySQL error code for unknown table
                                    logging.debug(f"Ignoring 'unknown table' error when dropping temp table: {e}")
                                else:
                                    # Re-raise the exception for other types of errors
                                    raise
                        
                        # Now execute the final SELECT statement
                        final_select = extract_final_select(query)
                        if final_select:
                            logging.debug(f"Executing final SELECT statement: {final_select[:100]}...")
                            cursor.execute(final_select)
                            rows = cursor.fetchall()
                            logging.info(f"Retrieved {len(rows)} rows from final SELECT in {query_name}")
                        else:
                            logging.warning(f"No final SELECT statement found in {query_name}")
                    # For regular queries with date parameters
                    else:
                        for i, stmt in enumerate(statements):
                            if not stmt:
                                continue
                            
                            is_date_param = stmt.upper().startswith('SET @')
                            
                            if is_date_param:
                                # Date parameter statement
                                logging.debug(f"Executing date parameter {i+1}/{len(statements)}: {stmt}")
                                cursor.execute(stmt)
                                # Consume any results
                                try:
                                    cursor.fetchall()
                                except:
                                    pass
                                conn.commit()
                        
                        # Get the final SELECT statement
                        final_select = None
                        for stmt in statements:
                            if stmt.upper().startswith('SELECT'):
                                final_select = stmt
                                break
                        
                        if not final_select:
                            final_select = extract_final_select(query)
                        
                        if final_select:
                            logging.debug(f"Executing final SELECT statement: {final_select[:100]}...")
                            cursor.execute(final_select)
                            rows = cursor.fetchall()
                            logging.info(f"Retrieved {len(rows)} rows from final SELECT in {query_name}")
                        else:
                            logging.warning(f"No SELECT statement found in {query_name}")
                finally:
                    # Close the cursor and connection
                    cursor.close()
                    temp_connection.close()
            
            except Exception as e:
                logging.error(f"Error executing query with multi-statement execution: {str(e)}")
                return None, None
        else:
            # Regular query execution for simple queries without temp tables or date parameters
            logging.debug(f"Executing simple query for {query_name}")
            
            # Get a cursor from the connection
            conn = connection.get_connection()
            cursor = conn.cursor(dictionary=True)
            
            try:
                cursor.execute(query_without_headers)
                rows = cursor.fetchall()
                logging.info(f"Retrieved {len(rows)} rows from {query_name}")
            finally:
                cursor.close()
        
        if rows:
            df = pd.DataFrame(rows)
            
            if output_dir and not df.empty:
                # Export to CSV
                output_path = export_to_csv(df, output_dir, query_name)
                return df, output_path
            
            return df, None
        else:
            logging.warning(f"No results returned for query: {query_name}")
            return None, None
            
    except Exception as e:
        logging.error(f"Error executing query {query_name}: {str(e)}")
        return None, None

def export_to_csv(df: pd.DataFrame, output_dir: Path, query_name: str) -> Path:
    """Export DataFrame to a CSV file with a fixed descriptive name, overwriting if it exists."""
    # Generate filename without timestamp
    filename = f"unearned_income_{query_name}.csv"
    filepath = output_dir / filename
    
    # Export to CSV (will overwrite if exists)
    df.to_csv(filepath, index=False)
    logger.info(f"Data exported to {filepath}")
    
    return filepath

def extract_report_data(from_date='2024-01-01', to_date='2025-02-28', db_name=None):
    """
    Extract data from the unearned income report SQL into CSV files
    
    Args:
        from_date (str): Start date in YYYY-MM-DD format
        to_date (str): End date in YYYY-MM-DD format
        db_name (str, optional): Database name to connect to. If None, uses the default from .env
    """
    # Use the existing constants
    sql_file = QUERY_PATH
    output_dir = DATA_DIR
    
    # Set up logging
    setup_logging()
    
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Create DateRange object for better date handling
    try:
        date_range = DateRange.from_strings(from_date, to_date)
    except ValueError as e:
        logging.error(f"Invalid date range: {e}")
        return
    
    # Read the SQL file
    with open(sql_file, 'r') as f:
        full_sql = f.read()
    
    # Extract queries from SQL file with date parameters
    queries = extract_all_queries(full_sql, date_range)
    logging.info(f"Extracted {len(queries)} queries from {sql_file}")
    logging.info(f"Using date range: {date_range.start_date} to {date_range.end_date}")
    logging.info(f"Connecting to database: {db_name}")
    
    # Let ConnectionFactory validate and handle the database name
    try:
        # Initialize connection - this will validate the database name
        connection = ConnectionFactory.create_connection('local_mariadb', database=db_name)
        
        # Get the actual database name for logging
        actual_db = connection.config.database
        logging.info(f"ConnectionFactory selected database: {actual_db}")
        
        # Dictionary to store results
        query_results = {}
        
        # Process each query
        for query_name, query in queries.items():
            logging.info(f"Processing query: {query_name}")
            df, csv_path = execute_query(connection, actual_db, query_name, query, output_dir)
            query_results[query_name] = {
                'success': df is not None,
                'rows': len(df) if df is not None else 0,
                'file': csv_path
            }
        
        # Close connection
        if connection:
            connection.close()
        
        # Print summary
        print_summary(query_results, output_dir)
        
        return query_results
    except ValueError as e:
        logging.error(f"Database connection error: {e}")
        return None

def setup_logging():
    """Set up logging configuration"""
    log_dir = LOGS_DIR
    os.makedirs(log_dir, exist_ok=True)
    
    log_file = log_dir / f"unearned_income_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
    
    logging.basicConfig(
        level=logging.DEBUG,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler(log_file)
        ]
    )
    
    logging.info(f"Logging to {log_file}")

def print_summary(query_results, output_dir):
    """
    Print a summary table of the query results
    """
    # Calculate totals
    total_rows = sum(result['rows'] for result in query_results.values())
    successful_queries = sum(1 for result in query_results.values() if result['success'])
    failed_queries = sum(1 for result in query_results.values() if not result['success'])
    no_results_queries = sum(1 for result in query_results.values() if result['rows'] == 0)
    
    # Format and print summary table
    print("\n" + "="*100)
    print(" "*40 + "SUMMARY REPORT")
    print("="*100)
    print(f"{'Query Name':<30} | {'Rows':<8} | {'Status':<30} | {'Output File':<30}")
    print("-"*100)
    
    for query_name, result in query_results.items():
        filename = os.path.basename(result['file']) if result['file'] else "N/A"
        status = "Success" if result['success'] else "Failed"
        # Add color to status (not visible in logs but helpful in console)
        status_display = status
        if not result['success']:
            status_display = f"ERROR: {status[6:]}"  # Remove 'Error: ' prefix
        
        print(f"{query_name:<30} | {result['rows']:<8} | {status_display:<30} | {filename:<30}")
    
    print("-"*100)
    print(f"Total Queries: {len(query_results)}")
    print(f"Successful Queries: {successful_queries}")
    print(f"Failed Queries: {failed_queries}")
    print(f"Queries with No Results: {no_results_queries}")
    print(f"Total Rows Retrieved: {total_rows}")
    print(f"Total Files Generated: {sum(1 for r in query_results.values() if r['file'])}")
    print(f"Output Directory: {output_dir}")
    print("="*100 + "\n")
    
    # Also log the summary
    logging.info(f"Summary: {len(query_results)} queries processed, {successful_queries} successful, {failed_queries} failed, {no_results_queries} with no results")
    logging.info(f"Total rows retrieved: {total_rows}")
    logging.info(f"Files generated: {sum(1 for r in query_results.values() if r['file'])}")
    
    return

def main():
    """Main function to execute the export process."""
    try:
        # Add simple command-line argument parsing
        parser = argparse.ArgumentParser(description='Export unearned income report data.')
        
        # Date range arguments
        parser.add_argument('--from-date', type=str, help='Start date in YYYY-MM-DD format', default='2024-01-01')
        parser.add_argument('--to-date', type=str, help='End date in YYYY-MM-DD format', default='2025-02-28')
        
        # Show valid databases in help text
        db_help = f"Database name. Valid options: {', '.join(valid_databases)}" if valid_databases else "Database name"
        parser.add_argument('--database', type=str, help=db_help, default=default_database)
        
        args = parser.parse_args()
        
        # Set up basic logging for pre-initialization errors
        if not os.path.exists(LOGS_DIR):
            os.makedirs(LOGS_DIR, exist_ok=True)
        pre_log_file = os.path.join(LOGS_DIR, f"pre_init_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log")
        logging.basicConfig(level=logging.INFO, 
                            format='%(asctime)s - %(levelname)s - %(message)s',
                            handlers=[logging.FileHandler(pre_log_file), logging.StreamHandler()])
        
        # Validate date format
        try:
            # Use DateRange for validation
            DateRange.from_strings(args.from_date, args.to_date)
        except ValueError as e:
            logging.error(f"Date validation error: {e}")
            print(f"Error: Date validation failed. {e}")
            return
        
        # Check if SQL file exists
        if not os.path.exists(QUERY_PATH):
            logging.error(f"SQL file not found: {QUERY_PATH}")
            print(f"Error: SQL file not found: {QUERY_PATH}")
            return
        
        # Validate database name
        if not args.database:
            logging.error("No database specified and no default found in environment")
            print("Error: No database specified and no default found in environment")
            print(f"Valid databases: {', '.join(valid_databases)}" if valid_databases else "No valid databases configured")
            return
            
        # Call the function with arguments
        extract_report_data(from_date=args.from_date, to_date=args.to_date, db_name=args.database)
    except Exception as e:
        logging.error(f"Error in export process: {e}")
        print(f"Error: {e}")
        import traceback
        logging.error(traceback.format_exc())
        return None

if __name__ == "__main__":
    main() 