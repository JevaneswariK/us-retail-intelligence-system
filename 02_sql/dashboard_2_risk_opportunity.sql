-- ======================================================
-- Dashboard 2: Risk & Opportunity Engine
-- Volatility, Growth & Forecast Signals
-- ======================================================

-- 1. Revenue Stability Index
SELECT 
    ROUND(STDDEV(sales) / NULLIF(AVG(sales),0), 3) AS stability_index
FROM retail_monthly_sales
WHERE 1=1
[[AND {{sales_year}}]];


-- 2. Demand Variability Index
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
    ROUND(STDDEV(revenue) / NULLIF(AVG(revenue),0), 3) AS demand_variability
FROM monthly_data;


-- 3. Revenue Consistency Ratio
SELECT 
    ROUND(1 / (1 + (STDDEV(sales) / NULLIF(AVG(sales),0))), 3) AS consistency_ratio
FROM retail_monthly_sales
WHERE 1=1
[[AND {{sales_year}}]];


-- 4. Market Concentration Risk
WITH category_totals AS (
    SELECT 
        category_short_name,
        SUM(sales) AS revenue
    FROM retail_monthly_sales
    WHERE 1=1
    [[AND {{sales_year}}]]
    GROUP BY category_short_name
),
total AS (
    SELECT SUM(revenue) AS total_revenue FROM category_totals
)
SELECT 
    ROUND(MAX(revenue) * 100.0 / NULLIF((SELECT total_revenue FROM total),0), 2) 
    AS concentration_risk_percent
FROM category_totals;


-- ======================================================
-- Charts
-- ======================================================

-- 5. Revenue Deviations & Shock Detection
WITH base AS (
    SELECT 
        sales_date,
        SUM(sales) AS revenue
    FROM retail_monthly_sales
    WHERE 1=1
    [[AND {{sales_year}}]]
    [[AND {{category_top10}}]]
    GROUP BY sales_date
),
calc AS (
    SELECT 
        sales_date,
        revenue,
        AVG(revenue) OVER (
            ORDER BY sales_date
            ROWS BETWEEN 5 PRECEDING AND 1 PRECEDING
        ) AS moving_avg
    FROM base
)
SELECT 
    sales_date,
    revenue,
    moving_avg,
    (revenue - moving_avg) AS deviation,
    CASE 
        WHEN moving_avg IS NULL THEN 'Normal'
        WHEN revenue > moving_avg * 1.05 THEN 'Spike'
        WHEN revenue < moving_avg * 0.95 THEN 'Drop'
        ELSE 'Normal'
    END AS anomaly_flag,
    CASE WHEN revenue > moving_avg * 1.05 THEN revenue END AS spike_revenue,
    CASE WHEN revenue < moving_avg * 0.95 THEN revenue END AS drop_revenue,
    CASE WHEN ABS(revenue - moving_avg) <= moving_avg * 0.05 THEN revenue END AS normal_revenue
FROM calc
ORDER BY sales_date;


-- 6. Category Risk Distribution (Scale vs Volatility)
WITH base AS (
    SELECT 
        category_top10,
        DATE_TRUNC('month', sales_date) AS month,
        SUM(sales) AS revenue
    FROM retail_monthly_sales
    WHERE 1=1
    [[AND {{sales_year}}]]
    GROUP BY 1,2
),
stats AS (
    SELECT 
        category_top10,
        SUM(revenue) AS total_revenue,
        AVG(revenue) AS avg_revenue,
        STDDEV_POP(revenue) AS volatility,
        STDDEV_POP(revenue) / NULLIF(AVG(revenue),0) AS cv
    FROM base
    GROUP BY category_top10
),
medians AS (
    SELECT 
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_revenue) AS median_rev,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY cv) AS median_cv
    FROM stats
)
SELECT 
    s.category_top10,
    s.total_revenue,
    s.avg_revenue,
    s.volatility,
    s.cv,
    CASE 
        WHEN s.total_revenue >= m.median_rev AND s.cv <= m.median_cv THEN 'Stable High'
        WHEN s.total_revenue >= m.median_rev AND s.cv > m.median_cv THEN 'Risky High'
        WHEN s.total_revenue < m.median_rev AND s.cv <= m.median_cv THEN 'Stable Low'
        ELSE 'Weak/Risky'
    END AS risk_segment
FROM stats s
CROSS JOIN medians m;


-- 7. Growth vs Volatility Matrix
WITH base AS (
    SELECT 
        DATE_TRUNC('month', sales_date) AS month,
        category_top10,
        SUM(sales) AS revenue
    FROM retail_monthly_sales
    WHERE 1=1
    [[AND {{sales_year}}]]
    [[AND {{category_top10}}]]
    GROUP BY 1,2
),
calc AS (
    SELECT 
        month,
        category_top10,
        revenue,
        LAG(revenue) OVER (PARTITION BY category_top10 ORDER BY month) AS prev_revenue,
        AVG(revenue) OVER (
            PARTITION BY category_top10
            ORDER BY month
            ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
        ) AS moving_avg
    FROM base
)
SELECT 
    month,
    category_top10,
    revenue,
    (revenue - moving_avg) AS deviation,
    COALESCE((revenue - prev_revenue) / NULLIF(prev_revenue,0),0) AS growth_rate,
    CASE 
        WHEN prev_revenue IS NULL THEN 'Stable'
        WHEN revenue > prev_revenue THEN 'Growing'
        WHEN revenue < prev_revenue THEN 'Declining'
        ELSE 'Stable'
    END AS trend
FROM calc
WHERE moving_avg IS NOT NULL;


-- 8. Revenue Forecast & Trend
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
ma AS (
    SELECT 
        month,
        revenue,
        AVG(revenue) OVER (
            ORDER BY month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS moving_avg
    FROM monthly_data
),
trend AS (
    SELECT 
        month,
        revenue,
        moving_avg,
        moving_avg - LAG(moving_avg) OVER (ORDER BY month) AS slope
    FROM ma
),
last_point AS (
    SELECT * FROM trend
    WHERE moving_avg IS NOT NULL
    ORDER BY month DESC
    LIMIT 1
),
future_dates AS (
    SELECT generate_series(
        (SELECT MAX(month) FROM monthly_data) + INTERVAL '1 month',
        (SELECT MAX(month) FROM monthly_data) + INTERVAL '6 month',
        INTERVAL '1 month'
    ) AS month
),
forecast AS (
    SELECT 
        f.month,
        NULL::numeric AS revenue,
        NULL::numeric AS moving_avg,
        l.moving_avg + (ROW_NUMBER() OVER (ORDER BY f.month) * COALESCE(l.slope,0)) AS forecast
    FROM future_dates f
    CROSS JOIN last_point l
)
SELECT month, revenue, moving_avg, NULL::numeric AS forecast FROM ma
UNION ALL
SELECT month, revenue, moving_avg, forecast FROM forecast
ORDER BY month;
