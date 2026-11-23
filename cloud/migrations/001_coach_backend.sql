-- Hybrid Training AI Coach backend: accounts, credit ledger, conversations.
-- Every table has RLS on with no policies and every function is callable by service_role only,
-- so the app can reach this data only through the ai-coach edge function.
--
-- Credit rules (as described in the app): 20 free replies per calendar month (UTC), free credits
-- are used first, purchased credits never expire, a failed reply costs nothing, a refunded pack is
-- deducted (the purchased balance may go negative), deleting a conversation returns no credits.

create table if not exists public.coach_accounts (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  identity   text not null,
  consent_at timestamptz,
  purchased  integer not null default 0,
  deleting   boolean not null default false,
  created_at timestamptz not null default now()
);
comment on table public.coach_accounts is 'Hybrid Training AI Coach: one row per signed-in Coach user. Service role only.';

-- Keyed by a keyed hash of the email, not the user id, so the monthly allowance survives
-- deleting and re-creating an account.
create table if not exists public.coach_allowances (
  identity text not null,
  period   date not null,
  used     integer not null default 0 check (used >= 0),
  primary key (identity, period)
);
comment on table public.coach_allowances is 'Hybrid Training AI Coach: free replies used per month per hashed email. Service role only.';

create table if not exists public.coach_turns (
  id              uuid primary key,
  user_id         uuid not null references auth.users (id) on delete cascade,
  conversation_id uuid not null,
  question        text not null check (char_length(question) between 1 and 1600),
  answer          text,
  context         text not null default '' check (char_length(context) <= 2400),
  status          text not null check (status in ('pending', 'complete', 'failed')),
  source          text not null check (source in ('free', 'purchased')),
  identity        text not null,
  period          date not null,
  created_at      timestamptz(3) not null default now(),
  settled_at      timestamptz(3)
);
comment on table public.coach_turns is 'Hybrid Training AI Coach: questions and replies. Service role only.';
create index if not exists coach_turns_conversation_idx on public.coach_turns (user_id, conversation_id, created_at desc);
create index if not exists coach_turns_created_idx on public.coach_turns (created_at);
create unique index if not exists coach_turns_one_pending_idx on public.coach_turns (user_id) where status = 'pending';

-- Remembers ids of deleted requests so a late retry cannot recreate (and charge for) a deleted question.
create table if not exists public.coach_deleted_requests (
  id         uuid primary key,
  deleted_at timestamptz not null default now()
);
comment on table public.coach_deleted_requests is 'Hybrid Training AI Coach: ids of deleted requests. Service role only.';

create table if not exists public.coach_products (
  product_id text primary key,
  credits    integer not null check (credits > 0),
  enabled    boolean not null default false
);
comment on table public.coach_products is 'Hybrid Training AI Coach: credit packs. Set enabled = true to switch a pack on. Service role only.';
insert into public.coach_products (product_id, credits, enabled)
values ('coach_credits_50', 50, false), ('coach_credits_150', 150, false)
on conflict (product_id) do nothing;

-- Minimal transaction record, kept after account deletion so a store transaction is never credited twice.
create table if not exists public.coach_purchases (
  transaction text primary key,
  user_id     uuid not null,
  product_id  text not null,
  credits     integer not null,
  status      text,
  granted     boolean not null default false,
  refunded    boolean not null default false,
  created_at  timestamptz not null default now()
);
comment on table public.coach_purchases is 'Hybrid Training AI Coach: verified credit-pack transactions. Service role only.';

alter table public.coach_accounts enable row level security;
alter table public.coach_allowances enable row level security;
alter table public.coach_turns enable row level security;
alter table public.coach_deleted_requests enable row level security;
alter table public.coach_products enable row level security;
alter table public.coach_purchases enable row level security;
revoke all on public.coach_accounts, public.coach_allowances, public.coach_turns,
  public.coach_deleted_requests, public.coach_products, public.coach_purchases from anon, authenticated;

create or replace function public.coach_period() returns date
language sql stable set search_path = '' as $$
  select date_trunc('month', now() at time zone 'utc')::date
$$;

-- Returns a reserved credit to wherever it came from.
create or replace function public.coach_refund(p_turn public.coach_turns) returns boolean
language plpgsql set search_path = '' as $$
begin
  if p_turn.source = 'free' then
    update public.coach_allowances set used = greatest(0, used - 1)
    where identity = p_turn.identity and period = p_turn.period;
  else
    update public.coach_accounts set purchased = purchased + 1 where user_id = p_turn.user_id;
  end if;
  return true;
end $$;

create or replace function public.coach_session_valid(p_user uuid, p_session text) returns boolean
language plpgsql stable security definer set search_path = '' as $$
begin
  return exists (
    select 1 from auth.sessions s
    where s.id = p_session::uuid and s.user_id = p_user and (s.not_after is null or s.not_after > now())
  );
exception when others then
  return false;
end $$;

-- Fails any reply that has been pending too long (the function crashed or timed out) and returns its credit.
create or replace function public.coach_reconcile(p_user uuid) returns boolean
language plpgsql set search_path = '' as $$
declare
  v_turn public.coach_turns;
