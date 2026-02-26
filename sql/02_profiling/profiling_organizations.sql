-- =====================================================
-- Project: Enterprise Data Quality Lab
-- File: profiling_organizations.sql
-- Author: Dylan Blandino
-- Created: 2026-02-23
--
-- Description:
-- Data profiling analysis for enterprise_raw.organizations table.
--
-- Purpose:
-- - Understand data volume and structure
-- - Evaluate completeness of critical attributes
-- - Validate uniqueness of organization identifiers
-- - Detect duplicate entities
-- - Identify hierarchical integrity issues
--
-- Notes:
-- This script is read-only and does not modify data.
--
-- =====================================================



-- =====================================================
-- SECTION 1: Row count
-- =====================================================

SELECT
    'organizations' AS table_name,
    COUNT(*) AS row_count
FROM enterprise_raw.organizations;



-- =====================================================
-- FINDINGS
-- =====================================================
-- Summary:
-- Organization table successfully loaded with expected volume.
--
-- Details:
-- The table contains 15,000 organization records with no
-- indication of incomplete data load.
--
-- Impact:
-- Dataset is suitable for downstream profiling and integrity analysis.
--
-- Recommendation:
-- No action required.
--
-- =====================================================




-- =====================================================
-- SECTION 2: Completeness analysis
-- =====================================================

SELECT
    COUNT(*) AS total_rows,

    SUM(CASE WHEN org_id IS NULL THEN 1 ELSE 0 END) AS null_org_id_count,
    SUM(CASE WHEN org_name IS NULL THEN 1 ELSE 0 END) AS null_org_name_count,
    SUM(CASE WHEN country IS NULL THEN 1 ELSE 0 END) AS null_country_count,
    SUM(CASE WHEN status IS NULL THEN 1 ELSE 0 END) AS null_status_count,
    SUM(CASE WHEN created_at IS NULL THEN 1 ELSE 0 END) AS null_created_at_count,

    ROUND(
        SUM(CASE WHEN org_id IS NULL THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0)
    , 2) AS null_org_id_pct,

    ROUND(
        SUM(CASE WHEN org_name IS NULL THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0)
    , 2) AS null_org_name_pct,

    ROUND(
        SUM(CASE WHEN country IS NULL THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0)
    , 2) AS null_country_pct,

    ROUND(
        SUM(CASE WHEN status IS NULL THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0)
    , 2) AS null_status_pct,

    ROUND(
        SUM(CASE WHEN created_at IS NULL THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0)
    , 2) AS null_created_at_pct

FROM enterprise_raw.organizations;



-- =====================================================
-- FINDINGS
-- =====================================================
-- Summary:
-- Organization name completeness issue detected affecting 2% of records.
--
-- Details:
-- 299 out of 15,000 organizations have NULL org_name values, while all
-- other critical attributes show full completeness.
--
-- Impact:
-- Missing organization names may impact entity identification,
-- segmentation, and downstream reporting accuracy.
--
-- Recommendation:
-- Investigate upstream data capture processes and enforce org_name
-- as a mandatory attribute.
--
-- =====================================================




-- =====================================================
-- SECTION 3: Uniqueness analysis
-- =====================================================

-- Description:
-- Evaluate uniqueness of organization identifiers.
--
-- Purpose:
-- Ensure entity integrity and validate 1-row-per-organization assumption.
--
-- =====================================================


-- Query 1:
-- Compare total rows vs distinct org_id

SELECT 
	COUNT(*) AS total_rows,
    COUNT(DISTINCT org_id) AS distinct_org_id
FROM
	enterprise_raw.organizations;


-- Query 2:
-- Identify duplicate org_id values

SELECT
	org_id,
	COUNT(*) AS duplicate_count
FROM enterprise_raw.organizations
GROUP BY org_id
HAVING COUNT(*) > 1;

-- =====================================================
-- FINDINGS
-- =====================================================
-- Summary:
-- org_id is fully unique. No duplicate values detected.
--
-- Details:
-- Total row count matches distinct org_id count, and
-- duplicate detection query returned 0 records.
--
-- Impact:
-- org_id can be safely used as primary identifier for joins,
-- aggregations, and downstream reporting without risk of duplication.
--
-- Recommendation:
-- No remediation required. Maintain uniqueness validation as part
-- of ongoing Data Quality monitoring.
--
-- =====================================================

-- Uniqueness (business key)

-- Query 1:
-- Compare total rows vs distinct tax_id

SELECT 
	COUNT(*) AS total_rows,
	COUNT(tax_id) AS non_null_tax_id_rows,
    COUNT(DISTINCT tax_id) AS distinct_tax_id
