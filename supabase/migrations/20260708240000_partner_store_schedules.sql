-- Partner store opening hours (Mon=1 … Sun=7)

CREATE TABLE IF NOT EXISTS partner_schedules (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id   UUID NOT NULL REFERENCES partners(id) ON DELETE CASCADE,
  day_of_week  INT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
  open_time    TIME,
  close_time   TIME,
  is_closed    BOOLEAN NOT NULL DEFAULT false,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (partner_id, day_of_week)
);

CREATE INDEX IF NOT EXISTS idx_partner_schedules_partner
  ON partner_schedules(partner_id);

-- ── Helpers ───────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION partner_schedules_json(p_partner_id UUID)
RETURNS JSON
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE((
    SELECT json_agg(
      json_build_object(
        'day_of_week', ps.day_of_week,
        'open_time',   to_char(ps.open_time, 'HH24:MI'),
        'close_time',  to_char(ps.close_time, 'HH24:MI'),
        'is_closed',   ps.is_closed
      )
      ORDER BY ps.day_of_week
    )
    FROM partner_schedules ps
    WHERE ps.partner_id = p_partner_id
  ), '[]'::json);
$$;

CREATE OR REPLACE FUNCTION save_partner_schedules(
  p_partner_id UUID,
  p_schedules  JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  item JSONB;
  v_day   INT;
  v_open  TIME;
  v_close TIME;
  v_closed BOOLEAN;
BEGIN
  IF p_partner_id IS NULL THEN
    RETURN;
  END IF;

  DELETE FROM partner_schedules WHERE partner_id = p_partner_id;

  IF p_schedules IS NULL OR jsonb_typeof(p_schedules) <> 'array' THEN
    RETURN;
  END IF;

  FOR item IN SELECT * FROM jsonb_array_elements(p_schedules)
  LOOP
    v_day := (item->>'day_of_week')::INT;
    IF v_day IS NULL OR v_day < 1 OR v_day > 7 THEN
      CONTINUE;
    END IF;

    v_closed := COALESCE((item->>'is_closed')::BOOLEAN, false);

    IF v_closed THEN
      v_open := NULL;
      v_close := NULL;
    ELSE
      BEGIN
        v_open := NULLIF(trim(item->>'open_time'), '')::TIME;
        v_close := NULLIF(trim(item->>'close_time'), '')::TIME;
      EXCEPTION WHEN OTHERS THEN
        v_open := NULL;
        v_close := NULL;
      END;

      IF v_open IS NULL OR v_close IS NULL THEN
        v_closed := true;
        v_open := NULL;
        v_close := NULL;
      END IF;
    END IF;

    INSERT INTO partner_schedules (
      partner_id, day_of_week, open_time, close_time, is_closed
    ) VALUES (
      p_partner_id, v_day, v_open, v_close, v_closed
    );
  END LOOP;
END;
$$;

-- ── Partner store app RPCs ──────────────────────────────────────────────────

DROP FUNCTION IF EXISTS create_partner_store(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT
);

DROP FUNCTION IF EXISTS update_partner_store(
  UUID, TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT
);

DROP FUNCTION IF EXISTS create_partner(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT
);

DROP FUNCTION IF EXISTS create_partner(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, UUID
);

DROP FUNCTION IF EXISTS update_partner(
  TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, UUID
);

CREATE OR REPLACE FUNCTION create_partner_store(
  p_account_id    UUID,
  p_login_pass    TEXT,
  p_business_name TEXT,
  p_owner_name    TEXT DEFAULT NULL,
  p_phone         TEXT DEFAULT NULL,
  p_whatsapp      TEXT DEFAULT NULL,
  p_email         TEXT DEFAULT NULL,
  p_description   TEXT DEFAULT NULL,
  p_address_line  TEXT DEFAULT NULL,
  p_city          TEXT DEFAULT NULL,
  p_state         TEXT DEFAULT NULL,
  p_pincode       TEXT DEFAULT NULL,
  p_latitude      DOUBLE PRECISION DEFAULT NULL,
  p_longitude     DOUBLE PRECISION DEFAULT NULL,
  p_category      TEXT DEFAULT 'salon',
  p_schedules     JSONB DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_account_id    UUID := create_partner_store.p_account_id;
  v_business_name TEXT := trim(create_partner_store.p_business_name);
  v_owner_name    TEXT := nullif(trim(create_partner_store.p_owner_name), '');
  v_phone         TEXT := nullif(trim(create_partner_store.p_phone), '');
  v_whatsapp      TEXT := nullif(trim(create_partner_store.p_whatsapp), '');
  v_email         TEXT := nullif(trim(create_partner_store.p_email), '');
  v_description   TEXT := nullif(trim(create_partner_store.p_description), '');
  v_address_line  TEXT := nullif(trim(create_partner_store.p_address_line), '');
  v_city          TEXT := nullif(trim(create_partner_store.p_city), '');
  v_state         TEXT := nullif(trim(create_partner_store.p_state), '');
  v_pincode       TEXT := nullif(trim(create_partner_store.p_pincode), '');
  v_category      TEXT := coalesce(nullif(trim(create_partner_store.p_category), ''), 'salon');
  account_row     partner_accounts%ROWTYPE;
  new_row         partners%ROWTYPE;
BEGIN
  account_row := assert_partner_account_access(v_account_id, p_login_pass);

  IF v_business_name = '' THEN
    RAISE EXCEPTION 'Business name is required';
  END IF;

  IF v_phone IS NULL OR length(v_phone) <> 10 THEN
    RAISE EXCEPTION 'Phone must be 10 digits';
  END IF;

  IF v_whatsapp IS NULL OR length(v_whatsapp) <> 10 THEN
    RAISE EXCEPTION 'WhatsApp must be 10 digits';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM partner_categories pc
    WHERE pc.slug = v_category AND pc.is_active
  ) THEN
    v_category := 'salon';
  END IF;

  v_owner_name := coalesce(v_owner_name, account_row.owner_name);

  INSERT INTO partners (
    account_id, business_name, owner_name, phone, whatsapp, email,
    description, address_line, city, state, pincode,
    latitude, longitude, category, kyc_status, is_active
  ) VALUES (
    v_account_id, v_business_name, v_owner_name, v_phone, v_whatsapp, v_email,
    v_description, v_address_line, v_city, v_state, v_pincode,
    p_latitude, p_longitude, v_category, 'pending', true
  )
  RETURNING * INTO new_row;

  PERFORM save_partner_schedules(new_row.id, p_schedules);

  RETURN json_build_object(
    'id', new_row.id,
    'account_id', new_row.account_id,
    'business_name', new_row.business_name,
    'owner_name', new_row.owner_name,
    'phone', new_row.phone,
    'whatsapp', new_row.whatsapp,
    'alternate_phone', new_row.alternate_phone,
    'email', new_row.email,
    'description', new_row.description,
    'address_line', new_row.address_line,
    'city', new_row.city,
    'state', new_row.state,
    'pincode', new_row.pincode,
    'latitude', new_row.latitude,
    'longitude', new_row.longitude,
    'category', new_row.category,
    'is_active', new_row.is_active,
    'kyc_status', new_row.kyc_status,
    'primary_image', new_row.primary_image,
    'created_at', new_row.created_at,
    'schedules', partner_schedules_json(new_row.id)
  );
END;
$$;

CREATE OR REPLACE FUNCTION update_partner_store(
  p_account_id    UUID,
  p_login_pass    TEXT,
  p_store_id      UUID,
  p_business_name TEXT,
  p_phone         TEXT DEFAULT NULL,
  p_whatsapp      TEXT DEFAULT NULL,
  p_email         TEXT DEFAULT NULL,
  p_description   TEXT DEFAULT NULL,
  p_address_line  TEXT DEFAULT NULL,
  p_city          TEXT DEFAULT NULL,
  p_state         TEXT DEFAULT NULL,
  p_pincode       TEXT DEFAULT NULL,
  p_latitude      DOUBLE PRECISION DEFAULT NULL,
  p_longitude     DOUBLE PRECISION DEFAULT NULL,
  p_category      TEXT DEFAULT 'salon',
  p_schedules     JSONB DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_store_id      UUID := update_partner_store.p_store_id;
  v_business_name TEXT := trim(update_partner_store.p_business_name);
  v_phone         TEXT := nullif(trim(update_partner_store.p_phone), '');
  v_whatsapp      TEXT := nullif(trim(update_partner_store.p_whatsapp), '');
  v_email         TEXT := nullif(trim(update_partner_store.p_email), '');
  v_description   TEXT := nullif(trim(update_partner_store.p_description), '');
  v_address_line  TEXT := nullif(trim(update_partner_store.p_address_line), '');
  v_city          TEXT := nullif(trim(update_partner_store.p_city), '');
  v_state         TEXT := nullif(trim(update_partner_store.p_state), '');
  v_pincode       TEXT := nullif(trim(update_partner_store.p_pincode), '');
  v_category      TEXT := coalesce(nullif(trim(update_partner_store.p_category), ''), 'salon');
  updated_row     partners%ROWTYPE;
BEGIN
  PERFORM assert_partner_store_owned(p_account_id, p_login_pass, v_store_id);

  IF v_business_name = '' THEN
    RAISE EXCEPTION 'Business name is required';
  END IF;

  IF v_phone IS NULL OR length(v_phone) <> 10 THEN
    RAISE EXCEPTION 'Phone must be 10 digits';
  END IF;

  IF v_whatsapp IS NULL OR length(v_whatsapp) <> 10 THEN
    RAISE EXCEPTION 'WhatsApp must be 10 digits';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM partner_categories pc
    WHERE pc.slug = v_category AND pc.is_active
  ) THEN
    v_category := 'salon';
  END IF;

  UPDATE partners SET
    business_name = v_business_name,
    phone = v_phone,
    whatsapp = v_whatsapp,
    email = v_email,
    description = v_description,
    address_line = v_address_line,
    city = v_city,
    state = v_state,
    pincode = v_pincode,
    latitude = p_latitude,
    longitude = p_longitude,
    category = v_category
  WHERE id = v_store_id
  RETURNING * INTO updated_row;

  IF p_schedules IS NOT NULL THEN
    PERFORM save_partner_schedules(updated_row.id, p_schedules);
  END IF;

  RETURN json_build_object(
    'id', updated_row.id,
    'account_id', updated_row.account_id,
    'business_name', updated_row.business_name,
    'owner_name', updated_row.owner_name,
    'phone', updated_row.phone,
    'whatsapp', updated_row.whatsapp,
    'alternate_phone', updated_row.alternate_phone,
    'email', updated_row.email,
    'description', updated_row.description,
    'address_line', updated_row.address_line,
    'city', updated_row.city,
    'state', updated_row.state,
    'pincode', updated_row.pincode,
    'latitude', updated_row.latitude,
    'longitude', updated_row.longitude,
    'category', updated_row.category,
    'is_active', updated_row.is_active,
    'kyc_status', updated_row.kyc_status,
    'primary_image', updated_row.primary_image,
    'created_at', updated_row.created_at,
    'schedules', partner_schedules_json(updated_row.id)
  );
END;
$$;

CREATE OR REPLACE FUNCTION list_partner_stores(
  p_account_id UUID,
  p_login_pass TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_account_id UUID := list_partner_stores.p_account_id;
BEGIN
  PERFORM assert_partner_account_access(v_account_id, p_login_pass);

  RETURN COALESCE((
    SELECT json_agg(row_to_json(t) ORDER BY t.created_at DESC)
    FROM (
      SELECT
        p.id,
        p.account_id,
        p.business_name,
        p.owner_name,
        p.phone,
        p.whatsapp,
        p.alternate_phone,
        p.email,
        p.description,
        p.address_line,
        p.city,
        p.state,
        p.pincode,
        p.latitude,
        p.longitude,
        p.category,
        p.is_active,
        p.kyc_status,
        p.primary_image,
        p.created_at,
        partner_schedules_json(p.id) AS schedules
      FROM partners p
      WHERE p.account_id = v_account_id
    ) t
  ), '[]'::json);
END;
$$;

CREATE OR REPLACE FUNCTION get_partner_store(
  p_account_id UUID,
  p_login_pass TEXT,
  p_store_id   UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  store_row partners%ROWTYPE;
BEGIN
  store_row := assert_partner_store_owned(p_account_id, p_login_pass, p_store_id);

  RETURN json_build_object(
    'id', store_row.id,
    'account_id', store_row.account_id,
    'business_name', store_row.business_name,
    'owner_name', store_row.owner_name,
    'phone', store_row.phone,
    'whatsapp', store_row.whatsapp,
    'alternate_phone', store_row.alternate_phone,
    'email', store_row.email,
    'description', store_row.description,
    'address_line', store_row.address_line,
    'city', store_row.city,
    'state', store_row.state,
    'pincode', store_row.pincode,
    'latitude', store_row.latitude,
    'longitude', store_row.longitude,
    'category', store_row.category,
    'is_active', store_row.is_active,
    'kyc_status', store_row.kyc_status,
    'primary_image', store_row.primary_image,
    'images', store_row.images,
    'created_at', store_row.created_at,
    'schedules', partner_schedules_json(store_row.id)
  );
END;
$$;

-- ── Admin RPCs ────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION create_partner(
  caller_id         TEXT,
  business_name     TEXT,
  owner_name        TEXT,
  phone             TEXT DEFAULT NULL,
  email             TEXT DEFAULT NULL,
  whatsapp          TEXT DEFAULT NULL,
  alternate_phone   TEXT DEFAULT NULL,
  city              TEXT DEFAULT NULL,
  state             TEXT DEFAULT NULL,
  pincode           TEXT DEFAULT NULL,
  category          TEXT DEFAULT 'salon',
  address_line      TEXT DEFAULT NULL,
  description       TEXT DEFAULT NULL,
  gst_number        TEXT DEFAULT NULL,
  website           TEXT DEFAULT NULL,
  google_map_embed  TEXT DEFAULT NULL,
  latitude          DOUBLE PRECISION DEFAULT NULL,
  longitude         DOUBLE PRECISION DEFAULT NULL,
  notes             TEXT DEFAULT NULL,
  account_id        UUID DEFAULT NULL,
  schedules         JSONB DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_business_name    TEXT := trim(create_partner.business_name);
  v_owner_name       TEXT := trim(create_partner.owner_name);
  v_phone            TEXT := nullif(trim(create_partner.phone), '');
  v_email            TEXT := nullif(trim(create_partner.email), '');
  v_whatsapp         TEXT := nullif(trim(create_partner.whatsapp), '');
  v_alternate_phone  TEXT := nullif(trim(create_partner.alternate_phone), '');
  v_city             TEXT := nullif(trim(create_partner.city), '');
  v_state            TEXT := nullif(trim(create_partner.state), '');
  v_pincode          TEXT := nullif(trim(create_partner.pincode), '');
  v_category         TEXT := coalesce(nullif(trim(create_partner.category), ''), 'salon');
  v_address_line     TEXT := nullif(trim(create_partner.address_line), '');
  v_description      TEXT := nullif(trim(create_partner.description), '');
  v_gst_number       TEXT := nullif(trim(create_partner.gst_number), '');
  v_website          TEXT := nullif(trim(create_partner.website), '');
  v_google_map_embed TEXT := nullif(trim(create_partner.google_map_embed), '');
  v_latitude         DOUBLE PRECISION := create_partner.latitude;
  v_longitude        DOUBLE PRECISION := create_partner.longitude;
  v_notes            TEXT := nullif(trim(create_partner.notes), '');
  v_account_id       UUID := create_partner.account_id;
  account_row        partner_accounts%ROWTYPE;
  new_row            partners%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF v_business_name = '' THEN
    RAISE EXCEPTION 'Business name is required';
  END IF;

  IF v_account_id IS NULL THEN
    IF v_owner_name = '' THEN
      RAISE EXCEPTION 'Owner name is required';
    END IF;

    INSERT INTO partner_accounts (
      owner_name, phone, email, whatsapp, alternate_phone, login_id
    ) VALUES (
      v_owner_name, v_phone, v_email, v_whatsapp, v_alternate_phone, v_phone
    )
    RETURNING * INTO account_row;

    v_account_id := account_row.id;
  ELSE
    IF NOT EXISTS (SELECT 1 FROM partner_accounts a WHERE a.id = v_account_id) THEN
      RAISE EXCEPTION 'Account not found';
    END IF;

    SELECT * INTO account_row FROM partner_accounts a WHERE a.id = v_account_id;
    v_owner_name := account_row.owner_name;
    v_phone := account_row.phone;
    v_email := account_row.email;
    v_whatsapp := account_row.whatsapp;
    v_alternate_phone := account_row.alternate_phone;
  END IF;

  INSERT INTO partners (
    account_id, business_name, owner_name, phone, email, whatsapp, alternate_phone,
    city, state, pincode, category, address_line, description,
    gst_number, website, google_map_embed, latitude, longitude, notes
  ) VALUES (
    v_account_id, v_business_name, v_owner_name, v_phone, v_email, v_whatsapp, v_alternate_phone,
    v_city, v_state, v_pincode, v_category, v_address_line, v_description,
    v_gst_number, v_website, v_google_map_embed, v_latitude, v_longitude, v_notes
  )
  RETURNING * INTO new_row;

  PERFORM save_partner_schedules(new_row.id, schedules);

  RETURN row_to_json(new_row);
END;
$$;

CREATE OR REPLACE FUNCTION update_partner(
  caller_id         TEXT,
  partner_id        UUID,
  business_name     TEXT,
  owner_name        TEXT,
  phone             TEXT DEFAULT NULL,
  email             TEXT DEFAULT NULL,
  whatsapp          TEXT DEFAULT NULL,
  alternate_phone   TEXT DEFAULT NULL,
  city              TEXT DEFAULT NULL,
  state             TEXT DEFAULT NULL,
  pincode           TEXT DEFAULT NULL,
  category          TEXT DEFAULT 'salon',
  address_line      TEXT DEFAULT NULL,
  description       TEXT DEFAULT NULL,
  gst_number        TEXT DEFAULT NULL,
  website           TEXT DEFAULT NULL,
  google_map_embed  TEXT DEFAULT NULL,
  latitude          DOUBLE PRECISION DEFAULT NULL,
  longitude         DOUBLE PRECISION DEFAULT NULL,
  notes             TEXT DEFAULT NULL,
  account_id        UUID DEFAULT NULL,
  schedules         JSONB DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_partner_id       UUID := update_partner.partner_id;
  v_business_name    TEXT := trim(update_partner.business_name);
  v_owner_name       TEXT := trim(update_partner.owner_name);
  v_phone            TEXT := nullif(trim(update_partner.phone), '');
  v_email            TEXT := nullif(trim(update_partner.email), '');
  v_whatsapp         TEXT := nullif(trim(update_partner.whatsapp), '');
  v_alternate_phone  TEXT := nullif(trim(update_partner.alternate_phone), '');
  v_city             TEXT := nullif(trim(update_partner.city), '');
  v_state            TEXT := nullif(trim(update_partner.state), '');
  v_pincode          TEXT := nullif(trim(update_partner.pincode), '');
  v_category         TEXT := coalesce(nullif(trim(update_partner.category), ''), 'salon');
  v_address_line     TEXT := nullif(trim(update_partner.address_line), '');
  v_description      TEXT := nullif(trim(update_partner.description), '');
  v_gst_number       TEXT := nullif(trim(update_partner.gst_number), '');
  v_website          TEXT := nullif(trim(update_partner.website), '');
  v_google_map_embed TEXT := nullif(trim(update_partner.google_map_embed), '');
  v_latitude         DOUBLE PRECISION := update_partner.latitude;
  v_longitude        DOUBLE PRECISION := update_partner.longitude;
  v_notes            TEXT := nullif(trim(update_partner.notes), '');
  v_account_id       UUID;
  updated_row        partners%ROWTYPE;
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  IF v_business_name = '' OR v_owner_name = '' THEN
    RAISE EXCEPTION 'Business name and owner name are required';
  END IF;

  SELECT p.account_id INTO v_account_id
  FROM partners p
  WHERE p.id = v_partner_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Partner not found';
  END IF;

  UPDATE partners SET
    business_name = v_business_name,
    owner_name = v_owner_name,
    phone = v_phone,
    email = v_email,
    whatsapp = v_whatsapp,
    alternate_phone = v_alternate_phone,
    city = v_city,
    state = v_state,
    pincode = v_pincode,
    category = v_category,
    address_line = v_address_line,
    description = v_description,
    gst_number = v_gst_number,
    website = v_website,
    google_map_embed = v_google_map_embed,
    latitude = v_latitude,
    longitude = v_longitude,
    notes = v_notes
  WHERE id = v_partner_id
  RETURNING * INTO updated_row;

  IF schedules IS NOT NULL THEN
    PERFORM save_partner_schedules(updated_row.id, schedules);
  END IF;

  IF v_account_id IS NOT NULL THEN
    UPDATE partner_accounts pa SET
      owner_name = v_owner_name,
      phone = coalesce(v_phone, pa.phone),
      email = v_email,
      whatsapp = v_whatsapp,
      alternate_phone = v_alternate_phone
    WHERE pa.id = v_account_id;
  END IF;

  RETURN row_to_json(updated_row);
END;
$$;

-- Include schedules in admin list
CREATE OR REPLACE FUNCTION list_partners(caller_id TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM assert_admin_partner_access(caller_id);

  RETURN COALESCE((
    SELECT json_agg(row_to_json(t) ORDER BY t.created_at DESC)
    FROM (
      SELECT
        p.id,
        p.account_id,
        p.business_name,
        p.owner_name,
        p.phone,
        p.email,
        p.whatsapp,
        p.alternate_phone,
        p.city,
        p.state,
        p.pincode,
        p.category,
        pc.name AS category_name,
        p.address_line,
        p.description,
        p.gst_number,
        p.website,
        p.google_map_embed,
        p.latitude,
        p.longitude,
        p.notes,
        p.is_active,
        p.kyc_status,
        p.login_id,
        (p.pass IS NOT NULL AND p.pass <> '') AS has_password,
        p.primary_image,
        p.images,
        p.created_at,
        a.phone AS account_phone,
        a.whatsapp AS account_whatsapp,
        (
          SELECT count(*)::int
          FROM partners p2
          WHERE p2.account_id = p.account_id
        ) AS store_count,
        partner_schedules_json(p.id) AS schedules
      FROM partners p
      LEFT JOIN partner_categories pc ON pc.slug = p.category
      LEFT JOIN partner_accounts a ON a.id = p.account_id
    ) t
  ), '[]'::json);
END;
$$;

GRANT EXECUTE ON FUNCTION partner_schedules_json(UUID) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION save_partner_schedules(UUID, JSONB) TO anon, authenticated, service_role;

DO $$
BEGIN
  GRANT EXECUTE ON FUNCTION create_partner_store(
    UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, JSONB
  ) TO anon, authenticated, service_role;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
  GRANT EXECUTE ON FUNCTION update_partner_store(
    UUID, TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, JSONB
  ) TO anon, authenticated, service_role;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
  GRANT EXECUTE ON FUNCTION create_partner(
    TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, UUID, JSONB
  ) TO anon, authenticated, service_role;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
  GRANT EXECUTE ON FUNCTION update_partner(
    TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, JSONB
  ) TO anon, authenticated, service_role;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

NOTIFY pgrst, 'reload schema';
