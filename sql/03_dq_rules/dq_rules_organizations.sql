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

-- [your query here]


-- =====================================================
-- RULE 2: Completeness — Missing tax_id
-- =====================================================

-- Description:
-- Identify organizations with NULL tax_id.

-- Query:

-- [your query here]


-- =====================================================
-- RULE 3: Consistency — Invalid country format
-- =====================================================

-- Description:
-- Identify country values that do not follow standard format.

-- Query:

-- [your query here]


-- =====================================================
-- RULE 4: Consistency — Duplicate organizations (org_name + country)
-- =====================================================

-- Description:
-- Identify duplicate organizations based on business key.

-- Query:

-- [your query here]


-- =====================================================
-- RULE 5: Referential integrity — Invalid parent_org_id
-- =====================================================

-- Description:
-- Identify orphan parent_org_id values.

-- Query:

-- [your query here]
