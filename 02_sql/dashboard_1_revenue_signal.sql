-- ======================================================
-- Dashboard 1: Revenue Signal Engine
-- U.S. Retail Macro Performance (1992–2025)
-- ======================================================

-- 1. Total Market Size
SELECT 
    CASE 
        WHEN SUM(sales) IS NULL THEN NULL
        WHEN SUM(sales) >= 1e9 THEN '$' || ROUND(SUM(sales)/1e9, 1) || 'B'
        WHEN SUM(sales) >= 1e6 THEN '$' || ROUND(SUM(sales)/1e6, 1) || 'M'
        WHEN SUM(sales) >= 1e3 THEN '$' || ROUND(SUM(sales)/1e3, 1) || 'K'
        ELSE '$' || ROUND(SUM(sales), 0)
    END AS total_market_size
FROM retail_monthly_sales
WHERE 1=1
[[AND {{sales_year}}]];


-- 2. Average Monthly Revenue
WITH monthly_data AS (
    SELECT 
        DATE_TRUNC('month', sales_date) AS month,
        SUM(sales) AS revenue
    FROM retail_monthly_sales
    WHERE 1=1
    [[AND {{sales_year}}]]
    GROUP BY 1
)
SELECT 
    CASE 
        WHEN AVG(revenue) >= 1e9 THEN '$' || ROUND(AVG(revenue)/1e9,1) || 'B'
        WHEN AVG(revenue) >= 1e6 THEN '$' || ROUND(AVG(revenue)/1e6,1) || 'M'
        WHEN AVG(revenue) >= 1e3 THEN '$' || ROUND(AVG(revenue)/1e3,1) || 'K'
        ELSE '$' || ROUND(AVG(revenue),0)
    END AS avg_monthly_revenue
FROM monthly_data;


-- 3. MoM Growth Rate
WITH monthly_data AS (
    SELECT 
        DATE_TRUNC('month', sales_date) AS month,
        SUM(sales) AS revenue
    FROM retail_monthly_sales
    WHERE 1=1
    [[AND {{sales_year}}]]
    GROUP BY 1
)
SELECT 
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY month)) 
        / NULLIF(LAG(revenue) OVER (ORDER BY month),0),
    2) AS mom_growth_rate
FROM monthly_data
ORDER BY month DESC
LIMIT 1;


-- 4. Top Demand Driver
SELECT category_short_name
FROM retail_monthly_sales
WHERE 1=1
[[AND {{sales_year}}]]
GROUP BY category_short_name
ORDER BY SUM(sales) DESC
LIMIT 1;


-- ======================================================
-- Charts
-- ======================================================

-- 5. Market Concentration (Top 5 vs Others)
WITH ranked_categories AS (
    SELECT 
        category_short_name,
        SUM(sales) AS revenue,
        RANK() OVER (ORDER BY SUM(sales) DESC) AS rnk
    FROM retail_monthly_sales
    WHERE 1=1
    [[AND {{sales_year}}]]
    GROUP BY category_short_name
)
SELECT 
    CASE 
        WHEN rnk <= 5 THEN 'Top 5 Categories'
        ELSE 'Others'
    END AS category_group,
    SUM(revenue) AS total_revenue,
    ROUND(SUM(revenue) * 100.0 / SUM(SUM(revenue)) OVER (), 2) AS share_percent
FROM ranked_categories
GROUP BY category_group;


-- 6. Top Categories by YoY Growth
WITH yearly_data AS (
    SELECT 
        EXTRACT(YEAR FROM sales_date) AS year,
        category_short_name,
        SUM(sales) AS revenue
    FROM retail_monthly_sales
    WHERE 1=1
    [[AND {{sales_year}}]]
    GROUP BY 1,2
),
growth_calc AS (
    SELECT 
        category_short_name,
        (revenue - LAG(revenue) OVER (PARTITION BY category_short_name ORDER BY year)) 
        / NULLIF(LAG(revenue) OVER (PARTITION BY category_short_name ORDER BY year),0) * 100 AS growth
    FROM yearly_data
)
SELECT 
    category_short_name,
    ROUND(AVG(growth),2) AS avg_yoy_growth
FROM growth_calc
WHERE growth IS NOT NULL
GROUP BY category_short_name
ORDER BY avg_yoy_growth DESC
LIMIT 10;


-- 7. Market Share Change by Category
WITH yearly_data AS (
    SELECT 
        EXTRACT(YEAR FROM sales_date) AS year,
        category_short_name,
        SUM(sales) AS revenue
    FROM retail_monthly_sales
    WHERE 1=1
    [[AND {{sales_year}}]]
    GROUP BY 1,2
),
market_share AS (
    SELECT 
        year,
        category_short_name,
        revenue * 100.0 / SUM(revenue) OVER (PARTITION BY year) AS share
    FROM yearly_data
),
bounds AS (
    SELECT MIN(year) AS start_year, MAX(year) AS end_year FROM yearly_data
)
SELECT 
    m.category_short_name,
    ROUND(
        MAX(CASE WHEN year = start_year THEN share END) -
        MAX(CASE WHEN year = end_year THEN share END)
    ,2) * -1 AS share_change
FROM market_share m, bounds
GROUP BY m.category_short_name
HAVING 
    MAX(CASE WHEN year = start_year THEN share END) IS NOT NULL
    AND MAX(CASE WHEN year = end_year THEN share END) IS NOT NULL
ORDER BY share_change DESC
LIMIT 10;


-- 8. Revenue Trend with Anomaly Detection
WITH monthly_data AS (
    SELECT 
        DATE_TRUNC('month', sales_date) AS month,
        SUM(sales) AS revenue
    FROM retail_monthly_sales
    WHERE 1=1
    [[AND {{sales_year}}]]
    GROUP BY 1
),
stats AS (
    SELECT 
        AVG(revenue) AS avg_rev,
        STDDEV(revenue) AS std_dev
    FROM monthly_data
)
SELECT 
    m.month,
    CASE WHEN ABS((m.revenue - s.avg_rev)/NULLIF(s.std_dev,0)) < 2 
         THEN m.revenue END AS normal_revenue,
    CASE WHEN ABS((m.revenue - s.avg_rev)/NULLIF(s.std_dev,0)) >= 2 
         THEN m.revenue END AS anomaly_revenue
FROM monthly_data m
CROSS JOIN stats s
ORDER BY m.month;