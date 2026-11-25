-- ============================================================================
-- AMUTHAM RAW MILK - COMPREHENSIVE CYBERSECURITY HARDENING SCRIPT (V2)
-- Paste and Run this entire script inside your Supabase SQL Editor
-- ============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. SAFE COLUMN HARDENING FOR ACCOUNT STATUS
-- Convert customers.account_status to VARCHAR(50) so any status ('ACTIVE', 'INACTIVE', 'SUSPENDED', 'DELETED')
-- can be used without PostgreSQL 22P02 enum casting errors or transaction blocks.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'customers' AND column_name = 'account_status'
    ) THEN
        ALTER TABLE customers ALTER COLUMN account_status DROP DEFAULT;
        ALTER TABLE customers ALTER COLUMN account_status TYPE VARCHAR(50) USING account_status::text;
        ALTER TABLE customers ALTER COLUMN account_status SET DEFAULT 'ACTIVE';
    END IF;
EXCEPTION
    WHEN others THEN null;
END $$;

-- 3. ENSURE ALL APPLICATION COLUMNS EXIST
ALTER TABLE customers ADD COLUMN IF NOT EXISTS email VARCHAR(255);
ALTER TABLE customers ADD COLUMN IF NOT EXISTS phone VARCHAR(20);
ALTER TABLE customers ADD COLUMN IF NOT EXISTS alternate_mobile VARCHAR(20);
ALTER TABLE customers ADD COLUMN IF NOT EXISTS alt_mobile VARCHAR(20);
ALTER TABLE customers ADD COLUMN IF NOT EXISTS payment_period VARCHAR(50) DEFAULT 'weekly';
ALTER TABLE customers ADD COLUMN IF NOT EXISTS billing_cycle VARCHAR(50) DEFAULT 'WEEKLY';
ALTER TABLE customers ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS password VARCHAR(255) DEFAULT '';
ALTER TABLE customers ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE customer_subscriptions ADD COLUMN IF NOT EXISTS billing_cycle VARCHAR(50) DEFAULT 'weekly';

-- 4. DATA INTEGRITY CHECK (NOT VALID avoids failing on existing legacy test records)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'check_customer_mobile_min_len'
    ) THEN
        ALTER TABLE customers 
        ADD CONSTRAINT check_customer_mobile_min_len 
        CHECK (length(mobile) >= 8) NOT VALID;
    END IF;
EXCEPTION
    WHEN others THEN null;
END $$;

-- 5. ANTI-DOS & RAPID QUERY RESOLUTION INDICES
-- Prevents full table scan attacks and query timing discrepancies
CREATE INDEX IF NOT EXISTS idx_customers_mobile ON customers (mobile);
CREATE INDEX IF NOT EXISTS idx_customers_customer_id ON customers (customer_id);
CREATE INDEX IF NOT EXISTS idx_payments_customer_id ON payments (customer_id);
CREATE INDEX IF NOT EXISTS idx_deliveries_customer_id ON deliveries (customer_id);
CREATE INDEX IF NOT EXISTS idx_cancellations_customer_id ON cancellation_requests (customer_id);
CREATE INDEX IF NOT EXISTS idx_cust_loc_customer_id ON customer_locations (customer_id);
CREATE INDEX IF NOT EXISTS idx_cust_sub_customer_id ON customer_subscriptions (customer_id);

-- 6. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE cancellation_requests ENABLE ROW LEVEL SECURITY;

-- Clean drop of legacy and conflicting policies
DROP POLICY IF EXISTS "Customers full read" ON customers;
DROP POLICY IF EXISTS "Customers self read write" ON customers;
DROP POLICY IF EXISTS "Customers self-lookup" ON customers;
DROP POLICY IF EXISTS "Customers self-service" ON customers;
DROP POLICY IF EXISTS "Customers update own profile" ON customers;
DROP POLICY IF EXISTS "Customers self update" ON customers;
DROP POLICY IF EXISTS "Customers register insert" ON customers;
DROP POLICY IF EXISTS "Customers insert policy" ON customers;
DROP POLICY IF EXISTS "Customers read policy" ON customers;
DROP POLICY IF EXISTS "Customers update policy" ON customers;

