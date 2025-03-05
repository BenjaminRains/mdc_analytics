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

Requirements:
    - .env file must be set up in the project root with MariaDB configuration:
        MARIADB_HOST=localhost
        MARIADB_PORT=3307
        MARIADB_USER=your_username
        MARIADB_PASSWORD=your_password
        MARIADB_DATABASE=your_database
        LOCAL_VALID_DATABASES=comma,separated,list,of,valid,databases
"""

import pandas as pd
import os
from datetime import datetime
import logging
import re  # Add missing import for regular expressions
from src.connections.factory import ConnectionFactory, get_valid_databases
import argparse
from scripts.base.index_manager import IndexManager
from pathlib import Path
from typing import Dict, Optional, List, Union, Any
import concurrent.futures
from tqdm import tqdm
import time

# Import shared utilities from sql_export_utils
from scripts.validation.payment_split.utils.sql_export_utils import (
    DateRange, read_sql_file, apply_date_parameters, 
    export_to_csv, print_summary
)

# Get the list of valid databases from environment
valid_databases = get_valid_databases('LOCAL_VALID_DATABASES')

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
    """Setup logging configuration."""
    # Ensure log directory exists
    Path(log_dir).mkdir(parents=True, exist_ok=True)
    
    # Create log filename with timestamp
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    log_file = os.path.join(log_dir, f'payment_validation_{timestamp}.log')
    
    # Configure logging
    logging.basicConfig(
        level=logging.DEBUG,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_file),
            logging.StreamHandler()  # Also print to console
        ]
    )
    
    logging.info("Starting payment validation export")
    logging.info(f"Log file: {log_file}")
    return log_file

def ensure_directory_exists(directory):
    """Create directory if it doesn't exist."""
    Path(directory).mkdir(parents=True, exist_ok=True)
    logging.info(f"Ensured directory exists: {directory}")

def load_query_file(query_name: str) -> str:
    """Load a query from the queries directory using pathlib."""
    query_path = Path(__file__).parent / 'queries' / f'{query_name}.sql'
    return read_sql_file(query_path)