begin
  perform 1 from public.coach_accounts where user_id = p_user for update;
  for v_turn in
    select * from public.coach_turns
    where user_id = p_user and status = 'pending' and created_at < now() - interval '3 minutes'
    for update
  loop
    update public.coach_turns set status = 'failed', settled_at = now() where id = v_turn.id;
    perform public.coach_refund(v_turn);
  end loop;
  return true;
end $$;

create or replace function public.coach_wallet(p_user uuid, p_identity text) returns jsonb
language plpgsql set search_path = '' as $$
declare
  v_account public.coach_accounts;
  v_period date := public.coach_period();
  v_used integer;
begin
  insert into public.coach_accounts (user_id, identity) values (p_user, p_identity)
  on conflict (user_id) do update set identity = excluded.identity
  returning * into v_account;
  select used into v_used from public.coach_allowances where identity = p_identity and period = v_period;
  return jsonb_build_object(
    'free', greatest(0, 20 - coalesce(v_used, 0)),
    'purchased', v_account.purchased,
    'reset_at', ((v_period + interval '1 month')::timestamp at time zone 'utc'),
    'consented', v_account.consent_at is not null,
    'pending', exists (select 1 from public.coach_turns where user_id = p_user and status = 'pending')
  );
end $$;

create or replace function public.coach_reserve(
  p_user uuid, p_identity text, p_id uuid, p_conversation uuid, p_question text, p_context text
) returns jsonb
language plpgsql set search_path = '' as $$
declare
  v_account public.coach_accounts;
  v_existing public.coach_turns;
  v_period date := public.coach_period();
  v_used integer;
  v_source text;
begin
  select * into v_account from public.coach_accounts where user_id = p_user for update;
  if not found then raise exception using message = 'sign_in_required'; end if;
  if v_account.deleting then raise exception using message = 'delete_pending'; end if;
  if exists (select 1 from public.coach_deleted_requests where id = p_id) then
    raise exception using message = 'request_deleted';
  end if;

  select * into v_existing from public.coach_turns where id = p_id;
  if found then
    if v_existing.user_id <> p_user or v_existing.conversation_id <> p_conversation or v_existing.question <> p_question then
      raise exception using message = 'request_conflict';
    end if;
    return jsonb_build_object('new', false, 'question', v_existing.question, 'context', v_existing.context);
  end if;

  if char_length(p_question) not between 1 and 1600 or char_length(coalesce(p_context, '')) > 2400 then
    raise exception using message = 'invalid_request';
  end if;
  if v_account.consent_at is null then raise exception using message = 'consent_required'; end if;
  if exists (select 1 from public.coach_turns where user_id = p_user and status = 'pending') then
    raise exception using message = 'already_pending';
  end if;
  if exists (select 1 from public.coach_turns where user_id = p_user and created_at > now() - interval '4 seconds') then
    raise exception using message = 'rate_limit';
  end if;
  if (select count(*) from public.coach_turns where user_id = p_user and created_at > now() - interval '1 day') >= 100
     or (select count(*) from public.coach_turns where created_at > now() - interval '1 day') >= 5000 then
    raise exception using message = 'daily_limit';
  end if;

  insert into public.coach_allowances (identity, period) values (p_identity, v_period)
  on conflict (identity, period) do nothing;
  select used into v_used from public.coach_allowances
  where identity = p_identity and period = v_period for update;
  if v_used < 20 then
    update public.coach_allowances set used = used + 1 where identity = p_identity and period = v_period;
    v_source := 'free';
  elsif v_account.purchased > 0 then
    update public.coach_accounts set purchased = purchased - 1 where user_id = p_user;
    v_source := 'purchased';
  else
    raise exception using message = 'no_credits';
  end if;

  insert into public.coach_turns (id, user_id, conversation_id, question, context, status, source, identity, period)
  values (p_id, p_user, p_conversation, p_question, coalesce(p_context, ''), 'pending', v_source, p_identity, v_period);
  return jsonb_build_object('new', true, 'question', p_question, 'context', coalesce(p_context, ''));
end $$;

-- p_answer null means the reply failed: the turn is marked failed and the credit returned.
create or replace function public.coach_settle(p_user uuid, p_id uuid, p_answer text) returns jsonb
language plpgsql set search_path = '' as $$
declare
  v_turn public.coach_turns;
begin
  perform 1 from public.coach_accounts where user_id = p_user for update;
  select * into v_turn from public.coach_turns where id = p_id and user_id = p_user for update;
  if not found then return jsonb_build_object('status', 'missing'); end if;
  if v_turn.status <> 'pending' then return jsonb_build_object('status', v_turn.status); end if;
  if p_answer is null or btrim(p_answer) = '' then
    update public.coach_turns set status = 'failed', settled_at = now() where id = p_id;
    perform public.coach_refund(v_turn);
    return jsonb_build_object('status', 'failed');
  end if;
  update public.coach_turns set status = 'complete', answer = p_answer, settled_at = now() where id = p_id;
  return jsonb_build_object('status', 'complete');
end $$;

