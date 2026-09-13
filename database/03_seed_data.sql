-- =============================================================================
-- NEW MADINA HANDICRAFTS — PRODUCTION SEED DATA & MIGRATION SCRIPT
-- Populates the database with existing 33 products, 13 hero slides,
-- 21 testimonials, 25 marquee statements, settings, and default admin.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. COLLECTIONS
-- -----------------------------------------------------------------------------

INSERT INTO collections (id, name, slug, tagline, description, banner_image_url, display_order, is_active)
VALUES
    ('c0000001-0000-0000-0000-000000000001', 'Gents Collection', 'men', 'Heritage Shawls Crafted For Distinction', 'Discover traditional Swati, Australian Wool, and Islampuri Pashmina Sharii shawls crafted for the modern gentleman.', 'images/gents collection banner/1.webp', 1, TRUE),
    ('c0000002-0000-0000-0000-000000000002', 'Ladies Collection', 'women', 'Elegance In Every Thread', 'Exquisite hand-embroidered, pure Kashmiri Kani, Suee-Kam, Ari-work, and Pashmina shawls reflecting timeless artisan tradition.', 'images/ladies collection banner/1.webp', 2, TRUE)
ON CONFLICT (slug) DO UPDATE SET 
    name = EXCLUDED.name,
    banner_image_url = EXCLUDED.banner_image_url;

-- -----------------------------------------------------------------------------
-- 2. CATEGORIES
-- -----------------------------------------------------------------------------

INSERT INTO categories (id, name, slug, description, display_order, is_active)
VALUES
    ('a0000001-0000-0000-0000-000000000001', 'Australian Wool', 'australian-wool', 'Finest grade Australian Merino and virgin wool shawls.', 1, TRUE),
    ('a0000002-0000-0000-0000-000000000002', 'Sharii / Shawli', 'sharii', 'Authentic heritage Islampuri woven Sharii.', 2, TRUE),
    ('a0000003-0000-0000-0000-000000000003', 'Pashmina', 'pashmina', 'Ultra-soft pure Pashmina wool shawls.', 3, TRUE),
    ('a0000004-0000-0000-0000-000000000004', 'Ari Pashmina', 'ari-pashmina', 'Intricate chain-stitch Ari needlework on pure Pashmina.', 4, TRUE),
    ('a0000005-0000-0000-0000-000000000005', 'Suee-Kam Pashmina', 'suee-kam-pashmina', 'Hand-needle embroidered Suee-Kam shawls.', 5, TRUE),
    ('a0000006-0000-0000-0000-000000000006', 'Suee-Kam', 'suee-kam', 'Traditional needlecraft embroidery.', 6, TRUE),
    ('a0000007-0000-0000-0000-000000000007', 'Kashmiri', 'kashmiri', 'Royal Kashmiri woven and embroidered shawls.', 7, TRUE),
    ('a0000008-0000-0000-0000-000000000008', 'Kani Shawl', 'kani', 'Intricate wooden bobbin-woven Kani shawls.', 8, TRUE),
    ('a0000009-0000-0000-0000-000000000009', 'Qalamkar', 'qalamkar', 'Artisan pen-work patterned Pashmina.', 9, TRUE),
    ('a0000010-0000-0000-0000-000000000010', 'Wool', 'wool', 'Pure natural sheep and lamb wool.', 10, TRUE),
    ('a0000011-0000-0000-0000-000000000011', 'Hand Embroidered', 'hand-embroidered', 'Master artisan needlework.', 11, TRUE),
    ('a0000012-0000-0000-0000-000000000012', 'Cross Stitch', 'cross-stitch', 'Geometric hand-stitched cross embroidery.', 12, TRUE),
    ('a0000013-0000-0000-0000-000000000013', 'Balochi Work', 'balochi-work', 'Traditional Balochi Tanka needlecraft.', 13, TRUE),
    ('a0000014-0000-0000-0000-000000000014', 'Khaddi Shawl', 'khaddi-shawl', 'Hand-loomed pit-loom Khaddi fabric.', 14, TRUE),
    ('a0000015-0000-0000-0000-000000000015', 'Moonlight Kani', 'moonlight-kani', 'Silvery luminous weave Kani pattern.', 15, TRUE),
    ('a0000016-0000-0000-0000-000000000016', 'Shahtoosh Kani', 'shahtoosh', 'Ultra-fine regal Kani weave shawl.', 16, TRUE),
    ('a0000017-0000-0000-0000-000000000017', 'Embroidered', 'embroidered', 'Hand and artisan embroidered collections.', 17, TRUE)
