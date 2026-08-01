/* ============================================================
   ORDER FUNNEL EXTRACTION & ANALYSIS — SYNTHETIC 1000-ROW DATASET
   Same logic as funnel_extraction.sql, run against
   Subscriptions_synthetic.csv / Payment_Status_Log_synthetic.csv /
   Cancelations_synthetic.csv (1,000 subscriptions, full event-log
   coverage, generated to match the conversion/cancelation patterns
   observed in the original 50-row sample).
   ============================================================ */

/* ---------- 1. FUNNEL FACT TABLE: one row per order ------------ */
WITH subs_clean AS (
    SELECT
        s.Subscription_ID AS subscription_id,
        s.Customer_ID     AS customer_id,
        s.Product_ID      AS product_id,
        s.Purchased_Users AS purchased_users,
        CAST(s.Revenue AS INTEGER) AS revenue,
        s.Active           AS is_active,
        CASE WHEN s.Order_Date IS NULL OR s.Order_Date = 'None' THEN NULL
             ELSE substr(s.Order_Date, 7, 4) || '-' || substr(s.Order_Date, 4, 2) || '-' || substr(s.Order_Date, 1, 2)
        END AS order_date,
        CASE WHEN s.Cancel_Date IS NULL OR s.Cancel_Date = 'None' THEN NULL
             ELSE substr(s.Cancel_Date, 7, 4) || '-' || substr(s.Cancel_Date, 4, 2) || '-' || substr(s.Cancel_Date, 1, 2)
        END AS cancel_date,
        s.Current_Payment_Status AS current_payment_status
    FROM Subscriptions s
),
log_progress AS (
    SELECT
        Subscription_ID AS subscription_id,
        MAX(Status_ID)  AS max_status_from_log,
        COUNT(*)        AS num_status_events,
        SUM(CASE WHEN Status_ID = 0 THEN 1 ELSE 0 END) AS error_events
    FROM Payment_Status_Log
    GROUP BY Subscription_ID
),
funnel_stage AS (
    SELECT
        sc.*,
        COALESCE(lp.max_status_from_log, sc.current_payment_status) AS funnel_stage_id,
        lp.num_status_events, lp.error_events
    FROM subs_clean sc
    LEFT JOIN log_progress lp ON lp.subscription_id = sc.subscription_id
),
funnel_labeled AS (
    SELECT
        fs.*,
        pd.Description AS funnel_stage_name,
        CASE WHEN fs.funnel_stage_id = 5 THEN 1 ELSE 0 END AS is_completed_order,
        CASE WHEN fs.funnel_stage_id = 0 THEN 1 ELSE 0 END AS is_error_order,
        CASE
            WHEN fs.funnel_stage_id IS NULL THEN 'No order activity'
            WHEN fs.funnel_stage_id = 5     THEN 'Completed'
            WHEN fs.cancel_date IS NOT NULL THEN 'Abandoned / Canceled'
            ELSE 'In progress / Stalled'
        END AS order_outcome
    FROM funnel_stage fs
    LEFT JOIN Payment_Status_Definitions pd ON pd.Status_ID = fs.funnel_stage_id
)
SELECT
    fl.subscription_id, fl.customer_id, c.Customer_Name AS customer_name,
    fl.product_id, p.Product_Name AS product_name,
    fl.order_date, fl.cancel_date,
    fl.funnel_stage_id, fl.funnel_stage_name, fl.order_outcome,
    fl.is_completed_order, fl.is_error_order,
    fl.num_status_events, fl.error_events,
    fl.revenue, fl.purchased_users, fl.is_active,
    cn.Cancelation_Reason1 AS cancelation_reason
FROM funnel_labeled fl
LEFT JOIN Customers c     ON c.Customer_ID = fl.customer_id
LEFT JOIN Products p      ON p.Product_ID  = fl.product_id
LEFT JOIN Cancelations cn ON cn.Subscription_ID = fl.subscription_id
ORDER BY fl.order_date;


