-- =============================================================================
-- NEW MADINA HANDICRAFTS — STOREFRONT VIEWS & BUSINESS LOGIC PROCEDURES
-- Optimized JSON Aggregations for Single-Roundtrip API Payloads
-- =============================================================================

-- -----------------------------------------------------------------------------
-- VIEW: Storefront Full Product Detail (Ready for /api/products/:slug)
-- Aggregates images, variants, specs, features, and care instructions into JSON
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_product_details AS
SELECT 
    p.id,
    p.legacy_id,
    p.sku,
    p.name,
    p.slug,
    c.name AS collection_name,
    c.slug AS collection_slug,
    p.short_description,
    p.full_description,
    p.material,
    p.dimensions,
    p.original_price,
    p.discount_price,
    COALESCE(p.discount_price, p.original_price) AS current_price,
    CASE 
        WHEN p.discount_price IS NOT NULL AND p.original_price > p.discount_price 
        THEN (p.original_price - p.discount_price)
        ELSE 0 
    END AS savings_amount,
    p.currency,
    p.stock_quantity,
    p.badge,
    p.is_featured,
    p.is_best_seller,
    p.is_new_arrival,
    p.is_sold_out,
    p.status,
    -- Categories list
    COALESCE(
        (SELECT json_agg(json_build_object('id', cat.id, 'name', cat.name, 'slug', cat.slug))
         FROM product_categories pc
         JOIN categories cat ON cat.id = pc.category_id
         WHERE pc.product_id = p.id), '[]'::json
    ) AS categories,
    -- Image gallery ordered by display_order
    COALESCE(
        (SELECT json_agg(json_build_object('id', pi.id, 'url', pi.image_url, 'alt', pi.alt_text, 'is_primary', pi.is_primary) ORDER BY pi.display_order ASC)
         FROM product_images pi
         WHERE pi.product_id = p.id), '[]'::json
    ) AS images,
    -- Color variants with individual sub-galleries
    COALESCE(
        (SELECT json_agg(json_build_object(
            'id', pv.id,
            'color_code', pv.color_code,
            'color_name', pv.color_name,
            'color_hex', pv.color_hex,
            'swatch_image', pv.swatch_image_url,
            'price_override', pv.price_override,
            'stock_quantity', pv.stock_quantity,
            'images', COALESCE(
                (SELECT json_agg(pvi.image_url ORDER BY pvi.display_order ASC)
                 FROM product_variant_images pvi
                 WHERE pvi.variant_id = pv.id), '[]'::json
            )
        ) ORDER BY pv.display_order ASC)
         FROM product_variants pv
         WHERE pv.product_id = p.id AND pv.is_active = TRUE), '[]'::json
    ) AS variants,
    -- Specifications table
    COALESCE(
        (SELECT json_object_agg(ps.spec_key, ps.spec_value)
         FROM product_specifications ps
         WHERE ps.product_id = p.id), '{}'::json
    ) AS specifications,
    -- Bullet features
    COALESCE(
        (SELECT json_agg(pf.feature_text ORDER BY pf.display_order ASC)
         FROM product_features pf
         WHERE pf.product_id = p.id), '[]'::json
    ) AS features,
    -- Care cards
    COALESCE(
        (SELECT json_agg(json_build_object(
            'title', pcc.title,
            'icon', pcc.icon,
            'items', COALESCE(
                (SELECT json_agg(pci.instruction ORDER BY pci.display_order ASC)
                 FROM product_care_items pci
                 WHERE pci.care_card_id = pcc.id), '[]'::json
            )
        ) ORDER BY pcc.display_order ASC)
         FROM product_care_cards pcc
         WHERE pcc.product_id = p.id), '[]'::json
    ) AS care_instructions,
    p.created_at,
    p.updated_at
FROM products p
JOIN collections c ON c.id = p.collection_id
WHERE p.status = 'active' AND p.deleted_at IS NULL;