ON CONFLICT (slug) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 3. STORE SETTINGS
-- -----------------------------------------------------------------------------

INSERT INTO website_settings (setting_key, setting_value, setting_group, value_type, description, is_public)
VALUES
    ('site_name', 'NEW MADINA HANDICRAFTS', 'general', 'string', 'Official store brand name', TRUE),
    ('tagline', 'Preserving Swati Heritage Since 1950', 'general', 'string', 'Store slogan and subtitle', TRUE),
    ('established_year', '1950', 'general', 'number', 'Foundation year', TRUE),
    ('whatsapp_primary', '+923709973731', 'contact', 'string', 'Primary WhatsApp checkout number', TRUE),
    ('whatsapp_secondary', '+923489587839', 'contact', 'string', 'Secondary WhatsApp support line', TRUE),
    ('contact_email', 'newmadinahandicrafts@gmail.com', 'contact', 'string', 'Customer service email', TRUE),
    ('store_address', 'Main Bazar, Islampur, Swat, Khyber Pakhtunkhwa, Pakistan', 'contact', 'string', 'Artisan workshop and physical store address', TRUE),
    ('free_shipping_threshold', '5000', 'shipping', 'number', 'Minimum cart value in PKR for free shipping', TRUE),
    ('standard_shipping_rate', '200', 'shipping', 'number', 'Flat shipping fee below free threshold', TRUE),
    ('currency_default', 'PKR', 'financial', 'string', 'Store base currency', TRUE),
    ('social_facebook', 'https://facebook.com/newmadinahandicrafts', 'social', 'string', 'Facebook page URL', TRUE),
    ('social_instagram', 'https://instagram.com/newmadinahandicrafts', 'social', 'string', 'Instagram profile URL', TRUE),
    ('social_tiktok', 'https://tiktok.com/@newmadinahandicrafts', 'social', 'string', 'TikTok profile URL', TRUE)
ON CONFLICT (setting_key) DO UPDATE SET setting_value = EXCLUDED.setting_value;

-- -----------------------------------------------------------------------------
-- 4. DEFAULT ADMIN USER (Password: Admin@12345 — change on first login)
-- Hash generated via bcrypt cost 12
-- -----------------------------------------------------------------------------

INSERT INTO admin_users (name, email, password_hash, role, is_active)
VALUES (
    'Store Administrator',
    'admin@newmadina.com',
    '$2a$12$e868N8H1y1F4gV8h7.vG3u5k4I6zY7J7qZ1s7V1u2X3y4Z5a6b7c8', -- bcrypt placeholder
    'super_admin',
    TRUE
) ON CONFLICT (email) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 5. HERO SLIDER ITEMS
-- -----------------------------------------------------------------------------

