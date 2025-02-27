"""
Export ProcedureLog Validation Data

This script connects to the specified database, ensures required indexes exist,
loads a set of common table expressions (CTEs) from separate .sql files, and executes
a series of SQL queries for procedure log validation. The results for each query
are exported to separate CSV files. The files are then analyzed to identify and
diagnose issues with procedure logging and payment tracking.

The exported CSV files are loaded and analyzed in the Jupyter notebook:
    notebooks/procedurelog_analysis.ipynb
This notebook provides interactive visualizations, statistical analysis, and
detailed investigation of validation results. It helps identify patterns,
anomalies, and potential issues in the procedure log data.

Validation Scope:
----------------
1. Procedure Data Integrity
   - Basic procedure attributes and relationships
   - Status transitions and workflow
   - Fee assignment and accuracy
   - Appointment linkage

2. Basic Payment Coverage
   - Presence/absence of payments
   - Payment rate statistics
   - Payment-procedure relationship flags
   Note: Detailed payment validation is handled in payment_split_validation/

3. Time-based Analysis
   - Temporal patterns
   - Status transitions over time
   - Procedure bundling patterns

Key Validation Questions:
-----------------------
Procedure Integrity:
- Are procedures being recorded with valid status codes?
- Do procedures have appropriate fees assigned?
- Are procedure codes valid and properly categorized?
- Are procedures properly linked to appointments?
- Are procedure status transitions logical?

Workflow Validation:
- What is the distribution of procedure statuses?
- Are completed procedures properly marked?
- Are treatment planned procedures being tracked?
- Are deleted procedures properly handled?

Fee Validation:
- Are procedure fees within expected ranges?
- Are zero-fee procedures appropriate?
- Do fee patterns match procedure types?
- Are provider-specific fee schedules consistent?

Basic Payment Coverage:
- What percentage of procedures have associated payments?
- Are completed procedures receiving payments?
- Are payments only on completed procedures?
- Are there anomalies in payment patterns?
Note: Detailed payment validation and reconciliation is handled in payment_split_validation/

Appointment Integration:
- Are procedures properly linked to appointments?
- Do appointment statuses align with procedure statuses?
- Are there orphaned procedures without appointments?

Provider Analysis:
- Are procedures properly attributed to providers?
- Are there provider-specific patterns in procedure data?
- Do provider fee schedules show consistency?

Usage:
    python export_procedurelog_validation.py [--output-dir <path>] [--log-dir <path>]
                                              [--database <dbname>] [--queries <names>]
                                              [--connection-type <type>]
                                              [--start-date <YYYY-MM-DD>]
                                              [--end-date <YYYY-MM-DD>]
                                              [--parallel]

Query files and common CTE definitions are stored as separate .sql files in the
'queries' directory. The required CTEs are dynamically prepended to each query,
with date filters replaced by CLI parameters (if provided).

Related Validation Scripts:
-------------------------
- payment_split_validation/: Detailed payment validation and reconciliation
- treatment_plan_validation/: Treatment planning workflow validation
- appointment_validation/: Appointment scheduling and status validation
"""

import pandas as pd
import os
from datetime import datetime, date
import logging
import argparse
import concurrent.futures
from tqdm import tqdm
from pathlib import Path
from typing import Dict, Optional, List, Tuple, NamedTuple
import re
import time
from src.connections.factory import ConnectionFactory
from scripts.base.index_manager import IndexManager

# Directory constants
BASE_DIR = Path(__file__).parent.resolve()
QUERIES_DIR = BASE_DIR / "queries"
CTES_DIR = QUERIES_DIR / "ctes"
LOG_DIR = BASE_DIR / "logs"
DATA_DIR = BASE_DIR / "data"

# Query descriptions and filenames
QUERY_DESCRIPTIONS = {
    'summary': 'Overall procedure data summary',
    'base_counts': 'Fundamental counts and statistics for procedures',
    'bundled_procedures': 'Analyzes procedures that are commonly performed together (bundled)',
    'status_distribution': 'Procedure status code distribution',
    'status_transitions': 'Procedure status transition patterns',
    'temporal_patterns': 'Month-by-month procedure analytics',
    'code_distribution': 'Distribution of procedures by procedure code',
    'fee_relationship_analysis': 'Analyzes the relationship between procedure fees and payments',
    'fee_validation': 'Analyzes procedure fees across different ranges, categories, and relationships',
    'payment_metrics': 'Analyzes payment ratios and patterns for completed procedures',
    'procedure_payment_links': 'Validates the relationships between procedures and their associated payments',
    'split_patterns': 'Analyzes how payments are split between insurance and direct payments',
    'appointment_overlap': 'How procedures connect to appointments',
    'edge_cases': 'Procedure and payment anomalies',
    'provider_performance': 'Provider-level procedure metrics',
    'procedures_raw': 'Raw procedure data with treatment plan and perio exam context'
}

