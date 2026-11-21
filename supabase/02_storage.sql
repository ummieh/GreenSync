-- =====================================================================
-- GreenSync  |  Supabase storage v1
-- Run AFTER 01_schema.sql, in the SQL Editor.
-- Safe to run more than once: existing policies are dropped and recreated.
--
-- Convention: every user upload lives under a folder named after the
-- user's id, e.g.  <user-id>/<filename>.jpg
-- The policies below check that first folder, so nobody can write into
-- someone else's folder.
-- =====================================================================

-- ---------- Buckets ---------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('avatars',        'avatars',        true,  2097152, array['image/jpeg','image/png','image/webp']),
  ('product-images', 'product-images', true,  5242880, array['image/jpeg','image/png','image/webp']),
  ('pickup-photos',  'pickup-photos',  false, 5242880, array['image/jpeg','image/png','image/webp']),
  ('content-images', 'content-images', true,  5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

-- Public buckets: anyone with the URL can VIEW the file (fine for avatars,
-- product photos and site content). Only the owner can upload/change/delete.
-- pickup-photos is private: only the owner and relevant vendors can read.

-- ---------- avatars / product-images: owner-only writes ---------------
do $$
declare b text;
begin
  foreach b in array array['avatars', 'product-images'] loop
    execute format('drop policy if exists %I on storage.objects', b || ': owner upload');
    execute format('drop policy if exists %I on storage.objects', b || ': owner update');
    execute format('drop policy if exists %I on storage.objects', b || ': owner delete');
    execute format($f$
      create policy "%1$s: owner upload" on storage.objects for insert to authenticated
        with check (bucket_id = %2$L and (storage.foldername(name))[1] = auth.uid()::text)$f$, b, b);
    execute format($f$
      create policy "%1$s: owner update" on storage.objects for update to authenticated
        using      (bucket_id = %2$L and (storage.foldername(name))[1] = auth.uid()::text)
        with check (bucket_id = %2$L and (storage.foldername(name))[1] = auth.uid()::text)$f$, b, b);
    execute format($f$
      create policy "%1$s: owner delete" on storage.objects for delete to authenticated
        using (bucket_id = %2$L and (storage.foldername(name))[1] = auth.uid()::text)$f$, b, b);
  end loop;
end $$;

-- ---------- pickup-photos: private ------------------------------------
drop policy if exists "pickup-photos: owner upload" on storage.objects;
drop policy if exists "pickup-photos: owner delete" on storage.objects;
drop policy if exists "pickup-photos: owner or relevant vendor read" on storage.objects;

create policy "pickup-photos: owner upload" on storage.objects for insert to authenticated
  with check (bucket_id = 'pickup-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "pickup-photos: owner delete" on storage.objects for delete to authenticated
  using (bucket_id = 'pickup-photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- Readable by the owner, or by a vendor who can see the request the photo is attached to.
-- (collection_requests RLS decides which requests a vendor may see.)
create policy "pickup-photos: owner or relevant vendor read" on storage.objects for select to authenticated
  using (
    bucket_id = 'pickup-photos' and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (select 1 from public.collection_requests r where r.photo_path = storage.objects.name)
    )
  );

-- ---------- content-images: admin-managed -----------------------------
-- Recycling centre photos, article covers and reward images.
drop policy if exists "content-images: admin write" on storage.objects;
create policy "content-images: admin write" on storage.objects for all to authenticated
  using      (bucket_id = 'content-images' and public.is_admin())
  with check (bucket_id = 'content-images' and public.is_admin());
