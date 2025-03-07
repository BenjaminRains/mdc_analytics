#!/usr/bin/env python
"""
Export Unearned Income Data

This script executes queries from the unearned income SQL file and exports 
the results to CSV files for financial analysis of unearned income.

Output Files Generated:
-----------------------
All files are stored in scripts/validation/payment_split/data/
1. unearned_income_main_transactions.csv - Detailed transaction data
2. unearned_income_unearned_type_summary.csv - Summary statistics by unearned type
3. unearned_income_payment_type_summary.csv - Summary statistics by payment type
4. unearned_income_monthly_trend.csv - Monthly trend of unearned income
5. unearned_income_patient_balance_report.csv - Patient balance information
6. unearned_income_aging_analysis.csv - Aging analysis of unearned income
7. unearned_income_negative_prepayments.csv - Negative prepayment transactions (potential refunds or adjustments)

Use Case:
---------
This script is specifically designed for financial accounting analysis of unearned income
(prepayments, deposits) that has not yet been applied to services. It helps analyze:
- Aging of unearned income amounts
- Distribution by unearned income type
- Payment types associated with unearned income
- Patient-level details for manual review

Key Differences from Income Transfer Export:
- Focuses on UnearnedType (accounting classification) rather than provider assignment
- Analyzes pre-payment patterns and financial risk
- Outputs are primarily for financial reporting and balance verification

Usage:
    python export_unearned_income_data.py --start-date YYYY-MM-DD --end-date YYYY-MM-DD [--database DB_NAME]

Requirements:
    - .env file must be set up in the project root with MariaDB configuration
    - SQL file should be structured according to expected patterns
"""

import os
import sys
import re
import logging
import pandas as pd
import argparse
from datetime import datetime, date
from pathlib import Path
from typing import Dict, List, Optional, Tuple, NamedTuple, Any
from dotenv import load_dotenv

# Add the src directory to the path to import project modules
src_path = Path(__file__).resolve().parents[3]
sys.path.append(str(src_path))

# Load environment variables from src/.env
env_path = src_path / "src" / ".env"
load_dotenv(dotenv_path=env_path)

# Import shared utilities
from scripts.validation.payment_split.utils.sql_export_utils import (
    DateRange, apply_date_parameters, read_sql_file, sanitize_table_name,
    export_to_csv
)

# Import other required modules
from src.connections.factory import ConnectionFactory, get_valid_databases

def init_logging():
    """Initialize basic console logging for startup messages.
    This will be replaced by setup_logging() later.
    """
    # Clean up any existing handlers
    root_logger = logging.getLogger()
    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)
    
    # Add a single console handler
    console_handler = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    console_handler.setFormatter(formatter)
    root_logger.setLevel(logging.INFO)
    root_logger.addHandler(console_handler)

# Initialize basic logging
init_logging()

# Load environment variables from src/.env
env_path = src_path / "src" / ".env"
load_dotenv(dotenv_path=env_path)
logging.info(f"Loading environment from: {env_path}")

# Constants
SCRIPT_DIR = Path(__file__).parent
QUERY_PATH = SCRIPT_DIR / "queries"
CTE_PATH = QUERY_PATH / "ctes"
DATA_DIR = SCRIPT_DIR / "data" / "unearned_income"
LOG_DIR = SCRIPT_DIR / "logs"

# Query descriptions for documentation and reporting
QUERY_DESCRIPTIONS = {
    'unearned_income_aging_analysis': 'Aging analysis of unearned income payments by time buckets',
    'unearned_income_main_transactions': 'Main transaction data for unearned income payments',
    'unearned_income_monthly_trend': 'Monthly trend analysis of unearned income',
    'unearned_income_negative_prepayments': 'Analysis of negative prepayments in the system',
    'unearned_income_patient_balance_report': 'Patient balance report with unearned income details',
    'unearned_income_payment_type_date_summary': 'Summary of payment types by date for unearned income',
    'unearned_income_top_patients': 'Top patients with unearned income balances',
    'unearned_income_unearned_type_summary': 'Summary of unearned income by unearned type'
}

