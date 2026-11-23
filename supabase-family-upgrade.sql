-- 小树苗：共同家长与多家庭切换专项升级
-- 适用于已经执行过旧版 supabase-setup.sql，但网页提示共同家长功能未就绪的项目。
-- 在 Supabase Dashboard -> SQL Editor 中完整执行本文件，然后刷新网站。

create extension if not exists pgcrypto;

do $$
begin
  if to_regclass('public.families') is null
     or to_regclass('public.family_members') is null
     or to_regclass('public.family_invitations') is null
     or to_regclass('public.family_states') is null then
    raise exception '缺少家庭基础数据表，请先完整执行 supabase-setup.sql';
  end if;
end;
$$;

-- 旧版可能限制一个账号只能属于一个家庭。移除 user_id 单列唯一约束，
-- 保留 (family_id, user_id) 主键，使已注册家长能够管理多个家庭。
alter table public.family_members
  drop constraint if exists family_members_user_id_key;

do $$
declare
  constraint_row record;
  user_column smallint;
begin
  select attnum into user_column
  from pg_attribute
  where attrelid = 'public.family_members'::regclass
    and attname = 'user_id'
    and not attisdropped;

  for constraint_row in
    select conname
    from pg_constraint
    where conrelid = 'public.family_members'::regclass
      and contype = 'u'
      and conkey = array[user_column]
  loop
    execute format('alter table public.family_members drop constraint %I', constraint_row.conname);
  end loop;
end;
$$;

create or replace function public.ensure_my_family()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_family uuid;
  v_name text;
begin
  if v_user is null then raise exception '请先登录'; end if;

  select f.id into v_family
  from public.families f
  join public.family_members fm on fm.family_id = f.id
  where f.owner_id = v_user and fm.user_id = v_user and fm.status = 'active'
  order by f.created_at
  limit 1;

  if v_family is null then
    select coalesce(nullif(p.family_name, ''), '我的家庭') into v_name
    from public.profiles p where p.id = v_user;

    insert into public.families (name, owner_id)
    values (coalesce(v_name, '我的家庭'), v_user)
    returning id into v_family;

    insert into public.family_members (family_id, user_id, role, status)
    values (v_family, v_user, 'owner', 'active')
    on conflict (family_id, user_id)
    do update set role = 'owner', status = 'active';
  end if;

  return v_family;
end;
$$;

create or replace function public.list_my_families()
returns table(family_id uuid, family_name text, role text, is_home boolean, joined_at timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select f.id, f.name, fm.role, f.owner_id = auth.uid(), fm.joined_at
  from public.family_members fm
  join public.families f on f.id = fm.family_id
  where fm.user_id = auth.uid() and fm.status = 'active'
  order by case when f.owner_id = auth.uid() then 0 else 1 end, fm.joined_at;
$$;

create or replace function public.list_family_members(p_family_id uuid)
returns table(user_id uuid, email text, nickname text, avatar_url text, role text, joined_at timestamptz)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_family_member(p_family_id) then raise exception '无权查看该家庭'; end if;
  return query
  select fm.user_id, p.email, p.nickname, p.avatar_url, fm.role, fm.joined_at
  from public.family_members fm
  join public.profiles p on p.id = fm.user_id
  where fm.family_id = p_family_id and fm.status = 'active'
  order by case when fm.role = 'owner' then 0 else 1 end, fm.joined_at;
end;
$$;

create or replace function public.list_family_invitations(p_family_id uuid)
returns table(invited_email text, invite_code text, expires_at timestamptz, created_at timestamptz)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_family_member(p_family_id) then raise exception '无权查看该家庭'; end if;
  return query
  select fi.invited_email, fi.invite_code, fi.expires_at, fi.created_at
  from public.family_invitations fi
  where fi.family_id = p_family_id
    and fi.status = 'pending'
    and fi.expires_at > now()
  order by fi.created_at desc;
end;
$$;

create or replace function public.create_family_invitation_for_family(
  p_family_id uuid,
  invited_email text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_email text := lower(trim(invited_email));
  v_code text;
  v_expires timestamptz := now() + interval '7 days';
begin
  if v_user is null then raise exception '请先登录'; end if;
  if not public.is_family_member(p_family_id) then raise exception '无权邀请该家庭的共同家长'; end if;
  if v_email !~ '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$' then
    raise exception '请输入正确的家长邮箱';
  end if;
  if v_email = lower(coalesce(auth.jwt() ->> 'email', '')) then
    raise exception '不能邀请当前登录邮箱';
  end if;
  if exists (
    select 1
    from public.family_members fm
    join public.profiles p on p.id = fm.user_id
    where fm.family_id = p_family_id
      and fm.status = 'active'
      and lower(p.email) = v_email
  ) then
    raise exception '该邮箱已经是这个家庭的成员';
  end if;

  update public.family_invitations fi
  set status = 'revoked'
  where fi.family_id = p_family_id
    and lower(fi.invited_email) = v_email
    and fi.status = 'pending';

  -- 使用 gen_random_uuid()，不依赖旧脚本中的 gen_random_bytes()。
  v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));

  insert into public.family_invitations
    (family_id, inviter_id, invited_email, invite_code, expires_at)
  values
    (p_family_id, v_user, v_email, v_code, v_expires);

  return jsonb_build_object(
    'invite_code', v_code,
    'invited_email', v_email,
    'expires_at', v_expires
  );
