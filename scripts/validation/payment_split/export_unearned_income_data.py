#!/usr/bin/env python
"""
Export Unearned Income Data

This script executes queries from the unearned income SQL file and exports 
the results to CSV files for financial analysis of unearned income.

Output Files Generated:
-----------------------
All files are stored in scripts/validation/payment_split/data/
1. unearned_income_main_transactions.csv - Detailed transaction data
2. unearned_income_unearned_type_summary.csv - Summary statistics by unearned type
3. unearned_income_payment_type_summary.csv - Summary statistics by payment type
4. unearned_income_monthly_trend.csv - Monthly trend of unearned income
5. unearned_income_patient_balance_report.csv - Patient balance information
6. unearned_income_aging_analysis.csv - Aging analysis of unearned income
7. unearned_income_negative_prepayments.csv - Negative prepayment transactions (potential refunds or adjustments)

Use Case:
---------
This script is specifically designed for financial accounting analysis of unearned income
(prepayments, deposits) that has not yet been applied to services. It helps analyze:
- Aging of unearned income amounts
- Distribution by unearned income type
- Payment types associated with unearned income
- Patient-level details for manual review

Key Differences from Income Transfer Export:
- Focuses on UnearnedType (accounting classification) rather than provider assignment
- Analyzes pre-payment patterns and financial risk
- Outputs are primarily for financial reporting and balance verification

Usage:
    python export_unearned_income_data.py [--from-date YYYY-MM-DD] [--to-date YYYY-MM-DD] [--database DB_NAME]

Requirements:
    - .env file must be set up in the project root with MariaDB configuration
    - SQL file should be structured according to expected patterns
"""

import os
import sys
import re
import logging
import pandas as pd
import argparse
from datetime import datetime, date
from pathlib import Path
from typing import Dict, List, Optional, Tuple, NamedTuple, Any
from dotenv import load_dotenv

# Add the src directory to the path to import project modules
src_path = Path(__file__).resolve().parents[3]
sys.path.append(str(src_path))

# Load environment variables from src/.env
env_path = src_path / "src" / ".env"
load_dotenv(dotenv_path=env_path)

# Import shared utilities
from scripts.validation.payment_split.utils.sql_export_utils import (
    DateRange, apply_date_parameters, read_sql_file, sanitize_table_name,
    extract_queries_with_markers, extract_all_queries_generic,
    export_to_csv, print_summary
)

# Import other required modules
from src.connections.factory import ConnectionFactory, get_valid_databases

def init_logging():
    """Initialize basic console logging for startup messages.
    This will be replaced by setup_logging() later.
    """
    # Clean up any existing handlers
    root_logger = logging.getLogger()
    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)
    
    # Add a single console handler
    console_handler = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    console_handler.setFormatter(formatter)
    root_logger.setLevel(logging.INFO)
    root_logger.addHandler(console_handler)

# Initialize basic logging
init_logging()

# Load environment variables from src/.env
env_path = src_path / "src" / ".env"
load_dotenv(dotenv_path=env_path)
logging.info(f"Loading environment from: {env_path}")

# Constants
SCRIPT_DIR = Path(__file__).parent
QUERY_PATH = SCRIPT_DIR / "queries" / "unearned_income_report.sql"
DATA_DIR = SCRIPT_DIR / "data" / "unearned_income"
LOG_DIR = SCRIPT_DIR / "logs"

# Use a query prefix for consistent file naming
QUERY_PREFIX = "unearned_income"