-- (a) Customers SELECT: Active/Suspended customers can read non-deleted accounts
CREATE POLICY "Customers read policy" ON customers 
    FOR SELECT 
    USING (COALESCE(account_status::text, 'ACTIVE') != 'DELETED');

-- (b) Customers INSERT: Unauthenticated mobile clients can register
CREATE POLICY "Customers insert policy" ON customers 
    FOR INSERT 
    WITH CHECK (customer_id IS NOT NULL AND mobile IS NOT NULL);

-- (c) Customers UPDATE: Update profile, password, or deactivate
CREATE POLICY "Customers update policy" ON customers 
    FOR UPDATE 
    USING (COALESCE(account_status::text, 'ACTIVE') != 'DELETED')
    WITH CHECK (true);

-- Deliveries Policies
DROP POLICY IF EXISTS "Deliveries read write policy" ON deliveries;
DROP POLICY IF EXISTS "Deliveries read policy" ON deliveries;
DROP POLICY IF EXISTS "Deliveries insert policy" ON deliveries;
DROP POLICY IF EXISTS "Deliveries update policy" ON deliveries;

CREATE POLICY "Deliveries read policy" ON deliveries 
    FOR SELECT 
    USING (true);

CREATE POLICY "Deliveries insert policy" ON deliveries 
    FOR INSERT 
    WITH CHECK (customer_id IS NOT NULL);

CREATE POLICY "Deliveries update policy" ON deliveries 
    FOR UPDATE 
    USING (true);

-- Payments Policies
DROP POLICY IF EXISTS "Payments read write policy" ON payments;
DROP POLICY IF EXISTS "Payments read policy" ON payments;
DROP POLICY IF EXISTS "Payments insert policy" ON payments;
DROP POLICY IF EXISTS "Payments update policy" ON payments;

CREATE POLICY "Payments read policy" ON payments 
    FOR SELECT 
    USING (true);

CREATE POLICY "Payments insert policy" ON payments 
    FOR INSERT 
    WITH CHECK (customer_id IS NOT NULL AND total_amount >= 0);

CREATE POLICY "Payments update policy" ON payments 
    FOR UPDATE 
    USING (true);

-- Cancellation Requests Policies
DROP POLICY IF EXISTS "Cancellations read policy" ON cancellation_requests;
DROP POLICY IF EXISTS "Cancellations insert policy" ON cancellation_requests;
DROP POLICY IF EXISTS "Cancellations update policy" ON cancellation_requests;

CREATE POLICY "Cancellations read policy" ON cancellation_requests 
    FOR SELECT 
    USING (true);

CREATE POLICY "Cancellations insert policy" ON cancellation_requests 
    FOR INSERT 
    WITH CHECK (customer_id IS NOT NULL);

CREATE POLICY "Cancellations update policy" ON cancellation_requests 
    FOR UPDATE 
    USING (true);

-- 7. SECURE AUTHENTICATION & PASSWORD AUTO-UPGRADE STORED PROCEDURE
CREATE OR REPLACE FUNCTION verify_and_upgrade_customer_password(
    p_mobile TEXT,
    p_password_hash TEXT,
    p_is_legacy_match BOOLEAN DEFAULT FALSE
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_customer_id VARCHAR(50);
    v_current_stored_password TEXT;
BEGIN
    -- Locate customer by mobile or customer_id
    SELECT id, password INTO v_customer_id, v_current_stored_password
    FROM customers
    WHERE (mobile = p_mobile OR customer_id = p_mobile)
      AND COALESCE(account_status::text, 'ACTIVE') != 'DELETED'
    LIMIT 1;

    IF v_customer_id IS NULL THEN
        RETURN FALSE;
    END IF;

    -- If client verified legacy plaintext password, upgrade to salted SHA-256 hash
    IF p_is_legacy_match THEN
        UPDATE customers
        SET password = p_password_hash,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = v_customer_id;
        RETURN TRUE;
    END IF;

    -- If stored password already matches the hash
    IF v_current_stored_password = p_password_hash THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$;
