/*
Payment Type Date Summary Query
========================

Purpose:
- Combines payment type and date analysis in one comprehensive view
- Shows payment type distribution by month for trend analysis
- Includes regular vs unearned income breakdown
- Enables time-series analysis of payment patterns
- Perfect for visualizing payment method trends over time

PANDAS ANALYSIS GUIDE
-------------------------------
This query produces a single result set with three sections (identified by the Section column)
that should be used together for comprehensive analysis. Follow these steps for effective analysis:

1. DATA LOADING & TRANSFORMATION:
   ```python
   # Import necessary libraries
   import pandas as pd
   import matplotlib.pyplot as plt
   import seaborn as sns
   
   # Load the query results
   df = pd.read_csv('payment_type_date_summary.csv')
   
   # Critical type conversions
   # Convert month to datetime (add day 1 for proper datetime)
   df['Payment Month'] = pd.to_datetime(df['Payment Month'] + '-01')
   
   # Convert all numeric columns to appropriate types
   numeric_cols = df.select_dtypes(include=['object']).columns
   for col in numeric_cols:
       if col not in ['Payment Month', 'Payment Type', 'Payment Category', 'Section']:
           df[col] = pd.to_numeric(df[col], errors='coerce')
   
   # Split the dataframe into three sections for specific analysis
   df_all = df[df['Section'] == 'All Payment Types']
   df_regular = df[df['Section'] == 'Regular Payments']
   df_unearned = df[df['Section'] == 'Unearned Income']
   ```

2. KEY ANALYSIS TECHNIQUES:
   A. Payment Method Trends Over Time
   ```python
   # Create pivot table of payment methods by month
   payment_trends = df_all.pivot_table(
       index='Payment Month', 
       columns='Payment Type',
       values='Total Amount',
       aggfunc='sum'
   )
   
   # Fill NaN with 0 for consistent plotting
   payment_trends = payment_trends.fillna(0)
   
   # Plot as line chart
   ax = payment_trends.plot(figsize=(14, 7), title='Payment Method Trends')
   ax.set_ylabel('Total Amount ($)')
   plt.xticks(rotation=45)
   ```
   
   B. Regular vs Unearned Analysis
   ```python
   # Calculate composition by month
   monthly_composition = df_all.groupby('Payment Month').agg({
       'Regular Payment Amount': 'sum',
       'Unearned Income Amount': 'sum'
   })
   
   # Create stacked area chart
   monthly_composition.plot.area(
       stacked=True, 
       figsize=(14, 7),
       title='Regular vs Unearned Payment Composition'
   )
   ```
   
   C. Payment Method Distribution
   ```python
   # Analyze distribution by payment type and category
   payment_distribution = pd.pivot_table(
       pd.concat([df_regular, df_unearned]),
       index='Payment Type',
       columns='Section',
       values='Total Amount',
       aggfunc='sum'
   )
   
   # Plot as stacked bar chart
   payment_distribution.plot(
       kind='barh', 
       stacked=True,
       figsize=(10, 8),
       title='Payment Method Distribution by Category'
   )
   ```

3. ADVANCED INSIGHTS & CALCULATIONS:
   - Income Transfer Analysis: Pay special attention to Income Transfer rows as they often sum to zero but represent significant internal money movement
   - Seasonality Detection: Look for recurring patterns in specific months using seasonal decomposition
   - Average Payment Size: Compare df_regular['Average Payment Amount'] across payment types to identify customer payment preferences
   - Month-over-Month Growth: Calculate percent change to identify growing or declining payment methods
   
4. POTENTIAL ISSUES:
   - Watch for negative values in "Unearned Income Amount" which represent application of previously collected funds
   - Zero-sum payment types (like Income Transfer) can distort percentage calculations
   - Small counts for some payment types in certain months may cause volatility in averages

NOTE FOR EXPORT SCRIPT:
- This query now returns a single result set with a 'Section' column to identify the three different analysis sections
- The query structure uses UNION ALL to combine the three previously separate queries
- Results can be filtered by the Section column for specific analysis

Dependencies:
- None (performs definition lookup directly)

Date Filter: @start_date to @end_date
*/

-- Set date parameters - uncomment and modify as needed
-- SET @start_date = '2024-01-01';
-- SET @end_date = '2025-02-28';

