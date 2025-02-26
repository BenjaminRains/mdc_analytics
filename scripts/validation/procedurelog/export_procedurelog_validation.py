"""
Export ProcedureLog Validation Data

This script connects to the specified database, ensures required indexes exist,
loads a set of common table expressions (CTEs) from a separate file, and executes
a series of SQL queries for procedure log validation. The results for each query
are exported to separate CSV files. The files are then analyzed to identify and
diagnose issues with procedure logging and payment tracking.

Usage:
    python export_procedurelog_validation.py [--output-dir <path>] [--log-dir <path>]
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

# Define query descriptions and filenames
QUERY_DESCRIPTIONS = {
    'summary': 'Overall procedure data summary',
    'status_distribution': 'Procedure status code distribution',
    'status_transitions': 'Procedure status transition patterns',
    'temporal_patterns': 'Month-by-month procedure analytics',
    'code_distribution': 'Distribution of procedures by procedure code',
    'fee_distribution': 'Distribution of procedures by fee amounts',
    'payment_distribution': 'Distribution of payment percentages',
    'payment_patterns': 'Payment patterns and linkage analysis',
    'payment_splits': 'Analysis of insurance vs. direct payments',
    'appointment_connections': 'How procedures connect to appointments',
    'procedure_pairs': 'Commonly paired procedures analysis',
    'edge_cases': 'Procedure and payment anomalies',
    'provider_performance': 'Provider-level procedure metrics',
    'procedures_raw': 'Raw procedure data with treatment plan and perio exam context'
}

def setup_logging(log_dir='scripts/validation/procedurelog/logs'):
    """Setup logging configuration."""
    # Ensure log directory exists
    Path(log_dir).mkdir(parents=True, exist_ok=True)
    
    # Create log filename with timestamp
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    log_file = os.path.join(log_dir, f'procedurelog_validation_{timestamp}.log')
    
    # Configure logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_file),
            logging.StreamHandler()  # Also print to console
        ]
    )
    
    logging.info("Starting procedure log validation export")
    logging.info(f"Log file: {log_file}")
    return log_file

def ensure_directory_exists(directory):
    """Create directory if it doesn't exist."""
    Path(directory).mkdir(parents=True, exist_ok=True)
    logging.info(f"Ensured directory exists: {directory}")

def parse_required_ctes(query_sql: str) -> List[str]:
    """
    Parse the header of the query SQL file to extract the list of required CTEs.
    Expected header format: "-- CTEs used: CTE1, CTE2, CTE3"
    """
    required_ctes = []
    for line in query_sql.splitlines():
        if line.startswith('-- CTEs used:'):
            # Remove the comment prefix and split by comma
            cte_line = line.replace('-- CTEs used:', '').strip()
            required_ctes = [cte.strip() for cte in cte_line.split(',') if cte.strip()]
            break  # Use only the first occurrence
    return required_ctes


def load_cte_file(cte_name: str) -> str:
    """
    Load an individual CTE file from the ctes subdirectory.
    """
    cte_path = Path(__file__).parent / 'queries' / 'ctes' / f'{cte_name}.sql'
    try:
        with cte_path.open('r') as f:
            return f.read()
    except Exception as e:
        logging.error(f"Error loading CTE file {cte_name}: {str(e)}")
        raise

def get_dynamic_ctes(required_ctes: List[str], start_date: Optional[str] = None, end_date: Optional[str] = None) -> str:
    """
    Assemble the SQL for the required CTEs.
    """
    cte_statements = []
    for cte_name in required_ctes:
        cte_content = load_cte_file(cte_name)
        # Replace date placeholders if they exist
        cte_content = cte_content.replace('{{START_DATE}}', start_date or '2024-01-01')
        cte_content = cte_content.replace('{{END_DATE}}', end_date or '2025-01-01')
        cte_statements.append(cte_content)
    return "\n\n".join(cte_statements)

def get_exports(start_date: Optional[str] = None, end_date: Optional[str] = None) -> List[Dict]:
    """
    Assemble export configurations by dynamically loading only the needed CTEs for each query.
    """
    exports = []
    
    for query_name, description in QUERY_DESCRIPTIONS.items():
        try:
            query_sql = load_query_file(query_name)
            # Parse the required CTEs from the query header comment
            required_ctes = parse_required_ctes(query_sql)
            if required_ctes:
                cte_sql = get_dynamic_ctes(required_ctes, start_date, end_date)
                # Concatenate the dynamically assembled CTEs with the query SQL
                full_query = f"{cte_sql}\n\n{query_sql}"
            else:
                full_query = query_sql  # Query does not declare any CTE dependencies
            
            exports.append({
                'name': query_name,
                'description': description,
                'query': full_query,
                'file': f"{query_name}.csv"
            })
        except Exception as e:
            logging.error(f"Error setting up query {query_name}: {str(e)}")
            continue
    
    return exports



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
                    'file': export['file']
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
            'file': export['file']
        }
    finally:
        # Always close the connection when done
        if fresh_connection:
            try:
                fresh_connection.close()
            except:
                pass

