-- Makes your account an approved vendor so you can show the vendor screens.
-- 1. Replace YOUR_EMAIL below with the email you signed up with (keep the quotes).
-- 2. Run it in the SQL Editor, then in the app go to Profile and switch to vendor view.

insert into vendor_profiles (user_id, business_name, phone, service_area, status)
select id, 'GreenSync Collectors', null, 'Kano', 'pending'
from auth.users where email = 'YOUR_EMAIL'
on conflict (user_id) do nothing;

update vendor_profiles set status = 'approved'
where user_id = (select id from auth.users where email = 'YOUR_EMAIL');

-- Optional: give yourself 300 demo points so you can show redeeming a reward.
insert into points_ledger (user_id, points, reason)
select id, 300, 'Welcome bonus (demo)' from auth.users where email = 'YOUR_EMAIL';
