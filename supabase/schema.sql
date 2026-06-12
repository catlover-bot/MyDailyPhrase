-- MyDailyPhrase Supabase draft schema
-- Safe defaults:
-- - Public feed, public comments, and ranking are intentionally not modeled/enabled here.
-- - Diary entries are private/local by default and are not synced by this schema.
-- - DM is text-only and mutual-follow-gated at application and RLS policy layers.
-- - iOS uses the publishable key plus a Supabase Auth session. Never embed service_role in the app.

create extension if not exists pgcrypto;

create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  auth_provider text not null check (auth_provider in ('apple', 'google', 'guest', 'local_developer_preview')),
  provider_user_id text not null,
  email text,
  role text not null default 'user' check (role in ('user', 'creator', 'admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (auth_provider, provider_user_id)
);

comment on table public.users is 'App-level profile owner row. For client writes, id must match auth.uid() from Supabase Auth. The iOS app uses publishable key + Supabase Auth access token; service_role is never embedded.';

create table if not exists public.profiles (
  user_id uuid primary key references public.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 24),
  bio text check (char_length(coalesce(bio, '')) <= 120),
  avatar_symbol text,
  interest_tags text[] not null default '{}',
  equipped_theme_id text not null default 'classic',
  profile_title text,
  is_discoverable boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is 'Build 35+ profile sync target. The iOS client maps local display name, bio, avatar symbol, interest tags, and updated_at here. Diary answers are intentionally not synced.';
comment on column public.profiles.user_id is 'Matches public.users.id and must equal auth.uid() for client writes. Local Apple sign-in alone is not sufficient; the client must also bridge to Supabase Auth.';

create table if not exists public.follows (
  follower_user_id uuid not null references public.users(id) on delete cascade,
  followed_user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_user_id, followed_user_id),
  check (follower_user_id <> followed_user_id)
);

create table if not exists public.blocks (
  blocker_user_id uuid not null references public.users(id) on delete cascade,
  blocked_user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_user_id, blocked_user_id),
  check (blocker_user_id <> blocked_user_id)
);

create table if not exists public.communities (
  id uuid primary key default gen_random_uuid(),
  creator_user_id uuid references public.users(id) on delete set null,
  name text not null check (char_length(name) between 1 and 36),
  description text not null default '' check (char_length(description) <= 140),
  category text not null default 'games',
  emoji text not null default '🎮',
  visibility text not null default 'invite_only' check (visibility in ('local_only', 'invite_only', 'public_disabled')),
  prompt_schedule text not null default 'daily' check (prompt_schedule in ('daily', 'weekly')),
  prompt_policy jsonb not null default '{}'::jsonb,
  prompt_packs text[] not null default '{}',
  theme_decoration_id text,
  allowed_tags text[] not null default '{}',
  blocked_words text[] not null default '{}',
  requires_creator_pass_to_create boolean not null default true,
  is_official_preset boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.memberships (
  community_id uuid not null references public.communities(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  member_role text not null default 'member' check (member_role in ('member', 'creator', 'moderator', 'admin')),
  joined_at timestamptz not null default now(),
  muted_at timestamptz,
  primary key (community_id, user_id)
);

create table if not exists public.dm_threads (
  id uuid primary key default gen_random_uuid(),
  user_a_id uuid not null references public.users(id) on delete cascade,
  user_b_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (user_a_id <> user_b_id),
  unique (user_a_id, user_b_id)
);

create table if not exists public.dm_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.dm_threads(id) on delete cascade,
  sender_user_id uuid not null references public.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 240),
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_user_id uuid not null references public.users(id) on delete cascade,
  target_kind text not null check (target_kind in ('user', 'community', 'dm_message')),
  target_id uuid not null,
  reason text not null check (reason in ('spam', 'harassment', 'unsafe_content', 'impersonation', 'other')),
  note text check (char_length(coalesce(note, '')) <= 280),
  status text not null default 'open' check (status in ('open', 'reviewing', 'closed')),
  created_at timestamptz not null default now()
);

create table if not exists public.admin_roles (
  user_id uuid primary key references public.users(id) on delete cascade,
  capabilities text[] not null default '{}',
  granted_by uuid references public.users(id) on delete set null,
  granted_at timestamptz not null default now()
);

create index if not exists profiles_discoverable_idx on public.profiles(is_discoverable);
create index if not exists follows_followed_idx on public.follows(followed_user_id);
create index if not exists blocks_blocked_idx on public.blocks(blocked_user_id);
create index if not exists memberships_user_idx on public.memberships(user_id);
create index if not exists dm_threads_user_a_idx on public.dm_threads(user_a_id);
create index if not exists dm_threads_user_b_idx on public.dm_threads(user_b_id);
create unique index if not exists dm_threads_pair_unique_idx
  on public.dm_threads (least(user_a_id, user_b_id), greatest(user_a_id, user_b_id));