def export_validation_results(connection_factory, connection_type, database, queries=None, 
                             output_dir=None, use_parallel=False, start_date=None, end_date=None):
    """
    Export procedure log validation query results to separate CSV files.

    Args:
        connection_factory: The ConnectionFactory to create new connections.
        connection_type: Type of connection to create.
        database: Database name to connect to.
        queries: List of query names to run (None for all).
        output_dir: Directory to store output files (None for default).
        use_parallel: Whether to execute queries in parallel (default: False)
        start_date: Optional start date for filtering data (YYYY-MM-DD)
        end_date: Optional end date for filtering data (YYYY-MM-DD)
    """
    # Set default output directory if none provided
    if output_dir is None:
        output_dir = Path(__file__).parent / 'data'
    
    logging.info(f"Starting export to {output_dir}")
    ensure_directory_exists(output_dir)
    
    # Load common CTEs once
    logging.info("Loading CTEs")
    ctes = get_ctes(start_date, end_date)
    
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
            status = "+" if r['success'] else "X"
            logging.info(f"  {status} {r['name']}: {r['duration']:.2f}s - {r.get('rows', 0):,} rows")

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description='Export ProcedureLog validation data to CSV files.',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    
    parser.add_argument(
        '--output-dir',
        type=str,
        default=str(Path(__file__).parent / 'data'),
        help='Directory where CSV files will be saved'
    )
    
    parser.add_argument(
        '--log-dir',
        type=str,
        default=str(Path(__file__).parent / 'logs'),
        help='Directory where log files will be saved'
    )
    
    parser.add_argument(
        '--database',
        type=str,
        default='opendental',
        help='Database name to connect to'
    )
    
    parser.add_argument(
        '--connection-type',
        type=str,
        default='dev',
        choices=['dev', 'prod', 'local', 'test'],
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

def ensure_indexes(connection, database_name):
    """Ensure required indexes exist for procedure validation queries."""
    logging.info("Checking and creating required procedure validation indexes...")
    
    REQUIRED_INDEXES = [
        # ProcedureLog - core indexes
        "CREATE INDEX IF NOT EXISTS idx_ml_procedurelog_core ON procedurelog (ProcNum, ProcDate, DateComplete, ProcStatus, ProcFee, CodeNum)",
        "CREATE INDEX IF NOT EXISTS idx_ml_procedurelog_window ON procedurelog (ProcDate)",
        "CREATE INDEX IF NOT EXISTS idx_ml_procedurelog_date_complete ON procedurelog (DateComplete)",
        "CREATE INDEX IF NOT EXISTS idx_ml_procedurelog_fee ON procedurelog (ProcFee)",
        "CREATE INDEX IF NOT EXISTS idx_ml_procedurelog_status ON procedurelog (ProcStatus)",
        
        # Payment tracking
        "CREATE INDEX IF NOT EXISTS idx_ml_paysplit_proc ON paysplit (ProcNum, SplitAmt)",
        "CREATE INDEX IF NOT EXISTS idx_ml_claimproc_proc ON claimproc (ProcNum, InsPayAmt, InsPayEst, Status)",
        
        # Code lookups
        "CREATE INDEX IF NOT EXISTS idx_ml_procedurecode_code ON procedurecode (ProcCode)",
        
        # Appointment links
        "CREATE INDEX IF NOT EXISTS idx_ml_procedurelog_appointment ON procedurelog (AptNum)",
        "CREATE INDEX IF NOT EXISTS idx_ml_appointment_date ON appointment (AptDateTime, AptStatus)"
    ]
    
    try:
        manager = IndexManager(database_name)
        
        # Show existing indexes before creation
        logging.info("Current procedure-related indexes:")
        manager.show_custom_indexes()
        
        # Create only the required indexes
        logging.info("Creating required procedure validation indexes...")
        manager.create_indexes(REQUIRED_INDEXES)
        
        # Verify indexes after creation
        logging.info("Verifying indexes after creation:")
        manager.show_custom_indexes()
        
        logging.info("Procedure validation index creation complete")
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
            use_parallel=args.parallel,
            start_date=args.start_date,
            end_date=args.end_date
        )
        
        logging.info("Procedure validation export completed successfully")
        
    except Exception as e:
        logging.error(f"Fatal error in main execution", exc_info=True)
        raise

if __name__ == "__main__":
    main()