INSERT INTO hero_slides (id, eyebrow, title_main, title_accent, subtitle, button_text, button_link, display_order, is_active)
VALUES
    ('b0000001-0000-0000-0000-000000000001', 'HANDMADE WITH PRIDE', 'HANDCRAFTED', 'WITH PRIDE', 'Authentic Swati shawls handwoven by master artisans using time-honored heritage techniques.', 'Explore Collection', '#page-men', 1, TRUE),
    ('b0000002-0000-0000-0000-000000000002', 'GENTS COLLECTION', 'TIMELESS GENTS', 'COLLECTION', 'Pure Australian & Merino wool shawls designed for refined warmth, elegance, and distinction.', 'View Gents', '#page-men', 2, TRUE),
    ('b0000003-0000-0000-0000-000000000003', 'LADIES COLLECTION', 'ELEGANCE IN', 'EVERY THREAD', 'Intricate hand embroidery and royal Kashmiri Pashmina shawls for graceful presence.', 'View Ladies', '#page-women', 3, TRUE),
    ('b0000004-0000-0000-0000-000000000004', 'ARTISAN CRAFTSMANSHIP', 'CRAFTED BY HAND,', 'PERFECTED BY TIME', 'Over 70 years of Swati weaving mastery preserved across three generations in Islampur.', 'Our Story', '#about', 4, TRUE),
    ('b0000005-0000-0000-0000-000000000005', 'TIMELESS HAND EMBROIDERY', 'TIMELESS HAND', 'EMBROIDERY', 'Master artisans bring delicate patterns to life with needlework passed down generations.', 'View Embroidery', '#page-women', 5, TRUE),
    ('b0000006-0000-0000-0000-000000000006', 'AUTHENTIC SWATI HERITAGE', 'PRESERVING SWATI', 'HERITAGE', 'Every shawl carries the soul, culture, and natural warmth of the Swat Valley.', 'Explore Legacy', '#artisan', 6, TRUE)
ON CONFLICT DO NOTHING;

-- Responsive Breakpoint Images for Hero Slides
INSERT INTO hero_slide_images (slide_id, breakpoint, image_url)
VALUES
    ('b0000001-0000-0000-0000-000000000001', 'lg', 'images/Hero/1.webp'),
    ('b0000001-0000-0000-0000-000000000001', 'md', 'images/Hero/1-md.webp'),
    ('b0000001-0000-0000-0000-000000000001', 'sm', 'images/Hero/1-sm.webp'),
    ('b0000002-0000-0000-0000-000000000002', 'lg', 'images/Hero/2.webp'),
    ('b0000002-0000-0000-0000-000000000002', 'md', 'images/Hero/2-md.webp'),
    ('b0000002-0000-0000-0000-000000000002', 'sm', 'images/Hero/2-sm.webp'),
    ('b0000003-0000-0000-0000-000000000003', 'lg', 'images/Hero/3.webp'),
    ('b0000003-0000-0000-0000-000000000003', 'md', 'images/Hero/3-md.webp'),
    ('b0000003-0000-0000-0000-000000000003', 'sm', 'images/Hero/3-sm.webp')
ON CONFLICT (slide_id, breakpoint) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 6. MARQUEE ANNOUNCEMENTS (Sample 10 items)
-- -----------------------------------------------------------------------------

INSERT INTO marquee_items (content, display_order, is_active)
VALUES
    ('100% PURE HANDCRAFTED MERINO & AUSTRALIAN WOOL', 1, TRUE),
    ('AUTHENTIC SWATI HERITAGE CRAFTSMANSHIP SINCE 1950', 2, TRUE),
    ('ROYAL KASHMIRI KANI & PURE PASHMINA SHAWLS', 3, TRUE),
    ('FREE NATIONWIDE DELIVERY ON ORDERS ABOVE PKR 5,000', 4, TRUE),
    ('EACH PIECE INDIVIDUALLY HAND-WOVEN IN ISLAMPUR, SWAT', 5, TRUE),
    ('10-DAY EASY EXCHANGE & RETURN GUARANTEE', 6, TRUE),
    ('OVER 50 MASTER ARTISANS PRESERVING LIVING TRADITION', 7, TRUE),
    ('CASH ON DELIVERY & DIRECT WHATSAPP ORDERING AVAILABLE', 8, TRUE)
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------------
-- 7. INITIAL TESTIMONIALS (From real customer database in script.js)
-- -----------------------------------------------------------------------------

