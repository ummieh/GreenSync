-- =====================================================================
-- GreenSync  |  Supabase schema v1
-- Run in: Supabase Dashboard > SQL Editor (one go, top to bottom).
-- Money is stored as numeric(12,2). Currency is assumed to be NGN.
-- =====================================================================

-- ---------- 1. ENUMS -------------------------------------------------
create type user_role        as enum ('user', 'vendor', 'admin');
create type approval_status  as enum ('pending', 'approved', 'rejected');
create type request_status   as enum ('pending', 'accepted', 'completed', 'cancelled');
create type product_status   as enum ('active', 'sold_out', 'removed');
create type order_status     as enum ('placed', 'confirmed', 'completed', 'cancelled');
create type fulfilment_type  as enum ('pickup', 'delivery');
create type transaction_kind as enum ('collection_payout', 'order_payment');
create type payment_status   as enum ('pending', 'paid', 'failed');
create type resource_type    as enum ('article', 'video', 'tip');

-- ---------- 2. TABLES ------------------------------------------------

-- One row per signed-up person. Created automatically (see trigger below).
create table profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text,
  phone       text,
  avatar_path text,
  role        user_role not null default 'user',
  created_at  timestamptz not null default now()
);

-- Business details a user submits to become a vendor.
create table vendor_profiles (
  user_id       uuid primary key references profiles(id) on delete cascade,
  business_name text not null,
  phone         text,
  service_area  text,
  status        approval_status not null default 'pending',
  created_at    timestamptz not null default now()
);

-- Shared by pickup items, marketplace products and recycling centres.
create table categories (
  id   int generated always as identity primary key,
  name text not null unique,
  icon text
);

create table recycling_centres (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  address         text not null,
  phone           text,
  description     text,
  image_path      text,
  latitude        double precision,
  longitude       double precision,
  operating_hours jsonb not null default '{}',
  is_active       boolean not null default true,
  created_at      timestamptz not null default now()
);

create table recycling_centre_categories (
  centre_id   uuid not null references recycling_centres(id) on delete cascade,
  category_id int  not null references categories(id) on delete cascade,
  primary key (centre_id, category_id)
);

create table educational_resources (
  id           uuid primary key default gen_random_uuid(),
  type         resource_type not null default 'article',
  title        text not null,
  body         text,
  media_url    text,
  cover_path   text,
  author_name  text,
  is_featured  boolean not null default false,
  is_published boolean not null default false,
  created_at   timestamptz not null default now()
);

-- Waste pickup requests (user -> vendor).
create table collection_requests (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references profiles(id) on delete cascade,
  vendor_id        uuid references profiles(id) on delete set null,
  status           request_status not null default 'pending',
  scheduled_date   timestamptz not null,
  address          text not null,
  phone            text,
  latitude         double precision,
  longitude        double precision,
  photo_path       text,
  notes            text,
  actual_weight_kg numeric(10,2),   -- filled by vendor on completion
  price_per_kg     numeric(12,2),   -- filled by vendor on completion
  completed_at     timestamptz,
  created_at       timestamptz not null default now(),
  check (vendor_id is null or vendor_id <> user_id)
);

create table collection_request_items (
  id                 uuid primary key default gen_random_uuid(),
  request_id         uuid not null references collection_requests(id) on delete cascade,
  category_id        int  not null references categories(id),
  estimated_weight_kg numeric(10,2) not null check (estimated_weight_kg > 0),
  quantity           int not null default 1 check (quantity > 0)
);

-- Points are an append-only ledger (positive = earned, negative = spent).
-- The balance is always SUM(points); it can never drift out of sync.
create table points_ledger (
  id                    bigint generated always as identity primary key,
  user_id               uuid not null references profiles(id) on delete cascade,
  points                int  not null check (points <> 0),
  reason                text not null,
  collection_request_id uuid references collection_requests(id) on delete set null,
  created_at            timestamptz not null default now()
);

-- Redeemable rewards catalogue.
create table rewards (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  description  text,
  image_path   text,
  points_cost  int  not null check (points_cost > 0),
  sponsor_name text,
  stock        int check (stock is null or stock >= 0),  -- null = unlimited
  valid_until  date,
  is_active    boolean not null default true
);

create table reward_redemptions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references profiles(id) on delete cascade,
  reward_id    uuid not null references rewards(id),
  points_spent int  not null,
  created_at   timestamptz not null default now()
);

