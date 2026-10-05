-- ============================================================
-- 06_lifecycle_analysis.sql
-- Purpose:
--   1. Compare New vs Returning sessions.
--   2. Build weekly user retention cohorts.
-- ============================================================


-- ============================================================
-- PART 1 — New vs Returning
-- ============================================================

WITH clean_events AS (

  SELECT

    user_pseudo_id,

    event_date,

    TIMESTAMP_MICROS(event_timestamp) AS event_datetime,

    event_name,

    (
      SELECT ep.value.int_value
      FROM UNNEST(event_params) ep
      WHERE ep.key = 'ga_session_id'
    ) AS ga_session_id,

    (
      SELECT ep.value.int_value
      FROM UNNEST(event_params) ep
      WHERE ep.key = 'ga_session_number'
    ) AS session_number

  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

),

session_metrics AS (

  SELECT

    user_pseudo_id,

    ga_session_id,

    MAX(session_number) AS session_number,

    MAX(IF(event_name = 'view_item', 1, 0)) AS viewed_product,

    MAX(IF(event_name = 'add_to_cart', 1, 0)) AS added_to_cart,

    MAX(IF(event_name = 'begin_checkout', 1, 0)) AS started_checkout,

    MAX(IF(event_name = 'purchase', 1, 0)) AS purchased

  FROM clean_events

  WHERE ga_session_id IS NOT NULL

  GROUP BY
    user_pseudo_id,
    ga_session_id

),

classified_sessions AS (

  SELECT

    *,

    CASE
      WHEN session_number = 1 THEN 'New'
      WHEN session_number > 1 THEN 'Returning'
      ELSE 'Unknown'
    END AS user_type

  FROM session_metrics

)

SELECT

  user_type,

  COUNT(*) AS sessions,

  SUM(viewed_product) AS product_view_sessions,

  SUM(added_to_cart) AS cart_sessions,

  SUM(started_checkout) AS checkout_sessions,

  SUM(purchased) AS purchase_sessions,

  ROUND(
    SAFE_DIVIDE(
      SUM(added_to_cart),
      SUM(viewed_product)
    ) * 100,
    2
  ) AS view_to_cart_pct,

  ROUND(
    SAFE_DIVIDE(
      SUM(purchased),
      COUNT(*)
    ) * 100,
    2
  ) AS session_purchase_rate

FROM classified_sessions

WHERE user_type != 'Unknown'

GROUP BY user_type

ORDER BY user_type;


-- ============================================================
-- PART 2 — Weekly Retention Cohorts
-- ============================================================

WITH user_activity AS (

  SELECT DISTINCT

    user_pseudo_id,

    PARSE_DATE('%Y%m%d', event_date) AS activity_date

  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

  WHERE user_pseudo_id IS NOT NULL

),

first_activity AS (

  SELECT

    user_pseudo_id,

    MIN(activity_date) AS first_date

  FROM user_activity

  GROUP BY user_pseudo_id

),

cohorts AS (

  SELECT

    user_pseudo_id,

    DATE_TRUNC(
      first_date,
      WEEK(MONDAY)
    ) AS cohort_week

  FROM first_activity

),

weekly_activity AS (

  SELECT DISTINCT

    ua.user_pseudo_id,

    DATE_TRUNC(
      ua.activity_date,
      WEEK(MONDAY)
    ) AS activity_week

  FROM user_activity ua

),

retention AS (

  SELECT

    c.cohort_week,

    DATE_DIFF(
      wa.activity_week,
      c.cohort_week,
      WEEK(MONDAY)
    ) AS week_number,

    COUNT(DISTINCT c.user_pseudo_id) AS active_users

  FROM cohorts c

  JOIN weekly_activity wa

    ON c.user_pseudo_id = wa.user_pseudo_id

  GROUP BY
    c.cohort_week,
    week_number

),

cohort_sizes AS (

  SELECT

    cohort_week,

    COUNT(*) AS cohort_size

  FROM cohorts

  GROUP BY cohort_week

)

SELECT

  r.cohort_week,

  r.week_number,

  r.active_users,

  cs.cohort_size,

  ROUND(
    SAFE_DIVIDE(
      r.active_users,
      cs.cohort_size
    ) * 100,
    2
  ) AS retention_pct

FROM retention r

JOIN cohort_sizes cs

  ON r.cohort_week = cs.cohort_week

WHERE r.week_number BETWEEN 0 AND 8

ORDER BY
  cohort_week,
  week_number;