# CTE files and their dependencies for proper loading order
CTE_DEPENDENCIES = {
    'unearned_income_patient_balances.sql': [],  # No dependencies
    'unearned_income_paytype_def.sql': [],  # No dependencies
    'unearned_income_provider_def.sql': [],  # No dependencies
    'unearned_income_unearntype_def.sql': []  # No dependencies
}

def get_ctes(date_range: DateRange = None) -> str:
    """
    Load and combine all unearned income CTE SQL files.
    
    Args:
        date_range: DateRange object with start and end dates
        
    Returns:
        Combined CTEs SQL string
    """
    # Require a DateRange to be provided
    if date_range is None:
        raise ValueError("Date range must be provided")
    
    # Check if CTE directory exists
    if not CTE_PATH.exists():
        logging.warning(f"CTE directory not found: {CTE_PATH}")
        return ""
    
    # List of main query files to check for CTEs
    main_query_files = [
        "unearned_income_aging_analysis.sql",
        "unearned_income_main_transactions.sql",
        "unearned_income_monthly_trend.sql",
        "unearned_income_negative_prepayments.sql",
        "unearned_income_patient_balance_report.sql",
        "unearned_income_payment_type_date_summary.sql",
        "unearned_income_top_patients.sql",
        "unearned_income_unearned_type_summary.sql"
    ]
    
    # Set of required CTEs (will be populated by scanning query files)
    required_ctes = set()
    
    # Scan main query files for include directives to identify required CTEs
    for query_file in main_query_files:
        query_path = QUERY_PATH / query_file
        if query_path.exists():
            try:
                query_content = read_sql_file(str(query_path))
                include_pattern = r'<<include:([^>]+)>>'
                includes = re.findall(include_pattern, query_content)
                
                for include_path in includes:
                    if include_path.startswith('ctes/'):
                        # Remove the ctes/ prefix
                        cte_name = include_path.replace('ctes/', '')
                        required_ctes.add(cte_name)
                    elif 'unearned_income_' in include_path:
                        required_ctes.add(include_path)
            except Exception as e:
                logging.error(f"Error scanning query file {query_file}: {str(e)}")
    
    # Get all SQL files in the CTE directory
    all_cte_files = list(CTE_PATH.glob('*.sql'))
    logging.info(f"Found {len(all_cte_files)} CTE files in {CTE_PATH}")
    
    # Add all unearned_income_ CTEs to the required set
    for cte_file in all_cte_files:
        if cte_file.name.startswith('unearned_income_'):
            required_ctes.add(cte_file.name)
    
    # Ensure the primary CTEs are included (these are fundamental building blocks)
    base_ctes = [
        "unearned_income_unearntype_def.sql",  # UnearnedType definitions first
        "unearned_income_paytype_def.sql",     # PayType definitions next
        "unearned_income_provider_defs.sql",   # Provider definitions (note: plural "defs")
        "unearned_income_patient_balances.sql" # Patient balances last as they may use the other CTEs
    ]
    
    for cte in base_ctes:
        required_ctes.add(cte)
    
    logging.info(f"Identified {len(required_ctes)} required CTEs: {', '.join(required_ctes)}")
    
    # Track processed files to avoid circular dependencies
    processed_files = set()
    
    # Store all CTEs here
    all_ctes = []
    
    # Function to process CTEs with include directives
    def process_cte(cte_file_path, indent_level=0):
        # Check for circular dependencies and skip if already processed
        if str(cte_file_path) in processed_files:
            logging.debug(f"{'  ' * indent_level}Skipping already processed file: {cte_file_path.name}")
            return None
        
        # Mark file as processed
        processed_files.add(str(cte_file_path))
        
        try:
            # Read the file contents
            cte_content = read_sql_file(str(cte_file_path))
            
            # Extract CTE name from the first AS statement
            cte_name_match = re.search(r'(\w+)\s+AS\s*\(', cte_content)
            original_cte_name = cte_name_match.group(1) if cte_name_match else None
            
            # IMPORTANT CHANGE: We'll no longer rename the CTEs in the content
            # Instead, we'll just add a comment to identify where it came from
            # This preserves the original CTE names that are referenced in the queries
            
            # Check for include directives in the content
            include_pattern = r'<<include:([^>]+)>>'
            includes = re.findall(include_pattern, cte_content)
            
            if includes:
                logging.debug(f"{'  ' * indent_level}Processing includes in {cte_file_path.name}: {includes}")
                
                # Process each include directive
                for include_path in includes:
                    # Determine if it's a relative or full path
                    if include_path.startswith('ctes/'):
                        # Path relative to query directory
                        include_file = QUERY_PATH / include_path
                    else:
                        # Path relative to CTE directory
                        include_file = CTE_PATH / include_path
                    
                    if include_file.exists():
                        # Process the included file first (recursive call)
                        include_content = process_cte(include_file, indent_level + 1)
                        
                        # Replace the include directive with empty string (it will be included separately)
                        if include_content is not None:
                            cte_content = cte_content.replace(f'<<include:{include_path}>>', '')
                    else:
                        logging.warning(f"{'  ' * indent_level}Include file not found: {include_file}")
                        # Remove the include directive to avoid SQL syntax errors
                        cte_content = cte_content.replace(f'<<include:{include_path}>>', '')
            
            # Apply date parameters
            if cte_content and date_range:
                cte_content = apply_date_parameters(cte_content, date_range)
                
            # Clean up content - remove empty lines and trim whitespace
            cte_content = "\n".join(line for line in cte_content.split("\n") if line.strip())
                
            # Add a comment indicating the source file
            cte_with_comment = f"""
-- From {cte_file_path.name}
{cte_content}"""
            
            return cte_with_comment
        
        except Exception as e:
            logging.error(f"{'  ' * indent_level}Error loading CTE file {cte_file_path}: {str(e)}")
            return None
    
    # Process the base CTEs first (they have known dependencies)
    for cte_name in base_ctes:
        if cte_name in required_ctes:
            cte_file = CTE_PATH / cte_name
            if cte_file.exists():
                logging.info(f"Processing base CTE: {cte_name}")
                cte_content = process_cte(cte_file)
                if cte_content:
                    all_ctes.append(cte_content)
                    logging.debug(f"Added base CTE from {cte_name}")
            else:
                logging.warning(f"Base CTE file not found: {cte_name}")
    
    # Now process the remaining required CTEs
    for cte_name in sorted(required_ctes):  # Sort to ensure deterministic order
        if cte_name not in base_ctes:  # Skip those we already processed
            cte_file = CTE_PATH / cte_name
            if cte_file.exists() and str(cte_file) not in processed_files:
                logging.info(f"Processing required CTE: {cte_name}")
                cte_content = process_cte(cte_file)
                if cte_content:
                    all_ctes.append(cte_content)
                    logging.debug(f"Added required CTE from {cte_name}")
            elif not cte_file.exists():
                logging.warning(f"Required CTE file not found: {cte_name}")
    
    # Join all CTEs with appropriate separators - don't add comma after the last CTE
    combined_ctes = ""
    for i, cte in enumerate(all_ctes):
        combined_ctes += cte.strip()
        if i < len(all_ctes) - 1:
            # If not the last CTE, add a comma after it
            combined_ctes += ",\n\n\n"
        else:
            # Add spacing after the last CTE
            combined_ctes += "\n"
    
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
    query_path = QUERY_PATH / f"{query_name}.sql"
    
    # Check if file exists
    if not query_path.exists():
        error_msg = f"Query file not found: {query_name}.sql at {query_path}"
        logging.error(error_msg)
        return {
            'name': query_name,
            'file': f"{query_name}.csv",
            'query': f"SELECT '{error_msg}' AS error_message",
            'description': QUERY_DESCRIPTIONS.get(query_name, "Unknown query")
        }
    
    # Load query content
    try:
        logging.info(f"Loading query file: {query_path}")
        query_content = read_sql_file(str(query_path))
    except Exception as e:
        error_msg = f"Error reading query file {query_name}.sql: {str(e)}"
        logging.error(error_msg)
        return {
            'name': query_name,
            'file': f"{query_name}.csv",
            'query': f"SELECT '{error_msg}' AS error_message",
            'description': QUERY_DESCRIPTIONS.get(query_name, "Unknown query")
        }
    
    # Check if query is empty
    if not query_content.strip():
        error_msg = f"Query file is empty: {query_name}.sql"
        logging.error(error_msg)
        return {
            'name': query_name,
            'file': f"{query_name}.csv",
            'query': f"SELECT '{error_msg}' AS error_message",
            'description': QUERY_DESCRIPTIONS.get(query_name, "Unknown query")
        }
    
    # Require a DateRange to be provided
    if date_range is None:
        raise ValueError("Date range must be provided")
    
    # Process include directives in the query
    include_pattern = r'<<include:([^>]+)>>'
    includes = re.findall(include_pattern, query_content)
    
    # Process each include directive
    for include_path in includes:
        # Determine the full path to the include file
        if include_path.startswith('ctes/'):
            # Path is relative to the query directory
            include_file = QUERY_PATH / include_path
        else:
            # Path is relative to the CTE directory
            include_file = CTE_PATH / include_path
        
        if include_file.exists():
            try:
                # Read the include file
                include_content = read_sql_file(str(include_file))
                
                # Apply date parameters to the included content
                if include_content and date_range:
                    include_content = apply_date_parameters(include_content, date_range)
                
                # Replace the include directive with the file content
                query_content = query_content.replace(f'<<include:{include_path}>>', include_content)
                logging.debug(f"Processed include directive: {include_path}")
            except Exception as e:
                logging.error(f"Error processing include directive '{include_path}': {str(e)}")
                # Remove the include directive to avoid SQL syntax errors
                query_content = query_content.replace(f'<<include:{include_path}>>', f"-- Error including {include_path}: {str(e)}")
        else:
            logging.warning(f"Include file not found: {include_file}")
            # Remove the include directive to avoid SQL syntax errors
            query_content = query_content.replace(f'<<include:{include_path}>>', f"-- Missing include: {include_path}")
    
    # Prepare SQL with date parameters and CTEs - ensure each statement ends with a semicolon
    final_query = f"""
-- Set date parameters
SET @start_date = '{date_range.start_date}';
SET @end_date = '{date_range.end_date}';
"""
    
    # Add the WITH clause only if CTEs are provided
    if ctes and ctes.strip():
        logging.info(f"Adding CTEs to query: {query_name}")
        
        # Ensure query_content ends with a semicolon
        if not query_content.strip().endswith(';'):
            query_content = query_content.strip() + ';'
            
        final_query += f"""
-- Common Table Expressions
WITH {ctes}

-- Main Query from {query_name}.sql
{query_content}
"""
    else:
        logging.warning(f"No CTEs provided for query: {query_name}")
        
        # Ensure query_content ends with a semicolon
        if not query_content.strip().endswith(';'):
            query_content = query_content.strip() + ';'
            
        final_query += f"""
-- Main Query from {query_name}.sql (no CTEs provided)
{query_content}
"""
    
    logging.info(f"Prepared query for {query_name}")
    
    return {
        'name': query_name,
        'file': f"{query_name}.csv",
        'query': final_query,
        'description': QUERY_DESCRIPTIONS.get(query_name, "Unknown query")
    }

