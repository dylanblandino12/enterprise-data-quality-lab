-- =====================================================
-- Project: Enterprise Data Quality Lab
-- File: profiling_contacts.sql
-- Author: Dylan Blandino
-- Created: 2026-02-23
--
-- Description:
-- Data profiling analysis for enterprise_raw.contacts table.
--
-- Purpose:
-- - Understand data structure
-- - Evaluate completeness
-- - Evaluate uniqueness
-- - Identify integrity issues
--
-- Notes:
-- This script contains exploratory queries only.
-- No data is modified.
--
-- =====================================================


-- =====================================================
-- SECTION 1: Row count
-- =====================================================

SELECT
    'organizations' AS table_name,
    COUNT(*) AS row_count
FROM enterprise_raw.organizations

UNION ALL

SELECT
    'contacts' AS table_name,
    COUNT(*) AS row_count
FROM enterprise_raw.contacts

UNION ALL

SELECT
    'contact_roles' AS table_name,
    COUNT(*) AS row_count
FROM enterprise_raw.contact_roles

UNION ALL

SELECT
    'interactions' AS table_name,
    COUNT(*) AS row_count
FROM enterprise_raw.interactions

UNION ALL

SELECT
    'source_vendor_contacts' AS table_name,
    COUNT(*) AS row_count
FROM enterprise_raw.source_vendor_contacts;


-- =====================================================
-- SECTION 2: Completeness analysis
-- =====================================================
SELECT 
    COUNT(*) AS total_rows,

    SUM(CASE WHEN contact_id IS NULL THEN 1 ELSE 0 END) AS null_contact_id_count,
    SUM(CASE WHEN org_id IS NULL THEN 1 ELSE 0 END) AS null_org_id_count,
    SUM(CASE WHEN full_name IS NULL THEN 1 ELSE 0 END) AS null_full_name_count,
    SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END) AS null_email_count,
    SUM(CASE WHEN status IS NULL THEN 1 ELSE 0 END) AS null_status_count,
    SUM(CASE WHEN created_at IS NULL THEN 1 ELSE 0 END) AS null_created_at_count,

    ROUND(
        SUM(CASE WHEN contact_id IS NULL THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0)
    , 2) AS null_contact_id_pct,

    ROUND(
        SUM(CASE WHEN org_id IS NULL THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0)
    , 2) AS null_org_id_pct,

    ROUND(
        SUM(CASE WHEN full_name IS NULL THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0)
    , 2) AS null_full_name_pct,

    ROUND(
        SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0)
    , 3) AS null_email_pct,

    ROUND(
        SUM(CASE WHEN status IS NULL THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0)
    , 2) AS null_status_pct,

    ROUND(
        SUM(CASE WHEN created_at IS NULL THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0)
    , 2) AS null_created_at_pct

FROM enterprise_raw.contacts;

-- =====================================================
-- FINDINGS
-- =====================================================
-- Summary:
-- Email completeness issue detected affecting 3.09% of contact records.
--
-- Details:
-- 1,236 out of 40,000 contacts have NULL email values, while all other
-- critical identifier and lifecycle fields show full completeness.
--
-- Impact:
-- Missing email addresses may limit communication capabilities and reduce
-- contact usability in operational and outreach processes.
--
-- Recommendation:
-- Review upstream data capture processes and assess whether email should
-- be enforced as a mandatory field depending on business requirements.
--
-- =====================================================



-- =====================================================
-- SECTION 3: Uniqueness analysis
-- =====================================================

-- Description:
-- Evaluate uniqueness of primary identifier contact_id
-- in enterprise_raw.contacts table.
--
-- Purpose:
-- Confirm 1-row-per-contact assumption and ensure safe
-- usage in joins and downstream reporting.
--
-- =====================================================


-- Query 1: Baseline comparison
-- Compare total rows vs distinct contact_id

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT contact_id) AS distinct_contact_id
FROM enterprise_raw.contacts;



-- Query 2: Duplicate detection
-- Identify duplicate contact_id values

SELECT
    contact_id,
    COUNT(*) AS duplicate_count
