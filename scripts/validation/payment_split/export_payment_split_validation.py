"""
Export Payment Split Validation Data

This script connects to the specified database, ensures required indexes exist,
loads a set of common table expressions (CTEs) from a separate file, and executes
a series of SQL queries for payment split validation. The results for each query
are exported to separate CSV files. The files are then analyzed in notebooks to
identify and diagnose issues.

Usage:
    python export_payment_split_validation.py [--output-dir <path>] [--log-dir <path>]
                                                [--database <dbname>] [--queries <names>]
                                                [--connection-type <type>]
                                                [--start-date <YYYY-MM-DD>]
                                                [--end-date <YYYY-MM-DD>]
                                                [--parallel]

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
from src.connections.factory import ConnectionFactory, get_valid_databases
import argparse
from scripts.base.index_manager import IndexManager
from pathlib import Path
from typing import Dict, Optional, List
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
        level=logging.INFO,
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

def get_ctes(start_date: Optional[str] = None, end_date: Optional[str] = None) -> str:
    """
    Get common table expressions from the 'ctes.sql' file.
    
    Args:
        start_date: Optional start date filter in YYYY-MM-DD format
        end_date: Optional end date filter in YYYY-MM-DD format
    
    Returns:
        CTE SQL with optional date filters applied
    """
    # Load the CTEs file
    ctes_path = Path(__file__).parent / 'queries' / 'ctes.sql'
    ctes = read_sql_file(ctes_path)
    
    # If date filters are provided, apply them using the date parameter utility
    if start_date or end_date:
        # Set default values if only one date is provided
        from_date = start_date if start_date else '2000-01-01'  # Default distant past date
        to_date = end_date if end_date else datetime.now().strftime('%Y-%m-%d')  # Default to today
        
        # Create a DateRange object
        date_range = DateRange.from_strings(from_date, to_date)
        
        # Apply date parameters, which will replace date placeholders in the SQL
        ctes = apply_date_parameters(ctes, date_range)
            
    return ctes

def get_query(query_name: str, ctes: str = None) -> dict:
    """Combine CTEs with a query and create export configuration."""
    query = load_query_file(query_name)
    if ctes:
        # Prepend CTE definitions to the query.
        full_query = f"{ctes}\n{query}"
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
        
        # Execute query and fetch results
        with mysql_connection.cursor(dictionary=True) as cursor:
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
                    'file': export['file']  # Add file key even for empty results
                }
            
            # Use export_to_csv utility from sql_export_utils
            output_file = Path(output_dir)
            file_name = export['file'].replace('.csv', '')  # Remove .csv extension as export_to_csv adds it
            
            # Export to CSV using the shared utility
            csv_path = export_to_csv(
                df=df,
                output_dir=output_file,
                query_name=file_name,
                include_date=False  # Date is already in the filename format
            )
        
        duration = (datetime.now() - start_time).total_seconds()
        return {
            'name': export['name'],
            'success': True,
            'rows': len(df),
            'duration': duration,
            'file': csv_path.name
        }
        
    except Exception as e:
        duration = (datetime.now() - start_time).total_seconds()
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

def export_validation_results(connection_type, database, queries=None, 
                             output_dir=None, use_parallel=False, start_date=None, end_date=None):
    """
    Export payment validation query results to separate CSV files.

    Args:
        connection_type: Type of connection to create.
        database: Database name to connect to.
        queries: List of query names to run (None for all).
        output_dir: Directory to store output files (None for default).
        use_parallel: Whether to use parallel execution.
        start_date: Optional start date for filtering.
        end_date: Optional end date for filtering.
    """
    if not output_dir:
        output_dir = os.path.join(os.path.dirname(__file__), 'data')
    
    # Create output directory if it doesn't exist
    ensure_directory_exists(output_dir)
    
    # Load CTEs
    ctes = get_ctes(start_date, end_date)
    
    # Get export configurations
    exports = get_exports(ctes)
    
    # Filter exports based on query list
    if queries:
        logging.info(f"Filtering exports to: {', '.join(queries)}")
        exports = [export for export in exports if export['name'] in queries]
    
    export_results = {}
    
    if use_parallel:
        logging.info(f"Using parallel execution for {len(exports)} exports")
        
        # Using ThreadPoolExecutor for parallel processing
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
            # Submit all tasks
            future_to_export = {
                executor.submit(
                    process_single_export, 
                    export, 
                    connection_type, 
                    database, 
                    output_dir
                ): export['name'] for export in exports
            }
            
            # Process as they complete with progress bar
            for future in tqdm(
                concurrent.futures.as_completed(future_to_export), 
                total=len(exports),
                desc="Exporting queries"
            ):
                export_name = future_to_export[future]
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
        logging.info(f"Processing {len(exports)} exports sequentially")
        
        # Process sequentially with progress bar
        for export in tqdm(exports, desc="Exporting queries"):
            logging.info(f"Processing export: {export['name']}")
            result = process_single_export(export, connection_type, database, output_dir)
            export_results[export['name']] = result
    
    # Print summary of results
    success_count = sum(1 for r in export_results.values() if r.get('success', False))
    failed_count = len(export_results) - success_count
    total_rows = sum(r.get('rows', 0) for r in export_results.values())
    
    logging.info(f"Export summary: {success_count} succeeded, {failed_count} failed, {total_rows} total rows")
    
    # Print details of failures
    if failed_count > 0:
        logging.warning("Failed exports:")
        for name, result in export_results.items():
            if not result.get('success', False):
                logging.warning(f"  - {name}: {result.get('error', 'Unknown error')}")

    # Convert export_results to the format expected by print_summary
    formatted_results = {
        name: {
            'status': 'SUCCESS' if result.get('success', False) else 'FAILURE',
            'rows': result.get('rows', 0),
            'output_file': Path(output_dir) / result.get('file', f"{name}.csv")
        }
        for name, result in export_results.items()
    }
    
    # Use print_summary utility to display a consistent summary
    print_summary(
        query_results=formatted_results,
        output_dir=Path(output_dir),
        script_name="Payment Split Validation"
    )
    
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
        default=r"C:\Users\rains\mdc_analytics\scripts\validation\payment_split\data",
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
        help='Start date for filtering data (YYYY-MM-DD format)'
    )
    
    parser.add_argument(
        '--end-date',
        help='End date for filtering data (YYYY-MM-DD format)'
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
        
        # Create a DateRange object if date filters are provided
        date_range = None
        if args.start_date or args.end_date:
            # Set default values if only one date is provided
            from_date = args.start_date if args.start_date else '2000-01-01'  # Default distant past date
            to_date = args.end_date if args.end_date else datetime.now().strftime('%Y-%m-%d')  # Default to today
            
            # Create the DateRange object
            date_range = DateRange.from_strings(from_date, to_date)
            logging.info(f"Using date range: {from_date} to {to_date}")
        
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
            queries=args.queries,
            output_dir=args.output_dir,
            use_parallel=args.parallel,
            start_date=args.start_date,
            end_date=args.end_date
        )
        
        logging.info("Payment validation export completed successfully")
        
    except Exception as e:
        logging.error(f"Fatal error in main execution", exc_info=True)
        raise

if __name__ == "__main__":
    main()
