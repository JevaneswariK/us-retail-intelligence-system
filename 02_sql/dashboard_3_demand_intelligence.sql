-- ======================================================
-- Dashboard 3: Demand Intelligence Engine
-- Category Performance, Efficiency & Distribution
-- ======================================================

-- 1. Average Revenue (Top 10 Categories)
WITH base AS (
    SELECT 
        SUM(sales) AS total_revenue,
        COUNT(DISTINCT category_top10) AS category_count
    FROM retail_monthly_sales
    WHERE 1=1
      AND category_top10 <> 'Other Retail Sectors'
      [[AND {{sales_year}}]]
      [[AND {{category_top10}}]]
)
SELECT 
    CASE 
        WHEN total_revenue IS NULL THEN NULL
        WHEN total_revenue / NULLIF(category_count,0) >= 1e9 THEN '$' || ROUND((total_revenue/category_count)/1e9,2) || 'B'
        WHEN total_revenue / NULLIF(category_count,0) >= 1e6 THEN '$' || ROUND((total_revenue/category_count)/1e6,2) || 'M'
        WHEN total_revenue / NULLIF(category_count,0) >= 1e3 THEN '$' || ROUND((total_revenue/category_count)/1e3,2) || 'K'
        ELSE '$' || ROUND((total_revenue/category_count),2)
    END AS avg_revenue_top10
FROM base;


-- 2. Revenue Dispersion (CV)
WITH category_data AS (
    SELECT 
        category_top10,
        SUM(sales) AS revenue
    FROM retail_monthly_sales
    WHERE 1=1
    [[AND {{sales_year}}]]
    GROUP BY category_top10
)
SELECT 
    ROUND(STDDEV(revenue) / NULLIF(AVG(revenue),0), 2) AS revenue_dispersion
FROM category_data;


-- 3. P10 Revenue (Downside Risk)
WITH monthly_data AS (
    SELECT 
        DATE_TRUNC('month', sales_date) AS month,
        SUM(sales) AS revenue
    FROM retail_monthly_sales
    WHERE 1=1
    [[AND {{sales_year}}]]
    [[AND {{category_top10}}]]
    GROUP BY 1
)
SELECT 
    ROUND(PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY revenue), 2) AS p10_revenue
FROM monthly_data;


-- 4. Revenue Efficiency Ratio
WITH category_rev AS (
    SELECT 
        category_top10,
        SUM(sales) AS revenue
    FROM retail_monthly_sales
    WHERE 1=1
    [[AND {{sales_year}}]]
    GROUP BY category_top10
),
stats AS (
    SELECT 
        MAX(revenue) AS max_rev,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue) AS median_rev
    FROM category_rev
)
SELECT 
    ROUND(max_rev / NULLIF(median_rev,0), 2) AS efficiency_ratio
FROM stats;


-- ======================================================
-- Charts
-- ======================================================

-- 5. Category Performance Segmentation
WITH stats AS (
    SELECT 
        category_top10,
        AVG(sales) AS avg_revenue,
        STDDEV(sales) AS sd
    FROM retail_monthly_sales
    WHERE 1=1
    [[AND {{sales_year}}]]
    GROUP BY category_top10
)
SELECT 
    category_top10,
    ROUND(avg_revenue,2) AS avg_revenue,
    ROUND(sd / NULLIF(avg_revenue,0),3) AS consistency_index,
    CASE 
        WHEN sd / NULLIF(avg_revenue,0) <= 0.35 THEN 'Stable Performers'
        WHEN sd / NULLIF(avg_revenue,0) <= 0.60 THEN 'Balanced Performers'
        ELSE 'High Variability'
    END AS segment
FROM stats
ORDER BY avg_revenue DESC;


-- 6. Revenue Momentum Distribution
WITH monthly_data AS (
    SELECT 
        DATE_TRUNC('month', sales_date) AS month,
        SUM(sales) AS revenue
    FROM retail_monthly_sales
    WHERE 1=1
    [[AND {{sales_year}}]]
    [[AND {{category_top10}}]]
    GROUP BY 1
),
changes AS (
    SELECT 
        revenue - LAG(revenue) OVER (ORDER BY month) AS change
    FROM monthly_data
)
SELECT 
    WIDTH_BUCKET(change, MIN(change) OVER (), MAX(change) OVER (), 12) AS bucket,
    COUNT(*) AS frequency
FROM changes
WHERE change IS NOT NULL
GROUP BY bucket
ORDER BY bucket;


-- 7. Seasonal Volatility by Category
SELECT 
    category_top10,
    sales_month,
    STDDEV(sales) / NULLIF(AVG(sales),0) AS volatility
FROM retail_monthly_sales
WHERE 1=1
[[AND {{sales_year}}]]
[[AND {{category_top10}}]]
GROUP BY category_top10, sales_month
ORDER BY category_top10, sales_month;


-- 8. Revenue Distribution Inequality (Lorenz Curve)
WITH category_rev AS (
    SELECT 
        category_top10,
        SUM(sales) AS revenue
    FROM retail_monthly_sales
    WHERE 1=1
    [[AND {{sales_year}}]]
    GROUP BY category_top10
),
lorenz AS (
    SELECT 
        revenue,
        SUM(revenue) OVER (ORDER BY revenue) / SUM(revenue) OVER () AS cum_rev,
        ROW_NUMBER() OVER (ORDER BY revenue) * 1.0 / COUNT(*) OVER () AS cum_cat
    FROM category_rev
)
SELECT 
    cum_cat AS x,
    cum_rev AS y,
    'Lorenz Curve' AS line
FROM lorenz
UNION ALL
SELECT 
    gs AS x,
    gs AS y,
    'Equality' AS line
FROM generate_series(0.0,1.0,0.01) gs
ORDER BY x;
