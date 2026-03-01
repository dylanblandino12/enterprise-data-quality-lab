-- =====================================================
-- Project: Enterprise Data Quality Lab
-- File: scorecard_organizations.sql
-- Author: Dylan Blandino
-- Created: 2026-02-23
--
-- Description:
-- Data Quality scorecard for enterprise_raw.organizations.
--
-- Output:
-- One row per DQ rule with KPI metrics.
-- =====================================================

WITH total_organizations AS (

    SELECT COUNT(*) AS total_records
    FROM enterprise_raw.organizations

),

rule_results AS (

    -- RULE 1: Missing org_name
    SELECT
        'DQ_ORG_001' AS dq_rule_id,
        'Missing org_name' AS rule_name,
        COUNT(*) AS failed_records
    FROM enterprise_raw.organizations
    WHERE org_name IS NULL


    UNION ALL


    -- RULE 2: Missing tax_id
    SELECT
        'DQ_ORG_002',
        'Missing tax_id',
        COUNT(*)
    FROM enterprise_raw.organizations
    WHERE tax_id IS NULL


    UNION ALL


    -- RULE 3: Invalid country format
    SELECT
        'DQ_ORG_003',
        'Invalid country format',
        COUNT(*)
    FROM enterprise_raw.organizations
    WHERE country IS NOT NULL
      AND (
            LENGTH(country) > 2
         OR country LIKE '%.%'
         OR country LIKE '%,%'
         OR country <> UPPER(country)
      )


    UNION ALL


    -- RULE 4: Duplicate org_name + country
    SELECT
        'DQ_ORG_004',
        'Duplicate organization',
        COUNT(*)
    FROM (
        SELECT
            COUNT(*) OVER (
                PARTITION BY org_name, country
            ) AS duplicate_count
        FROM enterprise_raw.organizations
        WHERE org_name IS NOT NULL
          AND country IS NOT NULL
    ) t
    WHERE duplicate_count > 1


    UNION ALL


    -- RULE 5: Invalid parent_org_id
    SELECT
        'DQ_ORG_005',
        'Invalid parent_org_id',
        COUNT(*)
    FROM enterprise_raw.organizations p
    LEFT JOIN enterprise_raw.organizations o
        ON p.parent_org_id = o.org_id
    WHERE o.org_id IS NULL
      AND p.parent_org_id IS NOT NULL

)

SELECT

    r.dq_rule_id,
    r.rule_name,
    t.total_records,
    r.failed_records,

    ROUND(
        1 - (r.failed_records::NUMERIC / NULLIF(t.total_records, 0)),
        4
    ) AS pass_rate,

    ROUND(
        r.failed_records::NUMERIC / NULLIF(t.total_records, 0),
        4
    ) AS fail_rate

FROM rule_results r
CROSS JOIN total_organizations t

ORDER BY r.dq_rule_id;
