# Income Transfer Analysis
# ========================
# This notebook analyzes income transfers to identify patterns, issues, and recommendations
# for improving provider assignment workflows.

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import os
from datetime import datetime
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from pathlib import Path

# Set some visualization defaults
plt.style.use('ggplot')
sns.set(style="whitegrid")
pd.set_option('display.max_columns', None)
pd.set_option('display.max_rows', 100)

# Get the data directory path - using appropriate relative path from notebook location
DATA_DIR = Path('../data/income_transfer_indicators')

# Function to load the most recent CSV files
def load_most_recent_data():
    """
    Load the most recent CSV files from the data directory
    Returns a dictionary of dataframes
    """
    # Get all CSV files in the directory
    csv_files = list(DATA_DIR.glob('*.csv'))
    
    # If no files, return empty dict
    if not csv_files:
        print("No CSV files found.")
        print(f"Looking in directory: {DATA_DIR.resolve()}")
        return {}
    
    # Get the most recent export date from filenames
    # Format: income_transfer_QUERYNAME_YYYYMMDD.csv
    dates = [f.name.split('_')[-1].replace('.csv', '') for f in csv_files if '_20' in f.name]
    if not dates:
        print("No valid dated CSV files found.")
        return {}
    
    most_recent_date = max(dates)
    print(f"Loading data from {most_recent_date}")
    
    # Load all CSV files for the most recent date
    dataframes = {}
    for csv_file in csv_files:
        if most_recent_date in csv_file.name:
            # Extract query name from filename
            # Format: income_transfer_QUERYNAME_YYYYMMDD.csv
            parts = csv_file.name.split('_')
            if len(parts) >= 3:
                # Join all middle parts to get the query name
                query_name = '_'.join(parts[2:-1])  # Skip first two parts (income_transfer) and last part (date.csv)
                
                print(f"Loading {query_name}...")
                df = pd.read_csv(csv_file)
                dataframes[query_name] = df
    
    return dataframes

# Load the data
data = load_most_recent_data()

# Display available datasets
if data:
    print("\nAvailable datasets:")
    for name, df in data.items():
        print(f"- {name}: {df.shape[0]} rows, {df.shape[1]} columns")
else:
    print("No data available. Please run the export script first.")

# -----------------------------------------------------------
# 1. Who: Analysis of users/groups creating unassigned payments
# -----------------------------------------------------------

def analyze_who():
    """Analyze who is creating unassigned payments"""
    if 'user_groups_creating_unassigned_payments' not in data:
        print("User groups data not available")
        return
    
    df = data['user_groups_creating_unassigned_payments']
    
    # Display the top users/groups by transaction count
    print("Top 10 users/groups creating unassigned payments:")
    top_users = df.sort_values('TransactionCount', ascending=False).head(10)
    display(top_users)
    
    # Create visualizations
    fig = plt.figure(figsize=(12, 8))
    
    # Top 10 users by transaction count
    plt.subplot(1, 2, 1)
    sns.barplot(x='TransactionCount', y='UserName', data=top_users)
    plt.title('Top 10 Users by Unassigned Transaction Count')
    plt.xlabel('Number of Transactions')
    plt.tight_layout()
    
    # Top 10 users by transaction amount
    plt.subplot(1, 2, 2)
    top_by_amount = df.sort_values('TotalAmount', ascending=False).head(10)
    sns.barplot(x='TotalAmount', y='UserName', data=top_by_amount)
    plt.title('Top 10 Users by Unassigned Transaction Amount')
    plt.xlabel('Total Amount ($)')
    plt.tight_layout()
    
    plt.show()
    
    # Return recommendations
    high_volume_users = df[df['TransactionCount'] > df['TransactionCount'].mean() + df['TransactionCount'].std()]
    return {
        'high_volume_users': high_volume_users,
        'recommendations': "Focus training and workflow improvements on these users/groups"
    }

# -----------------------------------------------------------
# 2. What: Analysis of payment types for unassigned transactions
# -----------------------------------------------------------

def analyze_what():
    """Analyze what payment types are associated with unassigned transactions"""
    if 'payment_sources_for_unassigned_transactions' not in data:
        print("Payment sources data not available")
        return
    
    df = data['payment_sources_for_unassigned_transactions']
    
    # Display the top payment types
    print("Top payment types with unassigned providers:")
    top_payment_types = df.sort_values('TransactionCount', ascending=False).head(10)
    display(top_payment_types)
    
    # Create visualizations
    fig = plt.figure(figsize=(14, 8))
    
    # Payment type distribution by count
    plt.subplot(1, 2, 1)
    sns.barplot(x='TransactionCount', y='PaymentType', data=top_payment_types)
    plt.title('Top Payment Types by Count')
    plt.xlabel('Number of Transactions')
    plt.tight_layout()
    
    # Payment type distribution by amount
    plt.subplot(1, 2, 2)
    top_by_amount = df.sort_values('TotalAmount', ascending=False).head(10)
    sns.barplot(x='TotalAmount', y='PaymentType', data=top_by_amount)
    plt.title('Top Payment Types by Amount')
    plt.xlabel('Total Amount ($)')
    plt.tight_layout()
    
    plt.show()
    
    # Return insights
    return {
        'top_payment_types': top_payment_types,
        'recommendations': "Review payment entry workflows for these payment types"
    }

