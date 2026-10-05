-- ============================================================
-- 05_acquisition_analysis.sql
-- Purpose: Compare session volume, funnel progression,
--          and purchase conversion by acquisition source.
--
-- Note:
-- traffic_source fields represent GA4 user-acquisition
-- information and should not be treated as perfect
-- session-level marketing attribution.
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

    device.category AS device_category,

    traffic_source.source AS acquisition_source,

    traffic_source.medium AS acquisition_medium,

    traffic_source.name AS acquisition_campaign

  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

),

session_metrics AS (

  SELECT

    user_pseudo_id,

    ga_session_id,

    ANY_VALUE(acquisition_source) AS acquisition_source,

    ANY_VALUE(acquisition_medium) AS acquisition_medium,

    ANY_VALUE(acquisition_campaign) AS acquisition_campaign,

    MAX(IF(event_name = 'view_item', 1, 0)) AS viewed_product,

    MAX(IF(event_name = 'add_to_cart', 1, 0)) AS added_to_cart,

    MAX(IF(event_name = 'begin_checkout', 1, 0)) AS started_checkout,

    MAX(IF(event_name = 'purchase', 1, 0)) AS purchased

  FROM clean_events

  WHERE ga_session_id IS NOT NULL

  GROUP BY
    user_pseudo_id,
    ga_session_id

)

SELECT

  acquisition_source,

  acquisition_medium,

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

FROM session_metrics

GROUP BY
  acquisition_source,
  acquisition_medium

HAVING COUNT(*) >= 100

ORDER BY purchase_sessions DESC

LIMIT 30;