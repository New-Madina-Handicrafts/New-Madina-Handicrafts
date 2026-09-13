-- =============================================================================
-- NEW MADINA HANDICRAFTS — PRODUCTION DATABASE ARCHITECTURE (POSTGRESQL 15+)
-- Comprehensive, Fully Normalized, High-Performance, Scalable Schema
-- =============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- -----------------------------------------------------------------------------
-- DOMAIN ENUMS & CUSTOM TYPES
-- -----------------------------------------------------------------------------

CREATE TYPE product_status_enum AS ENUM ('draft', 'active', 'archived', 'out_of_stock');
CREATE TYPE review_status_enum AS ENUM ('pending', 'approved', 'rejected', 'archived');
CREATE TYPE contact_status_enum AS ENUM ('new', 'read', 'replied', 'archived');
CREATE TYPE order_status_enum AS ENUM ('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'returned');
CREATE TYPE payment_status_enum AS ENUM ('pending', 'paid', 'failed', 'refunded', 'cod_pending');
CREATE TYPE fulfillment_status_enum AS ENUM ('unfulfilled', 'partial', 'fulfilled', 'returned');
CREATE TYPE inventory_change_type_enum AS ENUM ('restock', 'order_deduction', 'manual_adjustment', 'return_restock', 'damaged_writeoff');
CREATE TYPE admin_role_enum AS ENUM ('super_admin', 'admin', 'manager', 'editor', 'viewer');
CREATE TYPE discount_type_enum AS ENUM ('percentage', 'fixed_amount');
CREATE TYPE setting_value_type_enum AS ENUM ('string', 'number', 'boolean', 'json');

-- -----------------------------------------------------------------------------
-- AUTOMATIC TIMESTAMP & AUDIT HELPER FUNCTIONS
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- DOMAIN 1: PRODUCT CATALOG & TAXONOMY
-- =============================================================================

-- 1. Collections (e.g. Gents Collection, Ladies Collection)
CREATE TABLE collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    tagline VARCHAR(255),
    description TEXT,
    banner_image_url VARCHAR(500),
    banner_image_md VARCHAR(500),
    banner_image_sm VARCHAR(500),
    display_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ DEFAULT NULL
);

-- 2. Categories (Hierarchical with self-referencing parent_id)
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    image_url VARCHAR(500),
    display_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ DEFAULT NULL
);

-- 3. Products
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    legacy_id VARCHAR(20) UNIQUE, -- Stores 'm2', 'm3', 'w14', etc. for seamless migration
    sku VARCHAR(100) UNIQUE,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL UNIQUE,
    collection_id UUID NOT NULL REFERENCES collections(id) ON DELETE RESTRICT,
    short_description VARCHAR(500),
    full_description TEXT,
    material VARCHAR(150),
    dimensions VARCHAR(100),
    original_price DECIMAL(12, 2) NOT NULL CHECK (original_price >= 0),
    discount_price DECIMAL(12, 2) CHECK (discount_price IS NULL OR (discount_price >= 0 AND discount_price <= original_price)),
    currency VARCHAR(3) NOT NULL DEFAULT 'PKR',
    stock_quantity INTEGER NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
    low_stock_threshold INTEGER NOT NULL DEFAULT 3 CHECK (low_stock_threshold >= 0),
    badge VARCHAR(100), -- 'Best Seller', 'New Arrival', 'Save PKR 3,000'
    is_featured BOOLEAN NOT NULL DEFAULT FALSE,
    is_best_seller BOOLEAN NOT NULL DEFAULT FALSE,
    is_new_arrival BOOLEAN NOT NULL DEFAULT FALSE,
    is_sold_out BOOLEAN NOT NULL DEFAULT FALSE,
    status product_status_enum NOT NULL DEFAULT 'active',
    meta_title VARCHAR(255),
    meta_description VARCHAR(500),
    search_vector tsvector,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ DEFAULT NULL
);

-- 4. Product Categories (Many-to-Many Junction)
CREATE TABLE product_categories (
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (product_id, category_id)
);

