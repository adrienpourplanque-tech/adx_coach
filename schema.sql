-- ADX COACH — schéma Supabase
-- À exécuter dans : Supabase Dashboard > SQL Editor > New query
-- Projet Supabase dédié recommandé (séparé de qrlink)

-- ============ PROFILS ============
-- Complète auth.users (géré par Supabase Auth) avec les infos propres à l'app
create table profiles (
  id uuid references auth.users on delete cascade primary key,
  email text,
  prenom text,
  sports text[] default '{}',        -- ex: ['course','velo','natation','triathlon','trail']
  is_admin boolean default false,
  created_at timestamptz default now()
);

alter table profiles enable row level security;

-- Chacun voit et modifie son propre profil
create policy "profil visible par soi-même"
  on profiles for select using (auth.uid() = id);
create policy "profil modifiable par soi-même"
  on profiles for update using (auth.uid() = id);
create policy "profil créé par soi-même"
  on profiles for insert with check (auth.uid() = id);

-- L'admin voit tous les profils (liste des inscrits + emails)
create policy "admin voit tous les profils"
  on profiles for select using (
    exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin = true)
  );

-- ============ COURSES (base virtuelle, partagée) ============
create table races (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  type text,              -- 'route' | 'trail' | 'triathlon'
  format text,             -- '10km','semi','marathon','S','M','L','XL'...
  distance_km numeric,
  dplus_m numeric,
  swim_km numeric,         -- si triathlon
  bike_km numeric,         -- si triathlon
  run_km numeric,          -- si triathlon
  location text,
  race_date date,
  gpx_url text,
  source text,             -- 'verifiee' | 'saisie manuelle'
  created_by uuid references profiles(id),
  created_at timestamptz default now()
);

alter table races enable row level security;
create policy "courses lisibles par tous les connectés"
  on races for select using (auth.uid() is not null);
create policy "courses ajoutables par tous les connectés"
  on races for insert with check (auth.uid() is not null);

-- ============ OBJECTIF PRINCIPAL DE CHAQUE ATHLÈTE ============
create table goals (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references profiles(id) on delete cascade not null,
  race_id uuid references races(id),
  custom_name text,        -- si la course n'est pas dans la base
  custom_date date,
  mode text,                -- 'single' | 'triathlon'
  disc text,                 -- pour 'single'
  dist_km numeric,
  swim_km numeric, bike_km numeric, run_km numeric,   -- pour 'triathlon'
  created_at timestamptz default now()
);
alter table goals enable row level security;
create policy "objectif géré par son propriétaire"
  on goals for all using (auth.uid() = user_id);

-- ============ PERFORMANCES / SÉANCES LOGUÉES ============
create table entries (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references profiles(id) on delete cascade not null,
  date date not null,
  disciplines text[],
  distance_km numeric,
  duree text,
  fc_moy int, fc_max int,
  dplus_m numeric,
  rpe int,
  contexte text[],
  meteo text,
  note text,
  created_at timestamptz default now()
);
alter table entries enable row level security;
create policy "séances gérées par leur propriétaire"
  on entries for all using (auth.uid() = user_id);

-- ============ PLAN D'ENTRAÎNEMENT ============
create table program_sessions (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references profiles(id) on delete cascade not null,
  day_label text,
  disc text,
  title text,
  warmup text, main text, cooldown text,
  duration text, pace text, log_hint text,
  done boolean default false,
  rpe int, fc int, vitesse text, note text,
  created_at timestamptz default now()
);
alter table program_sessions enable row level security;
create policy "plan géré par son propriétaire"
  on program_sessions for all using (auth.uid() = user_id);

-- ============ MATÉRIEL ============
create table gear (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references profiles(id) on delete cascade not null,
  name text, status text, note text,
  created_at timestamptz default now()
);
alter table gear enable row level security;
create policy "matériel géré par son propriétaire"
  on gear for all using (auth.uid() = user_id);

-- ============ SEED : quelques courses connues pour démarrer ============
insert into races (name, type, format, distance_km, source) values
  ('Marathon de Paris', 'route', 'marathon', 42.195, 'verifiee'),
  ('Marathon de Lille', 'route', 'marathon', 42.195, 'verifiee'),
  ('Semi-marathon de Paris', 'route', 'semi', 21.0975, 'verifiee'),
  ('EmbrunMan', 'triathlon', 'XL', null, 'verifiee'),
  ('Ironman France (Nice)', 'triathlon', 'XL', null, 'verifiee');
update races set swim_km=3.8, bike_km=180, run_km=42.195, distance_km=225.995
  where name in ('EmbrunMan','Ironman France (Nice)');

-- ============ PREMIER COMPTE ADMIN ============
-- Après avoir créé ton compte normalement via la page d'inscription du site,
-- récupère ton user id (Supabase Dashboard > Authentication > Users), puis lance :
-- update profiles set is_admin = true where id = 'TON-UUID-ICI';