# Setup logging; ensures LOG_DIR exists and creates a log file with timestamp.
def setup_logging(log_dir: str = str(LOG_DIR)) -> str:
    Path(log_dir).mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    log_file = os.path.join(log_dir, f'procedurelog_validation_{timestamp}.log')
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_file),
            logging.StreamHandler()
        ]
    )
    logging.info("Starting procedure log validation export")
    logging.info(f"Log file: {log_file}")
    return log_file

def ensure_directory_exists(directory: str):
    Path(directory).mkdir(parents=True, exist_ok=True)
    logging.info(f"Ensured directory exists: {directory}")

# Parse required CTEs from a query file header.
def parse_required_ctes(query_sql: str) -> List[str]:
    """
    Parse the header of the query SQL file to extract the list of required CTEs.
    Expected header format: "-- Dependent CTEs: excluded_codes.sql, base_procedures.sql"
    """
    required_ctes = []
    for line in query_sql.splitlines():
        if line.startswith('-- Dependent CTEs:'):
            cte_line = line.replace('-- Dependent CTEs:', '').strip()
            # Get the filenames as-is, just strip whitespace
            required_ctes = [cte.strip() for cte in cte_line.split(',') if cte.strip()]
            # Remove .sql extension if present
            required_ctes = [cte[:-4] if cte.endswith('.sql') else cte for cte in required_ctes]
            break
    return required_ctes

# Date filter parsing using regex
DATE_FILTER_REGEX = re.compile(
    r'--\s*Date\s*filter:\s*([\d]{4}-[\d]{2}-[\d]{2})\s*to\s*([\d]{4}-[\d]{2}-[\d]{2})',
    re.IGNORECASE
)

class DateRange(NamedTuple):
    start_date: date
    end_date: date

    @classmethod
    def from_strings(cls, start: Optional[str], end: Optional[str]) -> 'DateRange':
        """Create a DateRange from string dates, with validation."""
        try:
            start_date = datetime.strptime(start, '%Y-%m-%d').date() if start else date(2024, 1, 1)
            end_date = datetime.strptime(end, '%Y-%m-%d').date() if end else date(2025, 1, 1)
            
            if end_date <= start_date:
                raise ValueError(f"End date {end_date} must be after start date {start_date}")
                
            return cls(start_date, end_date)
        except ValueError as e:
            logging.error(f"Date parsing error: {e}")
            raise

def parse_date_filter(content: str) -> Optional[DateRange]:
    """
    Parse the date filter from SQL content.
    Expected format: -- Date filter: 2024-01-01 to 2025-01-01
    """
    match = DATE_FILTER_REGEX.search(content)
    if match:
        try:
            return DateRange.from_strings(match.group(1), match.group(2))
        except ValueError:
            return None
    return None

def apply_date_filter(sql: str, date_range: DateRange) -> str:
    """Apply date range to SQL, with validation of the template variables."""
    if '{{START_DATE}}' not in sql or '{{END_DATE}}' not in sql:
        logging.warning("SQL missing date filter placeholders")
        return sql
        
    return sql.replace('{{START_DATE}}', str(date_range.start_date)).replace('{{END_DATE}}', str(date_range.end_date))

def parse_query_date_filter(query_sql: str) -> Optional[DateRange]:
    return parse_date_filter(query_sql)

def parse_cte_date_filter(cte_sql: str) -> Optional[DateRange]:
    return parse_date_filter(cte_sql)

# Load a query file from the queries directory.
def load_query_file(query_name: str) -> str:
    query_path = QUERIES_DIR / f"{query_name}.sql"
    try:
        return query_path.read_text(encoding="utf-8")
    except Exception as e:
        logging.error(f"Error loading query file '{query_name}' from {query_path}: {e}")
        raise

# Load a CTE file from the ctes subdirectory.
def load_cte_file(cte_name: str) -> str:
    """Load a CTE file using exact filename."""
    cte_path = CTES_DIR / f"{cte_name}.sql"
    try:
        return cte_path.read_text(encoding='utf-8')
    except Exception as e:
        logging.error(f"Error loading CTE file {cte_name} from {cte_path}: {e}")
        raise