# -----------------------------------------------------------
# 3. When: Analysis of time patterns for unassigned transactions
# -----------------------------------------------------------

def analyze_when():
    """Analyze when unassigned transactions are occurring"""
    time_patterns = {
        'hour': data.get('time_patterns_by_hour'),
        'day': data.get('time_patterns_by_day'),
        'month': data.get('time_patterns_by_month')
    }
    
    if not any(time_patterns.values()):
        print("Time pattern data not available")
        return
    
    # Create time pattern visualizations
    fig = make_subplots(rows=3, cols=1, 
                       subplot_titles=('Transactions by Hour of Day', 
                                      'Transactions by Day of Week', 
                                      'Transactions by Month'))
    
    # Hour of day pattern
    if time_patterns['hour'] is not None:
        hour_df = time_patterns['hour'].sort_values('Hour')
        fig.add_trace(
            go.Bar(x=hour_df['Hour'], y=hour_df['TransactionCount'], name='By Hour'),
            row=1, col=1
        )
    
    # Day of week pattern
    if time_patterns['day'] is not None:
        # Ensure days are in correct order
        day_order = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
        day_df = time_patterns['day']
        if 'DayName' in day_df.columns:
            day_df['DayOfWeek'] = pd.Categorical(day_df['DayName'], categories=day_order, ordered=True)
            day_df = day_df.sort_values('DayOfWeek')
            fig.add_trace(
                go.Bar(x=day_df['DayName'], y=day_df['TransactionCount'], name='By Day'),
                row=2, col=1
            )
    
    # Month pattern
    if time_patterns['month'] is not None:
        month_order = ['January', 'February', 'March', 'April', 'May', 'June', 
                      'July', 'August', 'September', 'October', 'November', 'December']
        month_df = time_patterns['month']
        if 'MonthName' in month_df.columns:
            month_df['Month'] = pd.Categorical(month_df['MonthName'], categories=month_order, ordered=True)
            month_df = month_df.sort_values('Month')
            fig.add_trace(
                go.Bar(x=month_df['MonthName'], y=month_df['TransactionCount'], name='By Month'),
                row=3, col=1
            )
    
    fig.update_layout(height=900, width=800, title_text="Time Patterns of Unassigned Transactions")
    fig.show()
    
    # Identify peak times
    peaks = {}
    if time_patterns['hour'] is not None:
        peaks['peak_hour'] = time_patterns['hour'].loc[time_patterns['hour']['TransactionCount'].idxmax()]['Hour']
    if time_patterns['day'] is not None and 'DayName' in time_patterns['day'].columns:
        peaks['peak_day'] = time_patterns['day'].loc[time_patterns['day']['TransactionCount'].idxmax()]['DayName']
    
    return {
        'time_patterns': time_patterns,
        'peaks': peaks,
        'recommendations': "Focus staff training and monitoring during peak transaction times"
    }

# -----------------------------------------------------------
# 4. Where: Analyze connection between appointments and unassigned payments
# -----------------------------------------------------------

def analyze_where():
    """Analyze where (which locations/providers) should be associated with unassigned payments"""
    if 'appointments_near_payment_date' not in data:
        print("Appointment data not available")
        return
    
    df = data['appointments_near_payment_date']
    
    # Analysis of appointments near payment dates
    print("Summary of appointments near unassigned payment dates:")
    display(df.describe())
    
    # Visualize days between appointment and payment
    if 'DaysBetween' in df.columns:
        plt.figure(figsize=(10, 6))
        sns.histplot(df['DaysBetween'], bins=30)
        plt.title('Days Between Appointment and Unassigned Payment')
        plt.xlabel('Days')
        plt.ylabel('Count')
        plt.axvline(x=0, color='red', linestyle='--', label='Payment Date')
        plt.legend()
        plt.tight_layout()
        plt.show()
    
    # Provider frequency in appointments
    if 'ProviderName' in df.columns:
        top_providers = df['ProviderName'].value_counts().head(10)
        plt.figure(figsize=(12, 6))
        top_providers.plot(kind='bar')
        plt.title('Top 10 Providers with Appointments Near Unassigned Payments')
        plt.xlabel('Provider')
        plt.ylabel('Count')
        plt.tight_layout()
        plt.show()
    
    # Return recommendations
    return {
        'appointments_near_payments': df.shape[0],
        'recommendations': "Consider automatic provider assignment based on recent appointments"
    }

# -----------------------------------------------------------
# 5. Why: Detailed analysis of unassigned transactions
# -----------------------------------------------------------

