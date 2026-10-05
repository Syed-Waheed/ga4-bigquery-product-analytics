-- ============================================================
-- 07_conversion_diagnosis.sql
-- Purpose: Diagnose weekly conversion changes by comparing
--          New vs Returning sessions.
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

    DATE(MIN(event_datetime)) AS session_date,

    MAX(IF(event_name = 'view_item', 1, 0)) AS viewed_product,

    MAX(IF(event_name = 'add_to_cart', 1, 0)) AS added_to_cart,

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

    DATE_TRUNC(
      session_date,
      WEEK(MONDAY)
    ) AS week_start,

    CASE
      WHEN session_number = 1 THEN 'New'
      WHEN session_number > 1 THEN 'Returning'
      ELSE 'Unknown'
    END AS user_type

  FROM session_metrics

)

SELECT

  week_start,

  user_type,

  COUNT(*) AS sessions,

  SUM(viewed_product) AS product_view_sessions,

  SUM(added_to_cart) AS cart_sessions,

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
  ) AS purchase_rate_pct,

  ROUND(
    SAFE_DIVIDE(
      SUM(purchased),
      SUM(SUM(purchased)) OVER (
        PARTITION BY week_start
      )
    ) * 100,
    2
  ) AS share_of_weekly_purchases_pct

FROM classified_sessions

WHERE user_type != 'Unknown'

GROUP BY
  week_start,
  user_type

ORDER BY
  week_start,
  user_type;