def extract_all_queries(full_sql: str, date_range: DateRange) -> Dict[str, str]:
    """
    Extract each query from the unearned income SQL file
    
    This function handles the structure of the unearned income SQL file,
    which may contain multiple queries with Common Table Expressions (CTEs).
    
    Args:
        full_sql: String containing all SQL queries (with date parameters already applied)
        date_range: DateRange object for date parameter substitution
        
    Returns:
        Dictionary mapping query names to query strings
    """
    queries = {}
    
    # Note: Date parameters should already be applied to the entire SQL file before calling this function
    # We no longer apply date parameters here to avoid duplicate replacements
    
    # Extract CTE preamble - from the beginning of the file to the first query marker
    # This includes SET statements and WITH clauses that need to be included with each query
    cte_preamble = ""
    first_marker_match = re.search(r'-- QUERY_NAME:', full_sql)
    if first_marker_match:
        cte_preamble = full_sql[:first_marker_match.start()].strip()
    
    # Try to extract using markers
    pattern = r'-- QUERY_NAME:\s+(\w+)(?:\s*\n|\r\n?)(.*?)(?=-- QUERY_NAME:|$)'
    matches = re.finditer(pattern, full_sql, re.DOTALL)
    
    for match in matches:
        query_name = match.group(1).strip()
        query_sql = match.group(2).strip()
        
        # If the query doesn't already have a WITH clause but needs the CTEs,
        # prepend the CTE preamble
        if cte_preamble and not query_sql.lstrip().upper().startswith(('WITH', 'SELECT')):
            # If the preamble already has WITH clause, use it directly
            if 'WITH' in cte_preamble:
                combined_sql = f"{cte_preamble}\n{query_sql}"
            else:
                combined_sql = query_sql
            queries[query_name] = combined_sql
        else:
            queries[query_name] = query_sql
        
        logging.info(f"Extracted query '{query_name}': {query_name}")
    
    # If no queries were found with markers, try fallback to the entire file
    if not queries:
        # Extract the first comment as the title (if present)
        title_match = re.search(r'^--\s*(.*?)$', full_sql, re.MULTILINE)
        title = title_match.group(1).strip() if title_match else 'Unearned Income Report'
        
        # Use a sanitized version of the first line comment as the query name
        query_name = 'unearned_income_report'
        
        # Store the entire SQL as one query
        queries[query_name] = full_sql
        
        logging.info(f"Extracted query '{query_name}': {title}")
    
    # Log the query names and titles for debugging
    if queries:
        logging.info("Query name to title mapping:")
        for name, sql in queries.items():
            # Extract the first comment line as a title
            title_match = re.search(r'^--\s*(.*?)$', sql, re.MULTILINE)
            title = title_match.group(0) if title_match else name
            logging.info(f"  - {name} -> {title}")
    
    return queries


def execute_query(connection, db_name, query_name, query, output_dir=None):
    """
    Execute a query and return the results as a DataFrame
    
    Args:
        connection: Database connection factory
        db_name: Database name
        query_name: Name of the query
        query: SQL query to execute
        output_dir: Optional output directory for CSV export
    
    Returns:
        Tuple of (DataFrame, csv_path)
    """
    df = None
    csv_path = None
    
    try:
        # Remove comments from the query to avoid issues
        query_without_headers = re.sub(r'--.*?$', '', query, flags=re.MULTILINE)
        
        # Connect to the database
        conn = connection.get_connection()
        cursor = conn.cursor(dictionary=True)
        
        # Execute the query
        logging.info(f"Executing query '{query_name}'")
        cursor.execute(query_without_headers)
        
        # Fetch the results
        rows = cursor.fetchall()
        logging.info(f"Query '{query_name}' returned {len(rows)} rows")
        
        # Create a DataFrame from the results
        if rows:
            df = pd.DataFrame(rows)
            
            # Export to CSV if an output directory is provided
            if output_dir and df is not None and not df.empty:
                csv_path = export_to_csv(
                    df, 
                    output_dir, 
                    query_name, 
                    prefix=QUERY_PREFIX, 
                    include_date=False  # Unearned income uses fixed descriptive names
                )
        
        cursor.close()
        
    except Exception as e:
        logging.error(f"Error executing query '{query_name}': {e}")
        logging.error(f"Query: {query_without_headers[:500]}...")  # Log first 500 chars of query
        
    return df, csv_path


def extract_report_data(from_date='2025-01-01', to_date='2025-02-28', db_name=None):
    """
    Extract and export unearned income data
    
    Args:
        from_date: Start date in YYYY-MM-DD format
        to_date: End date in YYYY-MM-DD format
        db_name: Database name to connect to (optional)
        
    Returns:
        Dictionary of query results
    """
    # Read SQL file
    sql_file = QUERY_PATH
    output_dir = DATA_DIR
    
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Convert string dates to DateRange object
    date_range = DateRange.from_strings(from_date, to_date)
    logging.info(f"Using date range: {from_date} to {to_date}")
    
    # Read SQL file contents
    full_sql = read_sql_file(sql_file)
    
    # Apply date parameters to the SQL file
    # This replaces the @FromDate and @ToDate variables in the SQL with the actual date values
    logging.info(f"Replacing SQL date parameters with from_date={from_date}, to_date={to_date}")
    full_sql = apply_date_parameters(full_sql, date_range)
    
    # Extract all queries
    queries = extract_all_queries(full_sql, date_range)
    
    if not queries:
        logging.error("No queries extracted from SQL file")
        return {}
    
    # Verify database name is provided
    if not db_name:
        error_msg = "No database specified. Please provide a valid database name with --database parameter."
        logging.error(error_msg)
        print(f"Error: {error_msg}")
        valid_dbs = get_valid_databases('LOCAL_VALID_DATABASES')
        if valid_dbs:
            print(f"Valid databases: {', '.join(valid_dbs)}")
        return {}
    
    # Connect to the database
    logging.info(f"Connecting to database: {db_name}")
    connection = ConnectionFactory.create_connection('local_mariadb', database=db_name)
    
    # Execute each query and store results
    query_results = {}
    
    for query_name, query in queries.items():
        logging.info(f"Processing query: '{query_name}'")
        
        # Execute the query
        df, csv_path = execute_query(connection, db_name, query_name, query, output_dir)
        
        # Store results
        result = {
            'status': 'SUCCESS' if df is not None and not df.empty else 'FAILED',
            'rows': len(df) if df is not None else 0,
            'output_file': csv_path
        }
        
        query_results[query_name] = result
    
    return query_results