def get_ctes(start_date: str, end_date: str) -> str:
    """
    Get common table expressions from the 'ctes' directory.
    
    Args:
        start_date: Required start date filter in YYYY-MM-DD format
        end_date: Required end date filter in YYYY-MM-DD format
    
    Returns:
        CTE SQL with date filters applied
    """
    # Load all SQL files from the CTEs directory
    ctes_dir = Path(__file__).parent / 'queries' / 'ctes'
    
    # Check if the directory exists
    if not ctes_dir.exists() or not ctes_dir.is_dir():
        raise FileNotFoundError(f"CTEs directory not found at: {ctes_dir}")
    
    # Define dependency order - put base CTEs first, then derived ones
    # This ensures CTEs that depend on other CTEs are defined after their dependencies
    preferred_order = [
        # Note: We'll handle date parameters directly via SQL variables instead of a separate CTE
        # "date_range.sql" is removed from the preferred order if it's only used to define date ranges
        "base_payments.sql",          # Base payments table
        "base_splits.sql",            # Base splits table
        "payment_summary.sql",        # Payment summary metrics
        "payment_method_analysis.sql", # Payment method analysis
        "payment_source_categories.sql", # Payment source categories
        "payment_source_summary.sql",  # Payment source summary
        "total_payments.sql",         # Total payment metrics
        "insurance_payment_analysis.sql", # Insurance payment analysis
        "procedure_payments.sql",     # Procedure payment analysis
        "split_pattern_analysis.sql", # Split pattern analysis
        "payment_base_counts.sql",    # Payment base counts
        "payment_join_diagnostics.sql", # Payment join diagnostics
        "payment_filter_diagnostics.sql", # Payment filter diagnostics
        "join_stage_counts.sql",      # Join stage counts
        "suspicious_split_analysis.sql", # Suspicious split analysis
        "payment_details_base.sql",   # Payment details base
        "payment_details_metrics.sql", # Payment details metrics
        "payment_daily_details.sql",  # Payment daily details
        "filter_stats.sql",           # Filter statistics
        "problem_payments.sql",       # Problem payments
        "claim_metrics.sql",          # Claim metrics
        "problem_claim_details.sql"   # Problem claim details
    ]
    
    # Get all SQL files in the directory
    all_files = list(ctes_dir.glob('*.sql'))
    
    # Filter out date_range.sql if we're handling dates via variables
    all_files = [f for f in all_files if f.name != 'date_range.sql']
    
    # Sort files based on preferred order, then alphabetically for the rest
    def sort_key(file):
        filename = file.name
        if filename in preferred_order:
            return preferred_order.index(filename)
        return len(preferred_order) + file.name.lower()
        
    sql_files = sorted(all_files, key=sort_key)
    
    if not sql_files:
        raise FileNotFoundError(f"No SQL files found in CTEs directory: {ctes_dir}")
    
    # Log the files being used
    logging.info(f"Found {len(sql_files)} CTE SQL files: {', '.join(f.name for f in sql_files)}")
    
    # Create a DateRange object from the required dates
    date_range = DateRange.from_strings(start_date, end_date)
    
    # Define date variables to be placed BEFORE the WITH clause
    # These will be used directly by the CTEs for all date filtering
    date_variables = (
        f"-- Set date parameters from CLI args\n"
        f"SET @start_date = '{date_range.start_date.strftime('%Y-%m-%d')}';\n"
        f"SET @end_date = '{date_range.end_date.strftime('%Y-%m-%d')}';\n\n"
    )
    
    # Start building the CTE parts
    cte_parts = []
    
    for i, sql_file in enumerate(sql_files):
        # Read the file content
        file_content = read_sql_file(sql_file).strip()
        
        # If this is the first file and it has a WITH clause, remove it
        if i == 0 and file_content.upper().startswith('WITH'):
            file_content = file_content[4:].strip()
        
        # Add a comment indicating the source file
        cte_part = f"-- From {sql_file.name}\n{file_content}"
        
        # Each CTE except the last one needs a comma at the end
        if i < len(sql_files) - 1 and not cte_part.rstrip().endswith(','):
            cte_part += ','
            
        cte_parts.append(cte_part)
    
    # Combine all CTEs with a single WITH keyword (after date variables)
    ctes = date_variables + "WITH\n" + "\n\n".join(cte_parts)
    
    # Apply date parameters for any remaining hardcoded dates
    ctes = apply_date_parameters(ctes, date_range)
            
    return ctes

def get_query(query_name: str, ctes: str = None) -> dict:
    """Combine CTEs with a query and create export configuration."""
    query = load_query_file(query_name)
    
    if ctes:
        # The ctes string should already have SET statements at the beginning,
        # followed by a single WITH clause with all CTEs
        
        # Check if the query has a WITH clause
        query_has_with = query.strip().upper().startswith('WITH')
        
        if query_has_with:
            # Remove the WITH from the query and append it to the CTEs
            query_without_with = query.strip()[4:].strip()
            
            # Add a comma to connect the CTEs if needed
            if not ctes.rstrip().endswith(','):
                full_query = f"{ctes},\n{query_without_with}"
            else:
                full_query = f"{ctes}\n{query_without_with}"
        else:
            # Query doesn't have WITH, just append it to the CTEs
            full_query = f"{ctes}\n{query}"
            
        # Log a preview of the combined query for debugging
        query_preview = "\n".join(full_query.split("\n")[:20])  # First 20 lines
        logging.debug(f"Query preview for {query_name}:\n{query_preview}\n...")
    else:
        full_query = query
        
    return {
        'name': query_name,
        'query': full_query,
        'file': f'payment_split_validation_2024_{query_name}.csv',
        'description': QUERY_DESCRIPTIONS.get(query_name, 'No description available')
    }

def get_exports(ctes: str) -> list:
    """Get all export configurations with CTEs attached.
    
    The CTEs are passed in as a parameter to avoid loading the file multiple times.
    """
    return [
        get_query('summary', ctes),
        get_query('base_counts', ctes),
        get_query('source_counts', ctes),
        get_query('filter_summary', ctes),
        get_query('diagnostic', ctes),
        get_query('verification', ctes),
        get_query('problems', ctes),
        get_query('duplicate_joins', ctes),
        get_query('join_stages', ctes),
        get_query('daily_patterns', ctes),
        get_query('payment_details', ctes),
        get_query('containment', ctes),
    ]

