-- ============================================================================
-- MIGRATION: Add Email, Alternate Mobile, and Payment Plan details
-- Execute this script in your Supabase SQL Editor if columns are not yet present
-- ============================================================================

-- 1. Ensure columns exist on customers table
ALTER TABLE customers ADD COLUMN IF NOT EXISTS email VARCHAR(255);
ALTER TABLE customers ADD COLUMN IF NOT EXISTS alternate_mobile VARCHAR(20);
ALTER TABLE customers ADD COLUMN IF NOT EXISTS alt_mobile VARCHAR(20);
ALTER TABLE customers ADD COLUMN IF NOT EXISTS payment_period VARCHAR(50) DEFAULT 'weekly';
ALTER TABLE customers ADD COLUMN IF NOT EXISTS billing_cycle VARCHAR(50) DEFAULT 'WEEKLY';

-- 2. Ensure billing_cycle exists on customer_subscriptions table
ALTER TABLE customer_subscriptions ADD COLUMN IF NOT EXISTS billing_cycle VARCHAR(50) DEFAULT 'weekly';