def setup_logging():
    """Configure complete logging for the script, replacing the initial setup.
    
    This configures both file and console logging with proper formatting.
    The file logger uses a timestamp in the filename to create unique log files.
    """
    # Create log directory if it doesn't exist
    os.makedirs(LOG_DIR, exist_ok=True)
    
    # Set up logging with timestamp in filename
    log_file = LOG_DIR / f"unearned_income_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
    
    # Clear existing handlers from init_logging()
    root_logger = logging.getLogger()
    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)
    
    # Configure new handlers
    file_handler = logging.FileHandler(log_file)
    console_handler = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    file_handler.setFormatter(formatter)
    console_handler.setFormatter(formatter)
    
    root_logger.setLevel(logging.INFO)
    root_logger.addHandler(file_handler)
    root_logger.addHandler(console_handler)
    
    logging.info(f"Logging to {log_file}")
    return log_file


def main():
    """Main function to run the export process"""
    # Set up logging
    log_file = setup_logging()
    
    # Get list of valid databases
    valid_databases = get_valid_databases('LOCAL_VALID_DATABASES')
    default_database = os.getenv('MARIADB_DATABASE')
    
    # Parse command-line arguments
    parser = argparse.ArgumentParser(description='Export Unearned Income Data')
    parser.add_argument('--from-date', default='2025-01-01', 
                        help='Start date (YYYY-MM-DD) - Will replace @FromDate in SQL')
    parser.add_argument('--to-date', default='2025-02-28', 
                        help='End date (YYYY-MM-DD) - Will replace @ToDate in SQL')
    
    # Show valid databases in help text
    db_help = f"Database name (optional, default: {default_database}). Valid options: {', '.join(valid_databases)}" if valid_databases else "Database name"
    parser.add_argument('--database', help=db_help, default=default_database)
    
    args = parser.parse_args()
    
    # Validate database - if not specified, use the default from env
    if not args.database:
        if default_database:
            args.database = default_database
            logging.info(f"Using default database from environment: {default_database}")
        else:
            logging.error("No database specified and no default found in environment")
            print("Error: No database specified and no default found in environment")
            if valid_databases:
                print(f"Please specify one of: {', '.join(valid_databases)}")
            return  # Exit early if no database is specified
    
    if valid_databases and args.database not in valid_databases:
        logging.error(f"Invalid database: {args.database}. Valid options: {', '.join(valid_databases)}")
        print(f"Error: Invalid database. Valid options: {', '.join(valid_databases)}")
        return  # Exit early if database is invalid
    
    logging.info("="*80)
    logging.info("STARTING EXPORT PROCESS: UNEARNED INCOME DATA")
    logging.info(f"SQL file: {QUERY_PATH.resolve()}")
    logging.info(f"Output directory: {DATA_DIR.resolve()}")
    logging.info(f"Date range: {args.from_date} to {args.to_date}")
    logging.info(f"Database: {args.database}")
    logging.info("="*80)
    
    # Extract and export data
    query_results = extract_report_data(
        from_date=args.from_date,
        to_date=args.to_date,
        db_name=args.database
    )
    
    # Only print summary if we have results
    if query_results:
        logging.info("="*80)
        logging.info("EXPORT PROCESS COMPLETE")
        logging.info(f"Total queries executed: {len(query_results)}")
        logging.info(f"Successfully exported queries: {sum(1 for r in query_results.values() if r.get('status') == 'SUCCESS')}")
        logging.info(f"Total rows exported: {sum(r.get('rows', 0) for r in query_results.values())}")
        logging.info("="*80)
        
        # Print detailed summary
        print_summary(query_results, DATA_DIR, "UNEARNED INCOME DATA")
    else:
        logging.error("Export process failed or no results returned")
        print("\nExport process failed. Check the logs for details.")


if __name__ == "__main__":
    main() 