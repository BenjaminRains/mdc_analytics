#!/usr/bin/env python
"""
Export Insurance Opportunity Analysis Script

This script executes all queries in the insurance opportunity analysis SQL file and exports 
the results of each query to separate CSV files for further analysis.

Features:
- Command-line arguments to specify date range and database
- Special handling for CTEs and multi-statement queries
- Detailed logging and summary reports

Usage:
    python export_insurance_opportunity_analysis.py [--from-date YYYY-MM-DD] [--to-date YYYY-MM-DD] [--database DB_NAME]

Requirements:
    - .env file must be set up in the project root with MariaDB configuration:
        MARIADB_HOST=localhost
        MARIADB_PORT=3307
        MARIADB_USER=your_username
        MARIADB_PASSWORD=your_password
        MARIADB_DATABASE=your_database
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
from typing import Optional, Tuple, List, Dict, NamedTuple
from dotenv import load_dotenv

# Add the src directory to the path to import project modules
src_path = Path(__file__).resolve().parents[3]
sys.path.append(str(src_path))

# Import the ConnectionFactory from the correct module
from src.connections.factory import ConnectionFactory

# Load environment variables from src/.env
env_path = src_path / "src" / ".env"
load_dotenv(dotenv_path=env_path)
logger = logging.getLogger('insurance_opportunity_analysis_export')
logger.info(f"Loading environment from: {env_path}")

from scripts.base.index_manager import sanitize_table_name

# Define constant paths
SCRIPT_DIR = Path(__file__).parent
DATA_DIR = SCRIPT_DIR / "data" / "insurance_opportunity_analysis"
LOGS_DIR = SCRIPT_DIR / "logs"
QUERY_PATH = SCRIPT_DIR / "queries" / "insurance_opportunity_analysis.sql"

# Create directories if they don't exist
os.makedirs(DATA_DIR, exist_ok=True)
os.makedirs(LOGS_DIR, exist_ok=True)

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(LOGS_DIR / f'insurance_opportunity_analysis_export_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log')
    ]
)

class DateRange(NamedTuple):
    """Represents a date range for filtering data in queries."""
    start_date: date
    end_date: date

    @classmethod
    def from_strings(cls, start: str, end: str) -> 'DateRange':
        """
        Create a DateRange from string dates in YYYY-MM-DD format
        
        Args:
            start: Start date string in YYYY-MM-DD format
            end: End date string in YYYY-MM-DD format
            
        Returns:
            DateRange object
        """
        try:
            start_date = datetime.strptime(start, "%Y-%m-%d").date()
            end_date = datetime.strptime(end, "%Y-%m-%d").date()
            
            if start_date > end_date:
                raise ValueError("Start date must be before or equal to end date")
                
            return cls(start_date, end_date)
        except ValueError as e:
            if "does not match format" in str(e):
                raise ValueError(f"Dates must be in YYYY-MM-DD format. Error: {e}")
            else:
                raise

def apply_date_parameters(sql: str, date_range: DateRange) -> str:
    """
    Apply date parameters to SQL query
    
    Args:
        sql: SQL query string
        date_range: DateRange object
        
    Returns:
        SQL query with date parameters applied
    """
    # Convert date range to strings
    from_date_str = date_range.start_date.strftime("%Y-%m-%d")
    to_date_str = date_range.end_date.strftime("%Y-%m-%d")
    
    # Replace date placeholders in the SQL
    modified_sql = sql
    
    # Replace date literals in DateRange CTE
    modified_sql = re.sub(
        r"'2024-01-01' AS start_date", 
        f"'{from_date_str}' AS start_date", 
        modified_sql
    )
    modified_sql = re.sub(
        r"'2024-12-31' AS end_date", 
        f"'{to_date_str}' AS end_date", 
        modified_sql
    )
    
    # Replace other date literals
    modified_sql = re.sub(r"'2024-01-01'", f"'{from_date_str}'", modified_sql)
    
    return modified_sql

def read_sql_file(file_path: Path) -> str:
    """
    Read SQL file contents
    
    Args:
        file_path: Path to SQL file
        
    Returns:
        String containing SQL file contents
    """
    with open(file_path, 'r') as f:
        return f.read()

def extract_all_queries(full_sql: str, date_range: DateRange) -> Dict[str, str]:
    """
    Extract each query from a multi-query SQL file
    
    Args:
        full_sql: String containing all SQL queries
        date_range: DateRange object for date parameter substitution
        
    Returns:
        Dictionary mapping query names to query strings
    """
    # For insurance opportunity analysis, we might have multiple queries separated by semicolons
    # But we'll start by treating it as one main query for simplicity
    queries = {}
    
    # First, strip comments
    sql_without_header_comments = re.sub(r'/\*.*?\*/', '', full_sql, flags=re.DOTALL)
    
    # Split by semicolon followed by a newline to separate multiple queries if they exist
    query_blocks = re.split(r';\s*\n', sql_without_header_comments)
    
    # Process each query block
    for i, block in enumerate(query_blocks):
        if not block.strip():
            continue  # Skip empty blocks
            
        # Try to extract a meaningful name from comments or analyze query structure
        # Look for section headings in comments
        section_match = re.search(r'--\s*(.*?)(?:\n|\r\n?)', block)
        
        if section_match:
            section_name = section_match.group(1).strip()
            clean_name = sanitize_table_name(section_name.lower().replace(' ', '_'))
        else:
            # Check if it's a specific analysis query
            if 'treatment plan' in block.lower():
                clean_name = 'treatment_plan_analysis'
            elif 'carrier' in block.lower():
                clean_name = 'carrier_analysis'
            elif 'insplan' in block.lower():
                clean_name = 'insurance_plan_analysis'
            else:
                clean_name = f"insurance_analysis_{i}"
        
        # Apply date parameters
        query_with_params = apply_date_parameters(block, date_range)
        
        queries[clean_name] = query_with_params
            
    # If no queries were found, use the entire SQL as one query
    if not queries:
        queries['insurance_opportunity_analysis'] = apply_date_parameters(full_sql, date_range)
        
    return queries

def extract_sql_query(query_text):
    """
    Extract the actual SQL without comment headers
    
    Args:
        query_text: SQL query text with comments
        
    Returns:
        SQL query without comments
    """
    # Remove comment lines
    lines = query_text.strip().split('\n')
    sql_lines = []
    
    for line in lines:
        if line.strip().startswith('--'):
            continue
        sql_lines.append(line)
    
    # Remove block comments
    sql_text = '\n'.join(sql_lines)
    sql_text = re.sub(r'/\*.*?\*/', '', sql_text, flags=re.DOTALL)
    
    return sql_text.strip()

def extract_final_select(query_text):
    """
    Extract the final SELECT statement from a query
    
    Args:
        query_text: SQL query
        
    Returns:
        Final SELECT statement
    """
    # Find all SELECT statements
    select_matches = list(re.finditer(r'SELECT\s+', query_text, re.IGNORECASE))
    
    if not select_matches:
        return query_text
    
    # Get the last SELECT
    last_select_pos = select_matches[-1].start()
    return query_text[last_select_pos:]

def execute_query(connection, db_name, query_name, query, output_dir=None):
    """
    Execute a query and return the resulting dataframe
    
    Args:
        connection: The database connection from ConnectionFactory
        db_name: Name of the database to connect to
        query_name: Name of the query (for logging)
        query: SQL query to execute
        output_dir: Directory to save CSV output (optional)
        
    Returns:
        tuple: (DataFrame with results, path to CSV file if saved)
    """
    # Extract the actual SQL without comment headers
    query_without_headers = extract_sql_query(query)
    
    # Check if this query contains CTEs or WITH clauses
    contains_cte = 'WITH ' in query_without_headers.upper() and ' AS (' in query_without_headers.upper()
    
    rows = []
    df = None
    csv_path = None
    
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)
    
    try:
        # For queries with CTEs, we need special handling
        if contains_cte:
            logging.info(f"Query '{query_name}' contains CTE. Using special handling for WITH clause.")
        
        # Get the actual MySQL connection from the ConnectionFactory connection object
        conn = connection.get_connection()
        
        # Get a cursor from the connection
        cursor = conn.cursor(dictionary=True)
        
        # Execute the query
        logging.info(f"Executing query '{query_name}'")
        cursor.execute(query_without_headers)
        
        # Fetch all rows
        rows = cursor.fetchall()
        logging.info(f"Query '{query_name}' returned {len(rows)} rows")
        
        # Create a dataframe from the results
        if rows:
            df = pd.DataFrame(rows)
            
            # Export to CSV if output_dir is specified
            if output_dir:
                csv_path = export_to_csv(df, output_dir, query_name)
                
        # Close cursor
        cursor.close()
        
    except Exception as e:
        logging.error(f"Error executing query '{query_name}': {e}")
        logging.error(f"Query: {query_without_headers[:500]}...")  # Log first 500 chars of query
        
    return df, csv_path
    
def export_to_csv(df: pd.DataFrame, output_dir: Path, query_name: str) -> Path:
    """
    Export dataframe to CSV
    
    Args:
        df: DataFrame to export
        output_dir: Directory to save CSV file
        query_name: Name of the query (for filename)
        
    Returns:
        Path to saved CSV file
    """
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Create filename with date
    current_date = datetime.now().strftime("%Y%m%d")
    csv_path = output_dir / f"{query_name}_{current_date}.csv"
    
    # Export to CSV
    df.to_csv(csv_path, index=False)
    logging.info(f"Exported {len(df)} rows to {csv_path}")
    
    return csv_path

def extract_report_data(from_date='2024-01-01', to_date='2024-12-31', db_name='opendental_analytics_opendentalbackup_02_28_2025'):
    """
    Extract data from the insurance opportunity analysis SQL into CSV files
    
    Args:
        from_date (str): Start date in YYYY-MM-DD format
        to_date (str): End date in YYYY-MM-DD format
        db_name (str): Database name to connect to
    """
    # Use the existing constants
    sql_file = QUERY_PATH
    output_dir = DATA_DIR
    
    # Set up logging
    setup_logging()
    
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Create DateRange object for better date handling
    try:
        date_range = DateRange.from_strings(from_date, to_date)
    except ValueError as e:
        logging.error(f"Invalid date range: {e}")
        return
    
    # Read the SQL file
    try:
        with open(sql_file, 'r') as f:
            full_sql = f.read()
    except FileNotFoundError:
        logging.error(f"SQL file not found: {sql_file}")
        print(f"Error: SQL file not found: {sql_file}")
        return
    
    # Extract queries from SQL file with date parameters
    queries = extract_all_queries(full_sql, date_range)
    logging.info(f"Extracted {len(queries)} queries from {sql_file}")
    logging.info(f"Using date range: {date_range.start_date} to {date_range.end_date}")
    logging.info(f"Connecting to database: {db_name}")
    
    # Initialize connection with the database name directly
    connection = ConnectionFactory.create_connection('local_mariadb', database=db_name)
    
    # Dictionary to store results
    query_results = {}
    
    # Process each query
    for query_name, query in queries.items():
        logging.info(f"Processing query: {query_name}")
        df, csv_path = execute_query(connection, db_name, query_name, query, output_dir)
        query_results[query_name] = {
            'success': df is not None,
            'rows': len(df) if df is not None else 0,
            'file': csv_path
        }
    
    # Close connection
    if connection:
        connection.close()
    
    # Print summary
    print_summary(query_results, output_dir)
    
    return query_results

def setup_logging():
    """Set up logging configuration"""
    log_dir = LOGS_DIR
    os.makedirs(log_dir, exist_ok=True)
    
    log_file = log_dir / f"insurance_opportunity_analysis_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
    
    logging.basicConfig(
        level=logging.DEBUG,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler(log_file)
        ]
    )
    
    logging.info(f"Logging to {log_file}")

def print_summary(query_results, output_dir):
    """
    Print a summary of the export process
    
    Args:
        query_results: Dictionary of query results
        output_dir: Output directory
    """
    print("\n" + "="*80)
    print(f"INSURANCE OPPORTUNITY ANALYSIS EXPORT SUMMARY")
    print("="*80)
    
    total_queries = len(query_results)
    successful_queries = sum(1 for result in query_results.values() if result['success'])
    total_rows = sum(result['rows'] for result in query_results.values())
    
    print(f"Total queries: {total_queries}")
    print(f"Successful queries: {successful_queries}")
    print(f"Failed queries: {total_queries - successful_queries}")
    print(f"Total rows exported: {total_rows}")
    print(f"Output directory: {output_dir}")
    print("\nDetailed Results:")
    
    for query_name, result in query_results.items():
        status = "SUCCESS" if result['success'] else "FAILED"
        print(f"  {query_name}: {status} - {result['rows']} rows")
        if result['file']:
            print(f"    Output: {result['file']}")
    
    print("="*80)

def main():
    """Main function to execute the export process."""
    try:
        # Add simple command-line argument parsing
        parser = argparse.ArgumentParser(description='Export insurance opportunity analysis data.')
        
        # Date range arguments
        parser.add_argument('--from-date', type=str, help='Start date in YYYY-MM-DD format', default='2024-01-01')
        parser.add_argument('--to-date', type=str, help='End date in YYYY-MM-DD format', default='2024-12-31')
        parser.add_argument('--database', type=str, help='Database name', default='opendental_analytics_opendentalbackup_02_28_2025')
        
        args = parser.parse_args()
        
        # Set up basic logging for pre-initialization errors
        if not os.path.exists(LOGS_DIR):
            os.makedirs(LOGS_DIR, exist_ok=True)
        pre_log_file = os.path.join(LOGS_DIR, f"pre_init_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log")
        logging.basicConfig(level=logging.INFO, 
                            format='%(asctime)s - %(levelname)s - %(message)s',
                            handlers=[logging.FileHandler(pre_log_file), logging.StreamHandler()])
        
        # Validate date format
        try:
            # Use DateRange for validation
            DateRange.from_strings(args.from_date, args.to_date)
        except ValueError as e:
            logging.error(f"Date validation error: {e}")
            print(f"Error: Date validation failed. {e}")
            return
        
        # Check if SQL file exists
        if not os.path.exists(QUERY_PATH):
            logging.error(f"SQL file not found: {QUERY_PATH}")
            print(f"Error: SQL file not found: {QUERY_PATH}")
            return
        
        # Call the function with arguments
        extract_report_data(from_date=args.from_date, to_date=args.to_date, db_name=args.database)
    except Exception as e:
        logging.error(f"Error in export process: {e}")
        print(f"Error: {e}")
        import traceback
        logging.error(traceback.format_exc())
        return None

if __name__ == "__main__":
    main() 