-- 5. Product Images (Gallery with ordering and primary badge)
CREATE TABLE product_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    image_url VARCHAR(500) NOT NULL,
    image_thumb_url VARCHAR(500),
    alt_text VARCHAR(255),
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 6. Product Variants (Color Swatches & Options)
CREATE TABLE product_variants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    sku VARCHAR(100) UNIQUE,
    color_code VARCHAR(50),
    color_name VARCHAR(100) NOT NULL,
    color_hex VARCHAR(7), -- e.g. #D4A373
    swatch_image_url VARCHAR(500),
    price_override DECIMAL(12, 2) CHECK (price_override IS NULL OR price_override >= 0),
    stock_quantity INTEGER NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
    display_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_product_variant_color UNIQUE (product_id, color_name)
);

-- 7. Product Variant Images (Dedicated gallery per color variant)
CREATE TABLE product_variant_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    variant_id UUID NOT NULL REFERENCES product_variants(id) ON DELETE CASCADE,
    image_url VARCHAR(500) NOT NULL,
    alt_text VARCHAR(255),
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 8. Product Specifications (Key-Value technical specs)
CREATE TABLE product_specifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    spec_key VARCHAR(100) NOT NULL,
    spec_value TEXT NOT NULL,
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_product_spec UNIQUE (product_id, spec_key)
);

-- 9. Product Features (Bullet list on detail page)
CREATE TABLE product_features (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    feature_text TEXT NOT NULL,
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 10. Product Care Groups & Cards
CREATE TABLE product_care_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    title VARCHAR(150) NOT NULL,
    icon VARCHAR(50), -- Emoji or icon class
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 11. Product Care Items
CREATE TABLE product_care_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    care_card_id UUID NOT NULL REFERENCES product_care_cards(id) ON DELETE CASCADE,
    instruction TEXT NOT NULL,
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- DOMAIN 2: CONTENT MANAGEMENT & STOREFRONT UI
-- =============================================================================

-- 12. Hero Slider
CREATE TABLE hero_slides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    eyebrow VARCHAR(150),
    title_main VARCHAR(255) NOT NULL,
    title_accent VARCHAR(255),
    subtitle TEXT,
    button_text VARCHAR(100),
    button_link VARCHAR(500),
    display_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 13. Hero Slide Responsive Images
CREATE TABLE hero_slide_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slide_id UUID NOT NULL REFERENCES hero_slides(id) ON DELETE CASCADE,
    image_url VARCHAR(500) NOT NULL,
    breakpoint VARCHAR(10) NOT NULL DEFAULT 'lg', -- 'lg' (desktop), 'md' (tablet), 'sm' (mobile)
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_slide_breakpoint UNIQUE (slide_id, breakpoint)
);

-- 14. Marquee Loop Statements
CREATE TABLE marquee_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content TEXT NOT NULL,
    display_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 15. Testimonials & Reviews
CREATE TABLE testimonials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_name VARCHAR(150) NOT NULL,
    customer_location VARCHAR(150),
    rating SMALLINT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review_text TEXT NOT NULL,
    review_date DATE NOT NULL DEFAULT CURRENT_DATE,
    is_featured BOOLEAN NOT NULL DEFAULT FALSE,
    is_verified_buyer BOOLEAN NOT NULL DEFAULT FALSE,
    status review_status_enum NOT NULL DEFAULT 'approved',
    admin_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 16. CMS Content Pages
CREATE TABLE pages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL UNIQUE,
    content TEXT,
    meta_title VARCHAR(255),
    meta_description VARCHAR(500),
    is_published BOOLEAN NOT NULL DEFAULT TRUE,
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- DOMAIN 3: USER & CUSTOMER MANAGEMENT
-- =============================================================================

