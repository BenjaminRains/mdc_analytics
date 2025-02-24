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
from typing import Dict, Optional

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

def get_ctes() -> str:
    """Get common table expressions from the 'ctes.sql' file."""
    return load_query_file('ctes')

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
        'file': f'payment_split_validation_2024_{query_name}.csv'
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

def export_validation_results(cursor, queries=None, output_dir=None):
    """
    Export payment validation query results to separate CSV files.

    Args:
        cursor: Database cursor object.
        queries: List of query names to run (None for all).
        output_dir: Directory to store output files (None for default).
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
    
    # Execute each query and export results
    for export in exports:
        try:
            logging.info(f"Processing export: {export['name']}")
            start_time = datetime.now()
            
            # Execute query and fetch results
            cursor.execute(export['query'])
            results = cursor.fetchall()
            
            # Convert to DataFrame
            df = pd.DataFrame(results)
            
            # Write to CSV (overwrite if file exists)
            output_path = os.path.join(output_dir, export['file'])
            if os.path.exists(output_path):
                logging.info(f"Overwriting existing file: {export['file']}")
            df.to_csv(output_path, index=False, mode='w')
            
            duration = (datetime.now() - start_time).total_seconds()
            logging.info(f"Exported {len(df):,} rows to {export['file']} in {duration:.2f} seconds")
            
        except Exception as e:
            logging.error(f"Error exporting {export['name']}: {str(e)}", exc_info=True)

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
        '--queries',
        nargs='+',
        choices=['duplicate_joins', 'join_stages'],
        help='Specific queries to run (default: all)'
    )
    
    return parser.parse_args()

def ensure_indexes(connection, database_name):
    """Ensure required indexes exist for validation queries."""
    logging.info("Checking and creating required payment validation indexes...")
    
    REQUIRED_INDEXES = [
        # Payment Analysis - core indexes for payment date filtering and joins
        "CREATE INDEX IF NOT EXISTS idx_ml_payment_core ON payment (PayNum, PayDate)",
        "CREATE INDEX IF NOT EXISTS idx_ml_payment_window ON payment (PayDate)",
        
        # Payment Split Analysis - for payment-split relationships
        "CREATE INDEX IF NOT EXISTS idx_ml_paysplit_payment ON paysplit (ProcNum, PayNum, SplitAmt)",
        "CREATE INDEX IF NOT EXISTS idx_ml_paysplit_proc_pay ON paysplit (ProcNum, PayNum, SplitAmt)",
        
        # Insurance Processing - for insurance payment identification
        "CREATE INDEX IF NOT EXISTS idx_ml_claimproc_core ON claimproc (ProcNum, InsPayAmt, InsPayEst, Status, ClaimNum)"
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
        logging.error(f"Error managing payment validation indexes: {str(e)}")
        raise

if __name__ == "__main__":
    try:
        # Parse command line arguments
        args = parse_args()
        
        # Setup logging
        log_file = setup_logging(args.log_dir)
        
        logging.info(f"Output directory: {args.output_dir}")
        logging.info(f"Database: {args.database}")
        if args.queries:
            logging.info(f"Running queries: {', '.join(args.queries)}")
        
        # Create single database connection using factory
        factory = ConnectionFactory()
        connection = factory.create_connection(
            connection_type='local_mariadb',
            database=args.database,
            use_root=True
        )
        
        # Use single connection for both operations
        with connection.connect() as conn:
            # Ensure required indexes exist
            ensure_indexes(conn, args.database)
            
            # Execute queries and export results using the same connection
            cursor = conn.cursor(dictionary=True)
            export_validation_results(cursor, args.queries, args.output_dir)
            
    except Exception as e:
        logging.error("Fatal error in main execution", exc_info=True)
        raise
