#!/usr/bin/env python3
"""
Export Payment Split Validation Data

This script connects to the specified database, ensures required indexes exist,
loads a set of common table expressions (CTEs) from a separate file, and executes
a series of SQL queries for payment split validation. The results for each query
are exported to separate CSV files. The files are then analyzed in notebooks to
identify and diagnose issues.

Usage:
    python export_payment_split_validation.py --start-date <YYYY-MM-DD> --end-date <YYYY-MM-DD>
                                                [--output-dir <path>] [--log-dir <path>]
                                                [--database <dbname>] [--queries <names>]
                                                [--connection-type <type>]
                                                [--parallel]

NOTE: The --start-date and --end-date parameters are REQUIRED. All data will be filtered 
to this date range, ensuring consistent results across all validation queries.

The list of queries and the common CTE definitions are stored as separate .sql files in
the 'queries' directory. The CTE file is prepended to each query before execution.
"""

import os
import logging
import pandas as pd
from datetime import datetime, date
import re
import sys
from pathlib import Path
import argparse
import concurrent.futures
from typing import NamedTuple, Dict, List, Any, Optional, Union
import time
from concurrent.futures import ProcessPoolExecutor

# Configure basic logging until we can set up proper logging
logging.basicConfig(level=logging.INFO, 
                   format='%(asctime)s - %(levelname)s - %(message)s')

# Add base directory to path for relative imports if needed
script_dir = os.path.dirname(os.path.abspath(__file__))
base_dir = os.path.abspath(os.path.join(script_dir, '../..'))
if base_dir not in sys.path:
    sys.path.insert(0, base_dir)

# Import DateRange from utils module instead of defining it
from scripts.validation.payment_split.utils.sql_export_utils import DateRange, apply_date_parameters

# Utility functions
def read_sql_file(file_path: str) -> str:
    """Read the contents of a SQL file."""
    try:
        with open(file_path, 'r') as f:
            return f.read()
    except Exception as e:
        logging.error(f"Error reading SQL file {file_path}: {str(e)}")
        return ""

# Import from appropriate locations based on project structure
from scripts.base.index_manager import IndexManager

# Import the ConnectionFactory directly without fallbacks
from src.connections.factory import ConnectionFactory, get_valid_databases

# Get the list of valid databases from environment
try:
    valid_databases = get_valid_databases('LOCAL_VALID_DATABASES')
except Exception as e:
    logging.warning(f"Could not get valid databases list: {str(e)}")
    valid_databases = []
    logging.warning("Permission checks will be skipped.")

# Get default database from environment
default_database = os.getenv('MARIADB_DATABASE')
if not default_database and valid_databases:
    default_database = valid_databases[0]  # Use first valid database as default if available

# Query descriptions to provide context on what each query analyzes
QUERY_DESCRIPTIONS = {
    'summary': 'High-level summary of payment splits and associated metrics',
    'base_counts': 'Basic count statistics of payments and procedures',
    'source_counts': 'Analysis of payment sources and their distribution',
    'filter_summary': 'Summary of how filters affect the dataset',
    'diagnostic': 'Detailed diagnostic information for troubleshooting',
    'verification': 'Verification of data integrity and consistency',
    'problems': 'Identification of potential issues in payment splits',
    'duplicate_joins': 'Analysis of duplicate join conditions',
    'join_stages': 'Progression of join operations and their effects',
    'daily_patterns': 'Day-by-day analysis of payment patterns',
    'payment_details': 'Detailed information about individual payments',
    'containment': 'Analysis of payment containment relationships',
}

