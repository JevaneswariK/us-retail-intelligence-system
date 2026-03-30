-- ============================================
-- Dashboard 2: Risk & Opportunity Engine
-- Volatility, Growth & Forecast Signals
-- ============================================


-- ============================================
-- KPI 1: Revenue Stability Index
-- ============================================
SELECT
    ROUND(STDDEV(sales)/NULLIF(AVG(sales),0), 3) AS stability_index
FROM retail_monthly_sales
WHERE 1=1
[[AND TO_CHAR(sales_date, 'YYYY') IN ({{sales_year}})]];


-- ============================================
-- KPI 2: Demand Variability Index
-- ============================================
WITH monthly AS (
  SELECT
    DATE_TRUNC('month', sales_date) AS month,
    SUM(sales) AS revenue
  FROM retail_monthly_sales
  WHERE 1=1
  [[AND TO_CHAR(sales_date, 'YYYY') IN ({{sales_year}})]]
  GROUP BY 1
)
SELECT
ROUND(STDDEV(revenue)/NULLIF(AVG(revenue),0),3) AS volatility_index
FROM monthly;


-- ============================================
-- KPI 3: Revenue Consistency Ratio
-- ============================================
SELECT
ROUND(1 / (1 + (STDDEV(sales)/NULLIF(AVG(sales),0))),3) AS consistency_score
FROM retail_monthly_sales
WHERE 1=1
[[AND TO_CHAR(sales_date, 'YYYY') IN ({{sales_year}})]];


-- ============================================
-- KPI 4: Market Concentration Risk
-- ============================================
WITH category_totals AS (
    SELECT 
        category_short_name,
        SUM(sales) AS revenue
    FROM retail_monthly_sales
    WHERE 1=1
    [[AND TO_CHAR(sales_date, 'YYYY') IN ({{sales_year}})]]
    GROUP BY category_short_name
),
totals AS (
    SELECT SUM(revenue) AS total_revenue FROM category_totals
),
top_category AS (
    SELECT MAX(revenue) AS top_revenue FROM category_totals
)
SELECT 
ROUND(top_revenue * 100.0 / NULLIF(total_revenue,0),2) AS concentration_percent
FROM top_category, totals;


-- ============================================
-- CHART 1: Revenue Deviations & Shock Detection
-- ============================================
WITH base AS (
    SELECT 
        sales_date,
        SUM(sales) AS revenue
    FROM retail_monthly_sales  
    WHERE 1=1
    [[AND TO_CHAR(sales_date, 'YYYY') IN ({{sales_year}})]]
    [[AND {{category_top10}}]]
    GROUP BY sales_date
),
cte AS (
    SELECT 
        sales_date,
        revenue,
        AVG(revenue) OVER (
            ORDER BY sales_date 
            ROWS BETWEEN 5 PRECEDING AND 1 PRECEDING
        ) AS moving_average
    FROM base
),
dev AS (
    SELECT 
        sales_date,
        revenue,
        moving_average,
        (revenue - moving_average) AS deviation,
        CASE 
            WHEN moving_average IS NULL THEN 'Normal'
            WHEN revenue > moving_average * 1.05 THEN 'Spike'
            WHEN revenue < moving_average * 0.95 THEN 'Drop'
            ELSE 'Normal'
        END AS anomalies
    FROM cte
)
SELECT 
    sales_date,
    revenue,
    moving_average,
    deviation,
    anomalies,
    CASE WHEN anomalies = 'Spike' THEN revenue END AS spike_revenue,
    CASE WHEN anomalies = 'Drop' THEN revenue END AS drop_revenue,
    CASE WHEN anomalies = 'Normal' THEN revenue END AS normal_revenue
FROM dev
ORDER BY sales_date;