def get_exports(ctes: str, date_range: DateRange = None) -> list:
    """
    Get all export queries for unearned income data.
    
    Args:
        ctes: Common Table Expressions string
        date_range: DateRange object for date parameter substitution
        
    Returns:
        List of export configurations
    """
    exports = []
    
    # List of query files to process (same as in get_ctes)
    query_names = [
        'unearned_income_aging_analysis',
        'unearned_income_main_transactions',
        'unearned_income_monthly_trend',
        'unearned_income_negative_prepayments',
        'unearned_income_patient_balance_report',
        'unearned_income_payment_type_date_summary',
        'unearned_income_top_patients',
        'unearned_income_unearned_type_summary'
    ]
    
    # Check if the files exist and add a warning if not
    missing_files = []
    for query_name in query_names:
        if not (QUERY_PATH / f"{query_name}.sql").exists():
            missing_files.append(query_name)
    
    if missing_files:
        logging.warning(f"The following query files were not found: {', '.join(missing_files)}")
    
    # Build export configuration for each query
    for query_name in query_names:
        # Skip files that don't exist
        if not (QUERY_PATH / f"{query_name}.sql").exists():
            logging.warning(f"Skipping missing query file: {query_name}.sql")
            continue
            
        export_config = get_query(query_name, ctes, date_range)
        exports.append(export_config)
        logging.info(f"Added export config for {query_name}")
    
    return exports