def setup_logging(log_dir='scripts/validation/payment_split/logs'):
    """Set up logging to file and console."""
    # Ensure log directory exists
    os.makedirs(log_dir, exist_ok=True)
    
    # Set up timestamp for log filename
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(log_dir, f"payment_validation_{timestamp}.log")
    
    # Reset logging configuration
    for handler in logging.root.handlers[:]:
        logging.root.removeHandler(handler)
    
    # Configure logging
    logging.basicConfig(
        level=logging.INFO,  # Root logger level set to INFO
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            # File handler with DEBUG level for detailed troubleshooting
            logging.FileHandler(log_file),
            # Console handler with INFO level
            logging.StreamHandler()
        ]
    )
    
    # Set file handler to DEBUG level to capture detailed logs
    logging.getLogger().handlers[0].setLevel(logging.DEBUG)
    # Set console handler to INFO level for cleaner output
    logging.getLogger().handlers[1].setLevel(logging.INFO)
    
    logging.info(f"Logging configured - writing detailed logs to {log_file}")
    return log_file

def ensure_directory_exists(directory):
    """Create directory if it doesn't exist."""
    Path(directory).mkdir(parents=True, exist_ok=True)
    logging.info(f"Ensured directory exists: {directory}")

def load_query_file(query_name: str) -> str:
    """Load a query from the queries directory using pathlib."""
    query_path = Path(__file__).parent / 'queries' / f'{query_name}.sql'
    return read_sql_file(query_path)

def get_ctes(date_range: DateRange = None) -> str:
    """
    Load and combine all CTE SQL files.
    
    Args:
        date_range: DateRange object with start and end dates
        
    Returns:
        Combined CTEs SQL string
    """
    # Require a DateRange to be provided
    if date_range is None:
        raise ValueError("Date range must be provided")
    
    # Get the queries/ctes directory
    ctes_dir = Path(os.path.dirname(os.path.abspath(__file__))) / 'queries' / 'ctes'
    if not ctes_dir.exists():
        logging.warning(f"CTE directory not found: {ctes_dir}")
        return ""
    
    # Define preferred loading order for CTEs based on actual filenames
    preferred_order = [
        "base_payments.sql",              # Base payments table
        "base_splits.sql",                # Base splits table
        "payment_summary.sql",            # Payment summary metrics
        "payment_method_analysis.sql",    # Payment method analysis
        "payment_source_categories.sql",  # Payment source categories
        "payment_source_summary.sql",     # Payment source summary
        "total_payments.sql",             # Total payment metrics
        "insurance_payment_analysis.sql", # Insurance payment analysis
        "procedure_payments.sql",         # Procedure payment analysis
        "split_pattern_analysis.sql",     # Split pattern analysis
        "payment_base_counts.sql",        # Payment base counts
        "payment_join_diagnostics.sql",   # Payment join diagnostics
        "payment_filter_diagnostics.sql", # Payment filter diagnostics
        "join_stage_counts.sql",          # Join stage counts
        "suspicious_split_analysis.sql",  # Suspicious split analysis
        "payment_details_base.sql",       # Payment details base
        "payment_details_metrics.sql",    # Payment details metrics
        "payment_daily_details.sql",      # Payment daily details
        "filter_stats.sql",               # Filter statistics
        "problem_payments.sql",           # Problem payments
        "claim_metrics.sql",              # Claim metrics
        "problem_claim_details.sql"       # Problem claim details
    ]
    
    # Get all SQL files in the directory
    all_files = list(ctes_dir.glob('*.sql'))
    logging.info(f"Found {len(all_files)} CTE files in {ctes_dir}")
    
    # Filter out date_range.sql if we're handling dates via variables
    all_files = [f for f in all_files if f.name != 'date_range.sql']
    
    # Sort files based on preferred order, then alphabetically for the rest
    def sort_key(file):
        filename = file.name
        if filename in preferred_order:
            return (0, preferred_order.index(filename))
        return (1, filename.lower())  # Use tuple for sorting, with first element indicating priority
    
    # Sort the files
    sorted_files = sorted(all_files, key=sort_key)
    logging.debug(f"Sorted {len(sorted_files)} CTE files for processing")
    
    # Combine all CTEs
    all_ctes = []
    for cte_file in sorted_files:
        try:
            # Read the file contents
            cte_content = read_sql_file(str(cte_file))
            
            # Apply date parameters
            if cte_content:
                cte_content = apply_date_parameters(cte_content, date_range)
                
                # Add a comment indicating the source file
                cte_with_comment = f"""
-- From {cte_file.name}
{cte_content}"""
                all_ctes.append(cte_with_comment)
                logging.debug(f"Added CTE from {cte_file.name}")
        except Exception as e:
            logging.error(f"Error loading CTE file {cte_file}: {str(e)}")
    
    # Join all CTEs with appropriate separators
    combined_ctes = ""
    for i, cte in enumerate(all_ctes):
        if i > 0:
            # If not the first CTE, add a comma and newline before it
            combined_ctes += ",\n"
        combined_ctes += cte.strip()
    
    logging.info(f"Combined {len(all_ctes)} CTEs into query structure")
    
    return combined_ctes

