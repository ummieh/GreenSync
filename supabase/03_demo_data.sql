-- GreenSync demo data. Run AFTER 01_schema.sql and 02_storage.sql.
-- Safe to run more than once: each block only inserts when its table is empty.
-- Everything here is sample data for presenting the app.

-- ---------- Rewards ----------------------------------------------------
insert into rewards (title, description, points_cost, sponsor_name, stock)
select * from (values
  ('N500 airtime',        'Mobile airtime sent to your phone',        50,  'GreenSync',        200),
  ('Reusable tote bag',   'Durable bag made from recycled fabric',    120, 'EcoWear Kano',      50),
  ('N2,000 grocery voucher','Use at partner supermarkets',             250, 'FreshMart',         40),
  ('Tree planting',       'We plant a tree in your name',             80,  'Green Kano Trust', null),
  ('Reusable water bottle','Stainless steel, 750 ml',                 300, 'EcoWear Kano',      30),
  ('N5,000 cash reward',  'Paid to your bank account',                600, 'GreenSync',         20)
) as v(title, description, points_cost, sponsor_name, stock)
where not exists (select 1 from rewards);

-- ---------- Recycling centres -----------------------------------------
do $$
declare
  c1 uuid; c2 uuid; c3 uuid; c4 uuid;
begin
  if exists (select 1 from recycling_centres) then return; end if;

  insert into recycling_centres (name, address, phone, description, operating_hours)
  values ('Kano Central Recycling Hub', 'Zoo Road, Kano', '0803 000 0101',
          'Accepts plastics, glass, paper and metal. Weighing and instant payment on site.',
          '{"Mon-Fri": "8:00 - 17:00", "Sat": "9:00 - 14:00"}')
  returning id into c1;
  insert into recycling_centres (name, address, phone, description, operating_hours)
  values ('Sabon Gari Eco Point', 'Sabon Gari Market Road, Kano', '0803 000 0102',
          'Community drop-off point for bottles, cans and cardboard.',
          '{"Mon-Sat": "8:00 - 16:00"}')
  returning id into c2;
  insert into recycling_centres (name, address, phone, description, operating_hours)
  values ('Bompai E-Waste Centre', 'Bompai Industrial Estate, Kano', '0803 000 0103',
          'Safe collection of old phones, laptops, batteries and cables.',
          '{"Mon-Fri": "9:00 - 16:00"}')
  returning id into c3;
  insert into recycling_centres (name, address, phone, description, operating_hours)
  values ('Nasarawa Textile and Organic Hub', 'Nasarawa GRA, Kano', '0803 000 0104',
          'Takes used clothing and kitchen or garden waste for composting.',
          '{"Tue-Sat": "9:00 - 15:00"}')
  returning id into c4;

  insert into recycling_centre_categories (centre_id, category_id)
  select c1, id from categories where name in ('Plastic','Glass','Paper & Cardboard','Metal');
  insert into recycling_centre_categories (centre_id, category_id)
  select c2, id from categories where name in ('Plastic','Glass','Paper & Cardboard');
  insert into recycling_centre_categories (centre_id, category_id)
  select c3, id from categories where name in ('Electronics','Metal');
  insert into recycling_centre_categories (centre_id, category_id)
  select c4, id from categories where name in ('Textiles','Organic');
end $$;

-- ---------- Learn: articles and tips -----------------------------------
insert into educational_resources (type, title, body, author_name, is_featured, is_published)
select * from (values
  ('article'::resource_type, 'How to sort your waste at home',
   E'Keep three containers: one for plastics and metals, one for paper and cardboard, and one for organic waste.\n\nRinse bottles and cans before storing them. Clean material fetches a better price and is easier to recycle.\n\nKeep glass separate and wrap broken pieces so collectors are not hurt.',
   'GreenSync Team', true, true),
  ('tip'::resource_type, 'Plastic bottles: remove the cap and flatten',
   E'Caps are often a different plastic from the bottle. Remove them, empty the bottle, and flatten it to save space in your bag or bin.',
   'GreenSync Team', false, true),
  ('article'::resource_type, 'What happens to your recyclables?',
   E'Collected material is sorted, cleaned and shredded or melted. Plastic becomes pellets for new products, paper is pulped, glass is melted and remoulded, and metal is smelted.\n\nEvery kilogram you recycle keeps waste out of drains and open dumps.',
   'GreenSync Team', false, true),
  ('tip'::resource_type, 'Turn kitchen waste into compost',
   E'Peels, vegetable scraps and garden leaves can be composted in a covered pit or bin. Turn it every week and it becomes rich soil in about two months.',
   'GreenSync Team', false, true),
  ('article'::resource_type, 'Why e-waste needs special care',
   E'Old phones, batteries and cables contain metals that are harmful if burned or dumped. Take them to an e-waste centre instead of throwing them away.',
   'GreenSync Team', false, true)
) as v(type, title, body, author_name, is_featured, is_published)
where not exists (select 1 from educational_resources);

