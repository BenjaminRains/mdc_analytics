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

from pathlib import Path
import argparse
import os
import re
import sys
# import time  # Unused import
import logging
# import json  # Unused import
# import csv   # Unused import - pandas is used for CSV operations
# import mysql.connector  # Unused import - using ConnectionFactory instead
import pandas as pd
from datetime import datetime
from dateutil.relativedelta import relativedelta
from dataclasses import dataclass
from typing import Dict, List, Tuple, Optional, Any, Set, Union
from dotenv import load_dotenv

# Add the src directory to the path to import project modules
src_path = Path(__file__).resolve().parents[3]
sys.path.append(str(src_path))

# Load environment variables from src/.env
env_path = src_path / "src" / ".env"
load_dotenv(dotenv_path=env_path)

# Import other required modules
from src.connections.factory import ConnectionFactory, get_valid_databases

# Define paths
BASE_PATH = Path(__file__).parent
SCRIPT_PATH = Path(__file__).resolve()
QUERY_PATH = BASE_PATH / "queries"
CTE_PATH = QUERY_PATH / "ctes"
DATA_DIR = BASE_PATH / "data" / "unearned_income"
LOG_DIR = BASE_PATH / "logs"

# Ensure directories exist
DATA_DIR.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(exist_ok=True)

def init_logging():
    """Initialize logging to file and console."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_dir = LOG_DIR
    log_dir.mkdir(exist_ok=True)
    
    # Use a consistent file name pattern with timestamp
    log_file = log_dir / f"log_unearned_income_export_{timestamp}.log"
    
    # Configure logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_file),
            logging.StreamHandler()
        ]
    )
    
    logging.info(f"Logging to {log_file}")
    return log_file

# Initialize basic logging
init_logging()

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

# Dictionary of query file dependencies
cte_dependencies = {
    # Base CTEs (no dependencies)
    'unearned_income_unearned_type_def.sql': [],  # No dependencies
    'unearned_income_pay_type_def.sql': [],  # No dependencies
    'unearned_income_provider_defs.sql': [],  # No dependencies
    'unearned_income_patient_balances.sql': [],  # No dependencies
    
    # Level 1 CTEs (depend only on base CTEs)
    'unearned_income_all_payment_types.sql': ['unearned_income_pay_type_def.sql'],
    'unearned_income_regular_payments.sql': [],
    'unearned_income_unearned_payments.sql': ['unearned_income_unearned_type_def.sql'],
    
    # Level 2 CTEs (depend on Level 1 or base CTEs)
    'unearned_income_patient_all_payments.sql': [
        'unearned_income_all_payment_types.sql'
    ],
    'unearned_income_patient_regular_payments.sql': [
        'unearned_income_regular_payments.sql'
    ],
    'unearned_income_patient_unearned_income.sql': [
        'unearned_income_unearned_payments.sql'
    ],
    'unearned_income_payment_unearned_type_summary.sql': ['unearned_income_unearned_type_def.sql'],
    'unearned_income_split_summary_by_type.sql': [],
    'unearned_income_transaction_counts.sql': [],
    'unearned_income_patient_payment_summary.sql': []
}

@dataclass
class DateRange:
    """Date range for query parameters."""
    start_date: str
    end_date: str
    
    def __str__(self):
        return f"{self.start_date} to {self.end_date}"


def apply_date_parameters(sql: str, date_range: DateRange) -> str:
    """
    Replace @start_date and @end_date in SQL with actual values.
    
    Args:
        sql: SQL query with @start_date and @end_date parameters
        date_range: DateRange object with start and end dates
        
    Returns:
        SQL query with parameters replaced
    """
    replacements = {
        "@start_date": f"'{date_range.start_date}'",
        "@end_date": f"'{date_range.end_date}'"
    }
    
    # Replace each parameter
    result = sql
    for param, value in replacements.items():
        result = result.replace(param, value)
    
    return result


def read_sql_file(file_path: str) -> str:
    """
    Read SQL file content.
    
    Args:
        file_path: Path to SQL file
        
    Returns:
        SQL query as string
    """
    with open(file_path, 'r', encoding='utf-8') as f:
        return f.read()


def sanitize_table_name(name: str) -> str:
    """
    Sanitize a name for use as a table name.
    
    Args:
        name: Name to sanitize
        
    Returns:
        Sanitized name
    """
    return re.sub(r'[^a-zA-Z0-9_]', '_', name)


def export_to_csv(df, output_dir, query_name, prefix=None, include_date=True):
    """
    Export DataFrame to CSV.
    
    Args:
        df: Pandas DataFrame to export
        output_dir: Directory to export to
        query_name: Name of the query (used for filename)
        prefix: Optional prefix for filename
        include_date: Whether to include date in filename
        
    Returns:
        Path to CSV file
    """
    if df is None or df.empty:
        logging.warning(f"No data to export for {query_name}")
        return None
    
    # Create output directory if it doesn't exist
    if not isinstance(output_dir, Path):
        output_dir = Path(output_dir)
    output_dir.mkdir(exist_ok=True, parents=True)
    
    # Create filename with optional prefix
    if prefix:
        filename = f"{prefix}_{query_name}"
    else:
        filename = f"{query_name}"
    
    # Add date if requested - now at the end before the extension
    if include_date:
        date_str = datetime.now().strftime("%Y%m%d")
        filename = f"{filename}_{date_str}.csv"
    else:
        filename = f"{filename}.csv"
    
    # Full path to CSV file
    csv_path = output_dir / filename
    
    # Export to CSV
    df.to_csv(csv_path, index=False)
    logging.info(f"Exported {len(df)} rows to {csv_path}")
    
    return csv_path

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
        "unearned_income_unearned_type_def.sql",  # UnearnedType definitions first
        "unearned_income_pay_type_def.sql",     # PayType definitions next
        "unearned_income_provider_defs.sql",    # Provider definitions
        "unearned_income_patient_balances.sql"  # Patient balances
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
                
            # Remove comments to avoid parser issues
            cte_content = re.sub(r'/\*.*?\*/', '', cte_content, flags=re.DOTALL)  # Remove multi-line comments
            cte_content = re.sub(r'--.*?(\n|$)', '\n', cte_content)  # Remove single-line comments
                
            # Strip all extra whitespace completely to create the most compact CTE possible
            cte_content = re.sub(r'\s+', ' ', cte_content)
            
            # Replace common multi-space patterns with single spaces
            cte_content = re.sub(r'\(\s+', '(', cte_content)
            cte_content = re.sub(r'\s+\)', ')', cte_content)
            cte_content = re.sub(r'\s+,', ',', cte_content)
            cte_content = re.sub(r',\s+', ', ', cte_content)
            
            # Format as a single-line CTE with minimal whitespace for maximum compatibility
            return cte_content.strip()
        
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
    
    # Join all CTEs with appropriate separators - ensure compact formatting for MariaDB compatibility
    combined_ctes = ""
    valid_ctes = []
    
    for i, cte in enumerate(all_ctes):
        # Extract the CTE name from the SQL
        cte_name_match = re.search(r'(\w+)\s+AS\s*\(', cte)
        if not cte_name_match:
            logging.warning(f"Couldn't extract CTE name from content, skipping: {cte[:50]}...")
            continue
            
        cte_name = cte_name_match.group(1)
        valid_ctes.append(cte)
    
    # Only combine if we have valid CTEs
    if valid_ctes:
        for i, cte in enumerate(valid_ctes):
            # If not the first CTE, add a comma
            if i > 0:
                combined_ctes += ", "
            
            # Add this CTE definition
            combined_ctes += cte
        
        logging.info(f"Combined {len(valid_ctes)} CTEs into query structure")
    else:
        logging.warning(f"No valid CTEs found to combine")
    
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
    
    # Remove comments from the query to avoid parser issues
    query_content = re.sub(r'/\*.*?\*/', '', query_content, flags=re.DOTALL)  # Remove multi-line comments
    query_content = re.sub(r'--.*?(\n|$)', '\n', query_content)  # Remove single-line comments
    
    # Special case handling for problematic queries
    if query_name == 'unearned_income_main_transactions':
        # Fix for the missing LEFT JOIN UnearnedIncomeUnearnedTypeDef
        if 'LEFT JOIN UnearnedIncomeUnearnedTypeDef' in query_content:
            logging.info(f"Fixing missing reference to UnearnedIncomeUnearnedTypeDef in {query_name}")
            # Replace the JOIN with a direct query to get the unearned type name
            query_content = query_content.replace(
                'LEFT JOIN UnearnedIncomeUnearnedTypeDef ud ON ud.DefNum = ps.UnearnedType',
                "-- Replaced with inline query\n"
            )
            # Replace references to ud.UnearnedTypeName with a direct lookup
            query_content = query_content.replace(
                'ud.UnearnedTypeName',
                "(SELECT def.ItemName FROM definition def WHERE def.DefNum = ps.UnearnedType)"
            )
            
        # Fix for the missing LEFT JOIN UnearnedIncomePayTypeDef
        if 'LEFT JOIN UnearnedIncomePayTypeDef pd' in query_content:
            logging.info(f"Fixing missing reference to UnearnedIncomePayTypeDef in {query_name}")
            # Replace the JOIN with a direct query to get the pay type name
            query_content = query_content.replace(
                'LEFT JOIN UnearnedIncomePayTypeDef pd ON pd.DefNum = pm.PayType',
                "-- Replaced with inline query\n"
            )
            # Replace references to pd.PayTypeName with a direct lookup
            query_content = query_content.replace(
                'pd.PayTypeName',
                "(SELECT def.ItemName FROM definition def WHERE def.DefNum = pm.PayType AND def.Category = 8)"
            )
    
    # Check query structure to determine how to handle it
    cleaned_content = query_content.strip()
    
    # Check for different query patterns
    is_direct_select = cleaned_content.upper().startswith('SELECT')
    has_own_with = cleaned_content.upper().startswith('WITH')
    has_union = 'UNION' in cleaned_content.upper()
    
    # Check if query_content starts with what appears to be a CTE name (CapitalizedName AS (...))
    starts_with_cte_name = re.match(r'^\s*(\w+)\s+AS\s*\(', cleaned_content)
    
    # Check for multiple CTE definitions (multiple "Name AS (" patterns)
    cte_defs = re.findall(r'\b(\w+)\s+AS\s*\(', cleaned_content)
    has_multiple_ctes = len(cte_defs) > 1
    
    # If this query has its own CTEs defined inline, log them
    if has_multiple_ctes:
        logging.info(f"Query has {len(cte_defs)} inline CTE definitions: {', '.join(cte_defs)}")
    
    # Prepare SQL with date parameters and CTEs - ensure each statement ends with a semicolon
    date_params = f"SET @start_date = '{date_range.start_date}'; SET @end_date = '{date_range.end_date}';"
    
    # Add the WITH clause only if CTEs are provided
    if ctes and ctes.strip():
        logging.info(f"Processing query: {query_name} (with shared CTEs)")
        
        # Ensure query_content ends with a semicolon
        if not cleaned_content.endswith(';'):
            cleaned_content = cleaned_content + ';'
        
        if is_direct_select:
            # Direct SELECT query with no CTEs - no need to include shared CTEs
            # Just execute it directly with date parameters
            final_query = f"{date_params} {cleaned_content}"
            logging.info(f"Query type: Direct SELECT statement (executing without CTEs)")
        elif has_own_with:
            # Query has its own WITH clause, use as-is without adding shared CTEs
            final_query = f"{date_params} {cleaned_content}"
            logging.info(f"Query type: Contains own WITH clause (executing without shared CTEs)")
        elif starts_with_cte_name or has_multiple_ctes:
            # This query has CTE definitions but is missing the WITH keyword
            # We need to add WITH and properly format multiple CTEs with commas
            logging.info(f"Query type: CTE definitions but missing WITH keyword (adding proper WITH clause)")
            
            # Add commas between CTE definitions - this is the critical fix
            if has_multiple_ctes:
                # Find all instances of ") Name AS (" and replace with "), Name AS ("
                modified_content = re.sub(r'\)\s+(\w+)\s+AS\s*\(', r'), \1 AS (', cleaned_content)
                final_query = f"{date_params} WITH {modified_content}"
            else:
                final_query = f"{date_params} WITH {cleaned_content}"
        elif has_union:
            # This is a complex query with UNIONs - see if it needs a WITH clause first
            if starts_with_cte_name or has_multiple_ctes:
                # This is a query with both CTEs and UNIONs - prioritize the CTE handling
                logging.info(f"Query type: Contains both CTEs and UNIONs (adding proper WITH clause)")
                # Add commas between CTE definitions
                if has_multiple_ctes:
                    # Find all instances of ") Name AS (" and replace with "), Name AS ("
                    modified_content = re.sub(r'\)\s+(\w+)\s+AS\s*\(', r'), \1 AS (', cleaned_content)
                    final_query = f"{date_params} WITH {modified_content}"
                else:
                    final_query = f"{date_params} WITH {cleaned_content}"
            else:
                # Just a UNION query without CTEs, execute directly
                final_query = f"{date_params} {cleaned_content}"
                logging.info(f"Query type: Contains UNIONs (executing directly without CTEs)")
        else:
            # Normal query that needs the shared CTEs
            final_query = f"{date_params} WITH {ctes.strip()} {cleaned_content}"
            logging.info(f"Query type: Standard query (using shared CTEs)")
    else:
        logging.info(f"Processing query: {query_name} (no shared CTEs)")
        
        # Ensure query_content ends with a semicolon
        if not cleaned_content.endswith(';'):
            cleaned_content = cleaned_content + ';'
        
        # Check if this query appears to reference CTEs directly
        if starts_with_cte_name or has_multiple_ctes:
            # The query expects CTEs but doesn't have the WITH keyword
            logging.info(f"Query type: Contains CTE definitions but missing WITH keyword (adding WITH)")
            
            # Add commas between CTE definitions - this is the critical fix
            if has_multiple_ctes:
                # Find all instances of ") Name AS (" and replace with "), Name AS ("
                modified_content = re.sub(r'\)\s+(\w+)\s+AS\s*\(', r'), \1 AS (', cleaned_content)
                final_query = f"{date_params} WITH {modified_content}"
            else:
                final_query = f"{date_params} WITH {cleaned_content}"
        else:
            # Just execute the query directly
            logging.info(f"Query type: Standard query (executing directly)")
            final_query = f"{date_params} {cleaned_content}"
    
    logging.info(f"Prepared query for {query_name}")
    
    # Create a clean, final version by removing excessive whitespace
    final_query = re.sub(r'\n{3,}', '\n\n', final_query)
    
    # Convert any multi-line comments to single-line to avoid parser confusion
    final_query = re.sub(r'/\*.*?\*/', '', final_query, flags=re.DOTALL)  # Remove multi-line comments
    final_query = re.sub(r'--.*?(\n|$)', '', final_query)  # Remove single-line comments
    
    # Since the query is now processed, also check for CTEs that are defined by include directives
    included_ctes = []
    
    # Extract include directives from the query
    include_pattern = r'<<include:([\w_\.]+)>>'
    include_matches = re.findall(include_pattern, query_content)
    
    if include_matches:
        logging.info(f"Found {len(include_matches)} include directives in {query_name}: {', '.join(include_matches)}")
        for include_file in include_matches:
            if include_file in cte_dependencies:
                included_ctes.append(include_file)
    
    return {
        'name': query_name,
        'file': f"{query_name}.csv",
        'query': final_query,
        'description': QUERY_DESCRIPTIONS.get(query_name, "Unknown query"),
        'included_ctes': included_ctes
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
        connection: Database connection
        db_name: Database name
        query_name: Name of the query
        query: SQL query to execute
        output_dir: Optional output directory for CSV export
    
    Returns:
        Path to CSV file
    """
    try:
        # Remove comments from the query to avoid issues
        query_without_headers = re.sub(r'--.*?$', '', query, flags=re.MULTILINE)
        
        # Log the first part of the query for debugging
        logging.info(f"Query preview for '{query_name}': {query_without_headers[:500].replace(chr(10), ' ')}...")
        
        # Get connection and cursor - use get_connection() to get the actual database connection
        conn = connection.get_connection()
        cursor = conn.cursor(dictionary=True)
        
        # Execute the query
        logging.info(f"Executing query '{query_name}' with separate statements")
        
        # Split the query into separate statements by semicolon
        statements = [stmt.strip() for stmt in query_without_headers.split(';') if stmt.strip()]
        
        rows = []
        for i, stmt in enumerate(statements):
            if stmt.strip():
                # Log shorter preview of each statement
                logging.info(f"Executing statement {i+1}/{len(statements)}: {stmt[:100].replace(chr(10), ' ')}...")
                cursor.execute(stmt)
                
                # Only fetch results from the last statement (the actual query, not the SET commands)
                if i == len(statements) - 1:
                    rows = cursor.fetchall()
                    
        logging.info(f"Query '{query_name}' returned {len(rows)} rows")
        
        # Export to CSV if output directory is specified
        if output_dir and rows:
            # Create DataFrame
            df = pd.DataFrame(rows)
            
            # Export to CSV
            output_file = export_to_csv(df, output_dir, query_name)
            return output_file
        
        return rows
        
    except Exception as e:
        logging.error(f"SQL Error executing query '{query_name}': {str(e)}")
        logging.error(f"SQL Statement causing the error (first 1000 chars):\n{query_without_headers[:1000]}")
        logging.error(f"Error executing query '{query_name}': {str(e)}")
        raise

