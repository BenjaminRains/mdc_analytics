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
    - SQL files should be available in the queries directory
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
from scripts.validation_development.payment_process.utils.sql_export_utils import (
    DateRange, apply_date_parameters, read_sql_file, sanitize_table_name,
    extract_queries_with_markers, extract_all_queries_generic,
    export_to_csv, print_summary
)

# Import other required modules
from src.connections.factory import ConnectionFactory, get_valid_databases
from scripts.validation_development.index_manager import sanitize_table_name as get_db_index_info

# Constants
SCRIPT_DIR = Path(__file__).parent
QUERIES_DIR = SCRIPT_DIR / "queries"
DATA_DIR = SCRIPT_DIR / "data" / "income_transfer_indicators"
LOG_DIR = SCRIPT_DIR / "logs"

# Dictionary mapping query names to their file paths
QUERIES = {
    "recent_procedures_for_patients_with_unassigned_payments": QUERIES_DIR / "income_trans_recent_procs_unassigned_pay.sql",
    "user_groups_creating_unassigned_payments": QUERIES_DIR / "income_trans_users_unassigned_pay.sql",
    "payment_sources_for_unassigned_transactions": QUERIES_DIR / "income_trans_pay_sources_unassigned.sql",
    "appointments_near_payment_date": QUERIES_DIR / "income_trans_appts_near_payment_date.sql",
    "time_patterns_by_day": QUERIES_DIR / "income_trans_patterns_day.sql",
    "time_patterns_by_month": QUERIES_DIR / "income_trans_patterns_by_month.sql",
    "detailed_payment_information": QUERIES_DIR / "income_trans_detailed_payment_info.sql",
    "unassigned_provider_transactions": QUERIES_DIR / "income_trans_unassigned_prov_trans.sql"
}

def extract_all_queries(date_range: DateRange) -> Dict[str, Dict[str, Any]]:
    """
    Extract all queries from individual SQL files
    
    Args:
        date_range: DateRange object for date parameter substitution
        
    Returns:
        Dictionary mapping query names to a dictionary containing query string and file path
    """
    queries = {}
    
    for query_name, query_path in QUERIES.items():
        try:
            # Read the SQL file
            logging.info(f"Reading SQL file: {query_path}")
            sql_content = read_sql_file(query_path)
            
            # Apply date parameters to replace placeholders in the SQL
            sql_with_dates = apply_date_parameters(sql_content, date_range)
            
            # Store the query and its file path
            queries[query_name] = {
                "query": sql_with_dates,
                "path": query_path
            }
            
        except Exception as e:
            logging.error(f"Error reading SQL file {query_path}: {e}")
    
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
                    prefix="income_transfer", 
                    include_date=True
                )
        
        cursor.close()
        
    except Exception as e:
        logging.error(f"Error executing query '{query_name}': {e}")
        logging.error(f"Query: {query_without_headers[:500]}...")  # Log first 500 chars of query
        
    return df, csv_path


def process_queries(date_range, db_name, output_dir):
    """
    Process all SQL queries
    
    Args:
        date_range: DateRange object for date parameter substitution
        db_name: Database name to connect to
        output_dir: Directory for output CSV files
        
    Returns:
        Dictionary of query results
    """
    # Extract all queries
    queries_data = extract_all_queries(date_range)
    
    if not queries_data:
        logging.error("No queries extracted from SQL files")
        return {}
    
    # Connect to the database
    logging.info(f"Connecting to database: {db_name}")
    connection = ConnectionFactory.create_connection('local_mariadb', database=db_name)
    
    # Execute each query and store results
    query_results = {}
    
    for query_name, query_info in queries_data.items():
        logging.info(f"Processing query: '{query_name}'")
        logging.info(f"SQL file: {query_info['path']}")
        
        # Execute the query
        df, csv_path = execute_query(connection, db_name, query_name, query_info['query'], output_dir)
        
        # Store results
        result = {
            'status': 'SUCCESS' if df is not None and not df.empty else 'FAILED',
            'rows': len(df) if df is not None else 0,
            'output_file': csv_path,
            'source_file': str(query_info['path'])
        }
        
        query_results[query_name] = result
    
    return query_results


def extract_report_data(from_date='2025-01-01', to_date='2025-02-28', db_name=None):
    """
    Extract and export data from all SQL files
    
    Args:
        from_date: Start date in YYYY-MM-DD format
        to_date: End date in YYYY-MM-DD format
        db_name: Database name to connect to (optional)
        
    Returns:
        Dictionary of query results from all SQL files
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
    
    # Process all SQL queries
    logging.info("="*80)
    logging.info("PROCESSING: INCOME TRANSFER INDICATORS")
    logging.info("="*80)
    
    query_results = process_queries(
        date_range,
        db_name,
        output_dir
    )
    
    return query_results


def setup_logging():
    """Configure logging for the script"""
    # Create log directory if it doesn't exist
    os.makedirs(LOG_DIR, exist_ok=True)
    
    # Set up logging with timestamp in filename
    log_file = LOG_DIR / f"log_income_transfer_indicators_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
    
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
    logging.info("STARTING EXPORT PROCESS: INCOME TRANSFER INDICATORS")
    logging.info(f"Output directory: {DATA_DIR.resolve()}")
    logging.info(f"Date range: {args.start_date} to {args.end_date}")
    logging.info(f"Database: {args.database}")
    logging.info("="*80)
    
    # Extract and export data from all SQL files
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
        print_summary(query_results, DATA_DIR, "INCOME TRANSFER INDICATORS")
    else:
        logging.error("Export process failed or no results returned")
        print("\nExport process failed. Check the logs for details.")


if __name__ == "__main__":
    main() 