# Dynamically assemble the required CTEs with date substitutions.
def get_dynamic_ctes(
    required_ctes: List[str],
    global_date_range: Optional[DateRange] = None
) -> str:
    """Assemble CTEs with proper date filtering."""
    if not required_ctes:
        return ""
        
    cte_statements = []
    for cte_name in required_ctes:
        cte_content = load_cte_file(cte_name)
        file_date_range = parse_date_filter(cte_content)
        
        # Use global date range if provided, otherwise use file's default
        date_range = global_date_range or file_date_range or DateRange(date(2024, 1, 1), date(2025, 1, 1))
        
        # Apply the date filter
        cte_content = apply_date_filter(cte_content, date_range)
        cte_statements.append(cte_content.strip())
    
    return "WITH " + ",\n".join(cte_statements)

# Assemble export configurations for each query, replacing date placeholders dynamically.
def get_exports(
    global_start_date: Optional[str] = None,
    global_end_date: Optional[str] = None,
    selected_queries: Optional[List[str]] = None
) -> List[Dict]:
    """Assemble export configurations with validated date filtering."""
    exports = []
    
    # Create global date range once
    try:
        global_date_range = DateRange.from_strings(global_start_date, global_end_date) if (global_start_date or global_end_date) else None
    except ValueError as e:
        logging.error(f"Invalid global date range: {e}")
        raise
    
    query_items = [(name, desc) for name, desc in QUERY_DESCRIPTIONS.items() 
                  if not selected_queries or name in selected_queries]
    
    for query_name, description in query_items:
        try:
            query_sql = load_query_file(query_name)
            
            # Get query's default date range
            query_date_range = parse_date_filter(query_sql)
            
            # Use global range if provided, otherwise use query's default
            date_range = global_date_range or query_date_range or DateRange(date(2024, 1, 1), date(2025, 1, 1))
            
            # Apply date filter to query
            query_sql = apply_date_filter(query_sql, date_range)
            
            # Handle CTEs with the same date range
            required_ctes = parse_required_ctes(query_sql)
            if required_ctes:
                cte_sql = get_dynamic_ctes(required_ctes, date_range)
                full_query = f"{cte_sql}\n\n{query_sql}"
            else:
                full_query = query_sql
                
            exports.append({
                'name': query_name,
                'description': description,
                'query': full_query,
                'file': f"{query_name}.csv"
            })
        except Exception as e:
            query_path = QUERIES_DIR / f"{query_name}.sql"
            logging.error(f"Error setting up query '{query_name}' (file: {query_path}): {e}")
            continue
            
    return exports

# Process a single export query and save its results to a CSV file.
def process_single_export(export, factory, connection_type, database, output_dir):
    fresh_connection = None
    start_time = datetime.now()
    try:
        fresh_connection = factory.create_connection(connection_type, database)
        mysql_connection = fresh_connection.connect()
        with mysql_connection.cursor(dictionary=True) as cursor:
            cursor.execute(export['query'])
            results = cursor.fetchall()
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
        if fresh_connection:
            try:
                fresh_connection.close()
            except Exception:
                pass

# Export validation results by executing queries in parallel or sequentially.
def export_validation_results(
    connection_factory, 
    connection_type, 
    database, 
    queries=None, 
    output_dir=None, 
    use_parallel=False, 
    start_date=None, 
    end_date=None
):
    if output_dir is None:
        output_dir = DATA_DIR
    logging.info(f"Starting export to {output_dir}")
    ensure_directory_exists(output_dir)
    logging.info("Loading export configurations (queries and CTEs)")
    exports = get_exports(start_date, end_date, selected_queries=queries)
    
    if queries:
        logging.info(f"Running selected queries: {', '.join(queries)}")
    logging.info("Query descriptions:")
    for export in exports:
        logging.info(f"  {export['name']}: {export['description']}")
    results = []
    if use_parallel:
        logging.info(f"Executing {len(exports)} queries in parallel...")
        with concurrent.futures.ThreadPoolExecutor(max_workers=min(4, len(exports))) as executor:
            future_to_export = {
                executor.submit(
                    process_single_export, export, connection_factory, connection_type, database, output_dir
                ): export['name'] for export in exports
            }
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
        with tqdm(total=len(exports), desc="Processing queries") as pbar:
            for export in exports:
                result = process_single_export(export, connection_factory, connection_type, database, output_dir)
                results.append(result)
                if result['success']:
                    logging.info(f"Exported {result['rows']:,} rows to {result['file']} in {result['duration']:.2f} seconds")
                else:
                    logging.error(f"Error exporting {export['name']}: {result['error']}")
                pbar.update(1)
    successful = sum(1 for r in results if r['success'])
    failed = len(results) - successful
    total_rows = sum(r['rows'] for r in results if r['success'])
    total_duration = sum(r['duration'] for r in results)
    logging.info(f"Export summary: {successful} queries successful, {failed} failed")
    logging.info(f"Total rows exported: {total_rows:,}")
    logging.info(f"Total processing time: {total_duration:.2f} seconds")
    if results:
        logging.info("Query performance (slowest to fastest):")
        sorted_results = sorted(results, key=lambda x: x['duration'], reverse=True)
        for r in sorted_results:
            status = "+" if r['success'] else "X"
            logging.info(f"  {status} {r['name']}: {r['duration']:.2f}s - {r.get('rows', 0):,} rows")

