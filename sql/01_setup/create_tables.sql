-- =====================================================
-- Project: Enterprise Data Quality Lab
-- File: create_tables.sql
-- Author: Dylan Blandino
-- Created: 2026-02-23
--
-- Description:
-- This script creates the core tables in the enterprise_raw
-- schema. These tables store raw data imported from source systems.
--
-- Tables included:
-- - organizations
-- - contacts
-- - contact_roles
-- - interactions
-- - source_vendor_contacts
--
-- Notes:
-- No constraints are applied at this stage.
-- This layer reflects raw source data.
--
-- =====================================================



-- =====================================================
-- SECTION 1: Create organizations table
-- =====================================================

CREATE TABLE enterprise_raw.organizations (
    org_id VARCHAR(20),
    org_name TEXT,
    legal_name TEXT,
    registration_number VARCHAR(50),
    tax_id VARCHAR(50),
    country TEXT,
    region TEXT,
    org_type TEXT,
    industry TEXT,
    status TEXT,
    parent_org_id VARCHAR(20),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- =====================================================
-- SECTION 2: Create contacts table
-- =====================================================

CREATE TABLE enterprise_raw.contacts (
    contact_id VARCHAR(20),
    org_id VARCHAR(20),
    first_name TEXT,
    last_name TEXT,
    full_name TEXT,
    email TEXT,
    phone TEXT,
    job_title TEXT,
    seniority_level TEXT,
    country TEXT,
    status TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- =====================================================
-- SECTION 3: Create contact_roles table
-- =====================================================

CREATE TABLE enterprise_raw.contact_roles (
    contact_id VARCHAR(20),
    org_id VARCHAR(20),
    role_type TEXT,
    start_date DATE,
    end_date DATE,
    is_primary BOOLEAN
);

-- =====================================================
-- SECTION 4: Create interactions table
-- =====================================================

CREATE TABLE enterprise_raw.interactions (
    interaction_id VARCHAR(20),
    contact_id VARCHAR(20),
    org_id VARCHAR(20),
    interaction_type TEXT,
    interaction_date DATE,
    channel TEXT,
    region TEXT,
    created_by TEXT
);

-- =====================================================
-- SECTION 5: Create source_vendor_contacts table
-- =====================================================

CREATE TABLE enterprise_raw.source_vendor_contacts (
    vendor_contact_id VARCHAR(20),
    full_name TEXT,
    email TEXT,
    country TEXT,
    job_title TEXT,
    status TEXT
);