def process_single_export(export, connection_type, database, output_dir):
    """Process a single export query and save results to CSV."""
    fresh_connection = None
    start_time = datetime.now()
    
    try:
        # Create a new connection for each query using class method
        fresh_connection = ConnectionFactory.create_connection(connection_type, database)
        mysql_connection = fresh_connection.connect()
        
        # Add debug logging for the query
        query_first_lines = export['query'].split('\n')[:10]  # Show first 10 lines instead of 5
        query_preview = '\n'.join(query_first_lines) + '\n...'
        logging.debug(f"Executing query for {export['name']}:\n{query_preview}")
        
        # Execute query and fetch results
        with mysql_connection.cursor(dictionary=True) as cursor:
            try:
                cursor.execute(export['query'])
                results = cursor.fetchall()
                
                # Convert to DataFrame
                df = pd.DataFrame(results)
                
                if len(df) == 0:
                    return {
                        'name': export['name'],
                        'success': True,
                        'rows': 0,
                        'duration': (datetime.now() - start_time).total_seconds(),
                        'message': "No results returned",
                        'file': export['file']  # Add file key for consistency
                    }
                
                # Save to CSV
                output_path = os.path.join(output_dir, export['file'])
                df.to_csv(output_path, index=False)
                
                return {
                    'name': export['name'],
                    'success': True,
                    'rows': len(df),
                    'duration': (datetime.now() - start_time).total_seconds(),
                    'message': f"Saved to {output_path}",
                    'file': export['file']  # Add file key for consistency
                }
            except Exception as e:
                error_message = str(e)
                # Log more details about SQL errors
                if hasattr(e, 'errno') and hasattr(e, 'sqlstate'):
                    error_message = f"{e.errno} ({e.sqlstate}): {e.msg}"
                    # Log the problematic part of the query if we can identify it
                    if "line" in error_message:
                        try:
                            line_match = re.search(r'line (\d+)', error_message)
                            if line_match:
                                line_num = int(line_match.group(1))
                                query_lines = export['query'].split('\n')
                                if 1 <= line_num <= len(query_lines):
                                    error_context = '\n'.join(query_lines[max(0, line_num-3):min(len(query_lines), line_num+2)])
                                    logging.error(f"Error context around line {line_num}:\n{error_context}")
                        except Exception as context_error:
                            logging.error(f"Error getting context: {context_error}")
                
                return {
                    'name': export['name'],
                    'success': False,
                    'rows': 0,
                    'duration': (datetime.now() - start_time).total_seconds(),
                    'error': error_message,  # Use 'error' key as expected by caller
                    'file': export['file']  # Add file key for consistency
                }
                
    except Exception as e:
        duration = (datetime.now() - start_time).total_seconds()
        logging.exception(f"Error in process_single_export for {export['name']}: {str(e)}")
        return {
            'name': export['name'],
            'success': False,
            'rows': 0,
            'duration': duration,
            'error': str(e),
            'file': export['file']  # Add file key even for failures
        }
    finally:
        # Always close the connection when done
        if fresh_connection:
            try:
                fresh_connection.close()
            except:
                pass
        
        end_time = datetime.now()
        elapsed = (end_time - start_time).total_seconds()
        logging.debug(f"Export {export['name']} completed in {elapsed:.2f} seconds")