-- Combined query with all payment type sections in one result set
SELECT 
    'All Payment Types' AS 'Section',
    DATE_FORMAT(ps.DatePay, '%Y-%m') AS 'Payment Month',
    IFNULL(
        (SELECT def.ItemName 
         FROM definition def 
         WHERE def.DefNum = pm.PayType), 
        'Income Transfer'
    ) AS 'Payment Type',
    'All' AS 'Payment Category',
    COUNT(*) AS 'Transaction Count',
    SUM(ps.SplitAmt) AS 'Total Amount',
    COUNT(DISTINCT ps.PatNum) AS 'Unique Patients',
    SUM(CASE WHEN ps.UnearnedType = 0 THEN ps.SplitAmt ELSE 0 END) AS 'Regular Payment Amount',
    SUM(CASE WHEN ps.UnearnedType != 0 THEN ps.SplitAmt ELSE 0 END) AS 'Unearned Income Amount',
    CASE 
        WHEN SUM(ps.SplitAmt) = 0 THEN 0
        ELSE (SUM(CASE WHEN ps.UnearnedType = 0 THEN ps.SplitAmt ELSE 0 END) / SUM(ps.SplitAmt)) * 100
    END AS 'Regular Payment %',
    NULL AS 'Average Payment Amount',
    NULL AS 'Prepayment Amount',
    NULL AS 'Treatment Plan Prepayment Amount'
FROM paysplit ps
INNER JOIN payment pm ON pm.PayNum = ps.PayNum
WHERE ps.DatePay BETWEEN @start_date AND @end_date
GROUP BY DATE_FORMAT(ps.DatePay, '%Y-%m'), pm.PayType

UNION ALL

SELECT 
    'Regular Payments' AS 'Section',
    DATE_FORMAT(ps.DatePay, '%Y-%m') AS 'Payment Month',
    IFNULL(
        (SELECT def.ItemName 
         FROM definition def 
         WHERE def.DefNum = pm.PayType), 
        'Income Transfer'
    ) AS 'Payment Type',
    'Regular Payments' AS 'Payment Category',
    COUNT(*) AS 'Transaction Count',
    SUM(ps.SplitAmt) AS 'Total Amount',
    COUNT(DISTINCT ps.PatNum) AS 'Unique Patients',
    SUM(ps.SplitAmt) AS 'Regular Payment Amount',
    0 AS 'Unearned Income Amount',
    100 AS 'Regular Payment %',
    AVG(ps.SplitAmt) AS 'Average Payment Amount',
    NULL AS 'Prepayment Amount',
    NULL AS 'Treatment Plan Prepayment Amount'
FROM paysplit ps
INNER JOIN payment pm ON pm.PayNum = ps.PayNum
WHERE ps.DatePay BETWEEN @start_date AND @end_date
    AND ps.UnearnedType = 0
GROUP BY DATE_FORMAT(ps.DatePay, '%Y-%m'), pm.PayType

UNION ALL

SELECT 
    'Unearned Income' AS 'Section',
    DATE_FORMAT(ps.DatePay, '%Y-%m') AS 'Payment Month',
    IFNULL(
        (SELECT def.ItemName 
         FROM definition def 
         WHERE def.DefNum = pm.PayType), 
        'Income Transfer'
    ) AS 'Payment Type',
    'Unearned Income' AS 'Payment Category',
    COUNT(*) AS 'Transaction Count',
    SUM(ps.SplitAmt) AS 'Total Amount',
    COUNT(DISTINCT ps.PatNum) AS 'Unique Patients',
    0 AS 'Regular Payment Amount',
    SUM(ps.SplitAmt) AS 'Unearned Income Amount',
    0 AS 'Regular Payment %',
    AVG(ps.SplitAmt) AS 'Average Payment Amount',
    SUM(CASE WHEN ps.UnearnedType = 288 THEN ps.SplitAmt ELSE 0 END) AS 'Prepayment Amount',
    SUM(CASE WHEN ps.UnearnedType = 439 THEN ps.SplitAmt ELSE 0 END) AS 'Treatment Plan Prepayment Amount'
FROM paysplit ps
INNER JOIN payment pm ON pm.PayNum = ps.PayNum
WHERE ps.DatePay BETWEEN @start_date AND @end_date
    AND ps.UnearnedType != 0
GROUP BY DATE_FORMAT(ps.DatePay, '%Y-%m'), pm.PayType

ORDER BY Section, Payment Month, Total Amount DESC; 