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
"""

import pandas as pd
import os
from datetime import datetime
import logging
from src.connections.factory import ConnectionFactory
import argparse
from scripts.base.index_manager import IndexManager
from pathlib import Path
from typing import Dict, Optional, List
import concurrent.futures
from tqdm import tqdm
import time

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
    try:
        with query_path.open('r') as f:
            return f.read()
    except Exception as e:
        logging.error(f"Error loading query file {query_name}: {str(e)}")
        raise

def get_ctes(start_date: Optional[str] = None, end_date: Optional[str] = None) -> str:
    """
    Get common table expressions from the 'ctes.sql' file.
    
    Args:
        start_date: Optional start date filter in YYYY-MM-DD format
        end_date: Optional end date filter in YYYY-MM-DD format
    
    Returns:
        CTE SQL with optional date filters applied
    """
    ctes = load_query_file('ctes')
    
    # If date filters are provided, modify the CTE to include them
    if start_date or end_date:
        date_filters = []
        if start_date:
            date_filters.append(f"p.PayDate >= '{start_date}'")
        if end_date:
            date_filters.append(f"p.PayDate <= '{end_date}'")
            
        # Insert date filters into the base CTE
        if date_filters:
            filter_clause = " AND " + " AND ".join(date_filters)
            # This assumes a specific structure in the CTE - adjust as needed
            # Look for "base_payments" CTE and add date filter before the first closing parenthesis
            ctes = ctes.replace("FROM payment p", f"FROM payment p WHERE 1=1 {filter_clause}")
            
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

def process_single_export(export, factory, connection_type, database, output_dir):
    """Process a single export query and save results to CSV."""
    fresh_connection = None
    start_time = datetime.now()
    
    try:
        # Create a new connection for each query
        fresh_connection = factory.create_connection(connection_type, database)
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
            
            # Write to CSV (overwrite if file exists)
            output_path = os.path.join(output_dir, export['file'])
            df.to_csv(output_path, index=False, mode='w')
        
        duration = (datetime.now() - start_time).total_seconds()
        return {
            'name': export['name'],
            'success': True,
            'rows': len(df),
            'duration': duration,
            'file': export['file']
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

def export_validation_results(connection_factory, connection_type, database, queries=None, 
                             output_dir=None, use_parallel=False):
    """
    Export payment validation query results to separate CSV files.

    Args:
        connection_factory: The ConnectionFactory to create new connections.
        connection_type: Type of connection to create.
        database: Database name to connect to.
        queries: List of query names to run (None for all).
        output_dir: Directory to store output files (None for default).
        use_parallel: Whether to execute queries in parallel (default: False)
    """
    # Set default output directory if none provided
    if output_dir is None:
        output_dir = r"C:\Users\rains\mdc_analytics\scripts\validation\payment_split\data"
    
    logging.info(f"Starting export to {output_dir}")
    ensure_directory_exists(output_dir)
    
    # Load common CTEs once
    logging.info("Loading CTEs")
    ctes = get_ctes()
    
    # Get export configurations, passing in the loaded CTEs
    exports = get_exports(ctes)
    
    # Filter exports if specific queries requested
    if queries:
        exports = [e for e in exports if e['name'] in queries]
        logging.info(f"Running selected queries: {', '.join(queries)}")

    # Log query descriptions
    logging.info("Query descriptions:")
    for export in exports:
        logging.info(f"  {export['name']}: {export['description']}")
    
    results = []
    
    if use_parallel:
        logging.info(f"Executing {len(exports)} queries in parallel...")
        with concurrent.futures.ThreadPoolExecutor(max_workers=min(4, len(exports))) as executor:
            # Submit all tasks
            future_to_export = {
                executor.submit(
                    process_single_export, export, connection_factory, connection_type, database, output_dir
                ): export['name'] for export in exports
            }
            
            # Create a progress bar
            with tqdm(total=len(exports), desc="Processing queries") as pbar:
                for future in concurrent.futures.as_completed(future_to_export):
                    query_name = future_to_export[future]
                    try:
                        result = future.result()
                        results.append(result)
                        if result['success']:
                            logging.info(f"Exported {result['rows']:,} rows to {result['file']} in {result['duration']:.2f} seconds")
                        else:
                            logging.error(f"Error exporting {query_name}: {result['error']}")
                    except Exception as exc:
                        logging.error(f"Query {query_name} generated an exception: {exc}")
                    pbar.update(1)
    else:
        # Execute each query sequentially with a progress bar
        with tqdm(total=len(exports), desc="Processing queries") as pbar:
            for export in exports:
                result = process_single_export(export, connection_factory, connection_type, database, output_dir)
                results.append(result)
                
                if result['success']:
                    logging.info(f"Exported {result['rows']:,} rows to {result['file']} in {result['duration']:.2f} seconds")
                else:
                    logging.error(f"Error exporting {export['name']}: {result['error']}")
                    
                pbar.update(1)
    
    # Summary of results
    successful = sum(1 for r in results if r['success'])
    failed = len(results) - successful
    total_rows = sum(r['rows'] for r in results if r['success'])
    total_duration = sum(r['duration'] for r in results)
    
    logging.info(f"Export summary: {successful} queries successful, {failed} failed")
    logging.info(f"Total rows exported: {total_rows:,}")
    logging.info(f"Total processing time: {total_duration:.2f} seconds")
    
    # Sort and display query performance
    if results:
        logging.info("Query performance (slowest to fastest):")
        sorted_results = sorted(results, key=lambda x: x['duration'], reverse=True)
        for r in sorted_results:
            status = "✓" if r['success'] else "✗"
            logging.info(f"  {status} {r['name']}: {r['duration']:.2f}s - {r.get('rows', 0):,} rows")

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description='Export payment validation data to CSV files',
        formatter_class=argparse.RawTextHelpFormatter
    )
    
    parser.add_argument(
        '--output-dir',
        default=r"C:\Users\rains\mdc_analytics\scripts\validation\payment_split\data",
        help='Directory to store output files'
    )
    
    parser.add_argument(
        '--log-dir',
        default='scripts/validation/payment_split/logs',
        help='Directory to store log files'
    )
    
    parser.add_argument(
        '--database',
        default='opendental_analytics_opendentalbackup_01_03_2025',
        help='Database name to connect to'
    )
    
    parser.add_argument(
        '--connection-type',
        default='local_mariadb',
        choices=['local_mariadb', 'local_mysql', 'mdc'],
        help='Type of database connection to use'
    )
    
    parser.add_argument(
        '--queries',
        nargs='+',
        choices=['summary', 'base_counts', 'source_counts', 'filter_summary', 
                'diagnostic', 'verification', 'problems', 'duplicate_joins', 
                'join_stages', 'daily_patterns', 'payment_details', 'containment'],
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

def ensure_indexes(connection, database_name):
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
        if args.start_date:
            logging.info(f"Start date filter: {args.start_date}")
        if args.end_date:
            logging.info(f"End date filter: {args.end_date}")
        logging.info(f"Parallel execution: {args.parallel}")
        
        # Create connection factory
        factory = ConnectionFactory()
        
        # Create initial connection for index check
        connection = factory.create_connection(args.connection_type, args.database)
        
        # Ensure required indexes exist
        ensure_indexes(connection, args.database)
        
        # Close initial connection
        connection.close()
        
        # Export validation results with connection factory
        export_validation_results(
            connection_factory=factory,
            connection_type=args.connection_type,
            database=args.database,
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
