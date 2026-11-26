-- GC-Pedidos: banco de dados no Supabase
-- Cole tudo no SQL Editor do Supabase e clique em Run. Pode rodar uma vez só.

-- 1) Tabelas ---------------------------------------------------------------
create table public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  nome       text not null default '',
  tel        text not null default '',
  endereco   text not null default '',
  funcao     text not null default '',
  foto       text,
  created_at timestamptz not null default now()
);

create table public.suppliers (
  id         uuid primary key default gen_random_uuid(),
  owner      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nome       text not null,
  whatsapp   text not null,
  created_at timestamptz not null default now()
);

create table public.products (
  id          uuid primary key default gen_random_uuid(),
  owner       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nome        text not null default '',
  marca       text not null default '',
  q1          integer not null default 0 check (q1 >= 0),   -- quantidade 1 (entrada)
  d1          date,                                          -- data de entrada
  q2          integer not null default 0 check (q2 >= 0),   -- quantidade 2 (saída)
  d2          date,                                          -- data de saída
  minimo      integer not null default 0 check (minimo >= 0),
  supplier_id uuid references public.suppliers(id) on delete set null,
  created_at  timestamptz not null default now()
);

create table public.orders (
  id            uuid primary key default gen_random_uuid(),
  owner         uuid not null default auth.uid() references auth.users(id) on delete cascade,
  supplier_name text not null,
  supplier_wa   text not null,
  items         jsonb not null default '[]'::jsonb,
  txt           text not null default '',
  created_at    timestamptz not null default now()
);

create index on public.suppliers (owner);
create index on public.products  (owner);
create index on public.products  (supplier_id);
create index on public.orders    (owner, created_at desc);

-- 2) Segurança (Row Level Security): cada pessoa só enxerga os próprios dados --
alter table public.profiles  enable row level security;
alter table public.suppliers enable row level security;
alter table public.products  enable row level security;
alter table public.orders    enable row level security;

create policy "perfil: ler o proprio"   on public.profiles for select to authenticated using (id = (select auth.uid()));
create policy "perfil: criar o proprio" on public.profiles for insert to authenticated with check (id = (select auth.uid()));
create policy "perfil: editar o proprio" on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy "fornecedores: dono" on public.suppliers for all to authenticated
  using (owner = (select auth.uid())) with check (owner = (select auth.uid()));

create policy "produtos: dono" on public.products for all to authenticated
  using (owner = (select auth.uid()))
  with check (
    owner = (select auth.uid())
    and (supplier_id is null or exists (
      select 1 from public.suppliers s where s.id = supplier_id and s.owner = (select auth.uid())))
  );

create policy "pedidos: dono" on public.orders for all to authenticated
  using (owner = (select auth.uid())) with check (owner = (select auth.uid()));

-- 3) Cria o perfil automaticamente quando a conta é criada -------------------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, nome, tel, endereco, funcao)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'nome', ''),
    coalesce(new.raw_user_meta_data->>'tel', ''),
    coalesce(new.raw_user_meta_data->>'endereco', ''),
    coalesce(new.raw_user_meta_data->>'funcao', '')
  );
  return new;
end $$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 4) Atualização em tempo real entre aparelhos --------------------------------
alter publication supabase_realtime add table public.products, public.suppliers, public.orders;