def execute_query(connection, db_name, query_name, query, output_dir=None):
    """
    Execute a query and optionally export the results to CSV.
    
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
        
        # Log the first part of the query for debugging
        logging.info(f"Query preview for '{query_name}': {query_without_headers[:500].replace(chr(10), ' ')}...")
        
        # Connect to the database
        conn = connection.get_connection()
        cursor = conn.cursor(dictionary=True)
        
        # Execute the query - Following the successful approach from test_db_connection.py
        logging.info(f"Executing query '{query_name}' with separate statements")
        try:
            # Split the query into separate statements by semicolon
            statements = [stmt.strip() for stmt in query_without_headers.split(';') if stmt.strip()]
            
            for i, stmt in enumerate(statements):
                if stmt.strip():
                    # Log shorter preview of each statement
                    logging.info(f"Executing statement {i+1}/{len(statements)}: {stmt[:100].replace(chr(10), ' ')}...")
                    cursor.execute(stmt)
                    
                    # Only fetch results from the last statement (the actual query, not the SET commands)
                    if i == len(statements) - 1:
                        rows = cursor.fetchall()
                        logging.info(f"Query '{query_name}' returned {len(rows)} rows")
                        
                        # Create a DataFrame from the results
                        if rows:
                            df = pd.DataFrame(rows)
                            
                            # Export to CSV if an output directory is provided
                            if output_dir and not df.empty:
                                csv_path = export_to_csv(
                                    df, 
                                    output_dir, 
                                    query_name, 
                                    prefix='unearned_income', 
                                    include_date=False  # Unearned income uses fixed descriptive names
                                )
            
        except Exception as sql_err:
            logging.error(f"SQL Error executing query '{query_name}': {sql_err}")
            logging.error(f"SQL Statement causing the error (first 1000 chars):\n{query_without_headers[:1000]}")
            
        cursor.close()
        
    except Exception as e:
        logging.error(f"Error executing query '{query_name}': {e}")
        logging.error(f"Query (first 500 chars): {query_without_headers[:500]}...")  # Log first 500 chars of query
        
    return df, csv_path

def test_cte_query(connection, db_name, date_range):
    """
    Test a simple CTE query to verify database connectivity and CTE functionality
    
    Args:
        connection: Database connection factory
        db_name: Database name
        date_range: DateRange object with start and end dates
        
    Returns:
        Whether the test was successful
    """
    try:
        logging.info("Testing simple CTE query...")
        
        conn = connection.get_connection()
        cursor = conn.cursor(dictionary=True)
        
        # Build a simple test query with similar structure to our main queries
        test_query = f"""
        -- Set date parameters
        SET @start_date = '{date_range.start_date}';
        SET @end_date = '{date_range.end_date}';
        
        -- Simple CTE
        WITH payment_counts AS (
            SELECT 
                COUNT(*) as payment_count,
                MIN(DatePay) as min_date,
                MAX(DatePay) as max_date
            FROM paysplit
            WHERE DatePay BETWEEN @start_date AND @end_date
        )
        SELECT * FROM payment_counts;
        """
        
        # Split into separate statements
        statements = [stmt.strip() for stmt in test_query.split(';') if stmt.strip()]
        
        # Execute each statement separately
        for i, stmt in enumerate(statements):
            if stmt.strip():
                logging.info(f"Test CTE - Executing statement {i+1}/{len(statements)}: {stmt[:100].replace(chr(10), ' ')}...")
                cursor.execute(stmt)
                
                # Only fetch results from the last statement
                if i == len(statements) - 1:
                    rows = cursor.fetchall()
                    logging.info(f"Test CTE query returned {len(rows)} rows")
                    
                    if rows:
                        for row in rows:
                            logging.info(f"Test CTE results: {row}")
                        return True
                    else:
                        logging.warning("Test CTE query returned no rows")
                        return False
        
        cursor.close()
    except Exception as e:
        logging.error(f"Error executing test CTE query: {str(e)}")
        return False
    
    return False

def extract_report_data(start_date, end_date, db_name=None):
    """
    Extract and export unearned income data
    
    Args:
        start_date: Start date in YYYY-MM-DD format
        end_date: End date in YYYY-MM-DD format
        db_name: Database name to connect to (optional)
        
    Returns:
        Dictionary of query results
    """
    # Create output directory if it doesn't exist
    output_dir = DATA_DIR
    os.makedirs(output_dir, exist_ok=True)
    logging.debug(f"Output directory: {output_dir.resolve()}")
    
    # Convert string dates to DateRange object
    date_range = DateRange.from_strings(start_date, end_date)
    logging.info(f"Using date range: {start_date} to {end_date}")
    
    # Load and combine all CTEs
    try:
        ctes = get_ctes(date_range)
        logging.info(f"Loaded CTEs successfully")
    except Exception as e:
        logging.error(f"Error loading CTEs: {str(e)}")
        ctes = ""
    
    # Get export configurations
    exports = get_exports(ctes, date_range)
    
    if not exports:
        logging.error("No queries found for export")
        return {}
    
    # Use default database if none is specified
    if not db_name:
        db_name = "opendental_analytics_opendentalbackup_02_28_2025"
        logging.info(f"No database specified, using default: {db_name}")
    
    # Connect to the database
    logging.info(f"Connecting to database: {db_name}")
    connection = ConnectionFactory.create_connection('local_mariadb', database=db_name)
    
    # First test a simple CTE query to verify database connectivity and CTE functionality
    cte_test_result = test_cte_query(connection, db_name, date_range)
    if not cte_test_result:
        logging.warning("CTE test query failed, proceeding anyway but queries may fail")
    else:
        logging.info("CTE test query successful, proceeding with main queries")
    
    # Execute each query and store results
    query_results = {}
    
    for export in exports:
        query_name = export['name']
        query = export['query']
        
        logging.info(f"Processing query: '{query_name}' - {QUERY_DESCRIPTIONS.get(query_name, 'Unknown query')}")
        
        # Execute the query
        df, csv_path = execute_query(connection, db_name, query_name, query, output_dir)
        
        # Store results
        result = {
            'status': 'SUCCESS' if df is not None and not df.empty else 'FAILED',
            'rows': len(df) if df is not None else 0,
            'output_file': csv_path,
            'description': QUERY_DESCRIPTIONS.get(query_name, 'Unknown query')
        }
        
        query_results[query_name] = result
    
    return query_results


def setup_logging():
    """Configure complete logging for the script, replacing the initial setup.
    
    This configures both file and console logging with proper formatting.
    The file logger uses a timestamp in the filename to create unique log files.
    """
    # Create log directory if it doesn't exist
    os.makedirs(LOG_DIR, exist_ok=True)
    
    # Set up logging with timestamp in filename
    log_file = LOG_DIR / f"unearned_income_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
    
    # Clear existing handlers from init_logging()
    root_logger = logging.getLogger()
    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)
    
    # Configure new handlers
    file_handler = logging.FileHandler(log_file)
    console_handler = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    file_handler.setFormatter(formatter)
    console_handler.setFormatter(formatter)
    
    root_logger.setLevel(logging.INFO)
    root_logger.addHandler(file_handler)
    root_logger.addHandler(console_handler)
    
    logging.info(f"Logging to {log_file}")
    return log_file


def main():
    """Main function to run the export process"""
    # Set up logging
    log_file = setup_logging()
    
    # Get list of valid databases
    valid_databases = get_valid_databases('LOCAL_VALID_DATABASES')
    default_database = os.getenv('MARIADB_DATABASE', 'opendental_analytics_opendentalbackup_02_28_2025')
    
    # Parse command-line arguments
    parser = argparse.ArgumentParser(description='Export Unearned Income Data')
    parser.add_argument('--start-date', required=True,
                        help='Start date (YYYY-MM-DD) - Required parameter that will replace @start_date in SQL')
    parser.add_argument('--end-date', required=True,
                        help='End date (YYYY-MM-DD) - Required parameter that will replace @end_date in SQL')
    
    # Show valid databases in help text
    db_help = f"Database name (optional, default: {default_database}). Valid options: {', '.join(valid_databases)}" if valid_databases else "Database name"
    parser.add_argument('--database', help=db_help, default=None)
    
    try:
        args = parser.parse_args()
    except SystemExit:
        print("\nError: Both --start-date and --end-date are required arguments.")
        print("Example usage: python export_unearned_income_data.py --start-date 2025-01-01 --end-date 2025-02-28 [--database DB_NAME]")
        sys.exit(1)
    
    # Use default database if none is specified
    if not args.database:
        if default_database:
            logging.info(f"No database specified, using default from environment: {default_database}")
            # Note: We don't set args.database here, letting extract_report_data use its default
        else:
            logging.warning("No database specified and no default found in environment, will use hardcoded default")
    elif valid_databases and args.database not in valid_databases:
        logging.warning(f"Warning: Specified database '{args.database}' is not in the list of valid databases: {', '.join(valid_databases)}")
        print(f"Warning: Specified database '{args.database}' is not in the list of valid databases")
        print(f"Valid options: {', '.join(valid_databases)}")
        print("Proceeding with the specified database anyway...")
    
    logging.info("="*80)
    logging.info("STARTING EXPORT PROCESS: UNEARNED INCOME DATA")
    logging.info(f"Query directory: {QUERY_PATH.resolve()}")
    logging.info(f"CTE directory: {CTE_PATH.resolve()}")
    logging.info(f"Output directory: {DATA_DIR.resolve()}")
    logging.info(f"Date range: {args.start_date} to {args.end_date}")
    logging.info(f"Database: {args.database or '(using default)'}")
    logging.info(f"Available queries: {', '.join(QUERY_DESCRIPTIONS.keys())}")
    logging.info("="*80)
    
    # Extract and export data
    query_results = extract_report_data(
        start_date=args.start_date,
        end_date=args.end_date,
        db_name=args.database
    )
    
    # Print summary of results
    if query_results:
        logging.info("="*80)
        logging.info("QUERY EXECUTION SUMMARY:")
        print("\nEXPORT SUMMARY:")
        print("="*80)
        
        for query_name, result in query_results.items():
            status = "✅" if result['status'] == 'SUCCESS' else "❌"
            description = result.get('description', 'No description')
            output_file = result.get('output_file', 'No output file')
            rows = result.get('rows', 0)
            
            logging.info(f"{status} {query_name}: {rows} rows - {description}")
            print(f"{status} {query_name}: {rows} rows - {description}")
            if output_file and output_file != 'No output file':
                print(f"   Output: {output_file}")
            
        logging.info("="*80)
        print("="*80)
    
    logging.info("EXPORT PROCESS COMPLETED")
    print("\nExport process completed.")
    print(f"Log file: {log_file}")


if __name__ == "__main__":
    main() 