-- Marketplace listings: any signed-in user can be a seller.
create table products (
  id                 uuid primary key default gen_random_uuid(),
  seller_id          uuid not null references profiles(id) on delete cascade,
  category_id        int  not null references categories(id),
  title              text not null,
  description        text,
  price              numeric(12,2) not null check (price >= 0),   -- per unit
  unit               text not null default 'kg',
  quantity_available numeric(10,2) not null check (quantity_available >= 0),
  location           text,
  image_paths        text[] not null default '{}',
  status             product_status not null default 'active',
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create table cart_items (
  user_id    uuid not null references profiles(id) on delete cascade,
  product_id uuid not null references products(id) on delete cascade,
  quantity   numeric(10,2) not null check (quantity > 0),
  primary key (user_id, product_id)
);

-- One order per seller (a mixed cart is split by place_orders_from_cart).
create table orders (
  id               uuid primary key default gen_random_uuid(),
  buyer_id         uuid not null references profiles(id),
  seller_id        uuid not null references profiles(id),
  status           order_status not null default 'placed',
  fulfilment       fulfilment_type not null,
  delivery_address text,
  note             text,
  total_amount     numeric(12,2) not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  check (buyer_id <> seller_id)
);

-- title and unit_price are snapshots: later edits to a listing never alter past orders.
create table order_items (
  id         uuid primary key default gen_random_uuid(),
  order_id   uuid not null references orders(id) on delete cascade,
  product_id uuid references products(id) on delete set null,
  title      text not null,
  unit_price numeric(12,2) not null,
  quantity   numeric(10,2) not null check (quantity > 0)
);

-- Payment records. Written only by the database functions below.
-- provider / provider_reference stay empty until Phase 6 decides the payment flow.
create table transactions (
  id                    uuid primary key default gen_random_uuid(),
  kind                  transaction_kind not null,
  payer_id              uuid not null references profiles(id),
  payee_id              uuid not null references profiles(id),
  amount                numeric(12,2) not null check (amount >= 0),
  status                payment_status not null default 'pending',
  collection_request_id uuid references collection_requests(id),
  order_id              uuid references orders(id),
  provider              text,
  provider_reference    text,
  created_at            timestamptz not null default now(),
  check (
    (kind = 'collection_payout' and collection_request_id is not null and order_id is null) or
    (kind = 'order_payment'     and order_id is not null and collection_request_id is null)
  )
);

create table product_reviews (
  id          uuid primary key default gen_random_uuid(),
  product_id  uuid not null references products(id) on delete cascade,
  reviewer_id uuid not null references profiles(id) on delete cascade,
  rating      smallint not null check (rating between 1 and 5),
  comment     text,
  created_at  timestamptz not null default now(),
  unique (product_id, reviewer_id)
);

-- ---------- 3. INDEXES ----------------------------------------------
create index on collection_requests (status);
create index on collection_requests (user_id);
create index on collection_requests (vendor_id);
create index on collection_request_items (request_id);
create index on points_ledger (user_id);
create index on products (seller_id);
create index on products (category_id);
create index on products (status);
create index on orders (buyer_id);
create index on orders (seller_id);
create index on order_items (order_id);
create index on transactions (payer_id);
create index on transactions (payee_id);

-- ---------- 4. HELPER FUNCTIONS & TRIGGERS --------------------------

create function is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

create function is_vendor() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'vendor');
$$;

-- Create a profile row whenever someone signs up (email or Google).
create function handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'));
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- Nobody can promote themselves. (Edits made in the Dashboard have no
-- auth.uid(), so you, the owner, can still set roles by hand.)
create function protect_profile_role() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.role is distinct from old.role and auth.uid() is not null and not public.is_admin() then
    raise exception 'Only an admin can change a role';
  end if;
  return new;
end $$;

create trigger profiles_protect_role
  before update on profiles
  for each row execute function protect_profile_role();

-- Approving a vendor application flips the profile role automatically.
create function sync_vendor_role() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'approved' then
    update public.profiles set role = 'vendor' where id = new.user_id and role = 'user';
  elsif old.status = 'approved' then
    update public.profiles set role = 'user' where id = new.user_id and role = 'vendor';
  end if;
  return new;
end $$;

create trigger vendor_status_sync_role
  after update of status on vendor_profiles
  for each row execute function sync_vendor_role();

create function set_updated_at() returns trigger
language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

create trigger products_updated_at before update on products
  for each row execute function set_updated_at();
create trigger orders_updated_at before update on orders
  for each row execute function set_updated_at();

-- ---------- 5. BUSINESS FUNCTIONS (called from Flutter with .rpc()) -
-- State changes that involve money, points or stock go through these
-- functions so the app can never set its own price, points or stock.