-- 17. Admin Users (Dashboard Access)
CREATE TABLE admin_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(150) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role admin_role_enum NOT NULL DEFAULT 'editor',
    avatar_url VARCHAR(500),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 18. Customers (Future User Accounts / Registered Buyers)
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100),
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(30),
    password_hash VARCHAR(255), -- Nullable for guest buyers who haven't set a password
    is_email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    is_phone_verified BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 19. Customer Addresses
CREATE TABLE customer_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    label VARCHAR(50) DEFAULT 'Home', -- 'Home', 'Office', etc.
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100),
    phone VARCHAR(30) NOT NULL,
    address_line1 VARCHAR(255) NOT NULL,
    address_line2 VARCHAR(255),
    city VARCHAR(100) NOT NULL,
    state_province VARCHAR(100),
    postal_code VARCHAR(30),
    country VARCHAR(100) NOT NULL DEFAULT 'Pakistan',
    is_default_shipping BOOLEAN NOT NULL DEFAULT FALSE,
    is_default_billing BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- DOMAIN 4: INVENTORY & OPERATIONS
-- =============================================================================

-- 20. Inventory Audit Ledger (Immutable Change History)
CREATE TABLE inventory_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    variant_id UUID REFERENCES product_variants(id) ON DELETE CASCADE,
    quantity_change INTEGER NOT NULL, -- e.g. +20 (restock), -1 (order)
    stock_after INTEGER NOT NULL,
    change_type inventory_change_type_enum NOT NULL,
    reference_id UUID, -- order_id, whatsapp_order_id, etc.
    notes TEXT,
    created_by UUID REFERENCES admin_users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 21. Website Settings (Configurable Store Variables)
CREATE TABLE website_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    setting_key VARCHAR(100) NOT NULL UNIQUE,
    setting_value TEXT,
    setting_group VARCHAR(50) NOT NULL DEFAULT 'general',
    value_type setting_value_type_enum NOT NULL DEFAULT 'string',
    description TEXT,
    is_public BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 22. Contact Form Submissions
CREATE TABLE contact_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(150) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(30),
    subject VARCHAR(255),
    message TEXT NOT NULL,
    status contact_status_enum NOT NULL DEFAULT 'new',
    admin_notes TEXT,
    ip_address VARCHAR(45),
    user_agent TEXT,
    replied_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 23. Newsletter Subscribers
CREATE TABLE newsletter_subscribers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    source VARCHAR(50) DEFAULT 'footer',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    unsubscribed_at TIMESTAMPTZ
);

-- =============================================================================
-- DOMAIN 5: WHATSAPP ORDER MANAGEMENT & INQUIRIES
-- =============================================================================

-- 24. WhatsApp Orders
CREATE TABLE whatsapp_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number VARCHAR(50) NOT NULL UNIQUE, -- e.g. NMH-WA-20260901-001
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    customer_name VARCHAR(150) NOT NULL,
    phone VARCHAR(30) NOT NULL,
    email VARCHAR(255),
    country VARCHAR(100) DEFAULT 'Pakistan',
    city VARCHAR(100),
    shipping_address TEXT NOT NULL,
    apartment VARCHAR(100),
    postal_code VARCHAR(30),
    customer_notes TEXT,
    payment_method VARCHAR(50) NOT NULL DEFAULT 'Cash on Delivery (COD)',
    subtotal DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    shipping_cost DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    total_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    currency VARCHAR(3) NOT NULL DEFAULT 'PKR',
    status order_status_enum NOT NULL DEFAULT 'pending',
    admin_notes TEXT,
    raw_wa_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 25. WhatsApp Order Items (With Historical Snapshot Protection)
CREATE TABLE whatsapp_order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES whatsapp_orders(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id) ON DELETE SET NULL,
    variant_id UUID REFERENCES product_variants(id) ON DELETE SET NULL,
    product_name_snapshot VARCHAR(255) NOT NULL,
    sku_snapshot VARCHAR(100),
    selected_color_snapshot VARCHAR(100),
    unit_price_snapshot DECIMAL(12, 2) NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    total_price DECIMAL(12, 2) NOT NULL,
    product_url VARCHAR(500),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- DOMAIN 6: FUTURE ONLINE COMMERCE & CHECKOUT SYSTEM
