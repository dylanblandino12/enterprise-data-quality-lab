-- =====================================================
-- Project: Enterprise Data Quality Lab
-- File: create_schemas.sql
-- Author: Dylan Blandino
-- Created: 2026-02-23
--
-- Description:
-- This script creates the database schemas used in the
-- Enterprise Data Quality Lab project.
--
-- Schemas included:
-- - enterprise_raw: raw data layer
-- - enterprise_dq: data quality results layer
-- - enterprise_reporting: reporting and dashboard layer
--
-- Notes:
-- This script should be executed before creating any tables.
--
-- =====================================================



-- =====================================================
-- SECTION 1: Create enterprise_raw schema
-- =====================================================

CREATE SCHEMA IF NOT EXISTS enterprise_raw
    AUTHORIZATION postgres;

-- =====================================================
-- SECTION 2: Create enterprise_dq schema
-- =====================================================



-- =====================================================
-- SECTION 3: Create enterprise_reporting schema
-- =====================================================
