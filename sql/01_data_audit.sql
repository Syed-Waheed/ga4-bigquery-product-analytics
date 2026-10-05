-- ============================================================
-- 01_data_audit.sql
-- Google Merchandise Store — GA4 Product Analytics
-- Purpose: Audit dataset size, event coverage, date range,
--          and inspect purchase event parameters.
-- ============================================================


-- 1. Dataset overview

SELECT
  COUNT(*) AS event_count,
  COUNT(DISTINCT user_pseudo_id) AS user_count,
  COUNT(DISTINCT event_date) AS day_count
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`;


-- 2. Event distribution

SELECT
  event_name,
  COUNT(*) AS event_count
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
GROUP BY event_name
ORDER BY event_count DESC;


-- 3. Date coverage

SELECT
  MIN(event_date) AS first_date,
  MAX(event_date) AS last_date,
  COUNT(DISTINCT event_date) AS number_of_days
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`;


-- 4. Inspect purchase event parameters

SELECT
  event_name,
  ep.key,
  ep.value.string_value,
  ep.value.int_value,
  ep.value.double_value
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
UNNEST(event_params) AS ep
WHERE event_name = 'purchase'
LIMIT 50;
