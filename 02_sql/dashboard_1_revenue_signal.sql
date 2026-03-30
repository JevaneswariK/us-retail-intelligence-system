-- ============================================
-- Dashboard 1: Revenue Signal Engine
-- U.S. Retail Macro Performance (1992–2025)
-- ============================================


-- ============================================
-- KPI 1: Total Market Size
-- ============================================
WITH base AS (
    SELECT SUM(sales) AS total
    FROM retail_monthly_sales 
    WHERE 1=1
    [[AND {{sales_year}}]]
    [[AND {{business_segment}}]]
)
SELECT
CASE
    WHEN total IS NULL THEN NULL
    WHEN total >= 1000000000 THEN CONCAT('$', ROUND(total / 1000000000.0, 1), 'B')
    WHEN total >= 1000000 THEN CONCAT('$', ROUND(total / 1000000.0, 1), 'M')
    WHEN total >= 1000 THEN CONCAT('$', ROUND(total / 1000.0, 1), 'K')
    ELSE CONCAT('$', ROUND(total, 0))
END AS total_revenue
FROM base;


-- ============================================
-- KPI 2: Average Monthly Revenue
-- ============================================
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', sales_date) AS month,
        SUM(sales) AS revenue 
    FROM retail_monthly_sales
    WHERE 1=1 
    [[AND {{sales_year}}]]
    [[AND {{business_segment}}]]
    GROUP BY 1
)
SELECT
CASE
    WHEN AVG(revenue) IS NULL THEN NULL
    WHEN AVG(revenue) >= 1000000000 THEN CONCAT('$', ROUND(AVG(revenue)/1000000000.0,1),'B')
    WHEN AVG(revenue) >= 1000000 THEN CONCAT('$', ROUND(AVG(revenue)/1000000.0,1),'M')
    WHEN AVG(revenue) >= 1000 THEN CONCAT('$', ROUND(AVG(revenue)/1000.0,1),'K')
    ELSE CONCAT('$', ROUND(AVG(revenue),0))
END AS avg_monthly_revenue
FROM monthly;


-- ============================================
-- KPI 3: MoM Growth Rate
-- ============================================
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', sales_date) AS month,
        SUM(sales) AS revenue
    FROM retail_monthly_sales 
    WHERE 1=1
    [[AND {{sales_year}}]]
    [[AND {{business_segment}}]]
    GROUP BY 1 
),
calc AS (
    SELECT
        month,
        revenue, 
        LAG(revenue) OVER (ORDER BY month) AS prev_revenue
    FROM monthly
)
SELECT
ROUND((revenue - prev_revenue) / NULLIF(prev_revenue,0), 2) AS mom_growth_percent
FROM calc
WHERE prev_revenue IS NOT NULL
ORDER BY month DESC
LIMIT 1;


-- ============================================
-- KPI 4: Top Demand Driver
-- ============================================
WITH agg AS (
    SELECT 
        category_short_name,
        SUM(sales) AS revenue
    FROM retail_monthly_sales   
    WHERE 1=1
    [[AND {{sales_year}}]] 
    [[AND {{business_segment}}]]
    GROUP BY category_short_name
)
SELECT category_short_name
FROM agg
ORDER BY revenue DESC
LIMIT 1;


-- ============================================
-- CHART 1: Market Concentration
-- ============================================
WITH category_sales AS (
    SELECT
        category_short_name,
        SUM(sales) AS revenue
    FROM retail_monthly_sales
    WHERE 1=1
    [[AND {{sales_year}}]]
    [[AND {{business_segment}}]]
    GROUP BY category_short_name
),
ranked AS (
    SELECT
        category_short_name,
        revenue,
        RANK() OVER (ORDER BY revenue DESC) AS rnk
    FROM category_sales
),
grouped AS (
    SELECT
        CASE 
            WHEN rnk <= 5 THEN 'Top 5 Categories'
            ELSE 'Others'
        END AS group_name,
        SUM(revenue) AS total_revenue
    FROM ranked
    GROUP BY 1
)
SELECT
    group_name,
    total_revenue,
    ROUND(total_revenue / SUM(total_revenue) OVER () * 100, 2) AS share_percent
FROM grouped;


-- ============================================
-- CHART 2: Top Categories by YoY Growth
-- ============================================
WITH yearly AS (
    SELECT
        EXTRACT(YEAR FROM sales_date) AS year,
        category_short_name,
        SUM(sales) AS revenue
    FROM retail_monthly_sales
    WHERE 1=1
    [[AND {{sales_year}}]]
    [[AND {{business_segment}}]]
    GROUP BY 1,2
),
growth AS (
    SELECT
        category_short_name,
        year,
        revenue,
        LAG(revenue) OVER (PARTITION BY category_short_name ORDER BY year) AS prev_revenue
    FROM yearly
),
calc AS (
    SELECT
        category_short_name,
        ((revenue - prev_revenue) / NULLIF(prev_revenue,0)) * 100 AS yoy_growth
    FROM growth
    WHERE prev_revenue IS NOT NULL
)
SELECT
    category_short_name,
    ROUND(AVG(yoy_growth),2) AS avg_growth_percent
FROM calc
GROUP BY category_short_name
ORDER BY avg_growth_percent DESC
LIMIT 10;


-- ============================================
-- CHART 3: Market Share Change
-- ============================================
WITH yearly AS (
    SELECT
        EXTRACT(YEAR FROM sales_date) AS year,
        category_short_name,
        SUM(sales) AS revenue
    FROM retail_monthly_sales
    WHERE 1=1
    [[AND {{sales_year}}]]
    [[AND {{business_segment}}]]
    GROUP BY 1,2
),
share AS (
    SELECT
        year,
        category_short_name,
        revenue,
        revenue / SUM(revenue) OVER (PARTITION BY year) * 100 AS share_percent
    FROM yearly
),
bounds AS (
    SELECT MIN(year) AS start_year, MAX(year) AS end_year
    FROM yearly
),
change_calc AS (
    SELECT
        s.category_short_name,
        MAX(CASE WHEN s.year = b.start_year THEN s.share_percent END) AS start_share,
        MAX(CASE WHEN s.year = b.end_year THEN s.share_percent END) AS end_share
    FROM share s
    CROSS JOIN bounds b
    GROUP BY s.category_short_name
)
SELECT
    category_short_name,
    ROUND(end_share - start_share,2) AS share_change
FROM change_calc
WHERE end_share IS NOT NULL AND start_share IS NOT NULL
ORDER BY share_change DESC
LIMIT 10;


-- ============================================
-- CHART 4: Revenue Trend + Anomaly Detection
-- ============================================
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', sales_date) AS month,
        SUM(sales) AS revenue
    FROM retail_monthly_sales 
    WHERE 1=1
    [[AND {{sales_year}}]]
    [[AND {{business_segment}}]]
    GROUP BY 1
),
stats AS (
    SELECT
        AVG(revenue) AS mean,
        STDDEV(revenue) AS std
    FROM monthly
),
calc AS (
    SELECT
        m.month,
        m.revenue,
        (m.revenue - s.mean) / NULLIF(s.std,0) AS z_score
    FROM monthly m
    CROSS JOIN stats s
)
SELECT
    month,
    CASE WHEN ABS(z_score) < 2 THEN revenue END AS normal_revenue,
    CASE WHEN ABS(z_score) >= 2 THEN revenue END AS anomaly_revenue
FROM calc
ORDER BY month;


