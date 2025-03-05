#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Unearned Income Analysis Script
-------------------------------
This script performs analysis on unearned income and unassigned provider transactions.
It handles path resolution properly using the config module or falls back to direct paths.
"""

# Import necessary libraries
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime, timedelta
import os
import sys
from pathlib import Path

# Set up path to find the config module
def setup_project_path():
    """Set up the Python path to include the project root for imports"""
    current_dir = Path(__file__).parent.absolute()
    project_root = current_dir
    # Walk up directories to find project root (where src directory exists)
    while not (project_root / "src").exists() and project_root != project_root.parent:
        project_root = project_root.parent
    
    if (project_root / "src").exists():
        if str(project_root) not in sys.path:
            sys.path.insert(0, str(project_root))
        return project_root
    else:
        print("Warning: Could not locate project root (directory containing 'src')")
        return None


# Set up project path
project_root = setup_project_path()

# Try to import config module or use direct paths
try:
    from src.config import DataPaths
    use_config = True
    print("Using configuration module for paths")
except ImportError:
    use_config = False
    print("Configuration module not found. Using direct paths.")

# Set visualization style
plt.style.use('ggplot')
sns.set_palette("Set2")
sns.set_context("notebook", font_scale=1.2)

# Configure pandas display settings
pd.set_option('display.max_columns', None)
pd.set_option('display.max_rows', 100)
pd.set_option('display.width', 1000)
pd.set_option('display.float_format', '{:.2f}'.format)


# ===============================================================================
# DATA LOADING AND INTEGRATION
# ===============================================================================

def setup_file_paths():
    """Set up file paths either using config module or direct paths"""
    if use_config:
        data_paths = DataPaths()
        
        # File paths using config
        income_transfer_dir = data_paths.payment_split_subdir("data") / "income_transfer_indicators"
        paths = {
            "unassigned_file": income_transfer_dir / "income_transfer_unassigned_provider_transactions_20250304.csv",
            "income_indicators_file": income_transfer_dir / "income_transfer_indicators.csv",
            "unearned_aging_file": data_paths.payment_split_subdir("data") / "unearned_income_aging_analysis.csv",
            "unearned_main_file": data_paths.payment_split_subdir("data") / "unearned_income_main_transactions.csv",
            "patient_balance_file": data_paths.payment_split_subdir("data") / "unearned_income_patient_balance_report.csv",
            "payment_type_file": data_paths.payment_split_subdir("data") / "unearned_income_payment_type_summary.csv",
        }
    else:
        # Direct paths relative to script location
        script_dir = Path(__file__).parent.absolute()
        data_dir = script_dir / "data"
        income_transfer_dir = data_dir / "income_transfer_indicators"
        
        paths = {
            "unassigned_file": income_transfer_dir / "income_transfer_unassigned_provider_transactions_20250304.csv",
            "income_indicators_file": income_transfer_dir / "income_transfer_indicators.csv",
            "unearned_aging_file": data_dir / "unearned_income_aging_analysis.csv",
            "unearned_main_file": data_dir / "unearned_income_main_transactions.csv",
            "patient_balance_file": data_dir / "unearned_income_patient_balance_report.csv",
            "payment_type_file": data_dir / "unearned_income_payment_type_summary.csv",
        }
    
    # Verify paths exist and print status
    for name, path in paths.items():
        print(f"{name}: {path} {'(exists)' if path.exists() else '(not found)'}")
    
    return paths


def load_data(file_paths):
    """Load all datasets with proper error handling"""
    data = {}
    
    # Load unassigned provider transactions
    try:
        print(f"\nAttempting to load unassigned provider transactions from {file_paths['unassigned_file']}")
        data['unassigned'] = pd.read_csv(file_paths['unassigned_file'], sep='|')
        print(f"Successfully loaded unassigned provider transactions: {len(data['unassigned'])} rows")
        
        # Clean column names
        data['unassigned'].columns = data['unassigned'].columns.str.strip()
        
        # Convert date column to datetime
        if 'TransactionDate' in data['unassigned'].columns:
            data['unassigned']['TransactionDate'] = pd.to_datetime(data['unassigned']['TransactionDate'])
        
        # Ensure numeric types
        for col in ['SplitAmt', 'AccountBalance', 'DaysOld']:
            if col in data['unassigned'].columns:
                data['unassigned'][col] = pd.to_numeric(data['unassigned'][col], errors='coerce')
    except Exception as e:
        print(f"Error loading unassigned provider transactions: {e}")
        data['unassigned'] = pd.DataFrame()
    
    # Load other datasets
    other_datasets = {
        'aging': file_paths['unearned_aging_file'],
        'main': file_paths['unearned_main_file'],
        'balance': file_paths['patient_balance_file'],
        'payment_type': file_paths['payment_type_file']
    }
    
    for name, file_path in other_datasets.items():
        try:
            print(f"\nAttempting to load {name} data from {file_path}")
            data[name] = pd.read_csv(file_path)
            print(f"Successfully loaded {name} data: {len(data[name])} rows")
        except Exception as e:
            print(f"Error loading {name} data: {e}")
            data[name] = pd.DataFrame()
    
    # Try to load income indicators if it exists
    try:
        print(f"\nAttempting to load income indicators from {file_paths['income_indicators_file']}")
        data['indicators'] = pd.read_csv(file_paths['income_indicators_file'])
        data['has_indicators'] = True
        print(f"Successfully loaded income indicators: {len(data['indicators'])} rows")
    except Exception as e:
        print(f"Note: Could not load income_transfer_indicators file: {e}")
        data['indicators'] = pd.DataFrame()
        data['has_indicators'] = False
    
    return data


def enrich_unassigned_transactions(data):
    """Integrate data from multiple sources to get a more complete view"""
    
    # Check if we have unassigned transactions
    if data['unassigned'].empty:
        print("No unassigned transactions to enrich")
        return pd.DataFrame()
    
    # Start with our base unassigned transactions
    df_enriched = data['unassigned'].copy()
    
    # Add patient balance information
    if not data['balance'].empty and 'PatNum' in data['balance'].columns and 'PatNum' in df_enriched.columns:
        balance_cols = [col for col in ['PatNum', 'EstBalance', 'BalTotal', 'InsEst', 
                                        'Bal_0_30', 'Bal_31_60', 'Bal_61_90', 'BalOver90'] 
                        if col in data['balance'].columns]
        
        if len(balance_cols) > 1:  # Need at least PatNum and one other column
            df_balance_slim = data['balance'][balance_cols]
            df_enriched = pd.merge(df_enriched, df_balance_slim, on='PatNum', how='left', suffixes=('', '_current'))
            print(f"Added patient balance information: {len(balance_cols)-1} balance columns")
    
    # Identify unearned income transactions from the main transactions data
    if not data['main'].empty and 'TransactionNum' in df_enriched.columns:
        # Check if we have SplitNum or TransactionNum in main data
        join_col = None
        if 'SplitNum' in data['main'].columns:
            join_col = 'SplitNum'
            data['main'] = data['main'].rename(columns={'SplitNum': 'TransactionNum'})
        elif 'TransactionNum' in data['main'].columns:
            join_col = 'TransactionNum'
        
        if join_col:
            # Select useful columns that exist in the dataframe
            main_cols = [col for col in ['TransactionNum', 'UnearnedType', 'UnearnedTypeName', 
                                         'ClinicNum', 'ClinicName'] 
                         if col in data['main'].columns]
            
            if len(main_cols) > 1:  # Need at least TransactionNum and one other column
                df_main_slim = data['main'][main_cols]
                df_enriched = pd.merge(df_enriched, df_main_slim, on='TransactionNum', how='left')
                print(f"Added unearned income transaction information: {len(main_cols)-1} columns")
    
    # Add aging information if available
    if not data['aging'].empty and 'PatNum' in data['aging'].columns and 'PatNum' in df_enriched.columns:
        aging_cols = [col for col in ['PatNum', 'OldestPrepaymentDays', 'TotalUnassignedPrepayments'] 
                      if col in data['aging'].columns]
        
        if len(aging_cols) > 1:  # Need at least PatNum and one other column
            # Keep only unique patient aging data
            df_aging_slim = data['aging'][aging_cols].drop_duplicates(subset=['PatNum'])
            df_enriched = pd.merge(df_enriched, df_aging_slim, on='PatNum', how='left')
            print(f"Added aging information: {len(aging_cols)-1} aging columns")
    
    # Add payment type statistics if available
    if data['has_indicators'] and not data['indicators'].empty and 'PatNum' in data['indicators'].columns and 'PatNum' in df_enriched.columns:
        # Determine which columns to include based on what's available
        indicator_cols = [col for col in ['PatNum', 'TransactionFrequency', 'AverageTransactionAmount', 'LastVisitDate'] 
                          if col in data['indicators'].columns]
        
        if len(indicator_cols) > 1:  # Only merge if we have useful data
            df_indicators_slim = data['indicators'][indicator_cols]
            df_enriched = pd.merge(df_enriched, df_indicators_slim, on='PatNum', how='left')
            print(f"Added payment type statistics: {len(indicator_cols)-1} indicator columns")
    
    # Create helper columns for analysis
    if 'TransactionDate' in df_enriched.columns:
        df_enriched['TransactionMonth'] = df_enriched['TransactionDate'].dt.strftime('%Y-%m')
        df_enriched['TransactionWeek'] = df_enriched['TransactionDate'].dt.strftime('%Y-%U')
        print("Added date-based helper columns")
    
    if 'SplitAmt' in df_enriched.columns:
        df_enriched['IsPositiveAmount'] = df_enriched['SplitAmt'] > 0
        df_enriched['AmountCategory'] = pd.cut(
            df_enriched['SplitAmt'].abs(), 
            bins=[0, 200, 1000, 5000, float('inf')],
            labels=['Tiny (<$200)', 'Small ($200-$999)', 'Medium ($1000-$5000)', 'Large (>$5000)']
        )
        print("Added amount-based helper columns")
    
    return df_enriched


# ===============================================================================
# ANALYSIS FUNCTIONS
# ===============================================================================

def analyze_unearned_classifications(df_enriched):
    """Compare unearned income classifications with unassigned provider transactions"""
    
    if df_enriched.empty:
        print("No data available for unearned classifications analysis")
        return
    
    # Check how many unassigned transactions are also classified as unearned income
    unearned_count = df_enriched['UnearnedType'].notna().sum() if 'UnearnedType' in df_enriched.columns else 0
    total_count = len(df_enriched)
    
    print(f"\n=== UNEARNED INCOME ANALYSIS ===")
    print(f"Total unassigned provider transactions: {total_count}")
    print(f"Transactions also classified as unearned income: {unearned_count} ({unearned_count/total_count:.1%})")
    
    # Analyze by unearned type
    if 'UnearnedTypeName' in df_enriched.columns:
        unearned_types = df_enriched['UnearnedTypeName'].value_counts(dropna=False)
        print("\n=== UNEARNED INCOME TYPES ===")
        print(unearned_types)
        
        # Cross-tabulate with our transaction categories if they exist
        if 'TransactionCategory' in df_enriched.columns:
            print("\n=== UNEARNED TYPE VS TRANSACTION CATEGORY ===")
            cross_tab = pd.crosstab(
                df_enriched['UnearnedTypeName'].fillna('Not Classified'), 
                df_enriched['TransactionCategory']
            )
            print(cross_tab)


def analyze_patient_balances(df_enriched):
    """Analyze patient balance patterns for unassigned transactions"""
    
    if df_enriched.empty:
        print("No data available for patient balance analysis")
        return
    
    balance_columns = ['EstBalance', 'BalTotal', 'AccountBalance', 
                        'Bal_0_30', 'Bal_31_60', 'Bal_61_90', 'BalOver90']
    
    available_columns = [col for col in balance_columns if col in df_enriched.columns]
    
    if not available_columns:
        print("No balance columns available for analysis")
        return
    
    print(f"\n=== PATIENT BALANCE ANALYSIS ===")
    
    # Print available balance metrics
    for col in available_columns:
        if col in df_enriched.columns:
            print(f"Average {col}: ${df_enriched[col].mean():.2f}")
    
    # Count transactions where balance changed significantly
    if 'EstBalance' in df_enriched.columns and 'AccountBalance' in df_enriched.columns:
        balance_change = (df_enriched['EstBalance'] - df_enriched['AccountBalance']).abs()
        significant_change = (balance_change > 100).sum()
        print(f"Transactions with significant balance changes since creation: {significant_change} ({significant_change/len(df_enriched):.1%})")
    
    # Analyze balance aging
    aging_cols = [col for col in ['Bal_0_30', 'Bal_31_60', 'Bal_61_90', 'BalOver90'] 
                  if col in df_enriched.columns]
    
    if aging_cols:
        print("\n=== PATIENT BALANCE AGING ===")
        aging_totals = df_enriched[aging_cols].sum()
        print(aging_totals)
        
        # Calculate percentage of balances by age
        balance_total = aging_totals.sum()
        if balance_total > 0:
            aging_pct = aging_totals / balance_total
            print("\n=== BALANCE AGING PERCENTAGES ===")
            for col, pct in aging_pct.items():
                print(f"{col}: {pct:.1%}")


def analyze_prepayment_aging(df_enriched):
    """Analyze the aging of prepayments and unearned income"""
    
    if df_enriched.empty or 'OldestPrepaymentDays' not in df_enriched.columns:
        print("No prepayment aging data available for analysis")
        return
    
    print(f"\n=== PREPAYMENT AGING ANALYSIS ===")
    print(f"Average age of oldest prepayment: {df_enriched['OldestPrepaymentDays'].mean():.1f} days")
    
    # Create age buckets for oldest prepayments
    df_enriched['PrepaymentAgeBucket'] = pd.cut(
        df_enriched['OldestPrepaymentDays'], 
        bins=[0, 30, 60, 90, 180, 365, float('inf')],
        labels=['0-30 days', '31-60 days', '61-90 days', '91-180 days', '181-365 days', 'Over 1 year']
    )
    
    # Count by age bucket
    age_counts = df_enriched['PrepaymentAgeBucket'].value_counts(dropna=False).sort_index()
    print("\n=== PREPAYMENT AGE DISTRIBUTION ===")
    print(age_counts)
    
    # Analyze prepayment amounts by age
    if 'SplitAmt' in df_enriched.columns:
        age_amounts = df_enriched.groupby('PrepaymentAgeBucket')['SplitAmt'].agg(['sum', 'mean', 'count'])
        print("\n=== PREPAYMENT AMOUNTS BY AGE ===")
        print(age_amounts)


def analyze_staff_and_clinic_patterns(df_enriched):
    """Analyze patterns by staff and clinic"""
    
    if df_enriched.empty:
        print("No data available for staff and clinic pattern analysis")
        return
    
    if 'EnteredBy' not in df_enriched.columns:
        print("No staff data (EnteredBy) available for analysis")
        return
    
    # Staff analysis
    staff_metrics = ['TransactionNum', 'SplitAmt']
    available_metrics = [col for col in staff_metrics if col in df_enriched.columns]
    
    if available_metrics:
        agg_dict = {}
        if 'TransactionNum' in available_metrics:
            agg_dict['Count'] = ('TransactionNum', 'count')
        
        if 'SplitAmt' in available_metrics:
            agg_dict['TotalAmount'] = ('SplitAmt', 'sum')
            agg_dict['AvgAmount'] = ('SplitAmt', 'mean')
        
        if 'TransactionCategory' in df_enriched.columns:
            for category in df_enriched['TransactionCategory'].unique():
                if pd.notna(category):
                    safe_category = category.replace('/', '_')
                    agg_dict[f'{safe_category}Count'] = ('TransactionCategory', 
                                                         lambda x: (x == category).sum())
        
        staff_transactions = df_enriched.groupby('EnteredBy').agg(**agg_dict).sort_values(
            'Count' if 'Count' in agg_dict.keys() else list(agg_dict.keys())[0], 
            ascending=False
        )
        
        print(f"\n=== STAFF TRANSACTION PATTERNS ===")
        print(staff_transactions)
    
    # Clinic analysis if available
    if 'ClinicName' in df_enriched.columns:
        clinic_agg_dict = {}
        if 'TransactionNum' in df_enriched.columns:
            clinic_agg_dict['Count'] = ('TransactionNum', 'count')
        
        if 'SplitAmt' in df_enriched.columns:
            clinic_agg_dict['TotalAmount'] = ('SplitAmt', 'sum')
            clinic_agg_dict['AvgAmount'] = ('SplitAmt', 'mean')
        
        if clinic_agg_dict:
            clinic_transactions = df_enriched.groupby('ClinicName').agg(**clinic_agg_dict).sort_values(
                'Count' if 'Count' in clinic_agg_dict.keys() else list(clinic_agg_dict.keys())[0], 
                ascending=False
            )
            
            print("\n=== CLINIC TRANSACTION PATTERNS ===")
            print(clinic_transactions)
        
        # Cross-tabulate staff by clinic
        print("\n=== STAFF BY CLINIC ===")
        staff_clinic_cross = pd.crosstab(
            df_enriched['EnteredBy'], 
            df_enriched['ClinicName'].fillna('Unknown')
        )
        print(staff_clinic_cross)


def create_enhanced_work_queues(df_enriched):
    """Create work queues with enhanced contextual information"""
    
    if df_enriched.empty:
        print("No data available to create work queues")
        return pd.DataFrame()
    
    enhanced_data = df_enriched.copy()
    
    # Check if we have the necessary columns
    has_priority = 'Priority' in enhanced_data.columns
    has_days_old = 'DaysOld' in enhanced_data.columns
    has_split_amt = 'SplitAmt' in enhanced_data.columns
    has_suggested_provider = 'SuggestedProvider' in enhanced_data.columns
    has_est_balance = 'EstBalance' in enhanced_data.columns
    has_oldest_prepayment = 'OldestPrepaymentDays' in enhanced_data.columns
    has_transaction_category = 'TransactionCategory' in enhanced_data.columns
    
    # Add intelligent priority scoring if we have basic information
    if has_days_old or has_split_amt:
        print("\n=== CREATING PRIORITY SCORES ===")
        enhanced_data['PriorityScore'] = 0
        
        # Factors:
        # 1. Base priority from original analysis
        if has_priority:
            priority_map = {'Critical': 30, 'High': 20, 'Medium': 10, 'Low': 5}
            enhanced_data['PriorityScore'] += enhanced_data['Priority'].map(priority_map).fillna(0)
            print("Added priority-based scoring")
        
        # 2. Age factors
        if has_days_old:
            enhanced_data['PriorityScore'] += enhanced_data['DaysOld'] / 10  # Add 1 point per 10 days
            print("Added age-based scoring")
        
        # 3. Amount factors (absolute value)
        if has_split_amt:
            enhanced_data['PriorityScore'] += enhanced_data['SplitAmt'].abs() / 1000  # Add 1 point per $1000
            print("Added amount-based scoring")
        
        # 4. Balance factors
        if has_est_balance:
            # Add points for large balances (could indicate unprocessed charges)
            enhanced_data['PriorityScore'] += enhanced_data['EstBalance'].abs() / 2000  # Add 1 point per $2000 balance
            print("Added balance-based scoring")
        
        # 5. Prepayment age if available
        if has_oldest_prepayment:
            enhanced_data['PriorityScore'] += enhanced_data['OldestPrepaymentDays'] / 30  # Add 1 point per 30 days
            print("Added prepayment age-based scoring")
        
        # 6. Add points for having a suggested provider (ease of resolution)
        if has_suggested_provider:
            enhanced_data.loc[enhanced_data['SuggestedProvider'].notna() & 
                             (enhanced_data['SuggestedProvider'] != ''), 'PriorityScore'] += 5
            print("Added suggested provider-based scoring")
        
        # Sort by the priority score
        enhanced_data = enhanced_data.sort_values('PriorityScore', ascending=False)
        
        # Create work queues with recommended action
        enhanced_data['RecommendedAction'] = ''
        
        if has_transaction_category:
            # Prepayment handling
            prepay_mask = enhanced_data['TransactionCategory'] == 'Prepayment/Deposit'
            
            # With suggested provider
            if has_suggested_provider:
                mask = prepay_mask & enhanced_data['SuggestedProvider'].notna() & (enhanced_data['SuggestedProvider'] != '')
                enhanced_data.loc[mask, 'RecommendedAction'] = 'Assign to suggested provider (recent appointment)'
            
            # Without suggested provider but positive account balance
            if has_suggested_provider and 'AccountBalance' in enhanced_data.columns:
                mask = prepay_mask & (~enhanced_data['SuggestedProvider'].notna() | 
                                     (enhanced_data['SuggestedProvider'] == '')) & (enhanced_data['AccountBalance'] > 0)
                enhanced_data.loc[mask, 'RecommendedAction'] = 'Assign to patient\'s primary provider'
            
            # Income transfer handling
            mask = enhanced_data['TransactionCategory'] == 'Income Transfer'
            enhanced_data.loc[mask, 'RecommendedAction'] = 'Verify source and complete income transfer'
            
            # Credit/Refund handling
            mask = enhanced_data['TransactionCategory'] == 'Credit/Refund'
            enhanced_data.loc[mask, 'RecommendedAction'] = 'Assign to original provider or primary provider'
            
            # For very small amounts that might be rounding or adjustments
            if has_split_amt and 'AccountBalance' in enhanced_data.columns:
                mask = (enhanced_data['SplitAmt'].abs() < 5) & (enhanced_data['AccountBalance'].abs() < 10)
                enhanced_data.loc[mask, 'RecommendedAction'] = 'Consider write-off (small amount)'
            
            # For very old transactions with no clear assignment
            if has_days_old and has_suggested_provider:
                mask = (enhanced_data['DaysOld'] > 90) & (~enhanced_data['SuggestedProvider'].notna() | 
                                                         (enhanced_data['SuggestedProvider'] == ''))
                enhanced_data.loc[mask, 'RecommendedAction'] = 'Escalate to office manager for review (aged)'
            
            print("Added recommended actions based on transaction types and characteristics")
        
        # Display the top priority items
        top_count = min(30, len(enhanced_data))
        print(f"\n=== TOP {top_count} PRIORITY ITEMS ===")
        display_columns = [col for col in ['TransactionNum', 'PatientName', 'SplitAmt', 'TransactionDate',
                                         'TransactionCategory', 'SuggestedProvider', 'AccountBalance',
                                         'DaysOld', 'PriorityScore', 'RecommendedAction'] 
                          if col in enhanced_data.columns]
        
        print(enhanced_data[display_columns].head(top_count))
    
    return enhanced_data


def export_enhanced_report(df, filename='unassigned_provider_enhanced_report.xlsx'):
    """Export the enhanced analysis results to Excel"""
    
    if df.empty:
        print("No data available to export")
        return
    
    try:
        with pd.ExcelWriter(filename) as writer:
            # Main data
            df.to_excel(writer, sheet_name='All Transactions', index=False)
            
            # Priority queues
            top_priority = df.head(30)
            top_priority.to_excel(writer, sheet_name='Priority Work Queue', index=False)
            
            # Transaction categories
            if 'TransactionCategory' in df.columns:
                categories = df['TransactionCategory'].unique()
                for category in categories:
                    if pd.notna(category):
                        category_df = df[df['TransactionCategory'] == category].head(50)
                        safe_name = str(category).replace('/', '_')[:31]  # Excel sheet names have limits
                        category_df.to_excel(writer, sheet_name=f'{safe_name}', index=False)
            
            # Staff analysis
            if 'EnteredBy' in df.columns:
                staff_agg_dict = {}
                
                if 'TransactionNum' in df.columns:
                    staff_agg_dict['Count'] = ('TransactionNum', 'count')
                
                if 'SplitAmt' in df.columns:
                    staff_agg_dict['TotalAmount'] = ('SplitAmt', 'sum')
                    staff_agg_dict['AvgAmount'] = ('SplitAmt', 'mean')
                    staff_agg_dict['MaxAmount'] = ('SplitAmt', 'max')
                
                if 'DaysOld' in df.columns:
                    staff_agg_dict['OldestTransaction'] = ('DaysOld', 'max')
                
                if staff_agg_dict:
                    staff_analysis = df.groupby('EnteredBy').agg(**staff_agg_dict).sort_values(
                        'Count' if 'Count' in staff_agg_dict.keys() else list(staff_agg_dict.keys())[0], 
                        ascending=False
                    )
                    staff_analysis.to_excel(writer, sheet_name='Staff Analysis', index=True)
            
            # Clinic analysis if available
            if 'ClinicName' in df.columns:
                clinic_agg_dict = {}
                
                if 'TransactionNum' in df.columns:
                    clinic_agg_dict['Count'] = ('TransactionNum', 'count')
                
                if 'SplitAmt' in df.columns:
                    clinic_agg_dict['TotalAmount'] = ('SplitAmt', 'sum')
                
                if clinic_agg_dict:
                    clinic_analysis = df.groupby('ClinicName').agg(**clinic_agg_dict).sort_values(
                        'Count' if 'Count' in clinic_agg_dict.keys() else list(clinic_agg_dict.keys())[0], 
                        ascending=False
                    )
                    clinic_analysis.to_excel(writer, sheet_name='Clinic Analysis', index=True)
            
            # Summary statistics 
            metrics = []
            values = []
            
            metrics.append('Total Transactions')
            values.append(len(df))
            
            if 'SplitAmt' in df.columns:
                metrics.append('Total Unassigned Amount')
                values.append(f"${df['SplitAmt'].sum():,.2f}")
            
            if 'DaysOld' in df.columns:
                metrics.append('Average Transaction Age (days)')
                values.append(f"{df['DaysOld'].mean():.1f}")
            
            if 'TransactionCategory' in df.columns:
                for category in ['Prepayment/Deposit', 'Income Transfer', 'Credit/Refund']:
                    if category in df['TransactionCategory'].values:
                        metrics.append(category)
                        values.append(len(df[df['TransactionCategory'] == category]))
            
            if 'Priority' in df.columns:
                critical_count = len(df[df['Priority'] == 'Critical'])
                metrics.append('Critical Priority Items')
                values.append(critical_count)
            
            if 'SuggestedProvider' in df.columns:
                provider_count = len(df[df['SuggestedProvider'].notna() & (df['SuggestedProvider'] != '')])
                metrics.append('Items With Suggested Provider')
                values.append(provider_count)
                
            summary_data = {
                'Metric': metrics,
                'Value': values
            }
            pd.DataFrame(summary_data).to_excel(writer, sheet_name='Summary', index=False)
        
        print(f"Enhanced report exported to {filename}")
    except Exception as e:
        print(f"Error exporting report: {e}")


def create_dashboard(df_enriched, save_path='unassigned_transactions_dashboard.png'):
    """Create a comprehensive dashboard of insights"""
    
    if df_enriched.empty:
        print("No data available to create dashboard")
        return
    
    print("\n=== CREATING VISUALIZATION DASHBOARD ===")
    dashboard_data = df_enriched.copy()
    
    # Set up the dashboard
    plt.figure(figsize=(20, 16))
    
    # Determine which plots we can create based on available columns
    plot_count = 0
    
    # Plot 1: Transaction amounts by category
    if 'TransactionCategory' in dashboard_data.columns and 'SplitAmt' in dashboard_data.columns:
        plot_count += 1
        plt.subplot(2, 2, plot_count)
        sns.boxplot(x='TransactionCategory', y='SplitAmt', data=dashboard_data)
        plt.title('Transaction Amounts by Category')
        plt.xticks(rotation=45, ha='right')
        plt.ylabel('Amount ($)')
        print("Added transaction amounts by category plot")
    
    # Plot 2: Transaction age by category
    if 'TransactionCategory' in dashboard_data.columns and 'DaysOld' in dashboard_data.columns:
        plot_count += 1
        plt.subplot(2, 2, plot_count)
        sns.boxplot(x='TransactionCategory', y='DaysOld', data=dashboard_data)
        plt.title('Transaction Age by Category')
        plt.xticks(rotation=45, ha='right')
        plt.ylabel('Age (days)')
        print("Added transaction age by category plot")
    
    # Plot 3: Priority distribution
    if 'Priority' in dashboard_data.columns:
        plot_count += 1
        plt.subplot(2, 2, plot_count)
        priority_counts = dashboard_data['Priority'].value_counts()
        plt.pie(priority_counts, labels=priority_counts.index, autopct='%1.1f%%', 
                colors=sns.color_palette("Set2", len(priority_counts)))
        plt.title('Transactions by Priority')
        print("Added priority distribution plot")
    
    # Plot 4: Transaction counts by staff member
    if 'EnteredBy' in dashboard_data.columns:
        plot_count += 1
        plt.subplot(2, 2, plot_count)
        staff_counts = dashboard_data['EnteredBy'].value_counts().head(8)  # Top 8 staff
        sns.barplot(x=staff_counts.index, y=staff_counts.values)
        plt.title('Top Staff Creating Unassigned Transactions')
        plt.xticks(rotation=45, ha='right')
        plt.ylabel('Number of Transactions')
        print("Added staff transaction counts plot")
    
    # If we created any plots, save the dashboard
    if plot_count > 0:
        plt.tight_layout()
        try:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            print(f"Dashboard saved as '{save_path}'")
        except Exception as e:
            print(f"Error saving dashboard: {e}")
        plt.show()
    else:
        print("No plots could be created due to missing data columns")


# ===============================================================================
# MAIN EXECUTION
# ===============================================================================

def main():
    """Main execution function"""
    print("=" * 80)
    print("UNEARNED INCOME ANALYSIS")
    print("=" * 80)
    
    # Set up file paths
    file_paths = setup_file_paths()
    
    # Load data
    data = load_data(file_paths)
    
    # Check if we have unassigned transactions data
    if data['unassigned'].empty:
        print("\nERROR: Could not load unassigned provider transactions data.")
        print("Please check the file path and ensure the file exists and is accessible.")
        return
    
    # Enrich the data
    df_enriched = enrich_unassigned_transactions(data)
    
    if df_enriched.empty:
        print("\nERROR: Could not enrich unassigned provider transactions data.")
        return
    
    # Run analyses
    analyze_unearned_classifications(df_enriched)
    analyze_patient_balances(df_enriched)
    analyze_prepayment_aging(df_enriched)
    analyze_staff_and_clinic_patterns(df_enriched)
    
    # Create work queues
    enhanced_queues = create_enhanced_work_queues(df_enriched)
    
    # Export report (uncomment to use)
    # export_enhanced_report(enhanced_queues)
    
    # Create dashboard
    create_dashboard(enhanced_queues)
    
    print("\nAnalysis complete!")


if __name__ == "__main__":
    main() 