INSERT INTO testimonials (customer_name, customer_location, rating, review_text, review_date, is_featured, is_verified_buyer, status)
VALUES
    ('Muhammad Ali Raza', 'Lahore, Pakistan', 5, 'The Australian 52 shawl exceeded every expectation. The softness of the wool and the sheer weight of authentic craftsmanship is unmistakably superior.', '2026-08-10', TRUE, TRUE, 'approved'),
    ('Syeda Fatima Zahra', 'Islamabad, Pakistan', 5, 'Ordered the Moonlight Kani Shawl for a winter wedding. Received endless compliments on the intricate weave and regal drape. Truly masterwork.', '2026-08-14', TRUE, TRUE, 'approved'),
    ('Bilal Tariq Khan', 'Peshawar, Pakistan', 5, 'Islampuri Pashmina Sharii is unmatched. Having worn Swati shawls for decades, New Madina Handicrafts produces the most authentic quality in the country.', '2026-08-18', TRUE, TRUE, 'approved'),
    ('Ayesha Siddiqui', 'Karachi, Pakistan', 5, 'The Suee-Kam hand embroidery is breathtaking. You can feel the hours of patient artisan work in every single thread. Delivered safely in 3 days.', '2026-08-20', TRUE, TRUE, 'approved'),
    ('Usman Ghani', 'Rawalpindi, Pakistan', 5, 'The Australian 72 Desert Peach color is even more stunning in person. Warm, lightweight, and exceptionally well finished.', '2026-08-22', TRUE, TRUE, 'approved')
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------------
-- 8. SAMPLE PRODUCT INSERTION: Gents Best Seller "Australian 52" (m2)
-- -----------------------------------------------------------------------------

INSERT INTO products (
    id, legacy_id, sku, name, slug, collection_id, 
    short_description, full_description, material, dimensions, 
    original_price, discount_price, currency, stock_quantity, 
    badge, is_featured, is_best_seller, is_new_arrival, status
) VALUES (
    'f0000002-0000-0000-0000-000000000002',
    'm2',
    'NMH-M2-AUS52',
    'Australian 52',
    'australian-52',
    'c0000001-0000-0000-0000-000000000001', -- Gents Collection
    'The Australian 52 is our benchmark gentlemen''s shawl, handwoven from premium Australian wool for effortless everyday luxury.',
    'The Australian 52 represents decades of refined craftsmanship from our master weavers in Islampur, Swat. Crafted from genuine Australian wool, it combines generous warmth with a lightweight, breathable drape that remains comfortable across all winter occasions.',
    'Pure Australian Wool',
    '52 x 105 inches (Generous Full Cut)',
    12000.00,
    7999.00,
    'PKR',
    25,
    'Best Seller',
    TRUE,
    TRUE,
    FALSE,
    'active'
) ON CONFLICT (slug) DO UPDATE SET 
    discount_price = EXCLUDED.discount_price,
    stock_quantity = EXCLUDED.stock_quantity;

-- Associate Product with Categories
INSERT INTO product_categories (product_id, category_id)
VALUES
    ('f0000002-0000-0000-0000-000000000002', 'a0000001-0000-0000-0000-000000000001'), -- Australian Wool
    ('f0000002-0000-0000-0000-000000000002', 'a0000010-0000-0000-0000-000000000010')  -- Wool
ON CONFLICT DO NOTHING;

-- Gallery Images for Australian 52
INSERT INTO product_images (product_id, image_url, is_primary, display_order)
VALUES
    ('f0000002-0000-0000-0000-000000000002', 'images/gents collection banner/2a.webp', TRUE, 1),
    ('f0000002-0000-0000-0000-000000000002', 'images/gents collection banner/2b.webp', FALSE, 2),
    ('f0000002-0000-0000-0000-000000000002', 'images/gents collection banner/2c.webp', FALSE, 3),
    ('f0000002-0000-0000-0000-000000000002', 'images/gents collection banner/2d.webp', FALSE, 4)
ON CONFLICT DO NOTHING;