def get_query(query_name: str, ctes: str = None, date_range: DateRange = None) -> dict:
    """
    Load a query by name and apply date parameters and CTEs.
    
    Args:
        query_name: Name of the query file (without .sql extension)
        ctes: Common Table Expressions to add to the query
        date_range: DateRange object with start and end dates
        
    Returns:
        Dict with query configuration
    """
    # Find the query file
    query_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'queries', f"{query_name}.sql")
    
    # Check if file exists
    if not os.path.exists(query_path):
        error_msg = f"Query file not found: {query_name}.sql at {query_path}"
        logging.error(error_msg)
        return {
            'name': query_name,
            'file': f"{query_name}.csv",
            'query': f"SELECT '{error_msg}' AS error_message",
        }
    
    # Load query content
    try:
        logging.info(f"Loading query file: {query_path}")
        query_content = read_sql_file(query_path)
    except Exception as e:
        error_msg = f"Error reading query file {query_name}.sql: {str(e)}"
        logging.error(error_msg)
        return {
            'name': query_name,
            'file': f"{query_name}.csv",
            'query': f"SELECT '{error_msg}' AS error_message",
        }
    
    # Check if query is empty
    if not query_content.strip():
        error_msg = f"Query file is empty: {query_name}.sql"
        logging.error(error_msg)
        return {
            'name': query_name,
            'file': f"{query_name}.csv",
            'query': f"SELECT '{error_msg}' AS error_message",
        }
    
    # Require a DateRange to be provided
    if date_range is None:
        raise ValueError("Date range must be provided")
    
    # Prepare SQL with date parameters and CTEs
    final_query = f"""
-- Set date parameters
SET @start_date = '{date_range.start_date}';
SET @end_date = '{date_range.end_date}';
"""
    
    # Add the WITH clause only if CTEs are provided
    if ctes and ctes.strip():
        logging.info(f"Adding CTEs to query: {query_name}")
        final_query += f"""
-- Common Table Expressions
WITH 
{ctes}

-- Main Query from {query_name}.sql
{query_content}
"""
    else:
        logging.warning(f"No CTEs provided for query: {query_name}")
        final_query += f"""
-- Main Query from {query_name}.sql (no CTEs provided)
{query_content}
"""
    
    logging.info(f"Prepared query for {query_name}")
    
    return {
        'name': query_name,
        'file': f"{query_name}.csv",
        'query': final_query
    }

def get_exports(ctes: str, date_range: DateRange = None) -> list:
    """
    Get the list of export queries to run.
    
    Args:
        ctes: Common Table Expressions string to add to each query
        date_range: DateRange object with start and end dates
        
    Returns:
        List of export configurations
    """
    # Require a DateRange to be provided
    if date_range is None:
        raise ValueError("Date range must be provided")
    
    # Get available export queries
    query_exports = []
    queries_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'queries')
    
    if os.path.isdir(queries_dir):
        # Get all SQL files from the queries directory
        for file_name in sorted(os.listdir(queries_dir)):
            if file_name.endswith('.sql'):
                query_name = os.path.splitext(file_name)[0]
                
                query_exports.append(query_name)
                logging.info(f"Found query file: {file_name}")
    
    if not query_exports:
        # Raise an error when no queries are found
        error_msg = "No query files found in the queries directory"
        logging.error(error_msg)
        raise ValueError(error_msg)
    
    # Create the export configurations
    exports = []
    for query_name in query_exports:
        query_config = get_query(query_name, ctes, date_range)
        exports.append(query_config)
        logging.info(f"Prepared export configuration for: {query_name}")
    
    return exports

