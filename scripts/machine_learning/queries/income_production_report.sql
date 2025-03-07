/*808 Daily production and income report with totals by provider and month to date */
/*Query code written/modified: 02/13/2018*/
SET @FromDate='2018-02-12' , @ToDate='2018-05-15';

-- Income and Production Report
-- This query provides a comprehensive view of production, adjustments, and income by provider

SELECT * FROM (
	-- Provider Summary
	SELECT 3 AS ItemOrder,
		0 AS OrderSpace,
		'' AS 'DATE',
		'Provider Totals:' AS 'Patient',
		'' AS PatNum,
		'' AS ProcCode,
		'' AS Description,
		'' AS ToothNum,
		'' AS Surf,
		pr.Abbr AS 'Prov',
		FORMAT(SUM(A.$Prod_), 2) AS '$Prod_',
		FORMAT(SUM(A.$Adjust_), 2) AS '$Adjust_',
		FORMAT(SUM(A.$TotProd_), 2) AS '$TotProd_',
		FORMAT(SUM(A.$TotIncome_), 2) AS '$TotIncome_'
	FROM patient p
	INNER JOIN (
		-- Production Subquery
		SELECT 
			pl.ProcDate AS 'Date',
			pl.PatNum,
			pc.AbbrDesc AS 'Description',
			pl.ProvNum,
			pl.ProcFee AS '$Prod_',
			0 AS '$Adjust_',
			0 AS '$WritOff_',
			pl.ProcFee AS '$TotProd_',
			0 AS '$PatIncome_',
			0 AS '$InsIncome_',
			0 AS '$TotIncome_',
			pl.ToothNum,
			pl.Surf,
			pc.ProcCode
		FROM procedurelog pl
		INNER JOIN procedurecode pc ON pc.CodeNum = pl.CodeNum
		WHERE pl.ProcStatus = 2 
		AND pl.ProcDate BETWEEN @FromDate AND @ToDate

		UNION ALL

		-- Adjustments Subquery
		SELECT 
			a.AdjDate AS 'Date',
			a.PatNum,
			d.ItemName AS 'Description',
			a.ProvNum,
			0 AS '$Prod_',
			a.AdjAmt AS '$Adjust_',
			0 AS '$WritOff_',
			a.AdjAmt AS '$TotProd_',
			0 AS '$PatIncome_',
			0 AS '$InsIncome_',
			0 AS '$TotIncome_',
			'' AS ToothNum,
			'' AS Surf,
			'' AS ProcCode
		FROM adjustment a
		INNER JOIN definition d ON a.AdjType = d.DefNum
		WHERE a.AdjDate BETWEEN @FromDate AND @ToDate
		AND a.AdjAmt != 0

		UNION ALL

		-- Patient Income Subquery
		SELECT 
			ps.DatePay AS 'Date',
			ps.PatNum,
			IFNULL(d.ItemName, 'Income Transfer') AS 'Description',
			ps.ProvNum,
			0 AS '$Prod_',
			0 AS '$Adjust_',
			0 AS '$WritOff_',
			0 AS '$TotProd_',
			ps.SplitAmt AS '$PatIncome_',
			0 AS '$InsIncome_',
			ps.SplitAmt AS '$TotIncome_',
			'' AS ToothNum,
			'' AS Surf,
			'' AS ProcCode
		FROM paysplit ps
		INNER JOIN payment pa ON ps.PayNum = pa.PayNum
		LEFT JOIN definition d ON pa.PayType = d.DefNum
		WHERE ps.DatePay BETWEEN @FromDate AND @ToDate

		UNION ALL

		-- Insurance Income and Writeoffs Subquery
		SELECT 
			cp.DateCP AS 'Date',
			cp.PatNum,
			carrier.CarrierName AS 'Description',
			cp.ProvNum,
			0 AS '$Prod_',
			0 AS '$Adjust_',
			-SUM(cp.WriteOff) AS '$WritOff_',
			-SUM(cp.WriteOff) AS '$TotProd_',
			0 AS '$PatIncome_',
			SUM(cp.InsPayAmt) AS '$InsIncome_',
			SUM(cp.InsPayAmt) AS '$TotIncome_',
			'' AS ToothNum,
			'' AS Surf,
			'' AS ProcCode
		FROM claimproc cp
		LEFT JOIN insplan ip ON ip.PlanNum = cp.PlanNum
		LEFT JOIN carrier ON carrier.CarrierNum = ip.CarrierNum
		WHERE (cp.Status = 1 OR cp.Status = 4)
		AND cp.DateCP BETWEEN @FromDate AND @ToDate
		GROUP BY cp.ClaimPaymentNum, cp.PatNum
	) A ON A.PatNum = p.PatNum
	INNER JOIN provider pr ON pr.ProvNum = A.ProvNum
	GROUP BY pr.ProvNum

	UNION ALL
	
	-- Separator Line
	SELECT 
		4 AS ItemOrder,
		0 AS OrderSpace,
		'----------' AS 'DATE',
		'----------',
		'-----' AS PatNum,
		'--------' AS ProcCode,
		'-----------' AS Description,
		'--------' AS ToothNum,
		'----' AS Surf,
		'------' AS 'Prov',
		'------',
		'------',
		'--------',
		'--------'

	UNION ALL

	-- Month to Date Totals
	SELECT 
		5 AS ItemOrder,
		0 AS OrderSpace,
		'' AS DATE,
		'MonthToDate Total:' AS 'Patient',
		'' AS PatNum,
		'' AS ProcCode,
		'' AS Description,
		'' AS ToothNum,
		'' AS Surf,
		'' AS 'Prov',
		'' AS $Prod_,
		'' AS $Adjust_,
		FORMAT(SUM(A.$TotProd_), 2) AS '$TotProd_',
		FORMAT(SUM(A.$TotIncome_), 2) AS '$TotIncome_'
	FROM patient p
	INNER JOIN (
		-- Similar subqueries as above but with month-to-date date filters
		-- ... (subqueries omitted for brevity) ...
	) A ON A.PatNum = p.PatNum
	INNER JOIN provider pr ON pr.ProvNum = A.ProvNum

	UNION ALL

	-- Patient Detail
	SELECT 
		1 AS ItemOrder,
		1 AS OrderSpace,
		'' AS DATE,
		CONCAT(p.LName, ', ', p.FName, ' ', p.MiddleI) AS 'Patient',
		'' AS PatNum,
		'' AS ProcCode,
		'' AS Description,
		'' AS ToothNum,
		'' AS Surf,
		'' AS 'Prov',
		'',
		'',
		'',
		''
	FROM patient p
	INNER JOIN (
		-- Similar subqueries as above
		-- ... (subqueries omitted for brevity) ...
	) A ON A.PatNum = p.PatNum
	INNER JOIN provider pr ON pr.ProvNum = A.ProvNum
	GROUP BY A.PatNum
) B
ORDER BY B.ItemOrder, B.Patient, B.OrderSpace, B.Date, B.ProcCode, B.Description, B.ToothNum, B.Surf;