-- =============================================================================

-- 26. Discount Coupons & Vouchers
CREATE TABLE coupons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    discount_type discount_type_enum NOT NULL,
    discount_value DECIMAL(12, 2) NOT NULL CHECK (discount_value > 0),
    min_order_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    max_discount_cap DECIMAL(12, 2), -- Cap for percentage discounts
    max_uses_total INTEGER,
    max_uses_per_customer INTEGER NOT NULL DEFAULT 1,
    times_used INTEGER NOT NULL DEFAULT 0,
    starts_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 27. Online Orders (Full E-Commerce)
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number VARCHAR(50) NOT NULL UNIQUE,
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    customer_email VARCHAR(255) NOT NULL,
    customer_phone VARCHAR(30) NOT NULL,
    shipping_address_id UUID REFERENCES customer_addresses(id) ON DELETE SET NULL,
    shipping_address_snapshot JSONB NOT NULL,
    billing_address_snapshot JSONB,
    coupon_id UUID REFERENCES coupons(id) ON DELETE SET NULL,
    subtotal DECIMAL(12, 2) NOT NULL,
    shipping_cost DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    discount_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    tax_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    total_amount DECIMAL(12, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'PKR',
    payment_method VARCHAR(50) NOT NULL DEFAULT 'cod',
    payment_status payment_status_enum NOT NULL DEFAULT 'pending',
    payment_gateway_ref VARCHAR(255),
    fulfillment_status fulfillment_status_enum NOT NULL DEFAULT 'unfulfilled',
    order_status order_status_enum NOT NULL DEFAULT 'pending',
    customer_notes TEXT,
    admin_notes TEXT,
    placed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    paid_at TIMESTAMPTZ,
    shipped_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 28. Online Order Line Items
CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id) ON DELETE SET NULL,
    variant_id UUID REFERENCES product_variants(id) ON DELETE SET NULL,
    product_name_snapshot VARCHAR(255) NOT NULL,
    sku_snapshot VARCHAR(100),
    selected_color_snapshot VARCHAR(100),
    unit_price_snapshot DECIMAL(12, 2) NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    total_price DECIMAL(12, 2) NOT NULL,
    thumbnail_url_snapshot VARCHAR(500),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 29. Customer Wishlists
CREATE TABLE wishlists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL DEFAULT 'My Wishlist',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 30. Customer Wishlist Items
CREATE TABLE wishlist_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wishlist_id UUID NOT NULL REFERENCES wishlists(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_wishlist_product UNIQUE (wishlist_id, product_id)
);

-- =============================================================================
-- DOMAIN 7: AUDIT LOGGING & SECURITY
-- =============================================================================

-- 31. Admin & System Audit Log (Immutable)
CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES admin_users(id) ON DELETE SET NULL,
    action VARCHAR(50) NOT NULL, -- 'create', 'update', 'delete', 'login_success', 'export'
    entity_type VARCHAR(100) NOT NULL, -- 'products', 'orders', 'website_settings'
    entity_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Revoke mutation rights on audit log to ensure compliance
REVOKE UPDATE, DELETE ON audit_log FROM PUBLIC;

-- =============================================================================
-- TRIGGERS FOR TIMESTAMPS & FULL-TEXT SEARCH
-- =============================================================================