def process_single_export(export, connection_type, database, output_dir, date_range):
    """Process a single export query and save results to CSV."""
    start_time = datetime.now()
    connection = None
    mysql_connection = None
    
    try:
        # Create a connection to the database
        logging.info(f"Creating connection to {database} with {connection_type}")
        connection = ConnectionFactory.create_connection(connection_type, database)
        
        if connection is None:
            raise ValueError(f"Failed to create connection to {database}")
        
        # Use get_connection() method as in the working script
        mysql_connection = connection.get_connection()
        if mysql_connection is None:
            raise ValueError(f"Failed to connect to {database}")
            
        # Print connection information for debugging
        logging.debug(f"Connection successful - type: {type(connection).__name__}, mysql_connection: {type(mysql_connection).__name__}")
            
        # Get the query and apply date parameters
        query = export['query']
        
        # Log the full query for debugging (only to file)
        logging.debug(f"===== FULL QUERY FOR {export['name']} =====")
        logging.debug(query)
        logging.debug("========== END FULL QUERY ==========")
        
        # Execute the query with detailed error handling
        with mysql_connection.cursor(dictionary=True) as cursor:
            try:
                # Log that we're about to execute
                logging.info(f"Executing query for {export['name']}")
                
                # First, check if there are SET statements that should be run separately
                set_statements = []
                main_query = []
                for line in query.split('\n'):
                    if line.strip().upper().startswith('SET @'):
                        set_statements.append(line.strip())
                    else:
                        main_query.append(line)
                
                # Execute any SET statements first
                if set_statements:
                    logging.info(f"Executing {len(set_statements)} SET statements")
                    for stmt in set_statements:
                        try:
                            cursor.execute(stmt)
                            logging.info(f"Successfully executed: {stmt}")
                        except Exception as e:
                            logging.error(f"Error executing SET statement {stmt}: {str(e)}")
                            raise
                
                # Now execute the main query
                main_query_text = '\n'.join(main_query)
                logging.info(f"Executing main query for {export['name']}")
                
                try:
                    cursor.execute(main_query_text)
                    logging.info(f"Main query execution complete for {export['name']}")
                except Exception as e:
                    logging.error(f"Error executing main query: {str(e)}")
                    # Log a snippet of the query around where the error might be
                    query_lines = main_query_text.split('\n')
                    for i, line in enumerate(query_lines):
                        if 'WITH' in line.upper() or 'SELECT' in line.upper():
                            context_start = max(0, i - 5)
                            context_end = min(len(query_lines), i + 10)
                            error_context = '\n'.join(query_lines[context_start:context_end])
                            logging.error(f"Query context around line {i+1}:\n{error_context}")
                            break
                    raise
                
                # Check for results
                if hasattr(cursor, 'description'):
                    if cursor.description:
                        column_info = ', '.join(col[0] for col in cursor.description)
                        logging.debug(f"Query returned columns: {column_info}")
                    else:
                        logging.warning(f"Query for {export['name']} returned no columns (cursor.description is empty)")
                else:
                    logging.warning(f"Cursor has no 'description' attribute")
                
                # Fetch results
                results = cursor.fetchall()
                logging.info(f"Query for {export['name']} returned {len(results) if results else 0} rows")
                
                # Check if we got any results back
                if not results or len(results) == 0:
                    # Do a simple test query to verify the database has data
                    test_query = "SELECT COUNT(*) as count FROM payment LIMIT 1"
                    logging.info(f"No results returned. Testing database with: {test_query}")
                    try:
                        cursor.execute(test_query)
                        test_result = cursor.fetchone()
                        if test_result:
                            logging.info(f"Test query shows {test_result['count']} payments in database")
                        else:
                            logging.warning("Test query returned no results - database might be empty")
                    except Exception as e:
                        logging.error(f"Error running test query: {str(e)}")
                
                # Convert to DataFrame
                if results and len(results) > 0:
                    df = pd.DataFrame(results)
                    logging.info(f"DataFrame created with {len(df)} rows and {len(df.columns)} columns")
                    
                    # Save to CSV
                    file_path = os.path.join(output_dir, export['file'])
                    df.to_csv(file_path, index=False)
                    logging.info(f"Results saved to {file_path}")
                    
                    # Return results
                    return {
                        'name': export['name'],
                        'rows': len(df),
                        'columns': len(df.columns),
                        'file': file_path,
                        'success': True,
                        'elapsed': datetime.now() - start_time
                    }
                else:
                    logging.warning(f"No results returned for {export['name']}")
                    return {
                        'name': export['name'],
                        'rows': 0,
                        'columns': 0,
                        'file': None,
                        'success': False,
                        'message': "No results returned",
                        'elapsed': datetime.now() - start_time
                    }
            except Exception as query_error:
                logging.error(f"Error during query execution for {export['name']}: {str(query_error)}")
                raise
    
    except Exception as e:
        logging.error(f"Error processing export {export['name']}: {str(e)}", exc_info=True)
        return {
            'name': export['name'],
            'success': False,
            'message': str(e),
            'elapsed': datetime.now() - start_time
        }
    
    finally:
        if mysql_connection:
            try:
                mysql_connection.close()
                logging.info("Database connection closed")
            except Exception as e:
                logging.warning(f"Error closing connection: {str(e)}")