def test_cte_query(connection, db_name, date_range):
    """
    Test a simple CTE query to verify database connectivity and CTE functionality
    
    Args:
        connection: Database connection object from ConnectionFactory
        db_name: Database name
        date_range: DateRange object with start and end dates
        
    Returns:
        Whether the test was successful
    """
    try:
        logging.info("Testing simple CTE query...")
        
        # Use get_connection() to get the actual database connection before getting a cursor
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
    Extract report data from the database.
    
    Args:
        start_date: Start date for the report
        end_date: End date for the report
        db_name: Database name to use (optional)
        
    Returns:
        Dictionary with query results
    """
    # Set up date range
    date_range = DateRange(start_date=start_date, end_date=end_date)
    logging.info(f"Using date range: {date_range}")
    
    # Get CTEs
    ctes = get_ctes(date_range)
    
    # Get exports
    exports = get_exports(ctes, date_range)
    
    # Connect to the database
    logging.info(f"Connecting to database: {db_name}")
    connection = ConnectionFactory.create_connection('local_mariadb', database=db_name)
    
    # First test a simple CTE query to verify database connectivity and CTE functionality
    test_cte_query(connection, db_name, date_range)
    
    # Execute each query
    query_results = {}
    for export in exports:
        query_name = export['name']
        query = export['query']
        description = export.get('description', '')
        
        try:
            logging.info(f"Processing query: '{query_name}' - {description}")
            
            # Execute the query
            output_file = execute_query(connection, db_name, query_name, query, output_dir=DATA_DIR)
            
            # Store results
            query_results[query_name] = {
                'status': 'SUCCESS',
                'description': description,
                'output_file': output_file,
                'rows': 0  # We don't have the row count here anymore
            }
        except Exception as e:
            logging.error(f"Error executing query '{query_name}': {str(e)}")
            query_results[query_name] = {
                'status': 'ERROR',
                'description': description,
                'error': str(e)
            }
    
    # Close the connection
    connection.close()
    
    return query_results

def main():
    """Main function to run the export process"""
    # Configure logging
    log_file = init_logging()
    
    # Print a clear header to separate runs
    logging.info("="*80)
    logging.info("STARTING EXPORT PROCESS: UNEARNED INCOME DATA")
    
    # Print paths for context and debugging
    logging.info(f"Query directory: {QUERY_PATH}")
    logging.info(f"CTE directory: {CTE_PATH}")
    logging.info(f"Output directory: {DATA_DIR}")
    
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Export unearned income data')
    parser.add_argument('--start-date', type=str, help='Start date (YYYY-MM-DD)')
    parser.add_argument('--end-date', type=str, help='End date (YYYY-MM-DD)')
    parser.add_argument('--db-name', type=str, help='Database name to use')
    parser.add_argument('--test', action='store_true', help='Test mode - execute a simple query only')
    args = parser.parse_args()
    
    # Determine date range
    if args.start_date and args.end_date:
        start_date = args.start_date
        end_date = args.end_date
    else:
        # Default to YTD if not specified
        # For testing, it's better to use a wider range to ensure data exists
        start_date = '2024-01-01'  # First day of current year
        end_date = '2025-02-28'    # Default to last month end
    
    db_name = args.db_name
    
    if not db_name:
        db_name = os.environ.get('ODDB_NAME')
        logging.info(f"No database specified, using default from environment: {db_name}")
    
    logging.info(f"Date range: {start_date} to {end_date}")
    logging.info(f"Database: {db_name if db_name else '(using default)'}")
    
    # List the available query files
    query_files = [f.stem for f in QUERY_PATH.glob("unearned_income_*.sql")]
    logging.info(f"Available queries: {', '.join(sorted(query_files))}")
    logging.info("="*80)
    
    # Extract and export the data
    if args.test:
        # Run just a test query
        connection = None
        try:
            connection = ConnectionFactory.create_connection('local_mariadb', database=db_name)
            test_cte_query(connection, db_name, DateRange(start_date, end_date))
        except Exception as e:
            logging.error(f"Error executing test query: {str(e)}")
        finally:
            if connection:
                connection.close()
    else:
        # Run the full export
        try:
            extract_report_data(start_date, end_date, db_name)
        except Exception as e:
            logging.error(f"Error in export process: {str(e)}")
            import traceback
            logging.error(traceback.format_exc())
    
    logging.info("="*80)
    logging.info("EXPORT PROCESS COMPLETED")
    print(f"Log file: {log_file}")

if __name__ == "__main__":
    main() 