FROM
	enterprise_raw.organizations;


-- Query 2:
-- Identify duplicate org_id values

SELECT
    tax_id,
    COUNT(*) AS duplicate_count
FROM enterprise_raw.organizations
WHERE tax_id IS NOT NULL
GROUP BY tax_id
HAVING COUNT(*) > 1;


-- =====================================================
-- FINDINGS
-- =====================================================
-- Summary:
-- tax_id is unique among populated values but has completeness issues.
--
-- Details:
-- 11,248 unique tax_id values exist, with remaining records containing NULL tax_id.
-- No duplicate tax_id values detected among non-null records.
--
-- Impact:
-- tax_id can be used as a unique identifier where present, but NULL values
-- limit its coverage across the full dataset.
--
-- Recommendation:
-- Improve upstream capture of tax_id and evaluate whether it should be
-- mandatory for all organizations.
--
-- =====================================================



-- =====================================================
-- SECTION 4: Duplicate detection
-- =====================================================

-- Description:
-- Detect potential duplicate organizations based on
-- business attributes rather than system identifier.
--
-- Purpose:
-- Identify multiple records that may represent the same
-- real-world organization despite having different org_id.
--
-- Notes:
-- Focus on attributes commonly used for entity identification.
--
-- =====================================================


-- Query 1:
-- Baseline comparison for business key combination

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (org_name, country)) AS distinct_org_name_country
FROM enterprise_raw.organizations;


-- =====================================================
-- FINDINGS
-- =====================================================
-- Summary:
-- Severe organization duplication detected based on org_name and country.
--
-- Details:
-- Only 182 unique organization name and country combinations exist
-- across 15,000 records, indicating extensive duplication of entities.
--
-- Impact:
-- Multiple org_id values likely represent the same real-world organization,
-- which can lead to entity fragmentation, inaccurate reporting, and
-- incorrect risk aggregation.
--
-- Recommendation:
-- Entity resolution and deduplication processes should be implemented.
-- org_name and country alone are insufficient to uniquely identify organizations.
--
-- =====================================================


-- Query 2:
-- Duplicate detection using business key attributes

SELECT
    org_name,
    country,
    COUNT(*) AS duplicate_count
FROM enterprise_raw.organizations
WHERE org_name IS NOT NULL
  AND country IS NOT NULL
GROUP BY org_name, country
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;


-- =====================================================
-- FINDINGS
-- =====================================================
-- Summary:
-- Organization duplication driven by inconsistent country formatting.
--
-- Details:
-- Multiple variations of country values (e.g., "UK", "U.K.", "CR",
-- "costa rica", "DE", "de", "U.S.", "united states") are associated
-- with the same organization names, creating artificial entity duplication.
--
-- Impact:
-- Lack of country standardization causes entity fragmentation,
-- leading to incorrect organization counts, inaccurate aggregation,
-- and unreliable reporting.
--
-- Recommendation:
-- Implement country normalization using ISO country codes and
-- apply standardization rules before entity matching or reporting.
--
-- =====================================================




-- =====================================================
-- SECTION 5: Referential integrity (parent_org_id)
-- =====================================================

-- Description:
-- Validate parent-child relationships within organizations table.
--
-- Purpose:
-- Identify orphan parent_org_id values that do not reference
-- a valid organization.
--
-- =====================================================


--Query 1 - KPI
-- Show the total orphans.
SELECT 
    COUNT(*) AS orphan_parent_org_count
FROM enterprise_raw.organizations p
LEFT JOIN enterprise_raw.organizations o
    ON p.parent_org_id = o.org_id
WHERE o.org_id IS NULL
  AND p.parent_org_id IS NOT NULL;


-- Query 2 - Breakdown
--Show the orphan parent_org_id for root cause analysis.
SELECT 
    p.parent_org_id
FROM enterprise_raw.organizations p
LEFT JOIN enterprise_raw.organizations o
    ON p.parent_org_id = o.org_id
WHERE o.org_id IS NULL
  AND p.parent_org_id IS NOT NULL;



-- =====================================================
-- FINDINGS
-- =====================================================
-- Summary:
-- No referential integrity issues detected in organization hierarchy.
--
-- Details:
-- All parent_org_id values successfully reference a valid org_id,
-- and no orphan parent-child relationships were found.
--
-- Impact:
-- Organizational hierarchy structure is reliable and can be safely
-- used for rollups, group reporting, and hierarchical analysis.
--
-- Recommendation:
-- No remediation required. Continue monitoring as part of ongoing
-- data quality controls.
--
-- =====================================================