def export_validation_results(connection_type, database, start_date, end_date,
                         queries=None, output_dir=None, use_parallel=False):
    """
    Run export queries and save results to CSV files.
    
    Args:
        connection_type: Connection type to use
        database: Database to connect to
        start_date: Start date for filtering payments (as string)
        end_date: End date for filtering payments (as string)
        queries: List of query names to run (default: all)
        output_dir: Directory to save results in
        use_parallel: Whether to use parallel processing
    
    Returns:
        Dict with export results
    """
    # Create a DateRange object from the date strings
    date_range = DateRange.from_strings(start_date, end_date)
    
    # Log the date range
    logging.info(f"Using date range: {date_range.start_date} to {date_range.end_date}")
    
    # Make sure indexes exist for efficient queries
    logging.info("Checking and creating required payment validation indexes...")
    try:
        ensure_indexes(database)
    except Exception as e:
        logging.warning(f"Problem with index creation: {str(e)}")
        logging.warning("Continuing without index optimization - queries may be slower")
    
    # Create output directory if it doesn't exist
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)
        logging.info(f"Output directory: {output_dir}")
    
    # Get the export configurations
    ctes = get_ctes(date_range)
    export_config = get_exports(ctes, date_range)
    
    # Filter exports if specific queries were requested
    if queries:
        export_config = [e for e in export_config if e['name'] in queries]
        logging.info(f"Filtered to {len(export_config)} queries: {', '.join(e['name'] for e in export_config)}")
    
    if not export_config:
        logging.warning("No exports configured - nothing to do!")
        return {"success": False, "message": "No exports configured"}
        
    results = []
    
    # Execute exports
    if use_parallel and len(export_config) > 1:
        # Parallel processing for multiple exports
        logging.info(f"Running {len(export_config)} exports in parallel")
        with ProcessPoolExecutor() as executor:
            future_to_export = {
                executor.submit(
                    process_single_export, 
                    export, 
                    connection_type, 
                    database,
                    output_dir,
                    date_range
                ): export['name'] for export in export_config
            }
            
            for future in concurrent.futures.as_completed(future_to_export):
                export_name = future_to_export[future]
                try:
                    result = future.result()
                    results.append(result)
                    logging.info(f"Completed export: {export_name}")
                except Exception as e:
                    logging.error(f"Export {export_name} generated an exception: {str(e)}", exc_info=True)
                    results.append({
                        'name': export_name,
                        'success': False,
                        'message': str(e)
                    })
    else:
        # Sequential processing
        logging.info(f"Running {len(export_config)} exports sequentially")
        for export in export_config:
            logging.info(f"Processing export: {export['name']}")
            result = process_single_export(export, connection_type, database, output_dir, date_range)
            results.append(result)
    
    # Complete export process with summary
    success_count = sum(1 for r in results if r.get('success', False))
    
    # Log summary with visual separator
    logging.info("="*80)
    logging.info(f"EXPORT VALIDATION COMPLETE: {success_count} of {len(results)} successful")
    logging.info(f"Date range: {date_range.start_date} to {date_range.end_date}")
    logging.info(f"Database: {database}")
    logging.info(f"Total exports processed: {len(results)}")
    logging.info(f"Output directory: {output_dir}")
    logging.info("="*80)
    
    return {
        "success": success_count == len(results),
        "results": results,
        "total": len(results),
        "successful": success_count
    }

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description='Export payment validation data to CSV files',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    
    parser.add_argument(
        '--output-dir',
        type=str,
        default=r"C:\Users\rains\mdc_analytics\scripts\validation\payment_split\data\payment_split_validation",
        help='Directory where CSV files will be saved'
    )
    
    parser.add_argument(
        '--log-dir',
        type=str,
        default='scripts/validation/payment_split/logs',
        help='Directory where log files will be saved'
    )
    
    # Show valid databases in help text
    db_help = f"Database name to connect to. Valid options: {', '.join(valid_databases)}" if valid_databases else "Database name to connect to"
    parser.add_argument(
        '--database',
        type=str,
        default=default_database,
        help=db_help + ". DO NOT use the live opendental database."
    )
    
    parser.add_argument(
        '--connection-type',
        type=str,
        default='local_mariadb',
        choices=['local_mariadb', 'local_mysql'],
        help='Type of database connection to use'
    )
    
    parser.add_argument(
        '--queries',
        nargs='+',
        choices=list(QUERY_DESCRIPTIONS.keys()),
        help='Specific queries to run (default: all)'
    )
    
    parser.add_argument(
        '--start-date',
        required=True,
        help='Start date for filtering data (YYYY-MM-DD format) - REQUIRED'
    )
    
    parser.add_argument(
        '--end-date',
        required=True,
        help='End date for filtering data (YYYY-MM-DD format) - REQUIRED'
    )
    
    parser.add_argument(
        '--parallel',
        action='store_true',
        help='Run queries in parallel for faster execution'
    )
    
    return parser.parse_args()