create index if not exists dm_messages_thread_created_idx on public.dm_messages(thread_id, created_at);
create index if not exists reports_target_idx on public.reports(target_kind, target_id);

alter table public.communities
  add column if not exists custom_prompt_seeds text[] not null default '{}',
  add column if not exists pinned_next_prompt_text text check (char_length(coalesce(pinned_next_prompt_text, '')) <= 70),
  add column if not exists archived_at timestamptz;

alter table public.memberships
  add column if not exists status text not null default 'active' check (status in ('active', 'muted'));

alter table public.users enable row level security;
alter table public.profiles enable row level security;
alter table public.follows enable row level security;
alter table public.blocks enable row level security;
alter table public.communities enable row level security;
alter table public.memberships enable row level security;
alter table public.dm_threads enable row level security;
alter table public.dm_messages enable row level security;
alter table public.reports enable row level security;
alter table public.admin_roles enable row level security;

-- Client-safe profile sync policies.
-- These policies intentionally do not allow anonymous broad writes.
-- If profile sync returns 401/403 or 42501, verify that the iOS app has a Supabase Auth session and that user_id equals auth.uid().
drop policy if exists "users_owner_select" on public.users;
drop policy if exists "users_owner_insert" on public.users;
drop policy if exists "users_owner_update" on public.users;
drop policy if exists "profiles_read_safe" on public.profiles;
drop policy if exists "profiles_owner_insert" on public.profiles;
drop policy if exists "profiles_owner_update" on public.profiles;
drop policy if exists "follows_owner_select" on public.follows;
drop policy if exists "follows_owner_insert" on public.follows;
drop policy if exists "follows_owner_delete" on public.follows;
drop policy if exists "blocks_owner_select" on public.blocks;
drop policy if exists "blocks_owner_insert" on public.blocks;
drop policy if exists "blocks_owner_delete" on public.blocks;
drop policy if exists "reports_owner_select" on public.reports;
drop policy if exists "reports_owner_insert" on public.reports;
drop policy if exists "communities_authenticated_read" on public.communities;
drop policy if exists "communities_creator_insert" on public.communities;
drop policy if exists "communities_creator_update" on public.communities;
drop policy if exists "memberships_authenticated_read_visible" on public.memberships;
drop policy if exists "memberships_owner_insert" on public.memberships;
drop policy if exists "memberships_owner_delete" on public.memberships;
drop policy if exists "memberships_owner_update" on public.memberships;
drop policy if exists "dm_threads_participant_select" on public.dm_threads;
drop policy if exists "dm_threads_mutual_insert" on public.dm_threads;
drop policy if exists "dm_threads_participant_update" on public.dm_threads;
drop policy if exists "dm_messages_participant_select" on public.dm_messages;
drop policy if exists "dm_messages_sender_insert" on public.dm_messages;

create policy "users_owner_select" on public.users
  for select to authenticated
  using (id = auth.uid());

create policy "users_owner_insert" on public.users
  for insert to authenticated
  with check (
    id = auth.uid()
    and role = 'user'
  );

create policy "users_owner_update" on public.users
  for update to authenticated
  using (id = auth.uid())
  with check (
    id = auth.uid()
    and role = 'user'
  );

create policy "profiles_read_safe" on public.profiles
  for select
  using (
    is_discoverable = true
    or user_id = auth.uid()
  );

create policy "profiles_owner_insert" on public.profiles
  for insert to authenticated
  with check (user_id = auth.uid());

create policy "profiles_owner_update" on public.profiles
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Backend-backed follow/block/report sync.
-- actor ids always come from Supabase Auth auth.uid(); Apple providerUserId is only an admin allowlist identifier.
create policy "follows_owner_select" on public.follows
  for select to authenticated
  using (
    follower_user_id = auth.uid()
    or followed_user_id = auth.uid()
  );

create policy "follows_owner_insert" on public.follows
  for insert to authenticated
  with check (follower_user_id = auth.uid());

create policy "follows_owner_delete" on public.follows
  for delete to authenticated
  using (follower_user_id = auth.uid());

create policy "blocks_owner_select" on public.blocks
  for select to authenticated
  using (
    blocker_user_id = auth.uid()
    or blocked_user_id = auth.uid()
  );

create policy "blocks_owner_insert" on public.blocks
  for insert to authenticated
  with check (blocker_user_id = auth.uid());

create policy "blocks_owner_delete" on public.blocks
  for delete to authenticated
  using (blocker_user_id = auth.uid());

create policy "reports_owner_select" on public.reports
  for select to authenticated
  using (reporter_user_id = auth.uid());

create policy "reports_owner_insert" on public.reports
  for insert to authenticated
  with check (reporter_user_id = auth.uid());