def export_validation_results(connection_type, database, start_date, end_date,
                         queries=None, output_dir=None, use_parallel=False):
    """
    Execute all validation queries and export results to CSV.
    
    Args:
        connection_type: Type of connection (e.g., 'local_mariadb')
        database: Database name
        queries: List of query names to run (if None, run all)
        output_dir: Output directory for CSV files
        use_parallel: Whether to use parallel processing
        start_date: Required start date filter in YYYY-MM-DD format
        end_date: Required end date filter in YYYY-MM-DD format
        
    Returns:
        Dictionary of export results
    """
    # Create the output directory if it doesn't exist
    if output_dir is None:
        output_dir = Path(__file__).parent / 'data' / 'payment_split_validation'
    
    ensure_directory_exists(output_dir)
    logging.info(f"Ensured directory exists: {output_dir}")
    
    # Get common table expressions
    ctes = get_ctes(start_date, end_date)
    
    # Get exports for the specified queries or all if none specified
    if queries:
        exports = [get_query(q, ctes) for q in queries]
        logging.info(f"Processing {len(exports)} specified exports: {', '.join(queries)}")
    else:
        exports = get_exports(ctes)
        logging.info(f"Processing {len(exports)} exports sequentially")
    
    # Execute exports
    export_results = {}
    
    if use_parallel:
        # Parallel processing
        from concurrent.futures import ThreadPoolExecutor
        with ThreadPoolExecutor(max_workers=4) as executor:
            futures = {}
            for export in exports:
                export_name = export['name']
                future = executor.submit(
                    process_single_export, 
                    export, 
                    connection_type, 
                    database, 
                    output_dir
                )
                futures[future] = export_name
            
            for future in tqdm(futures, desc="Processing exports"):
                export_name = futures[future]
                try:
                    result = future.result()
                    export_results[export_name] = result
                except Exception as exc:
                    logging.error(f"Export {export_name} generated an exception: {exc}")
                    export_results[export_name] = {
                        'name': export_name,
                        'success': False,
                        'error': str(exc)
                    }
    else:
        # Sequential processing
        for export in tqdm(exports, desc="Processing exports"):
            export_name = export['name']
            logging.info(f"Processing export: {export_name}")
            result = process_single_export(export, connection_type, database, output_dir)
            export_results[export_name] = result
    
    # Print summary of results
    success_count = sum(1 for r in export_results.values() if r.get('success', False))
    failed_count = len(export_results) - success_count
    total_rows = sum(r.get('rows', 0) for r in export_results.values())
    
    logging.info(f"Export summary: {success_count} succeeded, {failed_count} failed, {total_rows} total rows")
    
    if failed_count > 0:
        logging.warning("Failed exports:")
        for name, result in export_results.items():
            if not result.get('success', False):
                logging.warning(f"  - {name}: {result.get('error', 'Unknown error')}")
    
    return export_results

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
        
        # Log execution parameters
        logging.info(f"Output directory: {args.output_dir}")
        logging.info(f"Database: {args.database}")
        logging.info(f"Connection type: {args.connection_type}")
        
        # Create a DateRange object from the required date parameters
        date_range = DateRange.from_strings(args.start_date, args.end_date)
        logging.info(f"Using date range: {args.start_date} to {args.end_date}")
        
        # Validate database name
        if not args.database:
            logging.error("No database specified and no default found in environment")
            print("Error: No database specified and no default found in environment")
            print(f"Valid databases: {', '.join(valid_databases)}" if valid_databases else "No valid databases configured")
            return
            
        # Validate against allowed databases
        if valid_databases and args.database not in valid_databases:
            logging.error(f"Invalid database name: {args.database}")
            print(f"Error: Invalid database name. Must be one of: {', '.join(valid_databases)}")
            return
            
        try:
            # Create initial connection for index check
            connection = ConnectionFactory.create_connection(args.connection_type, args.database)
            
            # Ensure required indexes exist
            ensure_indexes(args.database)
            
            # Close initial connection
            connection.close()
        except ValueError as e:
            logging.error(f"Database connection error: {e}")
            print(f"Error: {e}")
            return
            
        # Export validation results
        export_validation_results(
            connection_type=args.connection_type,
            database=args.database,
            start_date=args.start_date,
            end_date=args.end_date,
            queries=args.queries,
            output_dir=args.output_dir,
            use_parallel=args.parallel
        )
        
        logging.info("Payment validation export completed successfully")
        
    except Exception as e:
        logging.error(f"Fatal error in main execution", exc_info=True)
        raise

if __name__ == "__main__":
    main()