def ensure_indexes(database_name):
    """Ensure required indexes exist for validation queries."""
    logging.info("Checking and creating required payment validation indexes...")
    
    REQUIRED_INDEXES = [
        # Payment Analysis - core indexes
        "CREATE INDEX IF NOT EXISTS idx_ml_payment_core ON payment (PayNum, PayDate)",
        "CREATE INDEX IF NOT EXISTS idx_ml_payment_window ON payment (PayDate)",
        
        # Payment Split Analysis
        "CREATE INDEX IF NOT EXISTS idx_ml_paysplit_payment ON paysplit (ProcNum, PayNum, SplitAmt)",
        "CREATE INDEX IF NOT EXISTS idx_ml_paysplit_proc_pay ON paysplit (ProcNum, PayNum, SplitAmt)",
        "CREATE INDEX IF NOT EXISTS idx_ml_paysplit_paynum ON paysplit (PayNum)",
        "CREATE INDEX IF NOT EXISTS idx_ml_paysplit_procnum ON paysplit (ProcNum)",
        
        # Insurance Processing
        "CREATE INDEX IF NOT EXISTS idx_ml_claimproc_core ON claimproc (ProcNum, InsPayAmt, InsPayEst, Status, ClaimNum)",
        "CREATE INDEX IF NOT EXISTS idx_ml_claimproc_procnum ON claimproc (ProcNum)",
        "CREATE INDEX IF NOT EXISTS idx_ml_claimproc_status ON claimproc (Status)",
        
        # Supporting lookups
        "CREATE INDEX IF NOT EXISTS idx_ml_claim_lookup ON claim (ClaimNum)"
    ]
    
    try:
        manager = IndexManager(database_name)  # Pass database name instead of connection
        
        # Show existing indexes before creation
        logging.info("Current payment-related indexes:")
        manager.show_custom_indexes()
        
        # Create only the required indexes
        logging.info("Creating required payment validation indexes...")
        manager.create_indexes(REQUIRED_INDEXES)
        
        # Verify indexes after creation
        logging.info("Verifying indexes after creation:")
        manager.show_custom_indexes()
        
        logging.info("Payment validation index creation complete")
    except Exception as e:
        logging.error(f"Error creating indexes: {str(e)}", exc_info=True)

