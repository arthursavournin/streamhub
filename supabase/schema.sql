-- Comptes StreamHub (version 2.0.0) : base Supabase.
-- Tout ce qui est stocké ici est chiffré sur l'appareil (account.js) : Supabase ne voit que des données illisibles.
--   vaults    : la clé du coffre (aléatoire), fermée deux fois : par le mot de passe et par la clé de secours
--   sync_data : les données synchronisées (réglages, J'aime, Ma liste, historique), chiffrées avec la clé du coffre

-- ---------- Coffre ----------

create table public.vaults (
  user_id uuid primary key references auth.users (id) on delete cascade,
  -- Paramètres de dérivation (version, itérations…), pour pouvoir les changer plus tard
  kdf jsonb not null check (jsonb_typeof(kdf) = 'object'),
  -- { iv, data } : clé du coffre chiffrée par la clé tirée du mot de passe
  password_lock jsonb not null check (jsonb_typeof(password_lock) = 'object'),
  -- { salt, iv, data } : clé du coffre chiffrée par la clé tirée de la clé de secours
  recovery_lock jsonb not null check (jsonb_typeof(recovery_lock) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- Données synchronisées ----------

create table public.sync_data (
  user_id uuid primary key references auth.users (id) on delete cascade,
  iv text not null,
  data text not null check (octet_length(data) <= 2000000),
  -- Augmente de 1 à chaque écriture : un appareil n'écrit que s'il a lu la dernière version
  version bigint not null default 1 check (version > 0),
  updated_at timestamptz not null default now()
);

-- updated_at tenu par la base
create function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
revoke execute on function public.touch_updated_at() from public, anon, authenticated;

create trigger vaults_touch before update on public.vaults
  for each row execute function public.touch_updated_at();
create trigger sync_data_touch before update on public.sync_data
  for each row execute function public.touch_updated_at();

-- ---------- Accès : chacun seulement sa ligne ----------

-- Les droits par défaut du schéma public donnent tout à anon et authenticated : on repart de zéro
revoke all on public.vaults, public.sync_data from anon, authenticated;
grant select, insert, update on public.vaults, public.sync_data to authenticated;

alter table public.vaults enable row level security;
alter table public.sync_data enable row level security;

create policy "Lire son coffre" on public.vaults for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Créer son coffre" on public.vaults for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Modifier son coffre" on public.vaults for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Lire ses données" on public.sync_data for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Créer ses données" on public.sync_data for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Modifier ses données" on public.sync_data for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- ---------- Supprimer son compte ----------

-- Supprime l'utilisateur connecté (et, en cascade, son coffre et ses données). security definer : un utilisateur
-- n'a pas le droit d'écrire dans auth.users ; la fonction ne touche qu'à la ligne de auth.uid().
create function public.delete_my_account()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from auth.users where id = (select auth.uid());
$$;
revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- ---------- Maintien en activité ----------

-- Appelée par le robot GitHub toutes les 6 h : le plan gratuit met le projet en pause après 7 jours sans activité.
-- Ne lit rien.
create function public.keepalive()
returns integer
language sql
stable
set search_path = ''
as $$
  select 1;
$$;
revoke execute on function public.keepalive() from public;
grant execute on function public.keepalive() to anon, authenticated;