def analyze_why():
    """Analyze why transactions are unassigned and potential solutions"""
    if 'unassigned_provider_transactions' not in data:
        print("Unassigned provider transactions data not available")
        return
    
    df = data['unassigned_provider_transactions']
    
    # Summary statistics
    print("Summary of unassigned provider transactions:")
    summary = {
        'Total Transactions': df.shape[0],
        'Total Amount': df['Amount'].sum() if 'Amount' in df.columns else 'N/A',
        'Average Amount': df['Amount'].mean() if 'Amount' in df.columns else 'N/A',
        'Date Range': f"{df['PaymentDate'].min()} to {df['PaymentDate'].max()}" if 'PaymentDate' in df.columns else 'N/A'
    }
    display(pd.Series(summary))
    
    # Analyze priority classifications if available
    if 'Priority' in df.columns:
        priority_counts = df['Priority'].value_counts()
        plt.figure(figsize=(10, 6))
        priority_counts.plot(kind='pie', autopct='%1.1f%%')
        plt.title('Unassigned Transactions by Priority')
        plt.ylabel('')
        plt.tight_layout()
        plt.show()
    
    # Analyze suggested providers if available
    if 'SuggestedProvider' in df.columns:
        suggested_providers = df['SuggestedProvider'].value_counts().head(10)
        plt.figure(figsize=(12, 6))
        suggested_providers.plot(kind='bar')
        plt.title('Top 10 Suggested Providers for Unassigned Transactions')
        plt.xlabel('Provider')
        plt.ylabel('Count')
        plt.tight_layout()
        plt.show()
    
    # Return overall recommendations
    return {
        'total_unassigned': df.shape[0],
        'total_amount': df['Amount'].sum() if 'Amount' in df.columns else 0,
        'recommendations': "Implement automated provider assignment based on priority and suggestions"
    }

# -----------------------------------------------------------
# Run all analyses and compile an executive summary
# -----------------------------------------------------------

def generate_executive_summary():
    """Generate an executive summary of all analyses"""
    results = {}
    
    print("="*80)
    print("ANALYZING WHO IS CREATING UNASSIGNED PAYMENTS")
    print("="*80)
    results['who'] = analyze_who()
    
    print("\n"+"="*80)
    print("ANALYZING WHAT PAYMENT TYPES ARE ASSOCIATED WITH UNASSIGNED TRANSACTIONS")
    print("="*80)
    results['what'] = analyze_what()
    
    print("\n"+"="*80)
    print("ANALYZING WHEN UNASSIGNED TRANSACTIONS ARE OCCURRING")
    print("="*80)
    results['when'] = analyze_when()
    
    print("\n"+"="*80)
    print("ANALYZING WHERE (APPOINTMENTS/PROVIDERS) RELATED TO UNASSIGNED PAYMENTS")
    print("="*80)
    results['where'] = analyze_where()
    
    print("\n"+"="*80)
    print("ANALYZING WHY TRANSACTIONS ARE UNASSIGNED AND POTENTIAL SOLUTIONS")
    print("="*80)
    results['why'] = analyze_why()
    
    # Compile executive summary
    print("\n\n"+"="*80)
    print("EXECUTIVE SUMMARY")
    print("="*80)
    
    # Only include results that are available
    summary_points = []
    
    if results.get('who'):
        top_users = results['who'].get('high_volume_users', [])
        if len(top_users) > 0:
            summary_points.append(f"• {len(top_users)} users account for a disproportionate number of unassigned transactions")
    
    if results.get('what'):
        top_types = results['what'].get('top_payment_types', [])
        if len(top_types) > 0:
            summary_points.append(f"• Top payment type with unassigned providers: {top_types.iloc[0]['PaymentType'] if len(top_types) > 0 else 'N/A'}")
    
    if results.get('when') and results['when'].get('peaks'):
        peaks = results['when']['peaks']
        if 'peak_hour' in peaks and 'peak_day' in peaks:
            summary_points.append(f"• Peak time for unassigned transactions: {peaks.get('peak_day', 'N/A')} at {peaks.get('peak_hour', 'N/A')}:00")
    
    if results.get('where'):
        summary_points.append(f"• {results['where'].get('appointments_near_payments', 0)} appointments found near unassigned payment dates")
    
    if results.get('why'):
        summary_points.append(f"• Total unassigned transactions: {results['why'].get('total_unassigned', 0)}")
        summary_points.append(f"• Total unassigned amount: ${results['why'].get('total_amount', 0):,.2f}")
    
    # Print summary points
    for point in summary_points:
        print(point)
    
    # Recommendations
    print("\nKEY RECOMMENDATIONS:")
    recommendations = []
    
    for analysis, result in results.items():
        if result and 'recommendations' in result:
            recommendations.append(f"• {result['recommendations']}")
    
    for rec in recommendations:
        print(rec)
    
    return results

# Run the executive summary
# Uncomment the line below to run the full analysis
# summary_results = generate_executive_summary() 