def parse_args():
    parser = argparse.ArgumentParser(
        description='Export ProcedureLog validation data to CSV files.',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument(
        '--output-dir',
        type=str,
        default=str(DATA_DIR),
        help='Directory where CSV files will be saved'
    )
    parser.add_argument(
        '--log-dir',
        type=str,
        default=str(LOG_DIR),
        help='Directory where log files will be saved'
    )
    parser.add_argument(
        '--database',
        type=str,
        required=True,
        help='Database name to connect to (REQUIRED). DO NOT use the live opendental database.'
    )
    parser.add_argument(
        '--connection-type',
        type=str,
        default='local_mariadb',
        choices=['local_mariadb'],
        help='Type of database connection to use (only local MariaDB connections are currently supported)'
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
    logging.info("Checking and creating required procedure validation indexes...")
    REQUIRED_INDEXES = [
        "CREATE INDEX IF NOT EXISTS idx_ml_procedurelog_core ON procedurelog (ProcNum, ProcDate, DateComplete, ProcStatus, ProcFee, CodeNum)",
        "CREATE INDEX IF NOT EXISTS idx_ml_procedurelog_window ON procedurelog (ProcDate)",
        "CREATE INDEX IF NOT EXISTS idx_ml_procedurelog_date_complete ON procedurelog (DateComplete)",
        "CREATE INDEX IF NOT EXISTS idx_ml_procedurelog_fee ON procedurelog (ProcFee)",
        "CREATE INDEX IF NOT EXISTS idx_ml_procedurelog_status ON procedurelog (ProcStatus)",
        "CREATE INDEX IF NOT EXISTS idx_ml_paysplit_proc ON paysplit (ProcNum, SplitAmt)",
        "CREATE INDEX IF NOT EXISTS idx_ml_claimproc_proc ON claimproc (ProcNum, InsPayAmt, InsPayEst, Status)",
        "CREATE INDEX IF NOT EXISTS idx_ml_procedurecode_code ON procedurecode (ProcCode)",
        "CREATE INDEX IF NOT EXISTS idx_ml_procedurelog_appointment ON procedurelog (AptNum)",
        "CREATE INDEX IF NOT EXISTS idx_ml_appointment_date ON appointment (AptDateTime, AptStatus)"
    ]
    try:
        manager = IndexManager(database_name)
        logging.info("Current procedure-related indexes:")
        manager.show_custom_indexes()
        logging.info("Creating required procedure validation indexes...")
        manager.create_indexes(REQUIRED_INDEXES)
        logging.info("Verifying indexes after creation:")
        manager.show_custom_indexes()
        logging.info("Procedure validation index creation complete")
    except Exception as e:
        logging.error(f"Error creating indexes: {str(e)}", exc_info=True)

def main():
    try:
        args = parse_args()
        setup_logging(args.log_dir)
        logging.info(f"Output directory: {args.output_dir}")
        logging.info(f"Database: {args.database}")
        logging.info(f"Connection type: {args.connection_type}")
        if args.start_date:
            logging.info(f"Start date filter: {args.start_date}")
        if args.end_date:
            logging.info(f"End date filter: {args.end_date}")
        logging.info(f"Parallel execution: {args.parallel}")
        factory = ConnectionFactory()
        connection = ConnectionFactory.create_connection('local_mariadb', args.database)
        ensure_indexes(connection, args.database)
        connection.close()
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
        logging.error("Fatal error in main execution", exc_info=True)
        raise

if __name__ == "__main__":
    main()