-- -----------------------------------------------------------------------------
-- VIEW: Hero Slider with Breakpoint Images
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_hero_slides AS
SELECT 
    hs.id,
    hs.eyebrow,
    hs.title_main,
    hs.title_accent,
    hs.subtitle,
    hs.button_text,
    hs.button_link,
    hs.display_order,
    COALESCE(
        (SELECT json_object_agg(hsi.breakpoint, hsi.image_url)
         FROM hero_slide_images hsi
         WHERE hsi.slide_id = hs.id), '{}'::json
    ) AS images
FROM hero_slides hs
WHERE hs.is_active = TRUE
ORDER BY hs.display_order ASC;

-- -----------------------------------------------------------------------------
-- STORED PROCEDURE: Record Inventory Movement & Update Stock
-- Ensures atomic stock adjustments with full audit ledger tracking
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION record_inventory_change(
    p_product_id UUID,
    p_variant_id UUID,
    p_quantity_change INTEGER,
    p_change_type inventory_change_type_enum,
    p_reference_id UUID DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_admin_id UUID DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    v_current_stock INTEGER;
    v_new_stock INTEGER;
BEGIN
    IF p_variant_id IS NOT NULL THEN
        -- Lock row for concurrency safety
        SELECT stock_quantity INTO v_current_stock 
        FROM product_variants 
        WHERE id = p_variant_id FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Product variant % not found', p_variant_id;
        END IF;

        v_new_stock := v_current_stock + p_quantity_change;
        IF v_new_stock < 0 THEN
            RAISE EXCEPTION 'Insufficient variant stock. Available: %, Requested Change: %', v_current_stock, p_quantity_change;
        END IF;

        UPDATE product_variants 
        SET stock_quantity = v_new_stock, updated_at = CURRENT_TIMESTAMP
        WHERE id = p_variant_id;
    ELSE
        -- Lock row for concurrency safety
        SELECT stock_quantity INTO v_current_stock 
        FROM products 
        WHERE id = p_product_id FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Product % not found', p_product_id;
        END IF;

        v_new_stock := v_current_stock + p_quantity_change;
        IF v_new_stock < 0 THEN
            RAISE EXCEPTION 'Insufficient product stock. Available: %, Requested Change: %', v_current_stock, p_quantity_change;
        END IF;

        UPDATE products 
        SET stock_quantity = v_new_stock, 
            is_sold_out = (v_new_stock = 0),
            updated_at = CURRENT_TIMESTAMP
        WHERE id = p_product_id;
    END IF;

    -- Record in immutable audit ledger
    INSERT INTO inventory_log (
        product_id, variant_id, quantity_change, stock_after, change_type, reference_id, notes, created_by
    ) VALUES (
        p_product_id, p_variant_id, p_quantity_change, v_new_stock, p_change_type, p_reference_id, p_notes, p_admin_id
    );

    RETURN v_new_stock;
END;
$$ LANGUAGE plpgsql;

-- -----------------------------------------------------------------------------
-- VIEW: Admin Executive Dashboard Stats
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_admin_dashboard_stats AS
SELECT
    (SELECT COUNT(*) FROM products WHERE deleted_at IS NULL) AS total_products,
    (SELECT COUNT(*) FROM products WHERE is_sold_out = TRUE AND deleted_at IS NULL) AS sold_out_products,
    (SELECT COUNT(*) FROM whatsapp_orders WHERE created_at >= CURRENT_DATE) AS wa_orders_today,
    (SELECT COUNT(*) FROM whatsapp_orders WHERE status = 'pending') AS wa_orders_pending,
    (SELECT COALESCE(SUM(total_amount), 0) FROM whatsapp_orders WHERE status IN ('confirmed', 'shipped', 'delivered')) AS total_revenue_pkr,
    (SELECT COUNT(*) FROM testimonials WHERE status = 'approved') AS total_reviews,
    (SELECT COALESCE(AVG(rating), 5.0) FROM testimonials WHERE status = 'approved') AS average_rating,
    (SELECT COUNT(*) FROM contact_submissions WHERE status = 'new') AS unread_inquiries;