end;
$$;

create or replace function public.accept_family_invitation(p_invite_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
  v_invite public.family_invitations%rowtype;
begin
  if v_user is null then raise exception '请先登录'; end if;

  select fi.* into v_invite
  from public.family_invitations fi
  where fi.invite_code = upper(trim(p_invite_code))
    and fi.status = 'pending'
  limit 1;

  if v_invite.id is null then raise exception '邀请链接无效或已使用'; end if;
  if v_invite.expires_at < now() then
    update public.family_invitations set status = 'expired' where id = v_invite.id;
    raise exception '邀请链接已过期，请让家长重新邀请';
  end if;
  if lower(v_invite.invited_email) <> v_email then
    raise exception '请使用被邀请的邮箱登录';
  end if;

  insert into public.family_members (family_id, user_id, role, status)
  values (v_invite.family_id, v_user, 'parent', 'active')
  on conflict (family_id, user_id)
  do update set role = 'parent', status = 'active';

  update public.family_invitations
  set status = 'accepted', accepted_by = v_user, accepted_at = now()
  where id = v_invite.id;

  return v_invite.family_id;
end;
$$;

revoke all on function public.ensure_my_family() from public;
revoke all on function public.list_my_families() from public;
revoke all on function public.list_family_members(uuid) from public;
revoke all on function public.list_family_invitations(uuid) from public;
revoke all on function public.create_family_invitation_for_family(uuid, text) from public;
revoke all on function public.accept_family_invitation(text) from public;

grant execute on function public.ensure_my_family() to authenticated;
grant execute on function public.list_my_families() to authenticated;
grant execute on function public.list_family_members(uuid) to authenticated;
grant execute on function public.list_family_invitations(uuid) to authenticated;
grant execute on function public.create_family_invitation_for_family(uuid, text) to authenticated;
grant execute on function public.accept_family_invitation(text) to authenticated;

-- 让 PostgREST 立即重新读取新增函数，避免短时间继续报 PGRST202。
notify pgrst, 'reload schema';

-- 成功时会返回 6 个 true。
select
  to_regprocedure('public.ensure_my_family()') is not null as ensure_my_family_ok,
  to_regprocedure('public.list_my_families()') is not null as list_my_families_ok,
  to_regprocedure('public.list_family_members(uuid)') is not null as list_family_members_ok,
  to_regprocedure('public.list_family_invitations(uuid)') is not null as list_family_invitations_ok,
  to_regprocedure('public.create_family_invitation_for_family(uuid,text)') is not null as create_invitation_ok,
  to_regprocedure('public.accept_family_invitation(text)') is not null as accept_invitation_ok;