-- ============================================
-- CHART 2: Category Risk Distribution
-- ============================================
WITH cte AS (
    SELECT 
        sales_date,
        category_top10,
        SUM(sales) AS revenue 
    FROM retail_monthly_sales 
    WHERE 1=1
    [[AND TO_CHAR(sales_date, 'YYYY') IN ({{sales_year}})]]
    GROUP BY sales_date, category_top10
),
volatile AS (
    SELECT 
        category_top10,
        SUM(revenue) AS total_revenue,
        AVG(revenue) AS avg_revenue,
        STDDEV_POP(revenue) AS volatility,
        STDDEV_POP(revenue) / NULLIF(AVG(revenue), 0) AS cv  
    FROM cte 
    GROUP BY category_top10
),
median AS (
    SELECT 
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_revenue) AS median_revenue,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY cv) AS median_cv
    FROM volatile
)
SELECT 
    v.category_top10,
    v.total_revenue,
    v.avg_revenue,
    v.volatility,
    v.cv,
    CASE 
        WHEN v.total_revenue > m.median_revenue AND v.cv < m.median_cv THEN 'Stable High'
        WHEN v.total_revenue > m.median_revenue AND v.cv > m.median_cv THEN 'Risky High'
        WHEN v.total_revenue < m.median_revenue AND v.cv < m.median_cv THEN 'Stable Low'
        ELSE 'Weak/Risky'
    END AS risk_level
FROM volatile v 
CROSS JOIN median m;


-- ============================================
-- CHART 3: Growth vs Volatility Matrix
-- ============================================
WITH base AS (
    SELECT 
        TO_DATE(year_month, 'Mon YYYY') AS ym_date,  
        year_month,
        category_top10,
        SUM(sales) AS revenue  
    FROM retail_monthly_sales 
    WHERE 1=1  
    [[AND TO_CHAR(sales_date, 'YYYY') IN ({{sales_year}})]]
    [[AND {{category_top10}}]]
    GROUP BY 1,2,3
),
calc AS (
    SELECT 
        ym_date,
        year_month,
        category_top10,
        revenue,
        AVG(revenue) OVER (
            PARTITION BY category_top10  
            ORDER BY ym_date  
            ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
        ) AS moving_average,
        LAG(revenue) OVER (
            PARTITION BY category_top10 
            ORDER BY ym_date 
        ) AS prev_revenue
    FROM base
),
final AS (
    SELECT 
        ym_date,
        year_month,
        category_top10,
        revenue,
        moving_average,
        (revenue - moving_average) AS deviation,
        COALESCE(revenue - prev_revenue, 0) AS growth,
        COALESCE((revenue - prev_revenue) / NULLIF(prev_revenue, 0), 0) AS growth_pct,
        CASE 
            WHEN prev_revenue IS NULL THEN 'Stable'
            WHEN revenue > prev_revenue THEN 'Growing'
            WHEN revenue < prev_revenue THEN 'Declining'
            ELSE 'Stable'
        END AS trend
    FROM calc
)
SELECT * 
FROM final
WHERE deviation IS NOT NULL  
ORDER BY category_top10, ym_date;


-- ============================================
-- CHART 4: Revenue Forecast & Trend
-- ============================================
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
date_bounds AS (
    SELECT
        MIN(month) AS min_month,
        MAX(month) AS max_month
    FROM monthly
),
date_series AS (
    SELECT generate_series(
        (SELECT min_month FROM date_bounds),
        (SELECT max_month FROM date_bounds) + INTERVAL '6 month',
        INTERVAL '1 month'
    ) AS month
),
joined AS (
    SELECT
        d.month,
        m.revenue
    FROM date_series d
    LEFT JOIN monthly m ON d.month = m.month
),
ma AS (
    SELECT
        month,
        revenue,
        AVG(revenue) OVER (
            ORDER BY month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS moving_avg
    FROM joined
),
trend_slope AS (
    SELECT
        month,
        revenue,
        moving_avg,
        (moving_avg - LAG(moving_avg) OVER (ORDER BY month)) AS trend_slope
    FROM ma
),
last_point AS (
    SELECT *
    FROM trend_slope
    WHERE moving_avg IS NOT NULL
    ORDER BY month DESC
    LIMIT 1
),
forecast AS (
    SELECT
        d.month,
        NULL::numeric AS revenue,
        NULL::numeric AS moving_avg,
        l.moving_avg + 
        (ROW_NUMBER() OVER (ORDER BY d.month) * COALESCE(l.trend_slope,0)) AS forecast
    FROM date_series d
    CROSS JOIN last_point l
    WHERE d.month > l.month
),
final AS (
    SELECT month, revenue, moving_avg, NULL::numeric AS forecast FROM ma
    UNION ALL
    SELECT month, revenue, moving_avg, forecast FROM forecast
)
SELECT *
FROM final
ORDER BY month;