FROM enterprise_raw.contacts
GROUP BY contact_id
HAVING COUNT(*) > 1;



-- =====================================================
-- FINDINGS
-- =====================================================
-- Summary:
-- contact_id is fully unique. No duplicate values detected.
--
-- Details:
-- Total row count matches distinct contact_id count, and
-- duplicate detection query returned 0 records.
--
-- Impact:
-- contact_id can be safely used as primary identifier for joins,
-- aggregations, and downstream reporting without risk of duplication.
--
-- Recommendation:
-- No remediation required. Maintain uniqueness validation as part
-- of ongoing Data Quality monitoring.
--
-- =====================================================



-- =====================================================
-- SECTION 4: Duplicate detection
-- =====================================================

-- Description:
-- Identify potential duplicate contacts based on
-- business attributes rather than system identifier.
--
-- Purpose:
-- Detect entity duplication not captured by contact_id,
-- which may indicate multiple records representing the
-- same real-world person.
--
-- Notes:
-- Focus on high-risk attributes used in communication
-- and entity identification.
--
-- =====================================================


-- Query 1: Baseline comparison (exclude NULL emails)

SELECT
    COUNT(*) AS total_rows,
    COUNT(email) AS non_null_email_rows,
    COUNT(DISTINCT email) AS unique_emails
FROM enterprise_raw.contacts;



-- Query 2: Duplicate email detection

SELECT 
    email,
    COUNT(*) AS duplicate_count
FROM enterprise_raw.contacts
WHERE email IS NOT NULL
GROUP BY email
HAVING COUNT(*) > 1;



-- =====================================================
-- FINDINGS
-- =====================================================
-- Summary:
-- High level of email duplication detected.
--
-- Details:
-- Only 96 unique email values exist across 40,000 contact records,
-- indicating extensive reuse of email addresses.
--
-- Impact:
-- Email cannot be assumed to uniquely identify a contact entity.
-- This limits its use in deduplication and identity resolution.
--
-- Recommendation:
-- Email should not be used as a sole unique identifier.
-- Consider composite keys or additional matching attributes.
--
-- =====================================================



-- Query 3: Duplicate detection using full_name and org_id

SELECT
    full_name,
    org_id,
    COUNT(*) AS duplicate_count
FROM enterprise_raw.contacts
GROUP BY full_name, org_id
HAVING COUNT(*) > 1;



-- =====================================================
-- FINDINGS
-- =====================================================
-- Summary:
-- Duplicate contact entities detected based on name and organization.
--
-- Details:
-- 1,953 duplicate combinations found across the dataset.
--
-- Impact:
-- Indicates potential duplicate contact records representing
-- the same real-world individual.
--
-- Recommendation:
-- Entity resolution and deduplication rules should be implemented.
--
-- =====================================================




-- =====================================================
-- SECTION 5: Referential integrity
-- =====================================================

--Query 1 - KPI
-- Show the total orphans.
SELECT 
    COUNT(*) AS orphan_contacts
FROM enterprise_raw.contacts c
LEFT JOIN enterprise_raw.organizations o
    ON c.org_id = o.org_id
WHERE o.org_id IS NULL;

-- Query 2 - Breakdown
--Show the orphan org_ids for root cause analysis.
SELECT
	c.org_id,
    COUNT(*) AS orphan_contacts
FROM enterprise_raw.contacts c
LEFT JOIN enterprise_raw.organizations o
    ON c.org_id = o.org_id
WHERE o.org_id IS NULL
GROUP BY c.org_id;


-- =====================================================
-- FINDINGS
-- =====================================================
-- Summary:
-- Referential integrity issue detected between contacts and organizations.
--
-- Details:
-- 615 contact records reference an org_id that does not exist
-- in the organizations table.
--
-- Impact:
-- These orphan records will fail to join with organization attributes,
-- resulting in incomplete reporting and potential data loss in analysis.
--
-- Recommendation:
-- Investigate missing organization records or invalid org_id values
-- and implement validation controls in upstream data ingestion.
--
-- =====================================================