/* ---------- 2. CUMULATIVE STAGE COUNTS -------------------------- */
WITH max_stage_per_order AS (
    SELECT Subscription_ID AS subscription_id, MAX(Status_ID) AS max_stage
    FROM Payment_Status_Log
    GROUP BY Subscription_ID
),
stage_defs AS (
    SELECT Status_ID AS stage_id, Description AS stage_name
    FROM Payment_Status_Definitions
    WHERE Status_ID BETWEEN 1 AND 5
)
SELECT
    sd.stage_id, sd.stage_name,
    COUNT(DISTINCT m.subscription_id) AS orders_reaching_stage,
    ROUND(100.0 * COUNT(DISTINCT m.subscription_id) /
        (SELECT COUNT(DISTINCT subscription_id) FROM max_stage_per_order), 1) AS pct_of_all_tracked_orders
FROM stage_defs sd
LEFT JOIN max_stage_per_order m ON m.max_stage >= sd.stage_id
GROUP BY sd.stage_id, sd.stage_name
ORDER BY sd.stage_id;


/* ---------- 3. SQL-ONLY FUNNEL METRICS (window functions) ------- */
WITH max_stage_per_order AS (
    SELECT Subscription_ID AS subscription_id, MAX(Status_ID) AS max_stage
    FROM Payment_Status_Log
    GROUP BY Subscription_ID
),
stage_defs AS (
    SELECT Status_ID AS stage_id, Description AS stage_name
    FROM Payment_Status_Definitions
    WHERE Status_ID BETWEEN 1 AND 5
),
stage_counts AS (
    SELECT sd.stage_id, sd.stage_name,
           COUNT(DISTINCT m.subscription_id) AS orders_reaching_stage
    FROM stage_defs sd
    LEFT JOIN max_stage_per_order m ON m.max_stage >= sd.stage_id
    GROUP BY sd.stage_id, sd.stage_name
),
funnel_metrics AS (
    SELECT stage_id, stage_name, orders_reaching_stage,
           LAG(orders_reaching_stage) OVER (ORDER BY stage_id) AS prev_stage_count,
           FIRST_VALUE(orders_reaching_stage) OVER (ORDER BY stage_id) AS start_count
    FROM stage_counts
)
SELECT
    stage_id, stage_name, orders_reaching_stage,
    ROUND(1.0 * orders_reaching_stage / NULLIF(prev_stage_count, 0), 4) AS step_conversion_rate,
    COALESCE(prev_stage_count - orders_reaching_stage, 0) AS dropoff_count,
    ROUND(1.0 - (1.0 * orders_reaching_stage / NULLIF(prev_stage_count, 0)), 4) AS dropoff_pct,
    ROUND(1.0 * orders_reaching_stage / start_count, 4) AS overall_conversion_from_start
FROM funnel_metrics
ORDER BY stage_id;


/* ---------- 4. REVENUE AT RISK: stalled orders by stage --------- */
SELECT
    s.Current_Payment_Status AS stalled_at_stage,
    pd.Description            AS stage_name,
    COUNT(*)                  AS num_orders,
    SUM(s.Revenue)             AS revenue_at_risk
FROM Subscriptions s
LEFT JOIN Payment_Status_Definitions pd ON pd.Status_ID = s.Current_Payment_Status
WHERE s.Cancel_Date IS NULL
  AND s.Current_Payment_Status < 5
GROUP BY s.Current_Payment_Status, pd.Description
ORDER BY revenue_at_risk DESC;


/* ---------- 5. CANCELATION REASON BREAKDOWN ---------------------- */
SELECT
    Cancelation_Reason1 AS reason,
    COUNT(*)             AS num_cancelations,
    SUM(s.Revenue)        AS revenue_lost
FROM Cancelations cn
JOIN Subscriptions s ON s.Subscription_ID = cn.Subscription_ID
GROUP BY Cancelation_Reason1
ORDER BY num_cancelations DESC;