-- ---------- Demo seller, listings, pickup requests and one order ------
-- A pretend member who owns the sample listings and requests (nobody can log in as them).
do $$
declare
  demo uuid := '00000000-0000-4000-8000-00000000de01';
  me   uuid;
  r1 uuid; r2 uuid; r3 uuid; o1 uuid;
begin
  if not exists (select 1 from auth.users where id = demo) then
    insert into auth.users
      (instance_id, id, aud, role, email, encrypted_password,
       raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values
      ('00000000-0000-0000-0000-000000000000', demo, 'authenticated', 'authenticated',
       'demo.member@greensync.invalid', '',
       '{"provider":"email","providers":["email"]}',
       '{"full_name":"Amina Yusuf (demo)"}', now(), now());
  end if;

  -- Marketplace listings
  if not exists (select 1 from products where seller_id = demo) then
    insert into products (seller_id, category_id, title, description, price, unit, quantity_available, location)
    select demo, c.id, v.title, v.descr, v.price, v.unit, v.qty, v.loc
    from (values
      ('Plastic',           'Clean PET bottles',        'Rinsed and sorted, caps removed.',          120,  'kg',    250, 'Kano'),
      ('Plastic',           'HDPE containers',          'Jerrycans and detergent bottles.',          150,  'kg',    120, 'Kano'),
      ('Glass',             'Clear glass bottles',      'Whole bottles, labels removed.',             60,  'kg',    300, 'Sabon Gari'),
      ('Paper & Cardboard', 'Flattened cardboard',      'Dry cardboard boxes, baled.',                80,  'kg',    500, 'Nasarawa'),
      ('Paper & Cardboard', 'Mixed office paper',       'Shredded and loose paper.',                  70,  'kg',    200, 'Kano'),
      ('Metal',             'Aluminium cans',           'Crushed drink cans.',                       450,  'kg',     90, 'Bompai'),
      ('Metal',             'Scrap iron',               'Mixed scrap, mostly sheets.',               180,  'kg',    800, 'Dawakin Kudu'),
      ('Electronics',       'Used phone batteries',     'Mixed batteries for safe recycling.',      1500,  'bag',    15, 'Bompai'),
      ('Textiles',          'Used cotton clothing',     'Clean cotton clothes for reuse or rags.',    90,  'kg',    150, 'Nasarawa')
    ) as v(cat, title, descr, price, unit, qty, loc)
    join categories c on c.name = v.cat;
  end if;

  -- Open pickup requests that vendors can accept
  if not exists (select 1 from collection_requests where user_id = demo) then
    insert into collection_requests (user_id, scheduled_date, address, phone, notes)
    values (demo, now() + interval '1 day', '12 Ahmadu Bello Way, Nasarawa, Kano', '0803 111 2233',
            'Bags are by the gate.') returning id into r1;
    insert into collection_request_items (request_id, category_id, estimated_weight_kg)
    select r1, id, 8 from categories where name = 'Plastic';
    insert into collection_request_items (request_id, category_id, estimated_weight_kg)
    select r1, id, 5 from categories where name = 'Paper & Cardboard';

    insert into collection_requests (user_id, scheduled_date, address, phone)
    values (demo, now() + interval '2 days', '4 Zaria Road, Sabon Gari, Kano', '0803 444 5566')
    returning id into r2;
    insert into collection_request_items (request_id, category_id, estimated_weight_kg)
    select r2, id, 15 from categories where name = 'Glass';

    insert into collection_requests (user_id, scheduled_date, address, phone, notes)
    values (demo, now() + interval '3 days', 'Plot 7, Bompai Industrial Estate, Kano', '0803 777 8899',
            'Call before arriving.') returning id into r3;
    insert into collection_request_items (request_id, category_id, estimated_weight_kg)
    select r3, id, 20 from categories where name = 'Metal';
  end if;

  -- One incoming order for the oldest real account, so the vendor Orders tab has content
  select id into me from profiles where id <> demo order by created_at limit 1;
  if me is not null and not exists (select 1 from orders where buyer_id = demo) then
    insert into orders (buyer_id, seller_id, status, fulfilment, note, total_amount)
    values (demo, me, 'placed', 'pickup', 'I will collect on Saturday.', 6000)
    returning id into o1;
    insert into order_items (order_id, title, unit_price, quantity)
    values (o1, 'Clean PET bottles', 120, 30),
           (o1, 'Flattened cardboard', 80, 30);
  end if;
end $$;
