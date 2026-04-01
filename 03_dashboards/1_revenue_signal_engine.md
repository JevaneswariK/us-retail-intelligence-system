# Dashboard 1 — Revenue Signal Engine  
U.S. Retail Macro Performance (1992–2025)

## Overview
The Revenue Signal Engine is used to analyze the long-term performance of the U.S. retail sector.  
It converts raw sales data into meaningful revenue insights.

The main focus is to understand growth patterns, category concentration, and unusual changes in revenue over a long period of time.

## Problem Statement
Retail data is not always stable. It is affected by seasonality, economic changes, and category-level variations.

The goal here is to separate real long-term growth from short-term fluctuations and noise in the data.

## Approach
- Aggregated transaction-level data into monthly revenue  
- Used window functions (LAG) to calculate growth trends  
- Ranked categories based on revenue contribution  
- Applied Z-score method to detect anomalies  

## Key Metrics
- **Total Market Size** → Overall industry revenue  
- **Average Monthly Revenue** → Baseline demand level  
- **MoM Growth Rate** → Monthly growth trend  
- **Top Demand Driver** → Highest revenue category  

## Key Findings
- Retail shows steady growth with faster increase after 2020  
- Revenue is concentrated in a few top categories (~65–70%)  
- Most anomalies are short-term and not structural  
- E-commerce and retail (excluding auto) are major growth drivers  

## Business Interpretation
This analysis helps to:

- Understand the difference between trend and noise  
- Identify important growth periods  
- Recognize dependency on key categories  