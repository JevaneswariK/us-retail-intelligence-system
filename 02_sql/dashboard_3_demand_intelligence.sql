-- =========================================
-- 📊 DASHBOARD 3: DEMAND INTELLIGENCE ENGINE
-- =========================================

-- =========================
-- 🔹 KPI 1: Avg Revenue per Category
-- =========================
WITH base AS (
  SELECT 
    SUM(sales) AS total_rev,
    COUNT(DISTINCT category_top10) AS cat_count
  FROM retail_monthly_sales
  WHERE 1=1 
    AND category_top10 <> 'Other Retail Sectors'
    [[AND TO_CHAR(sales_date, 'YYYY') IN ({{sales_year}})]]
    [[AND {{category_top10}}]]
),
calc AS (
  SELECT 
    COALESCE(total_rev / NULLIF(cat_count,0),0) AS revenue_per_category,
    total_rev
  FROM base
)
SELECT
CASE 
    WHEN total_rev IS NULL THEN NULL
    WHEN revenue_per_category >= 1000000000 THEN CONCAT('$', ROUND(revenue_per_category/1000000000.0,2), 'B')
    WHEN revenue_per_category >= 1000000 THEN CONCAT('$', ROUND(revenue_per_category/1000000.0,2), 'M')
    WHEN revenue_per_category >= 1000 THEN CONCAT('$', ROUND(revenue_per_category/1000.0,2), 'K')
    ELSE CONCAT('$', ROUND(revenue_per_category,2)) 
END AS revenue_per_category
FROM calc;


-- =========================
-- 🔹 KPI 2: Revenue Dispersion
-- =========================
WITH category_data AS (
    SELECT
        category_top10,
        SUM(sales) AS category_revenue
    FROM retail_monthly_sales
    WHERE 1=1
        [[AND TO_CHAR(sales_date, 'YYYY') IN ({{sales_year}})]]
    GROUP BY category_top10 
),
stats AS (
    SELECT 
        COUNT(*) AS cnt,
        STDDEV(category_revenue) AS sd,
        AVG(category_revenue) AS avg_val
    FROM category_data
)
SELECT 
CASE 
    WHEN cnt <= 1 THEN 0
    ELSE ROUND(sd / NULLIF(avg_val,0), 2)
END AS revenue_dispersion_score
FROM stats;


-- =========================
-- 🔹 KPI 3: P10 Revenue (Downside Risk)
-- =========================
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', sales_date) AS month,
        SUM(sales) AS revenue
    FROM retail_monthly_sales
    WHERE 1=1
        [[AND EXTRACT(YEAR FROM sales_date) IN ({{sales_year}})]]
        [[AND {{category_top10}}]]
    GROUP BY 1
),
stats AS (
    SELECT
        PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY revenue) AS downside_risk_p10,
        COUNT(*) AS cnt
    FROM monthly
)
SELECT 
CASE 
    WHEN cnt = 0 OR downside_risk_p10 IS NULL THEN NULL
    ELSE ROUND(downside_risk_p10::numeric, 2)
END AS downside_risk_p10
FROM stats;


-- =========================
-- 🔹 KPI 4: Revenue Efficiency Ratio
-- =========================
WITH category_rev AS (
    SELECT 
        category_top10,
        SUM(sales) AS revenue 
    FROM retail_monthly_sales
    WHERE 1=1
        [[AND TO_CHAR(sales_date, 'YYYY') IN ({{sales_year}})]]
        [[AND {{category_top10}}]] 
    GROUP BY category_top10
),
stats AS (
    SELECT 
        MAX(revenue) AS top_rev,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue) AS median_rev,
        COUNT(*) AS cnt
    FROM category_rev
)
SELECT
CASE
    WHEN cnt = 0 OR median_rev IS NULL OR median_rev = 0 THEN NULL
    ELSE ROUND((top_rev / median_rev)::numeric, 2)::text
END AS revenue_efficiency_ratio
FROM stats;