create or replace function public.coach_conversations(p_user uuid) returns jsonb
language sql stable set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', c.conversation_id, 'title', c.title, 'updated_at', c.updated_at)
                            order by c.updated_at desc), '[]'::jsonb)
  from (
    select t.conversation_id,
           left((array_agg(t.question order by t.created_at))[1], 60) as title,
           max(t.created_at) as updated_at
    from public.coach_turns t
    where t.user_id = p_user
    group by t.conversation_id
    order by max(t.created_at) desc
    limit 50
  ) c
$$;

create or replace function public.coach_delete_conversation(p_user uuid, p_conversation uuid) returns boolean
language plpgsql set search_path = '' as $$
begin
  perform 1 from public.coach_accounts where user_id = p_user for update;
  if exists (select 1 from public.coach_turns
             where user_id = p_user and conversation_id = p_conversation and status = 'pending') then
    raise exception using message = 'delete_pending';
  end if;
  insert into public.coach_deleted_requests (id)
  select id from public.coach_turns where user_id = p_user and conversation_id = p_conversation
  on conflict (id) do nothing;
  delete from public.coach_turns where user_id = p_user and conversation_id = p_conversation;
  return true;
end $$;

create or replace function public.coach_begin_delete(p_user uuid) returns boolean
language plpgsql set search_path = '' as $$
begin
  perform 1 from public.coach_accounts where user_id = p_user for update;
  if exists (select 1 from public.coach_turns where user_id = p_user and status = 'pending') then
    raise exception using message = 'delete_pending';
  end if;
  update public.coach_accounts set deleting = true where user_id = p_user;
  return true;
end $$;

-- Removes all Coach data for a user while leaving the sign-in itself in place. Used when the
-- Supabase project's sign-ins are shared with another product. Allowance and transaction
-- identifiers are kept, as the app's privacy text states.
create or replace function public.coach_erase(p_user uuid) returns boolean
language plpgsql set search_path = '' as $$
begin
  delete from public.coach_turns where user_id = p_user;
  delete from public.coach_accounts where user_id = p_user;
  return true;
end $$;

create or replace function public.coach_enabled_products() returns jsonb
language sql stable set search_path = '' as $$
  select coalesce(jsonb_agg(product_id order by product_id), '[]'::jsonb)
  from public.coach_products where enabled
$$;

-- Idempotent: a transaction is credited once, and deducted once if it is later refunded.
create or replace function public.coach_purchase(p_user uuid, p_transaction text, p_product text, p_status text) returns boolean
language plpgsql set search_path = '' as $$
declare
  v_credits integer;
  v_purchase public.coach_purchases;
begin
  select credits into v_credits from public.coach_products where product_id = p_product and enabled;
  if not found then return false; end if;
  perform 1 from public.coach_accounts where user_id = p_user for update;
  if not found then return false; end if;

  select * into v_purchase from public.coach_purchases where transaction = p_transaction for update;
  if not found then
    insert into public.coach_purchases (transaction, user_id, product_id, credits, status, granted, refunded)
    values (p_transaction, p_user, p_product, v_credits, p_status, p_status = 'owned', p_status = 'refunded');
    if p_status = 'owned' then
      update public.coach_accounts set purchased = purchased + v_credits where user_id = p_user;
      return true;
    end if;
    return false;
  end if;

  if v_purchase.user_id <> p_user then return false; end if;
  if p_status = 'owned' and not v_purchase.granted and not v_purchase.refunded then
    update public.coach_purchases set granted = true, status = p_status where transaction = p_transaction;
    update public.coach_accounts set purchased = purchased + v_purchase.credits where user_id = p_user;
    return true;
  end if;
  if p_status = 'refunded' and not v_purchase.refunded then
    update public.coach_purchases set refunded = true, status = p_status where transaction = p_transaction;
    if v_purchase.granted then
      update public.coach_accounts set purchased = purchased - v_purchase.credits where user_id = p_user;
    end if;
    return true;
  end if;
  return false;
end $$;

-- Functions in the public schema are callable through the REST API by default: close that door.
revoke execute on function
  public.coach_period(), public.coach_refund(public.coach_turns), public.coach_session_valid(uuid, text),
  public.coach_reconcile(uuid), public.coach_wallet(uuid, text),
  public.coach_reserve(uuid, text, uuid, uuid, text, text), public.coach_settle(uuid, uuid, text),
  public.coach_conversations(uuid), public.coach_delete_conversation(uuid, uuid),
  public.coach_begin_delete(uuid), public.coach_erase(uuid), public.coach_enabled_products(),
  public.coach_purchase(uuid, text, text, text)
from public, anon, authenticated;
grant execute on function
  public.coach_period(), public.coach_refund(public.coach_turns), public.coach_session_valid(uuid, text),
  public.coach_reconcile(uuid), public.coach_wallet(uuid, text),
  public.coach_reserve(uuid, text, uuid, uuid, text, text), public.coach_settle(uuid, uuid, text),
  public.coach_conversations(uuid), public.coach_delete_conversation(uuid, uuid),
  public.coach_begin_delete(uuid), public.coach_erase(uuid), public.coach_enabled_products(),
  public.coach_purchase(uuid, text, text, text)
to service_role;

notify pgrst, 'reload schema';
