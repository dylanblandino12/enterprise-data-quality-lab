-- =====================================================
-- Project: Enterprise Data Quality Lab
-- File: dq_rules_organizations.sql
-- Author: Dylan Blandino
-- Created: 2026-02-23
--
-- Description:
-- Data Quality rules for enterprise_raw.organizations table.
--
-- Purpose:
-- Translate profiling findings into formal, repeatable
-- data quality validation rules.
--
-- Scope:
-- - Completeness rules
-- - Validity rules
-- - Consistency rules
-- - Referential integrity rules
--
-- Notes:
-- These queries identify failing records.
-- They do not modify data.
--
-- =====================================================



-- =====================================================
-- RULE 1: Completeness — Missing org_name
-- =====================================================

-- Description:
-- Identify organizations with NULL org_name.

-- Query:

SELECT
	'DQ_ORG_001' AS dq_rule_id,
	org_id,
	org_name,
	country,
	created_at
FROM enterprise_raw.organizations
WHERE org_name IS NULL;



-- =====================================================
-- RULE 2: Completeness — Missing tax_id
-- =====================================================

-- Description:
-- Identify organizations with NULL tax_id.

-- Query:

SELECT
	'DQ_ORG_002' AS dq_rule_id,
	org_id,
	org_name,
	tax_id,
	country,
	created_at
FROM enterprise_raw.organizations
WHERE tax_id IS NULL;	


-- =====================================================
-- RULE 3: Consistency — Invalid country format
-- =====================================================

-- Description:
-- Identify country values that do not follow standard format.

-- Query:

SELECT
    'DQ_ORG_003' AS dq_rule_id,
    org_id,
    org_name,
    country,
    created_at
FROM enterprise_raw.organizations
WHERE country IS NOT NULL
  AND (
        LENGTH(country) > 2
     OR country LIKE '%.%'
     OR country LIKE '%,%'
     OR country <> UPPER(country)
  );



-- =====================================================
-- RULE 4: Consistency — Duplicate organizations (org_name + country)
-- =====================================================

-- Description:
-- Identify duplicate organizations based on business key.

-- Query:

SELECT
    'DQ_ORG_004' AS dq_rule_id,
    org_id,
    org_name,
    country,
    created_at
FROM (

    SELECT
        org_id,
        org_name,
        country,
        created_at,
        COUNT(*) OVER (
            PARTITION BY org_name, country
        ) AS duplicate_count

    FROM enterprise_raw.organizations
    WHERE org_name IS NOT NULL
      AND country IS NOT NULL

) t

WHERE duplicate_count > 1;


-- =====================================================
-- RULE 5: Referential integrity — Invalid parent_org_id
-- =====================================================

-- Description:
-- Identify organizations whose parent_org_id does not
-- exist in the organizations table.
--
-- Query:

SELECT
	  'DQ_ORG_005' AS dq_rule_id,
    p.org_id,
	  p.parent_org_id,
    p.org_name,
    p.created_at
FROM enterprise_raw.organizations p
LEFT JOIN enterprise_raw.organizations o
	ON p.parent_org_id = o.org_id
WHERE o.org_id IS NULL
	AND p.parent_org_id IS NOT NULL;
