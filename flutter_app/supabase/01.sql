-- ============================================================================
-- MILK DELIVERY MANAGEMENT SYSTEM - COMPLETE FIXED SUPABASE DATABASE SCHEMA
-- Execute this script inside your Supabase SQL Editor
-- ============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- 2. DROP CONFLICTING LEGACY TABLES (CASCADE) TO PREVENT TYPE MISMATCH ERRORS
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS cms_gallery CASCADE;
DROP TABLE IF EXISTS cms_enquiries CASCADE;
DROP TABLE IF EXISTS cms_products CASCADE;
DROP TABLE IF EXISTS notification_recipients CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS milk_stock_transactions CASCADE;
DROP TABLE IF EXISTS milk_stock CASCADE;
DROP TABLE IF EXISTS deposit_transactions CASCADE;
DROP TABLE IF EXISTS deposits CASCADE;
DROP TABLE IF EXISTS ice_box_allocations CASCADE;
DROP TABLE IF EXISTS ice_boxes CASCADE;
DROP TABLE IF EXISTS bottle_allocations CASCADE;
DROP TABLE IF EXISTS glass_bottles CASCADE;
DROP TABLE IF EXISTS settlements CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS invoices CASCADE;
DROP TABLE IF EXISTS delivery_items CASCADE;
DROP TABLE IF EXISTS deliveries CASCADE;
DROP TABLE IF EXISTS delivery_routes CASCADE;
DROP TABLE IF EXISTS delivery_assignments CASCADE;
DROP TABLE IF EXISTS milk_allocation_items CASCADE;
DROP TABLE IF EXISTS milk_allocations CASCADE;
DROP TABLE IF EXISTS cancellation_requests CASCADE;
DROP TABLE IF EXISTS delivery_timings CASCADE;
DROP TABLE IF EXISTS customer_subscriptions CASCADE;
DROP TABLE IF EXISTS customer_locations CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS milk_rate_history CASCADE;
DROP TABLE IF EXISTS milk_rates CASCADE;
DROP TABLE IF EXISTS milk_products CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;
DROP TABLE IF EXISTS roles CASCADE;

