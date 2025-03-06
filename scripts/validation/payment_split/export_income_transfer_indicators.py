#!/usr/bin/env python
"""
Export Income Transfer Indicators

This script executes all queries in the income transfer indicators SQL file and 
the unassigned provider transactions SQL file, exporting the results to separate 
CSV files. It focuses on analyzing provider assignment issues, particularly 
transactions where ProvNum = 0 (unassigned provider).

Output Files Generated:
-----------------------
All files are stored in scripts/validation/payment_split/data/income_transfer_indicators/
and include the current date in YYYYMMDD format in the filename:

From income_transfer_indicators.sql:
1. income_transfer_recent_procedures_for_patients_with_unassigned_payments_YYYYMMDD.csv
   - Shows recent procedures for patients with unassigned payments
2. income_transfer_user_groups_creating_unassigned_payments_YYYYMMDD.csv
   - Identifies users and groups creating unassigned provider transactions
3. income_transfer_payment_sources_for_unassigned_transactions_YYYYMMDD.csv
   - Analyzes payment types associated with unassigned transactions
4. income_transfer_appointments_near_payment_date_YYYYMMDD.csv
   - Identifies appointments near payment dates to determine likely providers
5. income_transfer_time_patterns_by_hour_YYYYMMDD.csv
   - Analyzes unassigned transactions by hour of day
6. income_transfer_time_patterns_by_day_YYYYMMDD.csv
   - Analyzes unassigned transactions by day of week
7. income_transfer_time_patterns_by_month_YYYYMMDD.csv
   - Analyzes unassigned transactions by month
8. income_transfer_detailed_payment_information_YYYYMMDD.csv
   - Provides detailed information about specific unassigned transactions

From unassigned_provider_transactions.sql:
9. income_transfer_unassigned_provider_transactions_YYYYMMDD.csv
   - Comprehensive report of all unassigned provider transactions
   - Includes priority classification and suggested provider assignments

Use Case:
---------
This script is specifically designed for operational workflow improvements related to 
provider assignment. It helps identify providers who should be assigned to income 
transactions by analyzing:
- Which users/groups create unassigned transactions
- Payment types associated with unassigned transactions
- Patient appointments and procedures that can suggest the correct provider

Key Differences from Unearned Income Export:
- Focuses on provider assignment (ProvNum = 0) rather than UnearnedType accounting
- Uses multiple independent queries with specific analytical purposes
- Outputs are specifically for operational decision-making about provider assignment

Usage:
    python export_income_transfer_indicators.py [--start-date YYYY-MM-DD] [--end-date YYYY-MM-DD] [--database DB_NAME]

Requirements:
    - .env file must be set up in the project root with MariaDB configuration
    - SQL files should have QUERY_NAME markers for proper extraction
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
from typing import Optional, Tuple, List, Dict, NamedTuple, Any
from dotenv import load_dotenv

# Configure basic logging first (will be properly configured in setup_logging)
logging.getLogger().setLevel(logging.INFO)
handler = logging.StreamHandler()
handler.setFormatter(logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s'))
logging.getLogger().addHandler(handler)

# Add the src directory to the path to import project modules
src_path = Path(__file__).resolve().parents[3]
sys.path.append(str(src_path))

# Load environment variables from src/.env
env_path = src_path / "src" / ".env"
load_dotenv(dotenv_path=env_path)
logging.info(f"Loading environment from: {env_path}")

# Import shared utilities
from scripts.validation.payment_split.utils.sql_export_utils import (
    DateRange, apply_date_parameters, read_sql_file, sanitize_table_name,
    extract_queries_with_markers, extract_all_queries_generic,
    export_to_csv, print_summary
)

# Import other required modules
from src.connections.factory import ConnectionFactory, get_valid_databases
from scripts.base.index_manager import sanitize_table_name as get_db_index_info

# Constants
SCRIPT_DIR = Path(__file__).parent
INDICATORS_QUERY_PATH = SCRIPT_DIR / "queries" / "income_transfer_indicators.sql"
UNASSIGNED_QUERY_PATH = SCRIPT_DIR / "queries" / "unassigned_provider_transactions.sql"
DATA_DIR = SCRIPT_DIR / "data" / "income_transfer_indicators"
LOG_DIR = SCRIPT_DIR / "logs"

# Use a query prefix for consistent file naming
QUERY_PREFIX = "income_transfer"

def extract_all_queries(full_sql: str, date_range: DateRange, is_unassigned_provider: bool = False) -> Dict[str, str]:
    """
    Extract each query from the SQL file
    
    Args:
        full_sql: String containing all SQL queries
        date_range: DateRange object for date parameter substitution
        is_unassigned_provider: Whether the SQL is from the unassigned provider transactions file
        
    Returns:
        Dictionary mapping query names to query strings
    """
    # If this is the unassigned provider transactions SQL, handle it differently
    if is_unassigned_provider:
        # Apply date parameters to replace placeholders in the SQL
        sql_with_dates = apply_date_parameters(full_sql, date_range)
        
        # Extract the main union query as a single report
        # The unassigned provider SQL doesn't use QUERY_NAME markers, so we handle it as a single query
        return {"unassigned_provider_transactions": sql_with_dates}
    
    # Otherwise, process income transfer indicators SQL with QUERY_NAME markers
    # First try to extract using the QUERY_NAME markers
    queries = extract_queries_with_markers(full_sql, date_range)
    
    # If no queries were found, fall back to generic extraction
    if not queries:
        logging.warning("No queries found using QUERY_NAME markers. Using generic extraction.")
        queries = extract_all_queries_generic(full_sql, date_range)
        
        # If still no queries, log an error
        if not queries:
            logging.error("Failed to extract any queries from the SQL file")
    
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
        # Also remove SQL comments with /* */ format, which are used in the unassigned provider SQL
        query_without_headers = re.sub(r'/\*.*?\*/', '', query_without_headers, flags=re.DOTALL)
        
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
                    include_date=True
                )
        
        cursor.close()
        
    except Exception as e:
        logging.error(f"Error executing query '{query_name}': {e}")
        logging.error(f"Query: {query_without_headers[:500]}...")  # Log first 500 chars of query
        
    return df, csv_path


def process_sql_file(query_path, date_range, db_name, output_dir, is_unassigned_provider=False):
    """
    Process a single SQL file, extracting and executing all queries
    
    Args:
        query_path: Path to the SQL file
        date_range: DateRange object for date parameter substitution
        db_name: Database name to connect to
        output_dir: Directory for output CSV files
        is_unassigned_provider: Whether this is the unassigned provider transactions SQL
        
    Returns:
        Dictionary of query results
    """
    # Read SQL file contents
    full_sql = read_sql_file(query_path)
    
    # Extract all queries
    queries = extract_all_queries(full_sql, date_range, is_unassigned_provider)
    
    if not queries:
        logging.error(f"No queries extracted from SQL file: {query_path}")
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


def extract_report_data(from_date='2025-01-01', to_date='2025-02-28', db_name=None):
    """
    Extract and export data from both SQL files
    
    Args:
        from_date: Start date in YYYY-MM-DD format
        to_date: End date in YYYY-MM-DD format
        db_name: Database name to connect to (optional)
        
    Returns:
        Dictionary of query results from both SQL files
    """
    output_dir = DATA_DIR
    
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Convert string dates to DateRange object
    date_range = DateRange.from_strings(from_date, to_date)
    logging.info(f"Using date range: {from_date} to {to_date}")
    
    # Verify database name is provided
    if not db_name:
        error_msg = "No database specified. Please provide a valid database name with --database parameter."
        logging.error(error_msg)
        print(f"Error: {error_msg}")
        valid_dbs = get_valid_databases('LOCAL_VALID_DATABASES')
        if valid_dbs:
            print(f"Valid databases: {', '.join(valid_dbs)}")
        return {}
    
    # Process both SQL files and combine results
    all_results = {}
    
    # 1. Process income transfer indicators SQL
    logging.info("="*80)
    logging.info("PROCESSING: INCOME TRANSFER INDICATORS")
    logging.info(f"SQL file: {INDICATORS_QUERY_PATH.resolve()}")
    logging.info("="*80)
    
    indicators_results = process_sql_file(
        INDICATORS_QUERY_PATH,
        date_range,
        db_name,
        output_dir,
        is_unassigned_provider=False
    )
    all_results.update(indicators_results)
    
    # 2. Process unassigned provider transactions SQL
    logging.info("="*80)
    logging.info("PROCESSING: UNASSIGNED PROVIDER TRANSACTIONS")
    logging.info(f"SQL file: {UNASSIGNED_QUERY_PATH.resolve()}")
    logging.info("="*80)
    
    unassigned_results = process_sql_file(
        UNASSIGNED_QUERY_PATH,
        date_range,
        db_name,
        output_dir,
        is_unassigned_provider=True
    )
    all_results.update(unassigned_results)
    
    return all_results


def setup_logging():
    """Configure logging for the script"""
    # Create log directory if it doesn't exist
    os.makedirs(LOG_DIR, exist_ok=True)
    
    # Set up logging with timestamp in filename
    log_file = LOG_DIR / f"income_transfer_indicators_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
    
    # Reset logging configuration
    for handler in logging.root.handlers[:]:
        logging.root.removeHandler(handler)
    
    # Configure logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_file),
            logging.StreamHandler()
        ]
    )
    
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
    parser = argparse.ArgumentParser(description='Export Income Transfer Indicators and Unassigned Provider Transactions')
    parser.add_argument('--start-date', default='2025-01-01', help='Start date (YYYY-MM-DD)')
    parser.add_argument('--end-date', default='2025-02-28', help='End date (YYYY-MM-DD)')
    
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
    logging.info("STARTING EXPORT PROCESS: INCOME TRANSFER AND UNASSIGNED PROVIDER REPORTS")
    logging.info(f"Output directory: {DATA_DIR.resolve()}")
    logging.info(f"Date range: {args.start_date} to {args.end_date}")
    logging.info(f"Database: {args.database}")
    logging.info("="*80)
    
    # Extract and export data from both SQL files
    query_results = extract_report_data(
        from_date=args.start_date,
        to_date=args.end_date,
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
        print_summary(query_results, DATA_DIR, "INCOME TRANSFER AND UNASSIGNED PROVIDER REPORTS")
    else:
        logging.error("Export process failed or no results returned")
        print("\nExport process failed. Check the logs for details.")


if __name__ == "__main__":
    main() 