def main():
    try:
        # Parse arguments
        args = parse_args()
        
        # Set up logging
        setup_logging(args.log_dir)
        
        # Log execution parameters with visual separators for better readability
        logging.info("="*80)
        logging.info("STARTING PAYMENT VALIDATION EXPORT PROCESS")
        logging.info(f"Date range: {args.start_date} to {args.end_date}")
        logging.info(f"Database: {args.database}")
        logging.info(f"Connection type: {args.connection_type}")
        logging.info(f"Output directory: {args.output_dir}")
        if args.queries:
            logging.info(f"Selected queries: {', '.join(args.queries)}")
        else:
            logging.info("Running all available queries")
        logging.info(f"Parallel execution: {'Enabled' if args.parallel else 'Disabled'}")
        logging.info("="*80)
        
        # Create a DateRange object from the required date parameters
        date_range = DateRange.from_strings(args.start_date, args.end_date)
        
        # Validate against allowed databases
        if valid_databases and args.database not in valid_databases:
            logging.error(f"Invalid database name: {args.database}")
            print(f"Error: Invalid database name. Must be one of: {', '.join(valid_databases)}")
            return
            
        try:
            # Create initial connection for index check
            connection = ConnectionFactory.create_connection(args.connection_type, args.database)
            
            if connection is None:
                logging.error(f"Failed to create connection to {args.database}")
                print(f"Error: Failed to create connection to {args.database}")
                return
                
            # Verify connection works
            mysql_connection = connection.get_connection()
            if mysql_connection is None:
                logging.error(f"Failed to connect to {args.database}")
                print(f"Error: Failed to connect to {args.database}")
                return
                
            # Close the connection
            mysql_connection.close()
            logging.info("Database connection validated successfully")
            
        except Exception as e:
            logging.error(f"Database connection error: {str(e)}", exc_info=True)
            print(f"Error: Database connection failed: {str(e)}")
            return
            
        # Run export validation
        results = export_validation_results(
            connection_type=args.connection_type,
            database=args.database,
            start_date=args.start_date,
            end_date=args.end_date,
            queries=args.queries,
            output_dir=args.output_dir,
            use_parallel=args.parallel
        )
        
        # Print a user-friendly summary to console
        if results.get("success", False):
            print("\nPayment validation export completed successfully!")
            print(f"Processed {results['total']} queries, all successful.")
            print(f"Results saved to: {args.output_dir}")
        else:
            print("\nPayment validation export completed with issues.")
            print(f"Processed {results['total']} queries, {results['successful']} successful, {results['total'] - results['successful']} failed.")
            print("Check the log file for details on failed queries.")
            print(f"Results saved to: {args.output_dir}")
        
    except Exception as e:
        logging.error(f"Fatal error in main execution", exc_info=True)
        print(f"\nAn unexpected error occurred: {str(e)}")
        print("Check the log file for detailed error information.")
        raise

if __name__ == "__main__":
    main()
