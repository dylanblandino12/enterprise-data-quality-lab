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

-- [your query here]


-- =====================================================
-- FINDINGS
-- =====================================================
-- Summary:
--
-- Details:
--
-- Impact:
--
-- Recommendation:
--
-- =====================================================



-- Query 2:
-- Identify duplicate org_id values

-- [your query here]


-- =====================================================
-- FINDINGS
-- =====================================================
-- Summary:
--
-- Details:
--
-- Impact:
--
-- Recommendation:
--
-- =====================================================




-- =====================================================
-- SECTION 4: Duplicate detection
-- =====================================================

-- Description:
-- Detect duplicate organizations using business attributes.
--
-- Purpose:
-- Identify entity duplication not captured by org_id.
--
-- =====================================================


-- Query 1:
-- Duplicate detection based on tax_id

-- [your query here]


-- =====================================================
-- FINDINGS
-- =====================================================
-- Summary:
--
-- Details:
--
-- Impact:
--
-- Recommendation:
--
-- =====================================================



-- Query 2:
-- Duplicate detection based on org_name and country

-- [your query here]


-- =====================================================
-- FINDINGS
-- =====================================================
-- Summary:
--
-- Details:
--
-- Impact:
--
-- Recommendation:
--
-- =====================================================




-- =====================================================
-- SECTION 5: Hierarchical integrity
-- =====================================================

-- Description:
-- Validate parent-child relationships between organizations.
--
-- Purpose:
-- Identify orphan parent_org_id values and hierarchy issues.
--
-- =====================================================


-- Query 1:
-- Identify orphan parent_org_id

-- [your query here]


-- =====================================================
-- FINDINGS
-- =====================================================
-- Summary:
--
-- Details:
--
-- Impact:
--
-- Recommendation:
--
-- =====================================================