CREATE TRIGGER trg_collections_updated_at BEFORE UPDATE ON collections FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_categories_updated_at BEFORE UPDATE ON categories FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_products_updated_at BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_product_variants_updated_at BEFORE UPDATE ON product_variants FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_hero_slides_updated_at BEFORE UPDATE ON hero_slides FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_testimonials_updated_at BEFORE UPDATE ON testimonials FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_pages_updated_at BEFORE UPDATE ON pages FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_admin_users_updated_at BEFORE UPDATE ON admin_users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_customers_updated_at BEFORE UPDATE ON customers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_customer_addresses_updated_at BEFORE UPDATE ON customer_addresses FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_website_settings_updated_at BEFORE UPDATE ON website_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_contact_submissions_updated_at BEFORE UPDATE ON contact_submissions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_whatsapp_orders_updated_at BEFORE UPDATE ON whatsapp_orders FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_coupons_updated_at BEFORE UPDATE ON coupons FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_orders_updated_at BEFORE UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Full-Text Search Vector Trigger
CREATE OR REPLACE FUNCTION products_search_vector_update()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector :=
        setweight(to_tsvector('english', COALESCE(NEW.name, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.material, '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(NEW.badge, '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(NEW.short_description, '')), 'C') ||
        setweight(to_tsvector('english', COALESCE(NEW.full_description, '')), 'D');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_products_search_vector
BEFORE INSERT OR UPDATE OF name, material, badge, short_description, full_description
ON products
FOR EACH ROW EXECUTE FUNCTION products_search_vector_update();

-- =============================================================================
-- PERFORMANCE INDEXES
-- =============================================================================

-- Products & Catalog Indexes
CREATE INDEX idx_products_collection_id ON products(collection_id);
CREATE INDEX idx_products_status ON products(status);
CREATE INDEX idx_products_search_vector ON products USING GIN(search_vector);
CREATE INDEX idx_products_featured ON products(is_featured) WHERE is_featured = TRUE AND deleted_at IS NULL;
CREATE INDEX idx_products_best_seller ON products(is_best_seller) WHERE is_best_seller = TRUE AND deleted_at IS NULL;
CREATE INDEX idx_products_new_arrival ON products(is_new_arrival) WHERE is_new_arrival = TRUE AND deleted_at IS NULL;
CREATE INDEX idx_products_active ON products(status, created_at DESC) WHERE deleted_at IS NULL;

CREATE INDEX idx_product_categories_cat_id ON product_categories(category_id);
CREATE INDEX idx_product_categories_prod_id ON product_categories(product_id);

CREATE INDEX idx_product_images_prod_order ON product_images(product_id, display_order);
CREATE INDEX idx_product_images_primary ON product_images(product_id) WHERE is_primary = TRUE;

CREATE INDEX idx_product_variants_prod ON product_variants(product_id, display_order);
CREATE INDEX idx_product_variant_images_var ON product_variant_images(variant_id, display_order);
CREATE INDEX idx_product_specs_prod ON product_specifications(product_id, display_order);
CREATE INDEX idx_product_features_prod ON product_features(product_id, display_order);
CREATE INDEX idx_product_care_cards_prod ON product_care_cards(product_id, display_order);
CREATE INDEX idx_product_care_items_card ON product_care_items(care_card_id, display_order);

-- Hero & Content Indexes
CREATE INDEX idx_hero_slides_active_order ON hero_slides(is_active, display_order);
CREATE INDEX idx_testimonials_status_featured ON testimonials(status, is_featured, created_at DESC);
CREATE INDEX idx_marquee_active_order ON marquee_items(is_active, display_order);

-- Orders & Operations Indexes
CREATE INDEX idx_whatsapp_orders_status ON whatsapp_orders(status, created_at DESC);
CREATE INDEX idx_whatsapp_orders_phone ON whatsapp_orders(phone);
CREATE INDEX idx_whatsapp_orders_created_at ON whatsapp_orders(created_at DESC);
CREATE INDEX idx_whatsapp_order_items_order ON whatsapp_order_items(order_id);

CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(order_status, payment_status, placed_at DESC);
CREATE INDEX idx_orders_order_number ON orders(order_number);
CREATE INDEX idx_order_items_order ON order_items(order_id);

CREATE INDEX idx_inventory_log_product ON inventory_log(product_id, created_at DESC);
CREATE INDEX idx_audit_log_entity ON audit_log(entity_type, entity_id, created_at DESC);
CREATE INDEX idx_audit_log_user ON audit_log(user_id, created_at DESC);
CREATE INDEX idx_contact_submissions_status ON contact_submissions(status, created_at DESC);