-- Vendor accepts a pending pickup.
create function accept_collection_request(p_request_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_vendor() then
    raise exception 'Only approved vendors can accept pickups';
  end if;
  update public.collection_requests
     set status = 'accepted', vendor_id = auth.uid()
   where id = p_request_id and status = 'pending' and user_id <> auth.uid();
  if not found then
    raise exception 'This request is no longer available';
  end if;
end $$;

-- Vendor completes a pickup: records weight/price, awards points, logs the payout.
create function complete_collection_request(p_request_id uuid, p_weight_kg numeric, p_price_per_kg numeric)
returns void language plpgsql security definer set search_path = '' as $$
declare
  r public.collection_requests;
  v_points int;
begin
  if p_weight_kg <= 0 or p_price_per_kg < 0 then
    raise exception 'Invalid weight or price';
  end if;

  select * into r from public.collection_requests
   where id = p_request_id and vendor_id = auth.uid() and status = 'accepted'
   for update;
  if not found then
    raise exception 'Request not found, or it is not assigned to you';
  end if;

  update public.collection_requests
     set status = 'completed', actual_weight_kg = p_weight_kg,
         price_per_kg = p_price_per_kg, completed_at = now()
   where id = r.id;

  v_points := floor(p_weight_kg * 10)::int;   -- PLACEHOLDER RULE: 10 points per kg
  if v_points > 0 then
    insert into public.points_ledger (user_id, points, reason, collection_request_id)
    values (r.user_id, v_points, 'Pickup completed', r.id);
  end if;

  insert into public.transactions (kind, payer_id, payee_id, amount, collection_request_id)
  values ('collection_payout', auth.uid(), r.user_id, round(p_weight_kg * p_price_per_kg, 2), r.id);
end $$;

-- Turn the caller's cart into orders (one per seller), using SERVER-side prices.
create function place_orders_from_cart(
  p_fulfilment fulfilment_type,
  p_address text default null,
  p_note text default null
) returns uuid[] language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_seller uuid;
  v_order_id uuid;
  v_ids uuid[] := '{}';
begin
  if v_uid is null then raise exception 'Not signed in'; end if;
  if p_fulfilment = 'delivery' and coalesce(trim(p_address), '') = '' then
    raise exception 'A delivery address is required';
  end if;
  if not exists (select 1 from public.cart_items where user_id = v_uid) then
    raise exception 'Your cart is empty';
  end if;

  -- lock the products so two buyers cannot take the same stock
  perform 1 from public.products
   where id in (select product_id from public.cart_items where user_id = v_uid)
   for update;

  if exists (
    select 1 from public.cart_items c join public.products p on p.id = c.product_id
     where c.user_id = v_uid
       and (p.status <> 'active' or p.quantity_available < c.quantity or p.seller_id = v_uid)
  ) then
    raise exception 'Some items are unavailable, out of stock, or are your own listings';
  end if;

  for v_seller in
    select distinct p.seller_id from public.cart_items c
      join public.products p on p.id = c.product_id where c.user_id = v_uid
  loop
    insert into public.orders (buyer_id, seller_id, fulfilment, delivery_address, note)
    values (v_uid, v_seller, p_fulfilment, p_address, p_note)
    returning id into v_order_id;

    insert into public.order_items (order_id, product_id, title, unit_price, quantity)
    select v_order_id, p.id, p.title, p.price, c.quantity
      from public.cart_items c join public.products p on p.id = c.product_id
     where c.user_id = v_uid and p.seller_id = v_seller;

    update public.orders
       set total_amount = (select sum(unit_price * quantity) from public.order_items where order_id = v_order_id)
     where id = v_order_id;

    insert into public.transactions (kind, payer_id, payee_id, amount, order_id)
    select 'order_payment', buyer_id, seller_id, total_amount, id from public.orders where id = v_order_id;

    v_ids := v_ids || v_order_id;
  end loop;

  update public.products p
     set quantity_available = p.quantity_available - c.quantity,
         status = case when p.quantity_available - c.quantity <= 0 then 'sold_out' else p.status end
    from public.cart_items c
   where c.product_id = p.id and c.user_id = v_uid;

  delete from public.cart_items where user_id = v_uid;
  return v_ids;
end $$;

-- Seller: placed -> confirmed -> completed (or cancelled). Buyer: cancel while 'placed'.
-- Cancelling returns the stock.
create function update_order_status(p_order_id uuid, p_status order_status) returns void
language plpgsql security definer set search_path = '' as $$
declare
  o public.orders;
  v_uid uuid := auth.uid();
begin
  select * into o from public.orders where id = p_order_id for update;
  if not found then raise exception 'Order not found'; end if;

  if v_uid = o.seller_id then
    if not ((o.status = 'placed'    and p_status in ('confirmed', 'cancelled')) or
            (o.status = 'confirmed' and p_status in ('completed', 'cancelled'))) then
      raise exception 'Invalid status change';
    end if;
  elsif v_uid = o.buyer_id then
    if not (o.status = 'placed' and p_status = 'cancelled') then
      raise exception 'Buyers can only cancel an order that is still placed';
    end if;
  else
    raise exception 'Not allowed';
  end if;

  update public.orders set status = p_status where id = o.id;

  if p_status = 'cancelled' then
    update public.products p
       set quantity_available = p.quantity_available + oi.quantity,
           status = case when p.status = 'sold_out' then 'active' else p.status end
      from public.order_items oi
     where oi.order_id = o.id and oi.product_id = p.id;
  end if;
end $$;

-- Spend points on a reward.
create function redeem_reward(p_reward_id uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  rw public.rewards;
  v_balance int;
  v_id uuid;
begin
  if v_uid is null then raise exception 'Not signed in'; end if;
  perform pg_advisory_xact_lock(hashtext(v_uid::text));

  select * into rw from public.rewards
   where id = p_reward_id and is_active
     and (valid_until is null or valid_until >= current_date)
     and (stock is null or stock > 0)
   for update;
  if not found then raise exception 'Reward not available'; end if;

  select coalesce(sum(points), 0) into v_balance from public.points_ledger where user_id = v_uid;
  if v_balance < rw.points_cost then raise exception 'Not enough points'; end if;

  insert into public.reward_redemptions (user_id, reward_id, points_spent)
  values (v_uid, rw.id, rw.points_cost) returning id into v_id;

  insert into public.points_ledger (user_id, points, reason)
  values (v_uid, -rw.points_cost, 'Redeemed: ' || rw.title);

  if rw.stock is not null then
    update public.rewards set stock = stock - 1 where id = rw.id;
  end if;
  return v_id;
end $$;

-- Only signed-in users may call these.
revoke execute on function accept_collection_request(uuid)                         from public, anon;
revoke execute on function complete_collection_request(uuid, numeric, numeric)     from public, anon;
revoke execute on function place_orders_from_cart(fulfilment_type, text, text)     from public, anon;
revoke execute on function update_order_status(uuid, order_status)                 from public, anon;
revoke execute on function redeem_reward(uuid)                                     from public, anon;
grant  execute on function accept_collection_request(uuid)                         to authenticated;
grant  execute on function complete_collection_request(uuid, numeric, numeric)     to authenticated;
grant  execute on function place_orders_from_cart(fulfilment_type, text, text)     to authenticated;
grant  execute on function update_order_status(uuid, order_status)                 to authenticated;
grant  execute on function redeem_reward(uuid)                                     to authenticated;

-- ---------- 6. VIEWS ------------------------------------------------

-- Safe subset of profiles (no phone) so listings can show a seller's name.
-- Deliberately runs with the view owner's rights (bypasses profiles RLS).
create view public_profiles as
  select id, full_name, avatar_path from profiles;

create view user_points with (security_invoker = true) as
  select user_id, sum(points)::int as balance from points_ledger group by user_id;

create view product_ratings with (security_invoker = true) as
  select product_id, round(avg(rating), 1) as avg_rating, count(*)::int as rating_count
    from product_reviews group by product_id;

revoke all on public_profiles from anon;
grant select on public_profiles, user_points, product_ratings to authenticated;

-- ---------- 7. ROW LEVEL SECURITY -----------------------------------
alter table profiles                    enable row level security;
alter table vendor_profiles             enable row level security;
alter table categories                  enable row level security;
alter table recycling_centres           enable row level security;
alter table recycling_centre_categories enable row level security;
alter table educational_resources       enable row level security;
alter table collection_requests         enable row level security;
alter table collection_request_items    enable row level security;
alter table points_ledger               enable row level security;
alter table rewards                     enable row level security;
alter table reward_redemptions          enable row level security;
alter table products                    enable row level security;
alter table cart_items                  enable row level security;
alter table orders                      enable row level security;
alter table order_items                 enable row level security;
alter table transactions                enable row level security;
alter table product_reviews             enable row level security;

-- Admins can do everything on these tables.
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','vendor_profiles','categories','recycling_centres','recycling_centre_categories',
    'educational_resources','collection_requests','collection_request_items','points_ledger',
    'rewards','reward_redemptions','products','orders','order_items','transactions','product_reviews'
  ] loop
    execute format(
      'create policy "admin all" on %I for all to authenticated using (public.is_admin()) with check (public.is_admin())', t);
  end loop;
end $$;

-- profiles: you see and edit only yourself (role changes are blocked by trigger)
create policy "read own profile"   on profiles for select to authenticated using (id = auth.uid());
create policy "update own profile" on profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- vendor_profiles: apply once, edit while pending, approved vendors are visible to all
create policy "read approved or own vendor" on vendor_profiles for select to authenticated
  using (status = 'approved' or user_id = auth.uid());
create policy "apply as vendor" on vendor_profiles for insert to authenticated
  with check (user_id = auth.uid() and status = 'pending');
create policy "edit pending application" on vendor_profiles for update to authenticated
  using (user_id = auth.uid() and status = 'pending')
  with check (user_id = auth.uid() and status = 'pending');

-- reference data: read-only for everyone signed in
create policy "read categories" on categories for select to authenticated using (true);
create policy "read active centres" on recycling_centres for select to authenticated using (is_active);
create policy "read centre categories" on recycling_centre_categories for select to authenticated using (true);
create policy "read published resources" on educational_resources for select to authenticated using (is_published);
create policy "read active rewards" on rewards for select to authenticated using (is_active);

-- collection requests
create policy "read relevant requests" on collection_requests for select to authenticated
  using (user_id = auth.uid() or vendor_id = auth.uid() or (status = 'pending' and public.is_vendor()));
create policy "create own request" on collection_requests for insert to authenticated
  with check (user_id = auth.uid() and status = 'pending' and vendor_id is null
              and actual_weight_kg is null and price_per_kg is null);
create policy "cancel own pending request" on collection_requests for update to authenticated
  using (user_id = auth.uid() and status = 'pending')
  with check (user_id = auth.uid() and status in ('pending', 'cancelled') and vendor_id is null
              and actual_weight_kg is null and price_per_kg is null);

create policy "read items of visible requests" on collection_request_items for select to authenticated
  using (exists (select 1 from collection_requests r where r.id = request_id));
create policy "add items to own pending request" on collection_request_items for insert to authenticated
  with check (exists (select 1 from collection_requests r
                      where r.id = request_id and r.user_id = auth.uid() and r.status = 'pending'));
create policy "remove items from own pending request" on collection_request_items for delete to authenticated
  using (exists (select 1 from collection_requests r
                 where r.id = request_id and r.user_id = auth.uid() and r.status = 'pending'));

-- points and rewards: read your own; writes only via functions
create policy "read own points"      on points_ledger      for select to authenticated using (user_id = auth.uid());
create policy "read own redemptions" on reward_redemptions for select to authenticated using (user_id = auth.uid());

-- marketplace
create policy "read listings" on products for select to authenticated
  using (status <> 'removed' or seller_id = auth.uid());
create policy "create own listing" on products for insert to authenticated
  with check (seller_id = auth.uid());
create policy "edit own listing" on products for update to authenticated
  using (seller_id = auth.uid()) with check (seller_id = auth.uid());
create policy "delete own listing" on products for delete to authenticated
  using (seller_id = auth.uid());

create policy "manage own cart" on cart_items for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "read own orders" on orders for select to authenticated
  using (buyer_id = auth.uid() or seller_id = auth.uid());
create policy "read items of own orders" on order_items for select to authenticated
  using (exists (select 1 from orders o where o.id = order_id));
create policy "read own transactions" on transactions for select to authenticated
  using (payer_id = auth.uid() or payee_id = auth.uid());

-- reviews: only buyers of a completed order may review that product
create policy "read reviews" on product_reviews for select to authenticated using (true);
create policy "review purchased product" on product_reviews for insert to authenticated
  with check (
    reviewer_id = auth.uid() and exists (
      select 1 from order_items oi join orders o on o.id = oi.order_id
       where oi.product_id = product_reviews.product_id
         and o.buyer_id = auth.uid() and o.status = 'completed')
  );
create policy "edit own review" on product_reviews for update to authenticated
  using (reviewer_id = auth.uid()) with check (reviewer_id = auth.uid());
create policy "delete own review" on product_reviews for delete to authenticated
  using (reviewer_id = auth.uid());

-- ---------- 8. SEED DATA --------------------------------------------
insert into categories (name, icon) values
  ('Plastic', 'plastic'), ('Glass', 'glass'), ('Paper & Cardboard', 'paper'),
  ('Metal', 'metal'), ('Electronics', 'electronics'), ('Organic', 'organic'),
  ('Textiles', 'textiles');