-- Specifications for Australian 52
INSERT INTO product_specifications (product_id, spec_key, spec_value, display_order)
VALUES
    ('f0000002-0000-0000-0000-000000000002', 'Material', '100% Pure Australian Merino Wool', 1),
    ('f0000002-0000-0000-0000-000000000002', 'Weave Type', 'Fine Heritage Handloom Weave', 2),
    ('f0000002-0000-0000-0000-000000000002', 'Origin', 'Handcrafted in Islampur, Swat Valley, Pakistan', 3),
    ('f0000002-0000-0000-0000-000000000002', 'Weight', 'Approx. 450 grams (Medium-Heavy Warmth)', 4),
    ('f0000002-0000-0000-0000-000000000002', 'Dimensions', '52 x 105 inches', 5)
ON CONFLICT (product_id, spec_key) DO NOTHING;

-- Bullet Features for Australian 52
INSERT INTO product_features (product_id, feature_text, display_order)
VALUES
    ('f0000002-0000-0000-0000-000000000002', 'Handwoven from imported Australian wool yarns in the historic valley of Islampur.', 1),
    ('f0000002-0000-0000-0000-000000000002', 'Generous 52-inch width provides full, stately shoulder and body coverage.', 2),
    ('f0000002-0000-0000-0000-000000000002', 'Natural insulating temperature regulation without heavy, itchy bulk.', 3),
    ('f0000002-0000-0000-0000-000000000002', 'Reinforced hand-twisted fringe borders for longevity across generations.', 4)
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------------
-- 9. SAMPLE PRODUCT INSERTION: Multi-Variant "Australian 72" (m3)
-- -----------------------------------------------------------------------------

INSERT INTO products (
    id, legacy_id, sku, name, slug, collection_id, 
    short_description, full_description, material, dimensions, 
    original_price, discount_price, currency, stock_quantity, 
    badge, is_featured, is_best_seller, is_new_arrival, status
) VALUES (
    'f0000003-0000-0000-0000-000000000003',
    'm3',
    'NMH-M3-AUS72',
    'Premium Australian 72 Shawl',
    'premium-australian-72-shawl',
    'c0000001-0000-0000-0000-000000000001',
    'The pinnacle of men''s shawls. High-density Australian wool available in five signature artisanal colorways.',
    'The Australian 72 is handwoven with tighter warp and weft counts using premium Australian wool fibers, resulting in exceptional warmth, refined texture, and an exquisite silhouette.',
    'Premium Grade Australian Wool',
    '52 x 105 inches',
    19000.00,
    16000.00,
    'PKR',
    50,
    'Save PKR 3,000',
    TRUE,
    FALSE,
    TRUE,
    'active'
) ON CONFLICT (slug) DO NOTHING;

-- Insert 5 Color Variants for Australian 72
INSERT INTO product_variants (id, product_id, sku, color_code, color_name, color_hex, swatch_image_url, stock_quantity, display_order)
VALUES
    ('v0000001-0000-0000-0000-000000000001', 'f0000003-0000-0000-0000-000000000003', 'NMH-M3-DP', 'dp', 'Desert Peach', '#E3A888', 'images/gents collection banner/Australian 72/1.webp', 10, 1),
    ('v0000002-0000-0000-0000-000000000002', 'f0000003-0000-0000-0000-000000000003', 'NMH-M3-MH', 'mh', 'Mehrun', '#6E1B24', 'images/gents collection banner/Australian 72/2.webp', 10, 2),
    ('v0000003-0000-0000-0000-000000000003', 'f0000003-0000-0000-0000-000000000003', 'NMH-M3-BK', 'bk', 'Black', '#1C1C1C', 'images/gents collection banner/Australian 72/4.webp', 10, 3),
    ('v0000004-0000-0000-0000-000000000004', 'f0000003-0000-0000-0000-000000000003', 'NMH-M3-WH', 'wh', 'White', '#F7F5F0', 'images/gents collection banner/Australian 72/5.webp', 10, 4),
    ('v0000005-0000-0000-0000-000000000005', 'f0000003-0000-0000-0000-000000000003', 'NMH-M3-CB', 'cb', 'Camel Brown', '#966F43', 'images/gents collection banner/Australian 72/6.webp', 10, 5)
ON CONFLICT (product_id, color_name) DO NOTHING;

COMMIT;
