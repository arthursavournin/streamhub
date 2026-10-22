-- Ménage quotidien (3 h 30) : applique les durées de conservation annoncées dans la politique de confidentialité
-- (confidentialite.html). À coller dans Supabase → SQL Editor → Run.
--   - inscription jamais confirmée : supprimée après 7 jours
--   - session : supprimée 90 jours après sa dernière utilisation
--   - compte sans aucune activité (connexion, session, synchronisation) pendant 3 ans : supprimé (coffre et données
--     synchronisées partent avec lui : on delete cascade)

create extension if not exists pg_cron;

select cron.schedule('streamhub-menage', '30 3 * * *', $$
  delete from auth.users where email_confirmed_at is null and created_at < now() - interval '7 days';
  delete from auth.sessions where coalesce(refreshed_at, updated_at, created_at) < now() - interval '90 days';
  delete from auth.users u
   where coalesce(u.last_sign_in_at, u.created_at) < now() - interval '3 years'
     and not exists (select 1 from auth.sessions s where s.user_id = u.id
                     and coalesce(s.refreshed_at, s.updated_at, s.created_at) >= now() - interval '3 years')
     and not exists (select 1 from public.sync_data d where d.user_id = u.id
                     and d.updated_at >= now() - interval '3 years');
$$);
