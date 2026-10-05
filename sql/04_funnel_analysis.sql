-- ============================================================
-- 04_funnel_analysis.sql
-- Purpose: Analyze the purchase funnel by device.
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

    device.category AS device_category

  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

),

session_metrics AS (

  SELECT

    user_pseudo_id,

    ga_session_id,

    ANY_VALUE(device_category) AS device_category,

    MAX(IF(event_name = 'view_item', 1, 0)) AS viewed_product,

    MAX(IF(event_name = 'add_to_cart', 1, 0)) AS added_to_cart,

    MAX(IF(event_name = 'begin_checkout', 1, 0)) AS started_checkout,

    MAX(IF(event_name = 'add_shipping_info', 1, 0)) AS added_shipping,

    MAX(IF(event_name = 'add_payment_info', 1, 0)) AS added_payment,

    MAX(IF(event_name = 'purchase', 1, 0)) AS purchased

  FROM clean_events

  WHERE ga_session_id IS NOT NULL

  GROUP BY
    user_pseudo_id,
    ga_session_id

)

SELECT

  device_category,

  COUNT(*) AS total_sessions,

  SUM(viewed_product) AS product_view_sessions,

  SUM(added_to_cart) AS cart_sessions,

  SUM(started_checkout) AS checkout_sessions,

  SUM(added_payment) AS payment_sessions,

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
      SUM(started_checkout),
      SUM(added_to_cart)
    ) * 100,
    2
  ) AS cart_to_checkout_pct,

  ROUND(
    SAFE_DIVIDE(
      SUM(purchased),
      SUM(started_checkout)
    ) * 100,
    2
  ) AS checkout_to_purchase_pct,

  ROUND(
    SAFE_DIVIDE(
      SUM(purchased),
      COUNT(*)
    ) * 100,
    2
  ) AS overall_conversion_pct

FROM session_metrics

GROUP BY device_category

ORDER BY total_sessions DESC;