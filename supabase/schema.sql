-- Execute em um projeto Supabase novo. Não use dados reais até revisar políticas e configurar e-mails.
create table public.accounts (
 id uuid primary key references auth.users(id) on delete cascade,
 name text not null check (char_length(name) between 1 and 100), email text not null,
 role text not null default 'client' check (role in ('client','professional','admin')),
 active boolean not null default true, created_at timestamptz not null default now()
);
create table public.profiles (
 id uuid primary key default gen_random_uuid(), user_id uuid not null unique references public.accounts(id) on delete cascade,
 name text not null check (char_length(name) between 1 and 100),
 category text not null check (category in ('Modelo','Fotografia','Produção de eventos','Consultoria de imagem','Maquiagem','Criadora de conteúdo')),
 city text not null check (char_length(city) between 1 and 100), bio text not null check (char_length(bio) <= 2000),
 status text not null default 'pending' check (status in ('approved','pending','blocked')),
 featured boolean not null default false, photo text not null default '', media jsonb not null default '[]'::jsonb check (jsonb_typeof(media)='array' and jsonb_array_length(media)<=30),
 views bigint not null default 0 check (views>=0), created_at timestamptz not null default now()
);
create table public.favorites (id uuid primary key default gen_random_uuid(), user_id uuid not null references public.accounts(id) on delete cascade, profile_id uuid not null references public.profiles(id) on delete cascade, unique(user_id,profile_id));
create table public.transactions (id uuid primary key default gen_random_uuid(), description text not null check(char_length(description) between 1 and 120), kind text not null check(kind in ('income','expense')), amount numeric(14,2) not null check(amount>0), date date not null, created_at timestamptz not null default now());

create function public.privacyfly_role() returns text language sql stable security definer set search_path='' as $$ select role from public.accounts where id=auth.uid() and active $$;
revoke all on function public.privacyfly_role() from public;
grant execute on function public.privacyfly_role() to authenticated, anon;
create function public.create_account() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.accounts(id,name,email,role) values(new.id,left(coalesce(nullif(new.raw_user_meta_data->>'name',''),split_part(new.email,'@',1)),100),new.email,case when new.raw_user_meta_data->>'role'='professional' then 'professional' else 'client' end);
 return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.create_account();

alter table public.accounts enable row level security;
alter table public.profiles enable row level security;
alter table public.favorites enable row level security;
alter table public.transactions enable row level security;
grant select on public.accounts to authenticated;
grant select,insert,update on public.profiles to authenticated;
grant select,insert,delete on public.favorites to authenticated;
grant select,insert,update,delete on public.transactions to authenticated;
create policy own_account on public.accounts for select to authenticated using (id=auth.uid() or public.privacyfly_role()='admin');
create policy admin_account_update on public.accounts for update to authenticated using (public.privacyfly_role()='admin' and role<>'admin') with check(public.privacyfly_role()='admin' and role<>'admin');
revoke update on public.accounts from authenticated,anon;
grant update(active) on public.accounts to authenticated;
create policy profile_select on public.profiles for select to authenticated using (public.privacyfly_role()='admin' or (user_id=auth.uid() and public.privacyfly_role()='professional'));
create policy profile_insert on public.profiles for insert to authenticated with check (user_id=auth.uid() and public.privacyfly_role()='professional' and status='pending' and not featured and views=0);
create policy profile_update on public.profiles for update to authenticated using (public.privacyfly_role()='admin' or (user_id=auth.uid() and public.privacyfly_role()='professional' and status<>'blocked')) with check (public.privacyfly_role()='admin' or (user_id=auth.uid() and public.privacyfly_role()='professional' and status='pending'));
create function public.protect_profile() returns trigger language plpgsql set search_path='' as $$
begin
 if current_user in ('postgres','supabase_admin') then return new; end if;
 if new.user_id<>old.user_id or new.id<>old.id or new.views<>old.views then raise exception 'Campo protegido'; end if;
 if public.privacyfly_role()<>'admin' then
   if new.featured<>old.featured then raise exception 'Campo protegido'; end if;
   new.status:='pending';
 end if;
 return new;
end $$;
create trigger profile_protected_fields before update on public.profiles for each row execute function public.protect_profile();
-- View pública: expõe exclusivamente perfis aprovados de contas habilitadas.
create view public.public_profiles with (security_barrier=true) as select p.id,p.user_id,p.name,p.category,p.city,p.bio,p.status,p.featured,p.photo,p.media,p.views,p.created_at from public.profiles p join public.accounts a on a.id=p.user_id where p.status='approved' and a.active;
revoke all on public.public_profiles from public,anon,authenticated;
grant select on public.public_profiles to anon,authenticated;
create policy favorite_read on public.favorites for select to authenticated using (user_id=auth.uid() and public.privacyfly_role() is not null);
create policy favorite_add on public.favorites for insert to authenticated with check (user_id=auth.uid() and public.privacyfly_role() is not null and exists(select 1 from public.public_profiles p where p.id=profile_id));
create policy favorite_remove on public.favorites for delete to authenticated using (user_id=auth.uid() and public.privacyfly_role() is not null);
create policy admin_finance on public.transactions for all to authenticated using(public.privacyfly_role()='admin') with check(public.privacyfly_role()='admin');

-- Bucket privado: mídias não aprovadas não ficam acessíveis a visitantes.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('portfolio','portfolio',false,10485760,array['image/jpeg','image/png','image/webp','video/mp4','video/webm']);
create policy portfolio_upload on storage.objects for insert to authenticated with check(bucket_id='portfolio' and public.privacyfly_role()='professional' and (storage.foldername(name))[1]=auth.uid()::text);
create policy portfolio_read on storage.objects for select to anon,authenticated using(bucket_id='portfolio' and (public.privacyfly_role()='admin' or (public.privacyfly_role()='professional' and (storage.foldername(name))[1]=auth.uid()::text) or exists(select 1 from public.public_profiles p where p.user_id::text=(storage.foldername(storage.objects.name))[1] and (p.photo=storage.objects.name or exists(select 1 from jsonb_array_elements(p.media) m where m->>'url'=storage.objects.name)))));
create policy portfolio_delete on storage.objects for delete to authenticated using(bucket_id='portfolio' and (public.privacyfly_role()='admin' or (public.privacyfly_role()='professional' and (storage.foldername(name))[1]=auth.uid()::text)));
create function public.record_view(profile_id uuid) returns void language sql security definer set search_path='' as $$
 update public.profiles set views=views+1 where id=profile_id and status='approved' and exists(select 1 from public.accounts a where a.id=user_id and a.active);
$$;
revoke all on function public.record_view(uuid) from public;
grant execute on function public.record_view(uuid) to anon,authenticated;

-- Depois de criar e confirmar sua conta de administrador no Auth, execute manualmente:
-- update public.accounts set role='admin' where id='UUID_DA_CONTA';
