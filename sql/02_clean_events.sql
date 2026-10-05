-- ============================================================
-- 02_clean_events.sql
-- Purpose: Extract important GA4 event parameters and
--          standardize event-level fields.
-- ============================================================

WITH clean_events AS (

  SELECT

    user_pseudo_id,

    event_date,

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
    ) AS ga_session_number,

    -- Event value / revenue value
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

    -- Currency
    (
      SELECT ep.value.string_value
      FROM UNNEST(event_params) ep
      WHERE ep.key = 'currency'
    ) AS currency,

    -- Device
    device.category AS device_category,
    device.operating_system AS operating_system,
    device.web_info.browser AS browser,

    -- Geography
    geo.country AS country,
    geo.city AS city

  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

)

SELECT *
FROM clean_events
LIMIT 100;