-- =========================
-- 📈 CHART 1: Category Segmentation
-- =========================
WITH category_stats AS (
    SELECT
        category_top10,
        SUM(sales) AS total_revenue, 
        AVG(sales) AS avg_revenue,
        STDDEV(sales) AS stddev_revenue
    FROM retail_monthly_sales
    WHERE 1=1
        [[AND TO_CHAR(sales_date, 'YYYY') IN ({{sales_year}})]]
    GROUP BY category_top10
),
final AS (
    SELECT
        category_top10,
        ROUND(avg_revenue::numeric, 2) AS avg_revenue,
        ROUND((stddev_revenue / NULLIF(avg_revenue, 0))::numeric, 3) AS consistency_index,
        CASE
            WHEN (stddev_revenue / NULLIF(avg_revenue, 0)) <= 0.35 THEN 'Stable Performers'
            WHEN (stddev_revenue / NULLIF(avg_revenue, 0)) <= 0.60 THEN 'Balanced Performers'
            ELSE 'High Variability'
        END AS performance_segment
    FROM category_stats
)
SELECT *
FROM final
ORDER BY avg_revenue DESC;


-- =========================
-- 📈 CHART 2: Revenue Momentum Distribution
-- =========================
WITH monthly AS (
    SELECT 
        DATE_TRUNC('month', sales_date) AS month,
        SUM(sales) AS revenue
    FROM retail_monthly_sales 
    WHERE 1=1
        [[AND TO_CHAR(sales_date, 'YYYY') IN ({{sales_year}})]]
        [[AND {{category_top10}}]]
    GROUP BY 1
),
mom_data AS (
    SELECT 
        month,
        revenue,
        revenue - LAG(revenue) OVER (ORDER BY month) AS mom_change
    FROM monthly
),
valid_changes AS (
    SELECT mom_change
    FROM mom_data
    WHERE mom_change IS NOT NULL
),
stats AS (
    SELECT 
        MIN(mom_change) AS min_val,
        MAX(mom_change) AS max_val
    FROM valid_changes
),
bucketed AS (
    SELECT 
        WIDTH_BUCKET(vc.mom_change, s.min_val, s.max_val, 12) AS bucket
    FROM valid_changes vc
    CROSS JOIN stats s
),
final AS (
    SELECT 
        b.bucket,
        COUNT(*) AS frequency,
        CONCAT(
            '[',
            ROUND((s.min_val + (b.bucket-1)*(s.max_val-s.min_val)/12)/1000000.0,2),
            'M, ',
            ROUND((s.min_val + (b.bucket)*(s.max_val-s.min_val)/12)/1000000.0,2),
            'M]'
        ) AS change_range
    FROM bucketed b
    CROSS JOIN stats s
    GROUP BY b.bucket, s.min_val, s.max_val
)
SELECT *
FROM final
ORDER BY bucket;


-- =========================
-- 📈 CHART 3: Seasonal Volatility
-- =========================
WITH monthly_stats AS (
    SELECT 
        category_top10,
        sales_month AS month,
        STDDEV(sales) / NULLIF(AVG(sales), 0) AS volatility
    FROM retail_monthly_sales
    WHERE 1=1 
        [[AND TO_CHAR(sales_date, 'YYYY') IN ({{sales_year}})]] 
        [[AND {{category_top10}}]]
    GROUP BY 1,2
)
SELECT *
FROM monthly_stats
ORDER BY category_top10, month;


-- =========================
-- 📈 CHART 4: Lorenz Curve
-- =========================
WITH category_rev AS (
    SELECT 
        category_top10,
        SUM(sales) AS revenue
    FROM retail_monthly_sales
    WHERE 1=1 
        [[AND TO_CHAR(sales_date, 'YYYY') IN ({{sales_year}})]]
    GROUP BY category_top10
),
lorenz AS (
    SELECT
        SUM(revenue) OVER (ORDER BY revenue) * 1.0 / SUM(revenue) OVER () AS y,
        SUM(1) OVER (ORDER BY revenue) * 1.0 / COUNT(*) OVER () AS x,
        'Lorenz Curve' AS line
    FROM category_rev
)
SELECT x, y, line
FROM lorenz

UNION ALL

SELECT gs, gs, 'Equality'
FROM generate_series(0.0, 1.0, 0.01) gs
ORDER BY x;