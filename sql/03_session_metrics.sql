-- ============================================================
-- 03_session_metrics.sql
-- Purpose: Build the final session-level analytical dataset.
--
-- Grain:
--   One row per user_pseudo_id + ga_session_id
--
-- This dataset is used downstream for:
--   - Funnel analysis
--   - Acquisition analysis
--   - Lifecycle analysis
--   - Tableau
--   - Python / ML
-- ============================================================

WITH clean_events AS (

  SELECT

    user_pseudo_id,

    PARSE_DATE('%Y%m%d', event_date) AS event_date,

    TIMESTAMP_MICROS(event_timestamp) AS event_datetime,

    event_name,

    -- Session ID
    (
      SELECT ep.value.int_value
      FROM UNNEST(event_params) ep
      WHERE ep.key = 'ga_session_id'
    ) AS ga_session_id,

    -- Session number
    (
      SELECT ep.value.int_value
      FROM UNNEST(event_params) ep
      WHERE ep.key = 'ga_session_number'
    ) AS session_number,

    -- Event value
    (
      SELECT COALESCE(
        ep.value.double_value,
        CAST(ep.value.int_value AS FLOAT64)
      )
      FROM UNNEST(event_params) ep
      WHERE ep.key = 'value'
    ) AS event_value,

    -- Transaction ID
    (
      SELECT ep.value.string_value
      FROM UNNEST(event_params) ep
      WHERE ep.key = 'transaction_id'
    ) AS transaction_id,

    -- Device
    device.category AS device_category,
    device.operating_system AS operating_system,
    device.web_info.browser AS browser,

    -- Geography
    geo.country AS country,
    geo.city AS city,

    -- Acquisition
    traffic_source.source AS acquisition_source,
    traffic_source.medium AS acquisition_medium

  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

),

session_metrics AS (

  SELECT

    user_pseudo_id,

    ga_session_id,

    MAX(session_number) AS session_number,

    DATE(MIN(event_datetime)) AS session_date,

    MIN(event_datetime) AS session_start,

    MAX(event_datetime) AS session_end,

    TIMESTAMP_DIFF(
      MAX(event_datetime),
      MIN(event_datetime),
      SECOND
    ) AS session_duration_seconds,

    COUNT(*) AS event_count,

    COUNTIF(event_name = 'page_view') AS page_views,

    COUNTIF(event_name = 'view_item') AS product_views,

    COUNTIF(event_name = 'add_to_cart') AS cart_adds,

    MAX(IF(event_name = 'view_item', 1, 0)) AS viewed_product,

    MAX(IF(event_name = 'add_to_cart', 1, 0)) AS added_to_cart,

    MAX(IF(event_name = 'begin_checkout', 1, 0)) AS started_checkout,

    MAX(IF(event_name = 'add_shipping_info', 1, 0)) AS added_shipping,

    MAX(IF(event_name = 'add_payment_info', 1, 0)) AS added_payment,

    MAX(IF(event_name = 'purchase', 1, 0)) AS purchased,

    SUM(
      IF(
        event_name = 'purchase',
        COALESCE(event_value, 0),
        0
      )
    ) AS purchase_revenue,

    -- Device
    ANY_VALUE(device_category) AS device_category,
    ANY_VALUE(operating_system) AS operating_system,
    ANY_VALUE(browser) AS browser,

    -- Geography
    ANY_VALUE(country) AS country,
    ANY_VALUE(city) AS city,

    -- Acquisition
    ANY_VALUE(acquisition_source) AS acquisition_source,
    ANY_VALUE(acquisition_medium) AS acquisition_medium

  FROM clean_events

  WHERE ga_session_id IS NOT NULL

  GROUP BY
    user_pseudo_id,
    ga_session_id

)

SELECT

  *,

  CASE
    WHEN session_number = 1 THEN 'New'
    WHEN session_number > 1 THEN 'Returning'
    ELSE 'Unknown'
  END AS user_type

FROM session_metrics

WHERE session_number IS NOT NULL;