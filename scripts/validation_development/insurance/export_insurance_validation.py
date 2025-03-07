"""
Export Insurance Validation Data

This script connects to the specified database, ensures required indexes exist,
loads a set of common table expressions (CTEs) from separate .sql files, and executes
a series of SQL queries for insurance validation. The results for each query
are exported to separate CSV files. The files are then analyzed to identify and
diagnose issues with insurance configuration, claims, and payment patterns.

The exported CSV files are loaded and analyzed in the Jupyter notebook:
    notebooks/insurance_analysis.ipynb
This notebook provides interactive visualizations, statistical analysis, and
detailed investigation of validation results. It helps identify patterns,
anomalies, and potential issues in the insurance data.

Validation Scope:
----------------
1. Carrier Configuration
   - Basic carrier setup and relationships
   - Electronic filing settings
   - Fee schedule assignments
   - Plan configurations

2. Payment Analysis
   - Payment accuracy vs estimates
   - Payment timing patterns
   - Write-off patterns
   - Deductible handling

3. Claims Processing
   - Claim submission patterns
   - Rejection rates and reasons
   - Processing time analysis
   - Electronic vs paper claims

Key Validation Questions:
-----------------------
Carrier Configuration:
- Are carriers properly configured for electronic filing?
- Do carriers have appropriate fee schedules assigned?
- Are special handling flags set correctly?
- Are plan configurations consistent within carriers?

Payment Analysis:
- How accurately do carriers pay compared to estimates?
- What are typical payment processing times?
- Are write-offs properly documented and reasonable?
- How are deductibles being applied?

Claims Processing:
- What percentage of claims are processed electronically?
- What are common rejection reasons by carrier?
- Are there patterns in claim processing times?
- Are claims being submitted with complete information?

Usage:
    python export_insurance_validation.py [--output-dir <path>] [--log-dir <path>]
                                        [--database <dbname>] [--queries <names>]
                                        [--connection-type <type>]
                                        [--start-date <YYYY-MM-DD>]
                                        [--end-date <YYYY-MM-DD>]
                                        [--parallel]

Query files and common CTE definitions are stored as separate .sql files in the
'queries' directory. The required CTEs are dynamically prepended to each query,
with date filters replaced by CLI parameters (if provided).
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
from scripts.validation_development.index_manager import IndexManager

# Directory constants
BASE_DIR = Path(__file__).parent.resolve()
QUERIES_DIR = BASE_DIR / "queries"
CTES_DIR = QUERIES_DIR / "ctes"
LOG_DIR = BASE_DIR / "logs"
DATA_DIR = BASE_DIR / "data"

# Query descriptions and filenames
QUERY_DESCRIPTIONS = {
    'carrier_payment_analysis_optimized': 'Analyzes carrier payment patterns, efficiency, and fee schedule adherence',
    'carrier_plan_configuration': 'Analyzes carrier plan configuration, fee schedules, and electronic filing settings',
    'claim_denial_patterns': 'Analyzes claim denial patterns, including status, processing times, and financial data',
    'insurance_opportunity_analysis': 'Analyzes insurance opportunity analysis, including carrier performance, procedure analysis, insurance plan insights, patient coverage patterns, and financial opportunity analysis',
    'pending_treatment_ins_opportunities': 'Analyzes pending treatment insurance opportunities, including treatment plans, patients, procedures, and insurance information'
}

def setup_logging(log_dir: str = str(LOG_DIR)) -> str:
    """Setup logging configuration."""
    Path(log_dir).mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    log_file = os.path.join(log_dir, f'insurance_validation_{timestamp}.log')
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_file),
            logging.StreamHandler()
        ]
    )
    logging.info("Starting insurance validation export")
    logging.info(f"Log file: {log_file}")
    return log_file

def ensure_directory_exists(directory: str):
    """Ensure the specified directory exists."""
    Path(directory).mkdir(parents=True, exist_ok=True)
    logging.info(f"Ensured directory exists: {directory}")

def parse_required_ctes(query_sql: str) -> List[str]:
    """Parse the header of the query SQL file to extract required CTEs."""
    required_ctes = []
    for line in query_sql.splitlines():
        if line.startswith('-- Dependent CTEs:'):
            cte_line = line.replace('-- Dependent CTEs:', '').strip()
            required_ctes = [cte.strip() for cte in cte_line.split(',') if cte.strip()]
            required_ctes = [cte[:-4] if cte.endswith('.sql') else cte for cte in required_ctes]
            break
    return required_ctes

# Date filter parsing using regex
DATE_FILTER_REGEX = re.compile(
    r'--\s*Date\s*filter:\s*([\d]{4}-[\d]{2}-[\d]{2})\s*to\s*([\d]{4}-[\d]{2}-[\d]{2})',
    re.IGNORECASE
)

class DateRange(NamedTuple):
    """Represents a date range for filtering data in queries and CTEs."""
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

def parse_date_filter(content: str, filename: str = "unknown") -> Optional[DateRange]:
    """Parse the date filter from SQL content."""
    match = DATE_FILTER_REGEX.search(content)
    if not match:
        logging.debug(f"No date filter found in {filename}")
        return None
        
    try:
        return DateRange.from_strings(match.group(1), match.group(2))
    except ValueError:
        logging.warning(f"Invalid date filter in {filename}")
        return None

def apply_date_filter(sql: str, date_range: DateRange, filename: str = "unknown") -> str:
    """Apply date range to SQL, replacing template variables."""
    has_start = '{{START_DATE}}' in sql
    has_end = '{{END_DATE}}' in sql
    
    if has_start or has_end:
        if not (has_start and has_end):
            logging.warning(f"Incomplete date placeholders in {filename}")
        return sql.replace('{{START_DATE}}', str(date_range.start_date)).replace('{{END_DATE}}', str(date_range.end_date))
    
    return sql

def get_dynamic_ctes(required_ctes: List[str], global_date_range: Optional[DateRange] = None) -> str:
    """Assemble CTEs in the exact order specified in the dependency comment."""
    if not required_ctes:
        return ""
    
    logging.debug(f"Processing CTEs in specified order: {', '.join(required_ctes)}")
    
    cte_statements = []
    for cte_name in required_ctes:
        try:
            cte_content = load_cte_file(cte_name)
            file_date_range = parse_date_filter(cte_content, f"CTE {cte_name}")
            date_range = global_date_range or file_date_range or DateRange(date(2024, 1, 1), date(2025, 1, 1))
            cte_content = apply_date_filter(cte_content, date_range, f"CTE {cte_name}")
            
            cte_lines = cte_content.splitlines()
            definition_start = 0
            for i, line in enumerate(cte_lines):
                if not line.strip().startswith('--'):
                    definition_start = i
                    break
            cte_definition = '\n'.join(cte_lines[definition_start:]).strip()
            
            # Remove any WITH or AS keywords from the CTE definition
            if cte_definition.upper().startswith('WITH '):
                cte_definition = cte_definition[5:].strip()
            
            # Remove trailing comma if present
            cte_definition = cte_definition.rstrip(',')
            
            cte_statements.append(cte_definition)
            logging.debug(f"Added CTE: {cte_name}")
            
        except Exception as e:
            logging.error(f"Error processing CTE {cte_name}: {e}")
            raise
    
    return ',\n\n'.join(cte_statements)

def get_exports(
    global_start_date: Optional[str] = None,
    global_end_date: Optional[str] = None,
    selected_queries: Optional[List[str]] = None
) -> List[Dict]:
    """Assemble export configurations with validated date filtering."""
    exports = []
    
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
            query_date_range = parse_date_filter(query_sql, f"query {query_name}")
            date_range = global_date_range or query_date_range or DateRange(date(2024, 1, 1), date(2025, 1, 1))
            query_sql = apply_date_filter(query_sql, date_range, f"query {query_name}")
            
            required_ctes = parse_required_ctes(query_sql)
            if required_ctes:
                logging.info(f"Query {query_name} requires CTEs (in order): {', '.join(required_ctes)}")
                cte_definitions = get_dynamic_ctes(required_ctes, date_range)
                full_query = f"WITH {cte_definitions}\n\n{query_sql}"
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

def process_single_export(export, factory, connection_type, database, output_dir):
    """Process a single export query and save results to CSV."""
    fresh_connection = None
    start_time = datetime.now()
    try:
        fresh_connection = factory.create_connection(connection_type, database)
        mysql_connection = fresh_connection.connect()
        
        with mysql_connection.cursor(dictionary=True) as cursor:
            if export['name'] in ['carrier_performance', 'carrier_payment_analysis']:
                cursor.execute("SET SESSION group_concat_max_len = 4096")
            
            logging.debug(f"Executing main query for {export['name']}:")
            logging.debug("SQL:\n" + export['query'])
            
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
        logging.error(f"Query that failed for {export['name']}:")
        logging.error("SQL:\n" + export['query'])
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
    """Export validation results by executing queries."""
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
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description='Export Insurance validation data to CSV files.',
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
    """Ensure required indexes exist for insurance validation."""
    logging.info("Checking and creating required insurance validation indexes...")
    REQUIRED_INDEXES = [
        "CREATE INDEX IF NOT EXISTS idx_ml_claimproc_core ON claimproc (ProcNum, InsPayAmt, InsPayEst, Status, ClaimNum)",
        "CREATE INDEX IF NOT EXISTS idx_ml_proc_core ON procedurelog (ProcDate, ProcStatus, ProcFee, CodeNum)",
        "CREATE INDEX IF NOT EXISTS idx_ml_paysplit_payment ON paysplit (ProcNum, PayNum, SplitAmt)",
        "CREATE INDEX IF NOT EXISTS idx_ml_payment_core ON payment (PayNum, PayDate)",
        "CREATE INDEX IF NOT EXISTS idx_ml_fee_core ON fee (CodeNum, Amount)",
        "CREATE INDEX IF NOT EXISTS idx_ml_claim_lookup ON claim (ClaimNum)",
        "CREATE INDEX IF NOT EXISTS idx_ml_claimproc_status ON claimproc (Status)",
        "CREATE INDEX IF NOT EXISTS idx_ml_claimproc_procnum ON claimproc (ProcNum)"
    ]
    try:
        manager = IndexManager(database_name)
        logging.info("Current insurance-related indexes:")
        manager.show_custom_indexes()
        logging.info("Creating required insurance validation indexes...")
        manager.create_indexes(REQUIRED_INDEXES)
        logging.info("Verifying indexes after creation:")
        manager.show_custom_indexes()
        logging.info("Insurance validation index creation complete")
    except Exception as e:
        logging.error(f"Error creating indexes: {str(e)}", exc_info=True)

def load_query_file(query_name: str) -> str:
    """Load a query file from the queries directory."""
    query_path = QUERIES_DIR / f"{query_name}.sql"
    if not query_path.exists():
        raise FileNotFoundError(f"Query file not found: {query_path}")
    try:
        return query_path.read_text(encoding="utf-8")
    except Exception as e:
        logging.error(f"Error loading query file '{query_name}' from {query_path}: {e}")
        raise IOError(f"Failed to read query file {query_path}: {str(e)}")

def load_cte_file(cte_name: str) -> str:
    """Load a CTE file from the ctes subdirectory."""
    cte_path = CTES_DIR / f"{cte_name}.sql"
    if not cte_path.exists():
        raise FileNotFoundError(f"CTE file not found: {cte_path}")
    try:
        return cte_path.read_text(encoding='utf-8')
    except Exception as e:
        logging.error(f"Error loading CTE file {cte_name} from {cte_path}: {e}")
        raise IOError(f"Failed to read CTE file {cte_path}: {str(e)}")

def validate_sql_directories():
    """Validate that required SQL directories exist and are accessible."""
    for path, name in [
        (QUERIES_DIR, "queries"),
        (CTES_DIR, "CTEs")
    ]:
        if not path.exists():
            raise FileNotFoundError(f"Required {name} directory not found: {path}")
        if not path.is_dir():
            raise NotADirectoryError(f"Required {name} path is not a directory: {path}")
        try:
            next(path.iterdir(), None)
        except PermissionError:
            raise PermissionError(f"Cannot access {name} directory: {path}")

def main():
    """Main execution function."""
    try:
        args = parse_args()
        setup_logging(args.log_dir)
        
        validate_sql_directories()
        
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
        logging.info("Insurance validation export completed successfully")
    except Exception as e:
        logging.error("Fatal error in main execution", exc_info=True)
        raise

if __name__ == "__main__":
    main()
