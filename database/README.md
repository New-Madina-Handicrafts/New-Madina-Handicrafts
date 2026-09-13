# NEW MADINA HANDICRAFTS — Database Architecture & Engineering Guide

## 1. Architectural Overview

This production database architecture is built specifically for **NEW MADINA HANDICRAFTS**, a luxury handcrafted shawl brand specializing in Swati, Kashmiri, Pashmina, Australian Wool, and hand-embroidered artisanal garments.

### Key Highlights:
- **Engine**: PostgreSQL 15+
- **Primary Keys**: UUID v4 (`gen_random_uuid()`) for global uniqueness and secure API endpoints.
- **Normalization**: Fully normalized 3NF schema eliminating redundancy while using PostgreSQL JSON aggregates and materialized views for sub-millisecond API responses.
- **Full-Text Search**: Native English `tsvector` with weighted ranking on product titles, materials, badges, and descriptions.
- **Audit & Inventory**: Immutable append-only ledger for all stock adjustments and admin operations.
- **Future-Proof**: Supports guest WhatsApp orders now, and seamlessly enables full online checkout, coupons, wishlists, and customer accounts without database refactoring.

---

## 2. Directory Structure

```
database/
├── 01_schema.sql             # Full DDL: tables, enums, triggers, indexes, and constraints
├── 02_views_and_functions.sql # JSON API views, stored procedures (atomic stock deduction), dashboard stats
├── 03_seed_data.sql          # Seed data (collections, categories, hero slides, testimonials, products)
└── README.md                 # Architecture documentation, query reference & deployment guide
```

---

## 3. Database Schema Summary (31 Tables across 7 Domains)

| Domain | Table Name | Purpose |
|---|---|---|
| **1. Catalog** | `collections` | Top-level collections (Men's / Gents, Women's / Ladies) |
| | `categories` | Filter categories with hierarchical parent-child support |
| | `products` | Core product items with pricing, badges, stock & FTS vector |
| | `product_categories` | Many-to-many junction connecting products to multiple filters |
| | `product_images` | Ordered image galleries with primary hero image flag |
| | `product_variants` | Color swatches (e.g. Desert Peach, Mehrun, Black, White) |
| | `product_variant_images` | Dedicated photo galleries per color variant |
| | `product_specifications` | Key-value technical specifications (Material, Weave, Origin) |
| | `product_features` | Bullet points on product detail pages |
| | `product_care_cards` | Care instruction categories (Washing, Storage, Styling) |
| | `product_care_items` | Individual instruction lines per care card |
| **2. UI & Content** | `hero_slides` | Dynamic homepage hero sliders with CTA links |
| | `hero_slide_images` | Responsive breakpoint images (lg, md, sm) per slide |
| | `marquee_items` | Infinite looping announcement bar text items |
| | `testimonials` | Customer reviews with star ratings, locations, and moderation |
| | `pages` | CMS static pages (Story, Craftsmanship, Policies) |
| **3. Identity & Users** | `admin_users` | Role-based admin accounts (super_admin, editor, etc.) |
| | `customers` | Future registered customer accounts |
| | `customer_addresses` | Saved customer shipping and billing addresses |
| **4. Operations** | `inventory_log` | Immutable stock movement ledger (restock, sale, damage) |
| | `website_settings` | Global configurable variables (WhatsApp numbers, rates) |
| | `contact_submissions` | Customer contact form inquiries with reply tracking |
| | `newsletter_subscribers` | Email marketing subscription list |
| **5. WhatsApp Orders** | `whatsapp_orders` | Customer orders generated via WhatsApp checkout flow |
| | `whatsapp_order_items` | Line items with historical price & name snapshots |
| **6. Online Commerce** | `coupons` | Discount codes (percentage / fixed) with usage limits |
| | `orders` | Full e-commerce orders (COD / online payment gateway) |
| | `order_items` | Online order line items with immutable snapshots |
| | `wishlists` | Customer saved items / heart button |
| | `wishlist_items` | Products saved within wishlists |
| **7. Governance** | `audit_log` | Append-only security log for all admin mutations |

---

## 4. How to Deploy

### Option A: Supabase (Recommended for Cloudflare Pages integration)
1. Create a free project at [supabase.com](https://supabase.com).
2. Open the **SQL Editor** in your Supabase dashboard.
3. Run `01_schema.sql`, then `02_views_and_functions.sql`, then `03_seed_data.sql`.
4. Supabase immediately provides auto-generated REST and GraphQL APIs for all views and tables.

### Option B: Neon / Standard PostgreSQL Server
1. Connect via `psql`:
   ```bash
   psql -h <your-host> -U <your-user> -d <your-database> -f 01_schema.sql
   psql -h <your-host> -U <your-user> -d <your-database> -f 02_views_and_functions.sql
   psql -h <your-host> -U <your-user> -d <your-database> -f 03_seed_data.sql
   ```

---

## 5. Ready-to-Use API Queries

### 1. Fetch Complete Product by Slug (Single Query)
```sql
SELECT * FROM v_product_details WHERE slug = 'australian-52';
```

### 2. Full-Text Search across Products
```sql
SELECT id, name, slug, original_price, discount_price, badge, ts_rank(search_vector, websearch_to_tsquery('english', 'pashmina kashmiri')) AS rank
FROM products
WHERE search_vector @@ websearch_to_tsquery('english', 'pashmina kashmiri')
  AND status = 'active' AND deleted_at IS NULL
ORDER BY rank DESC;
```

### 3. Record WhatsApp Order Atomically with Stock Deduction
```sql
-- Step 1: Insert WhatsApp Order
INSERT INTO whatsapp_orders (order_number, customer_name, phone, shipping_address, subtotal, total_amount)
VALUES ('NMH-WA-20260901-001', 'Ahmad Khan', '+923001234567', 'House 12, Street 4, F-7/2, Islamabad', 7999.00, 7999.00)
RETURNING id;

-- Step 2: Deduct stock via Stored Procedure
SELECT record_inventory_change(
    p_product_id := 'f0000002-0000-0000-0000-000000000002',
    p_variant_id := NULL,
    p_quantity_change := -1,
    p_change_type := 'order_deduction',
    p_notes := 'Deduction for WhatsApp Order NMH-WA-20260901-001'
);
```

### 4. Fetch Hero Slider for Homepage
```sql
SELECT * FROM v_hero_slides;
```

### 5. Fetch Real-time Admin Dashboard KPIs
```sql
SELECT * FROM v_admin_dashboard_stats;
```