-- 3. ENUM TYPES
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM (
        'SUPER_ADMIN', 'ADMIN', 'ACCOUNTS_STAFF', 'DELIVERY_MANAGER', 
        'DELIVERY_PERSON', 'CUSTOMER', 'CONTENT_MANAGER'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE account_status AS ENUM ('ACTIVE', 'INACTIVE', 'SUSPENDED');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE payment_status_enum AS ENUM ('PAID', 'PARTIAL', 'PENDING', 'OVERDUE');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE payment_method_enum AS ENUM ('CASH', 'UPI', 'BANK_TRANSFER', 'ONLINE', 'OTHER');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE cancellation_status AS ENUM ('REQUESTED', 'APPROVED', 'REJECTED', 'COMPLETED', 'EXPIRED');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE delivery_status_enum AS ENUM ('SCHEDULED', 'ASSIGNED', 'PREPARING', 'OUT_FOR_DELIVERY', 'NEAR_CUSTOMER', 'DELIVERED', 'FAILED', 'CANCELLED');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE settlement_status_enum AS ENUM ('PENDING', 'PARTIALLY_SETTLED', 'SETTLED', 'DIFFERENCE');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE asset_condition AS ENUM ('EXCELLENT', 'GOOD', 'FAIR', 'DAMAGED', 'LOST', 'MAINTENANCE', 'CLEANING');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE asset_status AS ENUM ('AVAILABLE', 'ALLOCATED', 'RETURNED', 'DAMAGED', 'LOST', 'MAINTENANCE', 'CLEANING');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE enquiry_status AS ENUM ('NEW', 'CONTACTED', 'FOLLOW_UP', 'CONVERTED', 'CLOSED', 'REJECTED');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- 4. USER ROLES & PROFILES
CREATE TABLE roles (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    role_name user_role UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO roles (role_name, description) VALUES
('SUPER_ADMIN', 'Full system access across all tenants and operations'),
('ADMIN', 'Administrative access to manage operations, customers, staff'),
('ACCOUNTS_STAFF', 'Access to payments, settlements, and billing reports'),
('DELIVERY_MANAGER', 'Manages daily routes, allocations, and delivery partners'),
('DELIVERY_PERSON', 'Mobile delivery partner managing daily route and collections'),
('CUSTOMER', 'Mobile app customer managing subscriptions and payments'),
('CONTENT_MANAGER', 'Website CMS editor')
ON CONFLICT (role_name) DO NOTHING;

CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(15) NOT NULL,
    user_role user_role NOT NULL DEFAULT 'CUSTOMER',
    account_status account_status DEFAULT 'ACTIVE',
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. EMPLOYEES (Delivery Partners, Staff, Managers)
CREATE TABLE employees (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    employee_id VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    mobile VARCHAR(15) NOT NULL,
    address TEXT,
    profile_photo TEXT,
    employee_type user_role NOT NULL DEFAULT 'DELIVERY_PERSON',
    joining_date DATE NOT NULL DEFAULT CURRENT_DATE,
    assigned_area VARCHAR(100),
    login_id VARCHAR(50) UNIQUE NOT NULL,
    vehicle_number VARCHAR(50),
    status account_status DEFAULT 'ACTIVE',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 6. MILK PRODUCTS & RATE HISTORY
CREATE TABLE milk_products (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    milk_type VARCHAR(50) NOT NULL,
    description TEXT,
    rate_per_liter DECIMAL(10,2) NOT NULL,
    image_url TEXT,
    status account_status DEFAULT 'ACTIVE',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE milk_rates (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    milk_product_id VARCHAR(50) REFERENCES milk_products(id) ON DELETE CASCADE,
    rate DECIMAL(10,2) NOT NULL,
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE,
    created_by VARCHAR(50) REFERENCES employees(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE milk_rate_history (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    milk_product_id VARCHAR(50) REFERENCES milk_products(id) ON DELETE CASCADE,
    old_rate DECIMAL(10,2) NOT NULL,
    new_rate DECIMAL(10,2) NOT NULL,
    modified_by VARCHAR(50) REFERENCES employees(id),
    modified_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    reason TEXT
);

-- 7. CUSTOMERS & LOCATION GEOMETRY (PostGIS)
CREATE TABLE customers (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    customer_id VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    mobile VARCHAR(15) NOT NULL,
    password VARCHAR(255),
    address TEXT NOT NULL,
    location VARCHAR(100) NOT NULL,
    latitude DECIMAL(10,8) NOT NULL,
    longitude DECIMAL(11,8) NOT NULL,
    geom GEOMETRY(Point, 4326),
    milk_product_id VARCHAR(50) REFERENCES milk_products(id),
    milk_quantity DECIMAL(5,2) NOT NULL DEFAULT 1.00,
    delivery_timing VARCHAR(50) NOT NULL DEFAULT '6:00 AM - 7:00 AM',
    assigned_delivery_person_id VARCHAR(50) REFERENCES employees(id),
    payment_status payment_status_enum DEFAULT 'PENDING',
    account_status account_status DEFAULT 'ACTIVE',
    monthly_rate DECIMAL(10,2) DEFAULT 1950.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE customer_locations (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    customer_id VARCHAR(50) REFERENCES customers(id) ON DELETE CASCADE,
    address TEXT NOT NULL,
    pincode VARCHAR(10) NOT NULL,
    area VARCHAR(100) NOT NULL,
    city VARCHAR(100) NOT NULL DEFAULT 'Chennai',
    district VARCHAR(100) NOT NULL DEFAULT 'Chennai',
    state VARCHAR(100) NOT NULL DEFAULT 'Tamil Nadu',
    latitude DECIMAL(10,8) NOT NULL,
    longitude DECIMAL(11,8) NOT NULL,
    geom GEOMETRY(Point, 4326),
    is_primary BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE customer_subscriptions (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    customer_id VARCHAR(50) REFERENCES customers(id) ON DELETE CASCADE,
    milk_product_id VARCHAR(50) REFERENCES milk_products(id),
    daily_quantity DECIMAL(5,2) NOT NULL,
    delivery_days VARCHAR(50) DEFAULT 'Monday-Sunday',
    timing_slot VARCHAR(50) NOT NULL DEFAULT '6:00 AM - 7:00 AM',
    start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date DATE,
    status account_status DEFAULT 'ACTIVE',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 8. DELIVERY TIMING ALLOCATION
CREATE TABLE delivery_timings (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    customer_id VARCHAR(50) REFERENCES customers(id) ON DELETE CASCADE,
    delivery_person_id VARCHAR(50) REFERENCES employees(id),
    delivery_area VARCHAR(100) NOT NULL,
    delivery_days VARCHAR(50) NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    priority INT DEFAULT 1,
    effective_from DATE NOT NULL,
    effective_until DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 9. CANCELLATION REQUESTS
CREATE TABLE cancellation_requests (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    customer_id VARCHAR(50) REFERENCES customers(id) ON DELETE CASCADE,
    cancellation_date DATE NOT NULL,
    end_date DATE,
    cancellation_day VARCHAR(20),
    start_time TIME,
    end_time TIME,
    reason TEXT,
    approval_status cancellation_status DEFAULT 'REQUESTED',
    approved_by VARCHAR(50) REFERENCES employees(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 10. MILK ALLOCATIONS & ITEMS
CREATE TABLE milk_allocations (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    delivery_person_id VARCHAR(50) REFERENCES employees(id) ON DELETE CASCADE,
    allocation_date DATE NOT NULL DEFAULT CURRENT_DATE,
    route_name VARCHAR(100) NOT NULL,
    total_customers INT NOT NULL DEFAULT 0,
    total_required_liters DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    milk_issued_liters DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    milk_delivered_liters DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    milk_returned_liters DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    wastage_liters DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    status VARCHAR(20) DEFAULT 'ISSUED',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE milk_allocation_items (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    allocation_id VARCHAR(50) REFERENCES milk_allocations(id) ON DELETE CASCADE,
    customer_id VARCHAR(50) REFERENCES customers(id) ON DELETE CASCADE,
    milk_product_id VARCHAR(50) REFERENCES milk_products(id),
    quantity DECIMAL(5,2) NOT NULL,
    is_cancelled BOOLEAN DEFAULT FALSE,
    delivery_status delivery_status_enum DEFAULT 'SCHEDULED',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 11. DELIVERIES & ROUTES
CREATE TABLE delivery_assignments (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    delivery_person_id VARCHAR(50) REFERENCES employees(id) ON DELETE CASCADE,
    customer_id VARCHAR(50) REFERENCES customers(id) ON DELETE CASCADE,
    sequence_order INT NOT NULL DEFAULT 1,
    assigned_date DATE NOT NULL DEFAULT CURRENT_DATE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE delivery_routes (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    delivery_person_id VARCHAR(50) REFERENCES employees(id) ON DELETE CASCADE,
    route_date DATE NOT NULL DEFAULT CURRENT_DATE,
    route_name VARCHAR(100) NOT NULL,
    total_distance_km DECIMAL(8,2) DEFAULT 0.00,
    estimated_time_minutes INT DEFAULT 0,
    waypoints_json JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE deliveries (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    customer_id VARCHAR(50) REFERENCES customers(id) ON DELETE CASCADE,
    delivery_person_id VARCHAR(50) REFERENCES employees(id),
    delivery_date DATE NOT NULL DEFAULT CURRENT_DATE,
    milk_product_id VARCHAR(50) REFERENCES milk_products(id),
    quantity DECIMAL(5,2) NOT NULL,
    rate_per_liter DECIMAL(10,2) NOT NULL,
    total_amount DECIMAL(10,2) GENERATED ALWAYS AS (quantity * rate_per_liter) STORED,
    delivery_status delivery_status_enum DEFAULT 'SCHEDULED',
    delivery_time TIMESTAMP WITH TIME ZONE,
    otp_code VARCHAR(6),
    photo_proof_url TEXT,
    signature_url TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE delivery_items (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    delivery_id VARCHAR(50) REFERENCES deliveries(id) ON DELETE CASCADE,
    item_name VARCHAR(100) NOT NULL,
    quantity DECIMAL(5,2) NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 12. INVOICES & PAYMENTS
CREATE TABLE invoices (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    invoice_number VARCHAR(50) UNIQUE NOT NULL,
    customer_id VARCHAR(50) REFERENCES customers(id) ON DELETE CASCADE,
    billing_period VARCHAR(50) NOT NULL,
    total_milk_amount DECIMAL(10,2) NOT NULL,
    other_charges DECIMAL(10,2) DEFAULT 0.00,
    discount DECIMAL(10,2) DEFAULT 0.00,
    total_amount DECIMAL(10,2) NOT NULL,
    paid_amount DECIMAL(10,2) DEFAULT 0.00,
    pending_amount DECIMAL(10,2) NOT NULL,
    due_date DATE NOT NULL,
    status payment_status_enum DEFAULT 'PENDING',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE payments (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    customer_id VARCHAR(50) REFERENCES customers(id) ON DELETE CASCADE,
    invoice_number VARCHAR(50) NOT NULL,
    billing_period VARCHAR(50) NOT NULL,
    total_milk_amount DECIMAL(10,2) NOT NULL,
    other_charges DECIMAL(10,2) DEFAULT 0.00,
    discount DECIMAL(10,2) DEFAULT 0.00,
    total_amount DECIMAL(10,2) NOT NULL,
    paid_amount DECIMAL(10,2) DEFAULT 0.00,
    pending_amount DECIMAL(10,2) NOT NULL,
    payment_date DATE DEFAULT CURRENT_DATE,
    payment_method payment_method_enum DEFAULT 'CASH',
    payment_status payment_status_enum DEFAULT 'PENDING',
    reference_number VARCHAR(100),
    collected_by VARCHAR(50) REFERENCES employees(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 13. SETTLEMENTS
CREATE TABLE settlements (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    delivery_person_id VARCHAR(50) REFERENCES employees(id) ON DELETE CASCADE,
    collection_date DATE NOT NULL DEFAULT CURRENT_DATE,
    total_collection DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    amount_submitted DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    balance_variance DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    settlement_status settlement_status_enum DEFAULT 'PENDING',
    notes TEXT,
    verified_by VARCHAR(50) REFERENCES employees(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 14. GLASS BOTTLES & ICE BOXES
CREATE TABLE glass_bottles (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    bottle_code VARCHAR(30) UNIQUE NOT NULL,
    size VARCHAR(20) NOT NULL,
    condition asset_condition DEFAULT 'GOOD',
    status asset_status DEFAULT 'AVAILABLE',
    assigned_customer_id VARCHAR(50) REFERENCES customers(id) ON DELETE SET NULL,
    assigned_delivery_person_id VARCHAR(50) REFERENCES employees(id) ON DELETE SET NULL,
    deposit_per_unit DECIMAL(10,2) DEFAULT 300.00,
    issue_date DATE,
    return_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE bottle_allocations (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    bottle_id VARCHAR(50) REFERENCES glass_bottles(id) ON DELETE CASCADE,
    customer_id VARCHAR(50) REFERENCES customers(id) ON DELETE CASCADE,
    delivery_person_id VARCHAR(50) REFERENCES employees(id),
    issued_count INT DEFAULT 1,
    returned_count INT DEFAULT 0,
    damaged_count INT DEFAULT 0,
    lost_count INT DEFAULT 0,
    allocation_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE ice_boxes (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    ice_box_code VARCHAR(30) UNIQUE NOT NULL,
    size_type VARCHAR(50) NOT NULL,
    condition asset_condition DEFAULT 'GOOD',
    status asset_status DEFAULT 'AVAILABLE',
    assigned_customer_id VARCHAR(50) REFERENCES customers(id) ON DELETE SET NULL,
    assigned_delivery_person_id VARCHAR(50) REFERENCES employees(id) ON DELETE SET NULL,
    deposit_amount DECIMAL(10,2) DEFAULT 600.00,
    issue_date DATE,
    return_date DATE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE ice_box_allocations (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    ice_box_id VARCHAR(50) REFERENCES ice_boxes(id) ON DELETE CASCADE,
    customer_id VARCHAR(50) REFERENCES customers(id) ON DELETE CASCADE,
    delivery_person_id VARCHAR(50) REFERENCES employees(id),
    issued_count INT DEFAULT 1,
    returned_count INT DEFAULT 0,
    damaged_count INT DEFAULT 0,
    lost_count INT DEFAULT 0,
    allocation_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 15. DEPOSITS LEDGER
CREATE TABLE deposits (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    customer_id VARCHAR(50) REFERENCES customers(id) ON DELETE CASCADE,
    asset_type VARCHAR(50) NOT NULL,
    asset_id VARCHAR(50),
    quantity INT NOT NULL DEFAULT 1,
    deposit_per_unit DECIMAL(10,2) NOT NULL,
    total_deposit DECIMAL(10,2) NOT NULL,
    deposit_paid DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    deposit_refund DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    balance DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    deposit_status VARCHAR(20) DEFAULT 'ACTIVE',
    transaction_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE deposit_transactions (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    deposit_id VARCHAR(50) REFERENCES deposits(id) ON DELETE CASCADE,
    customer_id VARCHAR(50) REFERENCES customers(id) ON DELETE CASCADE,
    transaction_type VARCHAR(20) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    payment_method payment_method_enum DEFAULT 'CASH',
    remarks TEXT,
    processed_by VARCHAR(50) REFERENCES employees(id),
    transaction_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 16. MILK STOCK & INVENTORY
CREATE TABLE milk_stock (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    stock_date DATE UNIQUE NOT NULL DEFAULT CURRENT_DATE,
    opening_stock DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    milk_received DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    milk_allocated DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    milk_delivered DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    milk_returned DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    wastage DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    closing_stock DECIMAL(10,2) GENERATED ALWAYS AS (opening_stock + milk_received - milk_allocated - wastage + milk_returned) STORED,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE milk_stock_transactions (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
    type VARCHAR(30) NOT NULL,
    liters DECIMAL(10,2) NOT NULL,
    supplier_or_partner VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 17. NOTIFICATIONS
CREATE TABLE notifications (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    image_url TEXT,
    target_type VARCHAR(50) NOT NULL DEFAULT 'ALL',
    target_group VARCHAR(100),
    priority VARCHAR(20) DEFAULT 'NORMAL',
    expiry_date DATE,
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(50) REFERENCES employees(id)
);

CREATE TABLE notification_recipients (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    notification_id VARCHAR(50) REFERENCES notifications(id) ON DELETE CASCADE,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 18. WEBSITE CMS
CREATE TABLE cms_products (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    image_url TEXT,
    is_featured BOOLEAN DEFAULT FALSE,
    is_available BOOLEAN DEFAULT TRUE,
    status account_status DEFAULT 'ACTIVE',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE cms_enquiries (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    name VARCHAR(100) NOT NULL,
    mobile VARCHAR(15) NOT NULL,
    email VARCHAR(100),
    product_interest VARCHAR(100),
    message TEXT,
    enquiry_date DATE DEFAULT CURRENT_DATE,
    source VARCHAR(50) DEFAULT 'WEBSITE',
    status enquiry_status DEFAULT 'NEW',
    assigned_staff_id VARCHAR(50) REFERENCES employees(id),
    follow_up_date DATE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE cms_gallery (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    title VARCHAR(150) NOT NULL,
    description TEXT,
    image_url TEXT NOT NULL,
    category VARCHAR(50) DEFAULT 'Products',
    display_order INT DEFAULT 0,
    is_visible BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 19. AUDIT LOGS
CREATE TABLE audit_logs (
    id VARCHAR(50) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    action VARCHAR(100) NOT NULL,
    module VARCHAR(50) NOT NULL,
    record_id VARCHAR(100),
    performed_by VARCHAR(100) NOT NULL,
    details JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 20. DATABASE TRIGGERS & SPATIAL FUNCTIONS
CREATE OR REPLACE FUNCTION update_customer_geom()
RETURNS TRIGGER AS $$
BEGIN
    NEW.geom = ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_customer_geom
BEFORE INSERT OR UPDATE OF latitude, longitude ON customers
FOR EACH ROW EXECUTE FUNCTION update_customer_geom();

CREATE OR REPLACE FUNCTION calculate_required_milk_for_partner(p_partner_id VARCHAR(50), p_date DATE)
RETURNS DECIMAL(10,2) AS $$
DECLARE
    v_total_sub DECIMAL(10,2) := 0.00;
    v_cancelled DECIMAL(10,2) := 0.00;
BEGIN
    SELECT COALESCE(SUM(milk_quantity), 0.00) INTO v_total_sub
    FROM customers
    WHERE assigned_delivery_person_id = p_partner_id AND account_status = 'ACTIVE';

    SELECT COALESCE(SUM(c.milk_quantity), 0.00) INTO v_cancelled
    FROM cancellation_requests cr
    JOIN customers c ON c.id = cr.customer_id
    WHERE c.assigned_delivery_person_id = p_partner_id
      AND cr.cancellation_date = p_date
      AND cr.approval_status = 'APPROVED';

    RETURN GREATEST(v_total_sub - v_cancelled, 0.00);
END;
$$ LANGUAGE plpgsql;

-- 21. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE settlements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Profiles read policy" ON profiles FOR SELECT USING (true);
CREATE POLICY "Profiles self update" ON profiles FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Customers full read" ON customers FOR SELECT USING (true);
CREATE POLICY "Customers self read write" ON customers FOR ALL USING (true);

CREATE POLICY "Deliveries read write policy" ON deliveries FOR ALL USING (true);
CREATE POLICY "Payments read write policy" ON payments FOR ALL USING (true);
CREATE POLICY "Settlements read write policy" ON settlements FOR ALL USING (true);

-- 22. INITIAL SEED DATA FOR DEMO & TESTING
INSERT INTO employees (id, employee_id, name, mobile, address, profile_photo, employee_type, assigned_area, login_id, vehicle_number, status)
VALUES (
    'EMP-1001',
    'EMP-1001',
    'Ramesh Kumar',
    '+91 7331152332',
    'Anna Nagar West, Chennai',
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
    'DELIVERY_PERSON',
    'Anna Nagar',
    'ramesh_dp',
    'TN-27-BA-4512 (Hero Splendor)',
    'ACTIVE'
) ON CONFLICT (employee_id) DO NOTHING;

INSERT INTO customers (id, customer_id, name, mobile, password, address, location, latitude, longitude, milk_quantity, delivery_timing, assigned_delivery_person_id, payment_status, account_status, monthly_rate)
VALUES (
    'CUST-8821',
    'CUST-8821',
    'Ramanathan Krishnan',
    '+91 98401 23456',
    'password123',
    'Flat 302, Green Park Apartments, Anna Nagar',
    'Anna Nagar West, Chennai',
    13.08270000,
    80.27070000,
    1.50,
    '6:00 AM - 7:00 AM',
    'EMP-1001',
    'PAID',
    'ACTIVE',
    1950.00
) ON CONFLICT (customer_id) DO NOTHING;

INSERT INTO payments (customer_id, invoice_number, billing_period, total_milk_amount, other_charges, discount, total_amount, paid_amount, pending_amount, payment_method, payment_status, reference_number)
VALUES (
    'CUST-8821',
    'INV-2026-08',
    'August 2026',
    1860.00,
    0.00,
    0.00,
    1860.00,
    1860.00,
    0.00,
    'UPI',
    'PAID',
    'UPI-8840123901'
) ON CONFLICT DO NOTHING;