-- Backend-backed communities and memberships.
-- Normal users may join as themselves. Creator/admin entitlement checks remain app-side and never use service_role in iOS.
-- Public posting/feed/comment/ranking remains disabled; this only exposes safe community cards and membership state to authenticated users.
create policy "communities_authenticated_read" on public.communities
  for select to authenticated
  using (
    archived_at is null
    and visibility in ('invite_only', 'public_disabled')
  );

create policy "communities_creator_insert" on public.communities
  for insert to authenticated
  with check (
    creator_user_id = auth.uid()
    and archived_at is null
  );

create policy "communities_creator_update" on public.communities
  for update to authenticated
  using (creator_user_id = auth.uid())
  with check (
    creator_user_id = auth.uid()
    and archived_at is null
  );

create policy "memberships_authenticated_read_visible" on public.memberships
  for select to authenticated
  using (
    exists (
      select 1 from public.communities c
      where c.id = memberships.community_id
        and c.archived_at is null
        and c.visibility in ('invite_only', 'public_disabled')
    )
  );

create policy "memberships_owner_insert" on public.memberships
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and member_role = 'member'
  );

create policy "memberships_owner_delete" on public.memberships
  for delete to authenticated
  using (user_id = auth.uid());

create policy "memberships_owner_update" on public.memberships
  for update to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and member_role = 'member'
  );

-- Backend-backed mutual-follow DM sync.
-- The iOS client uses Supabase Auth user ids for user_a_id, user_b_id, and sender_user_id.
-- Diary text is never synced by this schema; only explicit text entered into the DM UI can become dm_messages.body.
create policy "dm_threads_participant_select" on public.dm_threads
  for select to authenticated
  using (
    auth.uid() in (user_a_id, user_b_id)
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_user_id = auth.uid() and b.blocked_user_id = case when user_a_id = auth.uid() then user_b_id else user_a_id end)
         or (b.blocker_user_id = case when user_a_id = auth.uid() then user_b_id else user_a_id end and b.blocked_user_id = auth.uid())
    )
  );

create policy "dm_threads_mutual_insert" on public.dm_threads
  for insert to authenticated
  with check (
    auth.uid() in (user_a_id, user_b_id)
    and user_a_id <> user_b_id
    and exists (
      select 1 from public.follows f
      where f.follower_user_id = auth.uid()
        and f.followed_user_id = case when user_a_id = auth.uid() then user_b_id else user_a_id end
    )
    and exists (
      select 1 from public.follows f
      where f.follower_user_id = case when user_a_id = auth.uid() then user_b_id else user_a_id end
        and f.followed_user_id = auth.uid()
    )
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_user_id = auth.uid() and b.blocked_user_id = case when user_a_id = auth.uid() then user_b_id else user_a_id end)
         or (b.blocker_user_id = case when user_a_id = auth.uid() then user_b_id else user_a_id end and b.blocked_user_id = auth.uid())
    )
  );

create policy "dm_threads_participant_update" on public.dm_threads
  for update to authenticated
  using (auth.uid() in (user_a_id, user_b_id))
  with check (
    auth.uid() in (user_a_id, user_b_id)
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_user_id = auth.uid() and b.blocked_user_id = case when user_a_id = auth.uid() then user_b_id else user_a_id end)
         or (b.blocker_user_id = case when user_a_id = auth.uid() then user_b_id else user_a_id end and b.blocked_user_id = auth.uid())
    )
  );

create policy "dm_messages_participant_select" on public.dm_messages
  for select to authenticated
  using (
    exists (
      select 1 from public.dm_threads t
      where t.id = dm_messages.thread_id
        and auth.uid() in (t.user_a_id, t.user_b_id)
    )
  );

create policy "dm_messages_sender_insert" on public.dm_messages
  for insert to authenticated
  with check (
    sender_user_id = auth.uid()
    and exists (
      select 1 from public.dm_threads t
      where t.id = dm_messages.thread_id
        and auth.uid() in (t.user_a_id, t.user_b_id)
        and exists (
          select 1 from public.follows f
          where f.follower_user_id = auth.uid()
            and f.followed_user_id = case when t.user_a_id = auth.uid() then t.user_b_id else t.user_a_id end
        )
        and exists (
          select 1 from public.follows f
          where f.follower_user_id = case when t.user_a_id = auth.uid() then t.user_b_id else t.user_a_id end
            and f.followed_user_id = auth.uid()
        )
        and not exists (
          select 1 from public.blocks b
          where (b.blocker_user_id = auth.uid() and b.blocked_user_id = case when t.user_a_id = auth.uid() then t.user_b_id else t.user_a_id end)
             or (b.blocker_user_id = case when t.user_a_id = auth.uid() then t.user_b_id else t.user_a_id end and b.blocked_user_id = auth.uid())
        )
    )
  );

-- Future policies, still intentionally not broad-enabled:
-- create policy "reports_owner_insert" on public.reports for insert with check (reporter_user_id = auth.uid());
