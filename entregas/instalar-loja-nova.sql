-- Dred Stil: instalação completa SOMENTE em projeto Supabase novo.
-- Gerado por npm run sql:instalar. Não edite este arquivo à mão.
-- Abra no SQL Editor e execute inteiro uma única vez como administrador.
-- Banco existente: aplique apenas as migrações pendentes; não execute este arquivo.
-- Não cria conta admin nem inventa saldos por cor. Revise os dados iniciais antes de vender.

begin;

do $instalacao_nova$
declare v_tabela text;
begin
  foreach v_tabela in array array['categorias', 'produtos', 'usuarios', 'curtidas', 'pedidos', 'conteudo', 'estoques'] loop
    if to_regclass('public.' || v_tabela) is not null then
      raise exception 'Instalação recusada: a tabela public.% já existe. Use somente as migrações pendentes para atualizar a loja; nenhum dado foi alterado.', v_tabela;
    end if;
  end loop;
end;
$instalacao_nova$;

-- Fonte: supabase/estrutura.sql
-- Dred Stil: estrutura do banco no Supabase.
-- Rodar uma vez no SQL Editor do projeto (depois, rodar dados-iniciais.sql).

-- Categorias do catálogo (com um nível de subcategoria: pai aponta para a categoria principal).
create table if not exists categorias (
  slug       text primary key,
  nome       text not null,
  pai        text references categorias (slug) on update cascade on delete restrict,
  ordem      integer not null default 0,
  no_menu    boolean not null default true,
  criado_em  timestamptz not null default now()
);

create table if not exists produtos (
  handle     text primary key,
  nome       text not null,
  categoria  text not null references categorias (slug) on update cascade on delete restrict,
  preco      numeric(10, 2) not null default 0,
  preco_de   numeric(10, 2) not null default 0,
  descricao  text not null default '',
  tamanhos   jsonb not null default '[]',
  cores      jsonb not null default '[]',
  ativo      boolean not null default true,
  criado_em  timestamptz not null default now()
);

create table if not exists usuarios (
  id             uuid primary key default gen_random_uuid(),
  nome           text not null,
  email          text not null unique,
  senha          text not null,
  telefone       text not null default '',
  papel          text not null default 'cliente' check (papel in ('cliente', 'admin')),
  versao_sessao  integer not null default 1,
  criado_em      timestamptz not null default now()
);

-- A loja tem um único admin: o banco recusa um segundo.
create unique index if not exists usuarios_admin_unico on usuarios ((papel)) where papel = 'admin';

-- Excluir o produto ou a conta apaga as curtidas; trocar o handle do produto atualiza as curtidas.
create table if not exists curtidas (
  usuario_id  uuid not null references usuarios (id) on delete cascade,
  handle      text not null references produtos (handle) on delete cascade on update cascade,
  criado_em   timestamptz not null default now(),
  primary key (usuario_id, handle)
);
create index if not exists curtidas_handle_idx on curtidas (handle);

-- Pedidos feitos no site. Os itens guardam nome e preço do momento da compra.
-- Contam como venda os pedidos pagos, enviados ou entregues.
create table if not exists pedidos (
  id             uuid primary key default gen_random_uuid(),
  numero         bigint generated always as identity unique,
  usuario_id     uuid references usuarios (id) on delete set null,
  itens          jsonb not null,
  total          numeric(10, 2) not null default 0,
  status         text not null default 'aguardando'
                 check (status in ('aguardando', 'pago', 'enviado', 'entregue', 'cancelado')),
  criado_em      timestamptz not null default now(),
  atualizado_em  timestamptz not null default now()
);
create index if not exists pedidos_usuario_idx on pedidos (usuario_id);
create index if not exists pedidos_criado_idx on pedidos (criado_em desc);

-- Conteúdo editável pelo admin: 'faq', 'config', 'menu', 'destaques' e 'paginas'.
create table if not exists conteudo (
  chave  text primary key,
  valor  jsonb not null
);

create or replace view curtidas_por_produto with (security_invoker = true) as
  select handle, count(*)::int as total from curtidas group by handle;

create or replace view compras_por_usuario with (security_invoker = true) as
  select usuario_id, count(*)::int as compras
  from pedidos
  where usuario_id is not null and status in ('pago', 'enviado', 'entregue')
  group by usuario_id;

-- Faturamento no fuso de Brasília: hoje, últimos 7 dias, mês atual e total.
create or replace view vendas_resumo with (security_invoker = true) as
  with vendas as (
    select total, (criado_em at time zone 'America/Sao_Paulo') as quando
    from pedidos where status in ('pago', 'enviado', 'entregue')
  ), agora as (select (now() at time zone 'America/Sao_Paulo') as t)
  select
    count(*) filter (where quando::date = (select t::date from agora))::int as vendas_hoje,
    coalesce(sum(total) filter (where quando::date = (select t::date from agora)), 0) as faturamento_hoje,
    count(*) filter (where quando >= (select t from agora) - interval '7 days')::int as vendas_7_dias,
    coalesce(sum(total) filter (where quando >= (select t from agora) - interval '7 days'), 0) as faturamento_7_dias,
    count(*) filter (where date_trunc('month', quando) = date_trunc('month', (select t from agora)))::int as vendas_mes,
    coalesce(sum(total) filter (where date_trunc('month', quando) = date_trunc('month', (select t from agora))), 0) as faturamento_mes,
    count(*)::int as vendas_total,
    coalesce(sum(total), 0) as faturamento_total,
    (select count(*)::int from pedidos where status = 'aguardando') as pedidos_aguardando
  from vendas;

-- Faturamento por dia nos últimos 30 dias (dias sem venda aparecem com zero).
create or replace view vendas_por_dia with (security_invoker = true) as
  with dias as (
    select generate_series(
      (now() at time zone 'America/Sao_Paulo')::date - 29,
      (now() at time zone 'America/Sao_Paulo')::date,
      interval '1 day'
    )::date as dia
  )
  select d.dia, count(p.id)::int as vendas, coalesce(sum(p.total), 0) as faturamento
  from dias d
  left join pedidos p
    on (p.criado_em at time zone 'America/Sao_Paulo')::date = d.dia
   and p.status in ('pago', 'enviado', 'entregue')
  group by d.dia
  order by d.dia;

-- RLS ligado e sem políticas: só o servidor da loja (chave service_role) lê e grava.
alter table categorias enable row level security;
alter table produtos enable row level security;
alter table usuarios enable row level security;
alter table curtidas enable row level security;
alter table pedidos enable row level security;
alter table conteudo enable row level security;

-- Permissões explícitas: instalações novas não dependem dos grants padrão do
-- projeto Supabase. O servidor usa service_role, que no Supabase ignora RLS.
-- As chaves públicas continuam sem acesso, inclusive às views com security_invoker.
grant usage on schema public to service_role;
revoke all on table categorias, produtos, usuarios, curtidas, pedidos, conteudo,
  curtidas_por_produto, compras_por_usuario, vendas_resumo, vendas_por_dia from public, anon, authenticated;
grant select, insert, update, delete on table categorias, produtos, usuarios, curtidas, pedidos, conteudo to service_role;
grant select on table curtidas_por_produto, compras_por_usuario, vendas_resumo, vendas_por_dia to service_role;
revoke all on sequence pedidos_numero_seq from public, anon, authenticated;
grant usage, select on sequence pedidos_numero_seq to service_role;

-- Fotos enviadas pelo painel admin (leitura pública, envio só pelo servidor).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('produtos', 'produtos', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

-- Fonte: supabase/migracoes/002-contas-pagamentos-seguranca.sql
-- Dred Stil — migração 002: recuperação de senha, verificação em duas etapas, limites de tentativas
-- compartilhados, checkout com Pix (Getnet) e frete (Melhor Envio).
--
-- Rodar UMA vez no SQL Editor do Supabase, depois de estrutura.sql. É idempotente (pode repetir).
-- Não apaga dados: só cria tabelas/colunas/funções novas e amplia a lista de situações de pedido.
-- Reverter: ver supabase/migracoes/002-reverter.sql.


/* ---------------- contas ---------------- */
alter table usuarios add column if not exists email_verificado_em timestamptz;
alter table usuarios add column if not exists dois_fatores boolean not null default false;

-- Tokens de uso único (confirmar e-mail, redefinir senha). Só o hash fica guardado.
create table if not exists tokens_conta (
  token_hash  text primary key,
  usuario_id  uuid not null references usuarios (id) on delete cascade,
  tipo        text not null check (tipo in ('verificar_email', 'redefinir_senha')),
  expira_em   timestamptz not null,
  usado_em    timestamptz,
  criado_em   timestamptz not null default now()
);
create index if not exists tokens_conta_usuario_idx on tokens_conta (usuario_id, tipo);

-- Código de 6 dígitos enviado por e-mail no login (guardado como HMAC).
create table if not exists desafios_2fa (
  id_hash      text primary key,
  usuario_id   uuid not null references usuarios (id) on delete cascade,
  codigo_hash  text not null,
  tentativas   integer not null default 0,
  expira_em    timestamptz not null,
  criado_em    timestamptz not null default now()
);

-- Limites de tentativas: no banco para valerem em todas as instâncias da Vercel.
create table if not exists limites (
  chave          text primary key,
  contagem       integer not null,
  janela_inicio  timestamptz not null
);

-- Eventos de segurança (sem senhas, tokens, códigos, CPF ou dados de cartão).
create table if not exists auditoria (
  id          bigint generated always as identity primary key,
  usuario_id  uuid,
  acao        text not null,
  detalhe     jsonb not null default '{}',
  ip          text,
  criado_em   timestamptz not null default now()
);
create index if not exists auditoria_usuario_idx on auditoria (usuario_id, criado_em desc);

/* ---------------- produtos: embalagem para o frete ---------------- */
alter table produtos add column if not exists peso_kg        numeric(6, 3) not null default 0.3;
alter table produtos add column if not exists largura_cm     integer not null default 20;
alter table produtos add column if not exists altura_cm      integer not null default 4;
alter table produtos add column if not exists comprimento_cm integer not null default 28;

/* ---------------- pedidos: checkout e pagamento ---------------- */
alter table pedidos add column if not exists chave_idempotencia text;
alter table pedidos add column if not exists subtotal          numeric(10, 2);
alter table pedidos add column if not exists frete             numeric(10, 2) not null default 0;
alter table pedidos add column if not exists frete_servico     text;
alter table pedidos add column if not exists frete_nome        text;
alter table pedidos add column if not exists frete_prazo_dias  integer;
alter table pedidos add column if not exists cliente           jsonb;  -- nome, CPF e telefone (nota fiscal e envio)
alter table pedidos add column if not exists endereco          jsonb;
alter table pedidos add column if not exists pagamento_metodo  text;
alter table pedidos add column if not exists pagamento_id      text;
alter table pedidos add column if not exists pagamento_status  text;
alter table pedidos add column if not exists pagamento_dados   jsonb;  -- Pix copia-e-cola e validade
alter table pedidos add column if not exists rastreio          text;
alter table pedidos add column if not exists expira_em         timestamptz;

create unique index if not exists pedidos_idempotencia_idx on pedidos (usuario_id, chave_idempotencia) where chave_idempotencia is not null;
create unique index if not exists pedidos_pagamento_idx on pedidos (pagamento_id) where pagamento_id is not null;
create index if not exists pedidos_expira_idx on pedidos (status, expira_em) where expira_em is not null;

-- 'expirado': Pix não pago no prazo. 'revisar': pagamento com valor divergente ou pago depois de expirar.
alter table pedidos drop constraint if exists pedidos_status_check;
alter table pedidos add constraint pedidos_status_check
  check (status in ('aguardando', 'pago', 'enviado', 'entregue', 'cancelado', 'expirado', 'revisar'));

-- Notificações de pagamento já processadas (proteção contra repetição).
create table if not exists pagamento_eventos (
  id            bigint generated always as identity primary key,
  provedor      text not null,
  chave_evento  text not null,
  pedido_id     uuid references pedidos (id) on delete set null,
  status_obtido text,
  recebido_em   timestamptz not null default now(),
  unique (provedor, chave_evento)
);

alter table tokens_conta      enable row level security;
alter table desafios_2fa      enable row level security;
alter table limites           enable row level security;
alter table auditoria         enable row level security;
alter table pagamento_eventos enable row level security;

-- Permissões explícitas: em projetos novos do Supabase, tabelas novas não recebem permissões
-- automáticas (nem para service_role). Só o servidor (service_role) acessa; as chaves públicas não.
revoke all on table tokens_conta, desafios_2fa, limites, auditoria, pagamento_eventos from anon, authenticated;
grant select, insert, update, delete on table tokens_conta, desafios_2fa, limites, auditoria, pagamento_eventos to service_role;
grant usage, select on sequence auditoria_id_seq, pagamento_eventos_id_seq to service_role;

/* ---------------- funções (operações atômicas) ---------------- */

-- Conta uma tentativa na janela fixa. Devolve se ainda está permitido e quantos segundos faltam.
create or replace function consumir_limite(p_chave text, p_max integer, p_janela_s integer)
returns table (permitido boolean, espera_s integer)
language plpgsql set search_path = public as $$
declare v limites;
begin
  insert into limites as l (chave, contagem, janela_inicio) values (p_chave, 1, now())
  on conflict (chave) do update set
    contagem = case when l.janela_inicio < now() - make_interval(secs => p_janela_s) then 1 else l.contagem + 1 end,
    janela_inicio = case when l.janela_inicio < now() - make_interval(secs => p_janela_s) then now() else l.janela_inicio end
  returning * into v;
  return query select v.contagem <= p_max,
    greatest(1, ceil(extract(epoch from (v.janela_inicio + make_interval(secs => p_janela_s) - now()))))::integer;
end $$;

-- Consome um token de uso único; devolve o dono ou nada (inválido, expirado ou já usado).
create or replace function consumir_token_conta(p_hash text, p_tipo text)
returns uuid
language sql set search_path = public as $$
  update tokens_conta set usado_em = now()
   where token_hash = p_hash and tipo = p_tipo and usado_em is null and expira_em > now()
  returning usuario_id;
$$;

-- Registra a tentativa ANTES da comparação (no máximo 5) e devolve o hash para conferir.
create or replace function tentar_desafio_2fa(p_id_hash text)
returns table (usuario_id uuid, codigo_hash text)
language sql set search_path = public as $$
  update desafios_2fa set tentativas = tentativas + 1
   where id_hash = p_id_hash and expira_em > now() and tentativas < 5
  returning usuario_id, codigo_hash;
$$;

-- Cria o pedido do checkout. A mesma chave de idempotência devolve o pedido já criado
-- (clique duplo ou requisições simultâneas). Limita pedidos aguardando Pix por cliente.
create or replace function criar_pedido_checkout(
  p_usuario uuid, p_chave text, p_itens jsonb, p_subtotal numeric, p_frete numeric,
  p_frete_servico text, p_frete_nome text, p_frete_prazo integer,
  p_cliente jsonb, p_endereco jsonb, p_metodo text, p_validade_min integer
) returns setof pedidos
language plpgsql set search_path = public as $$
declare v_abertos integer;
begin
  return query select * from pedidos where usuario_id = p_usuario and chave_idempotencia = p_chave;
  if found then return; end if;

  select count(*) into v_abertos from pedidos
   where usuario_id = p_usuario and status = 'aguardando' and expira_em > now();
  if v_abertos >= 3 then raise exception 'limite_pedidos_abertos' using errcode = 'P0001'; end if;

  begin
    return query insert into pedidos (usuario_id, chave_idempotencia, itens, subtotal, frete, total, frete_servico,
                                      frete_nome, frete_prazo_dias, cliente, endereco, pagamento_metodo, expira_em)
      values (p_usuario, p_chave, p_itens, p_subtotal, p_frete, p_subtotal + p_frete, p_frete_servico,
              p_frete_nome, p_frete_prazo, p_cliente, p_endereco, p_metodo, now() + make_interval(mins => p_validade_min))
      returning *;
  exception when unique_violation then
    return query select * from pedidos where usuario_id = p_usuario and chave_idempotencia = p_chave;
  end;
end $$;

-- Aplica o status consultado no provedor. Nunca regride (de "pago" não volta), ignora repetições
-- e manda para "revisar" valor divergente ou pagamento que chegou depois de o pedido expirar.
create or replace function processar_pagamento(p_provedor text, p_pagamento_id text, p_status text, p_valor numeric)
returns text
language plpgsql set search_path = public as $$
declare p pedidos; v_novo text;
begin
  select * into p from pedidos where pagamento_id = p_pagamento_id for update;
  if not found then return 'ignorado'; end if;

  insert into pagamento_eventos (provedor, chave_evento, pedido_id, status_obtido)
  values (p_provedor, p_pagamento_id || ':' || p_status, p.id, p_status)
  on conflict (provedor, chave_evento) do nothing;
  if not found then return 'ignorado'; end if;

  if p_status = 'aprovado' then
    if p_valor is not null and p_valor <> p.total then v_novo := 'revisar';
    elsif p.status = 'aguardando' then v_novo := 'pago';
    elsif p.status in ('expirado', 'cancelado') then v_novo := 'revisar';
    end if;
  elsif p_status in ('negado', 'cancelado') and p.status = 'aguardando' then
    v_novo := 'cancelado';
  end if;

  update pedidos set pagamento_status = p_status, status = coalesce(v_novo, status), atualizado_em = now() where id = p.id;
  insert into auditoria (usuario_id, acao, detalhe)
  values (p.usuario_id, 'pagamento_atualizado', jsonb_build_object('pedido', p.numero, 'status', p_status, 'novo', v_novo));
  return case when v_novo is null then 'ignorado' else 'atualizado' end;
end $$;

-- As funções só podem ser chamadas pelo servidor (chave service_role), nunca pela API pública.
revoke execute on function consumir_limite(text, integer, integer) from public, anon, authenticated;
revoke execute on function consumir_token_conta(text, text) from public, anon, authenticated;
revoke execute on function tentar_desafio_2fa(text) from public, anon, authenticated;
revoke execute on function criar_pedido_checkout(uuid, text, jsonb, numeric, numeric, text, text, integer, jsonb, jsonb, text, integer) from public, anon, authenticated;
revoke execute on function processar_pagamento(text, text, text, numeric) from public, anon, authenticated;
grant execute on function consumir_limite(text, integer, integer) to service_role;
grant execute on function consumir_token_conta(text, text) to service_role;
grant execute on function tentar_desafio_2fa(text) to service_role;
grant execute on function criar_pedido_checkout(uuid, text, jsonb, numeric, numeric, text, text, integer, jsonb, jsonb, text, integer) to service_role;
grant execute on function processar_pagamento(text, text, text, numeric) to service_role;


-- Fonte: supabase/migracoes/003-cadastro-estoque-notas.sql
-- Dred Stil — migração 003: cadastro completo (nome, apelido, telefone, CPF), estoque por grupo
-- e notas fiscais. Rodar UMA vez no SQL Editor do Supabase, depois da 002. Idempotente.
-- Não apaga dados. Reverter: supabase/migracoes/003-reverter.sql.


/* ---------------- contas: apelido (nick) e CPF ---------------- */
alter table usuarios add column if not exists apelido text;
alter table usuarios add column if not exists cpf text;
alter table usuarios drop constraint if exists usuarios_apelido_formato;
alter table usuarios add constraint usuarios_apelido_formato check (apelido is null or apelido ~ '^[a-z0-9_.]{3,30}$');
alter table usuarios drop constraint if exists usuarios_cpf_formato;
alter table usuarios add constraint usuarios_cpf_formato check (cpf is null or cpf ~ '^[0-9]{11}$');
-- Apelido e CPF não se repetem entre contas (CPF é opcional).
create unique index if not exists usuarios_apelido_unico on usuarios (apelido) where apelido is not null;
create unique index if not exists usuarios_cpf_unico on usuarios (cpf) where cpf is not null;
-- Recuperação de senha pelo nome completo (busca sem diferenciar maiúsculas).
create index if not exists usuarios_nome_idx on usuarios (lower(nome));

/* ---------------- estoque por grupo ---------------- */
-- Um grupo (ex.: "Camisas", 30 peças) com vários produtos. Cada venda desce o total do grupo.
create table if not exists estoques (
  id             uuid primary key default gen_random_uuid(),
  nome           text not null unique check (length(nome) between 2 and 60),
  quantidade     integer not null default 0 check (quantidade >= 0),
  criado_em      timestamptz not null default now(),
  atualizado_em  timestamptz not null default now()
);
alter table produtos add column if not exists estoque_id uuid references estoques (id) on delete set null;
-- NCM do produto para a nota fiscal (61091000 = camiseta de malha de algodão; confirmar com o contador).
alter table produtos add column if not exists codigo_ncm text not null default '61091000';
alter table produtos drop constraint if exists produtos_codigo_ncm_formato;
alter table produtos add constraint produtos_codigo_ncm_formato check (codigo_ncm ~ '^[0-9]{8}$');

create table if not exists estoque_movimentos (
  id                bigint generated always as identity primary key,
  estoque_id        uuid not null references estoques (id) on delete cascade,
  delta             integer not null,
  quantidade_final  integer not null,
  motivo            text not null,
  pedido_id         uuid references pedidos (id) on delete set null,
  usuario_id        uuid,
  criado_em         timestamptz not null default now()
);
create index if not exists estoque_movimentos_idx on estoque_movimentos (estoque_id, criado_em desc);

alter table pedidos add column if not exists estoque_baixado boolean not null default false;

-- Baixa o estoque quando o pedido vira venda (Pago/Enviado/Entregue) e devolve se uma venda for cancelada.
-- Fica no banco para valer em todos os caminhos: Pix automático e mudança manual pelo admin.
create or replace function pedidos_estoque() returns trigger
language plpgsql set search_path = public as $$
declare r record; v_sinal integer;
begin
  if new.status in ('pago', 'enviado', 'entregue') and not old.estoque_baixado then
    v_sinal := -1; new.estoque_baixado := true;
  elsif new.status = 'cancelado' and old.estoque_baixado then
    v_sinal := 1; new.estoque_baixado := false;
  else
    return new;
  end if;
  for r in
    select p.estoque_id, sum((i ->> 'qtd')::integer) as qtd
      from jsonb_array_elements(new.itens) i
      join produtos p on p.handle = i ->> 'handle'
     where p.estoque_id is not null
     group by p.estoque_id
  loop
    update estoques set quantidade = greatest(0, quantidade + v_sinal * r.qtd), atualizado_em = now() where id = r.estoque_id;
    insert into estoque_movimentos (estoque_id, delta, quantidade_final, motivo, pedido_id)
    select r.estoque_id, v_sinal * r.qtd, e.quantidade,
           case when v_sinal < 0 then 'Venda #' else 'Cancelamento #' end || new.numero, new.id
      from estoques e where e.id = r.estoque_id;
  end loop;
  return new;
end $$;

drop trigger if exists pedidos_estoque on pedidos;
create trigger pedidos_estoque before update of status on pedidos
  for each row when (old.status is distinct from new.status) execute function pedidos_estoque();

/* ---------------- notas fiscais ---------------- */
create table if not exists notas_fiscais (
  id                uuid primary key default gen_random_uuid(),
  pedido_id         uuid not null references pedidos (id) on delete restrict,
  usuario_id        uuid references usuarios (id) on delete set null,
  ref               text not null unique,  -- referência enviada ao emissor
  provedor          text not null,
  status            text not null check (status in ('processando', 'autorizada', 'erro', 'cancelada')),
  numero            text,
  serie             text,
  chave             text,
  url_danfe         text,
  url_xml           text,
  mensagem          text,
  email_enviado_em  timestamptz,
  criado_em         timestamptz not null default now(),
  atualizado_em     timestamptz not null default now()
);
-- No máximo uma nota em andamento ou autorizada por pedido (evita nota duplicada).
create unique index if not exists notas_ativas_por_pedido on notas_fiscais (pedido_id) where status in ('processando', 'autorizada');
create index if not exists notas_usuario_idx on notas_fiscais (usuario_id, criado_em desc);

/* ---------------- RLS e permissões (só o servidor acessa) ---------------- */
alter table estoques           enable row level security;
alter table estoque_movimentos enable row level security;
alter table notas_fiscais      enable row level security;
revoke all on table estoques, estoque_movimentos, notas_fiscais from anon, authenticated;
grant select, insert, update, delete on table estoques, estoque_movimentos, notas_fiscais to service_role;
grant usage, select on sequence estoque_movimentos_id_seq to service_role;
revoke execute on function pedidos_estoque() from public, anon, authenticated;


-- Fonte: supabase/migracoes/004-getnet-global.sql
-- Somente o checkout Global: uma intenção pode conter tentativa recusada e depois aprovada.
-- A recusa de uma tentativa não cancela a intenção nem o pedido.
create or replace function processar_pagamento_global(p_pagamento_id text, p_status text, p_valor numeric)
returns text
language plpgsql set search_path = public as $$
declare p pedidos; v_novo text;
begin
  if p_status not in ('aprovado', 'negado', 'pendente', 'cancelado') then
    raise exception 'status_pagamento_invalido';
  end if;
  select * into p from pedidos where pagamento_id = p_pagamento_id and pagamento_metodo = 'getnet-checkout' for update;
  if not found then return 'ignorado'; end if;
  -- Nunca regredir um pedido já pago, em transporte ou entregue por aviso atrasado.
  if p.status in ('pago', 'enviado', 'entregue', 'revisar') then return 'ignorado'; end if;
  if p.pagamento_status = p_status then return 'ignorado'; end if;
  if p_status = 'aprovado' then
    if p_valor is null or p_valor <> p.total or p.status in ('expirado', 'cancelado') then v_novo := 'revisar';
    elsif p.status = 'aguardando' then v_novo := 'pago';
    end if;
  elsif p_status = 'cancelado' and p.status = 'aguardando' then v_novo := 'cancelado';
  end if;
  insert into pagamento_eventos (provedor, chave_evento, pedido_id, status_obtido)
    values ('getnet-global', p_pagamento_id || ':' || p_status, p.id, p_status)
    on conflict (provedor, chave_evento) do nothing;
  update pedidos set pagamento_status = p_status, status = coalesce(v_novo, status), atualizado_em = now() where id = p.id;
  insert into auditoria (usuario_id, acao, detalhe)
    values (p.usuario_id, 'pagamento_atualizado', jsonb_build_object('pedido', p.numero, 'status', p_status, 'novo', v_novo));
  return 'atualizado';
end $$;

revoke execute on function processar_pagamento_global(text, text, numeric) from public, anon, authenticated;
grant execute on function processar_pagamento_global(text, text, numeric) to service_role;

-- Fonte: supabase/migracoes/005-estoque-por-cor.sql
-- Dred Stil — 005: saldos por tipo de peça + cor. Aplicar depois da 004.
-- Os grupos antigos permanecem com cor NULL e seu saldo não é duplicado.

alter table estoques add column if not exists cor text;
alter table estoques add column if not exists arquivado boolean not null default false;
alter table estoques drop constraint if exists estoques_cor_formato;
alter table estoques add constraint estoques_cor_formato check (cor is null or length(btrim(cor)) between 1 and 40);
alter table estoques drop constraint if exists estoques_nome_key;
create unique index if not exists estoques_nome_cor_unicos on estoques
  ((case when cor is null then nome else lower(btrim(nome)) end), lower(btrim(coalesce(cor, '')))) where not arquivado;

-- A mesma cor de um produto só pode consumir um saldo. Cores distintas são independentes.
create table if not exists estoque_produtos_cores (
  handle text not null references produtos(handle) on update cascade on delete cascade,
  cor text not null check (cor = lower(btrim(cor)) and length(cor) between 1 and 40),
  estoque_id uuid not null references estoques(id) on delete restrict,
  primary key (handle, cor)
);
create index if not exists estoque_produtos_cores_estoque_idx on estoque_produtos_cores(estoque_id);
alter table estoque_produtos_cores enable row level security;
revoke all on estoque_produtos_cores from anon, authenticated;
grant select, insert, update, delete on estoque_produtos_cores to service_role;

-- Saldo, vínculos e histórico são alterados numa única transação.
create or replace function salvar_estoque_cor(p_id uuid, p_nome text, p_cor text,
  p_quantidade integer, p_produtos jsonb, p_usuario uuid) returns jsonb
language plpgsql set search_path = public as $$
declare v estoques; v_anterior integer := 0; v_novo boolean := p_id is null;
begin
  if length(btrim(p_nome)) not between 2 and 60 or p_quantidade not between 0 and 100000
     or (p_cor is not null and length(btrim(p_cor)) not between 1 and 40) then
    raise exception 'estoque_invalido' using errcode = '23514';
  end if;
  -- Também protege chamadas diretas da função com a chave do servidor.
  if exists (select 1 from jsonb_array_elements_text(p_produtos) h where not exists (
    select 1 from produtos p where p.handle = h and (p_cor is null or exists (
      select 1 from jsonb_array_elements(p.cores) c where lower(btrim(c->>'nome')) = lower(btrim(p_cor))
    ))
  )) then raise exception 'produto_sem_cor' using errcode = '23514'; end if;
  if v_novo then
    insert into estoques(nome, cor, quantidade) values (btrim(p_nome), nullif(btrim(p_cor), ''), p_quantidade) returning * into v;
  else
    select * into v from estoques where id = p_id and not arquivado for update;
    if not found then return null; end if;
    if lower(btrim(coalesce(v.cor, ''))) <> lower(btrim(coalesce(p_cor, ''))) then
      raise exception 'cor_estoque_imutavel' using errcode = '23514';
    end if;
    v_anterior := v.quantidade;
    update estoques set nome = btrim(p_nome), quantidade = p_quantidade, atualizado_em = now()
      where id = p_id returning * into v;
  end if;
  if v.cor is null then
    update produtos set estoque_id = null where estoque_id = v.id;
    update produtos set estoque_id = v.id where handle in (select jsonb_array_elements_text(p_produtos));
  else
    delete from estoque_produtos_cores where estoque_id = v.id;
    insert into estoque_produtos_cores(handle, cor, estoque_id)
      select h, lower(btrim(v.cor)), v.id from jsonb_array_elements_text(p_produtos) h
      on conflict(handle, cor) do update set estoque_id = excluded.estoque_id;
  end if;
  if v_novo or v_anterior <> p_quantidade then
    insert into estoque_movimentos(estoque_id, delta, quantidade_final, motivo, usuario_id)
    values (v.id, p_quantidade - v_anterior, p_quantidade,
      case when v_novo then 'Estoque criado' when p_quantidade > v_anterior then 'Entrada de peças' else 'Ajuste manual' end, p_usuario);
  end if;
  return to_jsonb(v);
end $$;

-- Arquivar mantém os saldos históricos e a referência dos pedidos já criados.
create or replace function arquivar_estoque(p_id uuid) returns boolean
language plpgsql set search_path = public as $$
begin
  perform 1 from estoques where id = p_id and not arquivado for update;
  if not found then return false; end if;
  update estoques set arquivado = true, atualizado_em = now() where id = p_id;
  delete from estoque_produtos_cores where estoque_id = p_id;
  update produtos set estoque_id = null where estoque_id = p_id;
  return true;
end $$;

-- Usa o vínculo conferido pelo servidor no momento da compra. Trocar o produto de
-- grupo depois não desvia a baixa nem a devolução para outro grupo/cor.
create or replace function pedidos_estoque() returns trigger
language plpgsql set search_path = public as $$
declare r record; v_sinal integer; v_antes integer; v_depois integer; v_delta integer;
begin
  if new.status in ('pago', 'enviado', 'entregue') and not old.estoque_baixado then
    v_sinal := -1; new.estoque_baixado := true;
  elsif new.status = 'cancelado' and old.estoque_baixado then
    v_sinal := 1; new.estoque_baixado := false;
  else return new;
  end if;
  if v_sinal = -1 then
    for r in
      select e.id as estoque_id, sum((i->>'qtd')::integer)::integer as qtd
      from jsonb_array_elements(new.itens) i
      left join produtos p on p.handle = i->>'handle'
      left join estoque_produtos_cores pc on pc.handle = p.handle and pc.cor = lower(btrim(i->>'cor'))
      join estoques e on e.id = case when i ? 'estoqueId'
        then nullif(i->>'estoqueId', '')::uuid else coalesce(pc.estoque_id, p.estoque_id) end
      group by e.id order by e.id
    loop
      select quantidade into v_antes from estoques where id = r.estoque_id for update;
      v_depois := greatest(0, v_antes - r.qtd);
      v_delta := v_depois - v_antes;
      update estoques set quantidade = v_depois, atualizado_em = now() where id = r.estoque_id;
      insert into estoque_movimentos(estoque_id, delta, quantidade_final, motivo, pedido_id)
      values (r.estoque_id, v_delta, v_depois, 'Venda #' || new.numero ||
        case when r.qtd > v_antes then ' (faltam ' || (r.qtd - v_antes) || ' peças; conferir reposição)' else '' end, new.id);
    end loop;
  else
    -- Os novos movimentos guardam a baixa efetiva. Movimentos anteriores à 005
    -- mantêm os valores já registrados pelo sistema antigo (sem reescrever o histórico).
    for r in select estoque_id, -sum(delta)::integer as qtd from estoque_movimentos
      where pedido_id = new.id group by estoque_id having sum(delta) < 0 order by estoque_id
    loop
      update estoques set quantidade = quantidade + r.qtd, atualizado_em = now()
        where id = r.estoque_id returning quantidade into v_depois;
      insert into estoque_movimentos(estoque_id, delta, quantidade_final, motivo, pedido_id)
      values (r.estoque_id, r.qtd, v_depois, 'Cancelamento #' || new.numero, new.id);
    end loop;
  end if;
  return new;
end $$;

revoke execute on function salvar_estoque_cor(uuid,text,text,integer,jsonb,uuid), arquivar_estoque(uuid) from public, anon, authenticated;
grant execute on function salvar_estoque_cor(uuid,text,text,integer,jsonb,uuid), arquivar_estoque(uuid) to service_role;
revoke execute on function pedidos_estoque() from public, anon, authenticated;

-- Fonte: supabase/migracoes/006-categorias-mover.sql
-- Categorias existentes podem mudar de pai sem alterar slug, produtos ou menu.
-- Rodar após as migrações anteriores. A loja mantém somente um nível de subcategoria.
-- A trava antes do comando serializa alterações concorrentes da árvore.
create or replace function public.travar_arvore_categorias()
returns trigger language plpgsql set search_path = public as $$
begin
  perform pg_advisory_xact_lock(783420761);
  return null;
end;
$$;

create or replace function public.validar_arvore_categorias()
returns trigger language plpgsql set search_path = public as $$
declare v_pai text;
begin
  if new.pai is null then return new; end if;
  if new.pai = new.slug then
    raise exception 'Uma categoria não pode ficar dentro dela mesma.' using errcode = '23514';
  end if;
  select pai into v_pai from public.categorias where slug = new.pai;
  if not found then
    raise exception 'Categoria principal não encontrada.' using errcode = '23503';
  end if;
  if v_pai is not null then
    raise exception 'Subcategorias só podem ficar dentro de uma categoria principal.' using errcode = '23514';
  end if;
  if exists (select 1 from public.categorias where pai = new.slug) then
    raise exception 'Esta categoria tem subcategorias. Mova as subcategorias primeiro.' using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists categorias_travar_arvore on public.categorias;
create trigger categorias_travar_arvore before insert or update of pai on public.categorias
for each statement execute function public.travar_arvore_categorias();
drop trigger if exists categorias_validar_arvore on public.categorias;
create trigger categorias_validar_arvore before insert or update of pai on public.categorias
for each row execute function public.validar_arvore_categorias();

-- Fonte: supabase/dados-iniciais.sql
-- Dred Stil: dados iniciais (categoria, produto, menu, destaques, páginas, perguntas frequentes e configurações).
-- Rodar uma vez, depois de estrutura.sql. Não sobrescreve o que já existir.

insert into categorias (slug, nome, ordem) values ('camisetas', 'Camisetas', 0)
on conflict (slug) do nothing;

insert into produtos (handle, nome, categoria, preco, preco_de, descricao, tamanhos, cores, ativo, criado_em)
values ('camiseta-oversized-dred-stil', 'Camiseta Oversized Dred Stil', 'camisetas', 99.9, 0, 'Camiseta oversized com estampa Dred Stil na frente e nas costas. Modelagem ampla, ombro caído e malha encorpada.', '["P","M","G","GG","XG"]'::jsonb, '[{"hex":"#F2EDE3","nome":"Off White","imagens":["/img/produtos/offwhite-frente.jpg","/img/produtos/offwhite-costas.jpg","/img/produtos/offwhite-frente-costas.jpg"]},{"hex":"#C9AE84","nome":"Bege","imagens":["/img/produtos/bege-frente.webp","/img/produtos/bege-costas.webp"]},{"hex":"#1A1A1A","nome":"Preto","imagens":["/img/produtos/preto-frente.webp","/img/produtos/preto-costas.webp"]}]'::jsonb, true, '2026-10-06T00:00:00+00:00')
on conflict (handle) do nothing;

insert into conteudo (chave, valor) values
  ('faq', '[{"pergunta":"Vocês têm loja física?","resposta":"Sim! Estamos na Av. Maria Antonieta, 354, em Pinhais/PR. Atendemos de segunda a sexta, das 10h às 19h, e aos sábados, das 10h às 18h."},{"pergunta":"Como faço meu pedido?","resposta":"Escolha o produto, a cor e o tamanho, adicione ao carrinho e clique em \"Finalizar a compra\". Você será levado ao nosso WhatsApp com o pedido pronto para combinarmos pagamento e entrega."},{"pergunta":"Quais são as formas de pagamento?","resposta":"Combinamos o pagamento no atendimento pelo WhatsApp. Parcelamos em até 6x sem juros."},{"pergunta":"Como escolho o tamanho certo?","resposta":"As camisetas oversized têm modelagem ampla e ombro caído. Se ficar em dúvida, chame a gente no WhatsApp que passamos as medidas de cada tamanho."},{"pergunta":"Posso trocar um produto?","resposta":"Pode. Veja as condições na página Trocas e devoluções ou fale com a gente pelo WhatsApp."}]'::jsonb),
  ('config', '{"banners":[{"alt":"Linha de Frente: moda feminina e masculina perto de você","link":"/catalogo","imagem":"/img/banners/linha-de-frente.webp"},{"alt":"linha de frente","link":"/catalogo","imagem":"https://vzltcwlcagbkgndldhnw.supabase.co/storage/v1/object/public/produtos/83320e58-52f2-4795-a908-2621626ddd69.webp"}],"parcelas":6,"telefone":"(41) 3557-6892","whatsapp":"554135576892","redesSociais":{"tiktok":"","youtube":"","facebook":"","instagram":"https://www.instagram.com/linha_de_frente_namoda/reels/"},"mensagemPromocional":"Parcele em até 6x sem juros"}'::jsonb),
  ('menu', '[{"tipo":"link","rotulo":"Início","link":"/","visivel":true},{"tipo":"catalogo","rotulo":"Catálogo","visivel":true},{"tipo":"pagina","rotulo":"Quem somos","pagina":"quem-somos","visivel":true},{"tipo":"pagina","rotulo":"Onde estamos","pagina":"onde-estamos","visivel":true}]'::jsonb),
  ('destaques', '[{"nome":"Camisetas","produtos":["camiseta-oversized-dred-stil"]}]'::jsonb),
  ('paginas', '{"quem-somos":{"titulo":"Quem somos","texto":"A **Dred Stil** nasceu de uma ideia simples: trazer o que há de mais atual na moda jovem para perto de você.\n\nCriamos peças que unem estilo, qualidade e personalidade, acompanhando as principais tendências sem deixar de lado a nossa própria identidade.\n\nMais do que vestir, queremos que cada peça represente uma atitude, um estilo e uma forma de se expressar.\n\n**Dred Stil — estilo que acompanha você.**\n\n## Nossa loja\nAlém do site, você pode nos visitar na Av. Maria Antonieta, 354, em Pinhais/PR. Lá dá para provar as peças, conhecer as novidades e falar com a nossa equipe.\n\n## Fale com a gente\nFicou com alguma dúvida? Chame no WhatsApp pelo botão verde no canto da tela ou veja as [perguntas frequentes](/#perguntas)."},"trocas-e-devolucoes":{"titulo":"Trocas e devoluções","texto":"Queremos que você fique feliz com a sua compra. Se algo não deu certo, veja abaixo como resolver.\n\n## Arrependimento (compras pela internet)\nConforme o Código de Defesa do Consumidor (art. 49), compras feitas fora da loja física podem ser canceladas em até **7 dias corridos** a partir do recebimento, com devolução integral do valor pago.\n\n## Troca de tamanho ou modelo\nPara trocar por outro tamanho, cor ou modelo, fale com a gente pelo WhatsApp ou vá até a loja física. A peça precisa estar sem uso, sem lavagem e com a etiqueta.\n\n## Produto com defeito\nSe a peça apresentar defeito de fabricação, você tem até **90 dias** após o recebimento para nos avisar. Fazemos a troca pelo mesmo produto ou, se não houver estoque, devolvemos o valor.\n\n## Como solicitar\n1. Chame a gente no WhatsApp informando o número do pedido ou o nome usado na compra.\n2. Conte o motivo da troca ou devolução e, em caso de defeito, envie fotos da peça.\n3. Nossa equipe explica como enviar ou entregar a peça e acompanha você até o fim."},"onde-estamos":{"titulo":"Onde estamos","texto":"## Endereço\nAv. Maria Antonieta, 354\nPinhais/PR · CEP 83.331-000\n\n## Horário de funcionamento\nSegunda a sexta: 10h às 19h\nSábado: 10h às 18h\nDomingo: fechado"},"seguranca":{"titulo":"Segurança","texto":"Cuidar dos seus dados é parte do nosso trabalho. Veja como protegemos você ao navegar e comprar na Dred Stil.\n\n## Sua conta\n- As senhas são guardadas de forma criptografada: nem a nossa equipe consegue vê-las.\n- O acesso à conta usa um cookie de sessão protegido, que não pode ser lido por outros sites.\n- Ao trocar a senha, as sessões abertas em outros aparelhos são encerradas.\n\n## Atendimento\n- Nunca pedimos sua senha por WhatsApp, telefone ou e-mail.\n- Esqueceu a senha? Use o link \"Esqueci minha senha\" na tela de entrar: enviamos pelo WhatsApp uma senha temporária para você trocar em Minha conta.\n- Nosso WhatsApp oficial é o mesmo informado no rodapé do site.\n- Desconfie de mensagens com preços muito abaixo do normal ou links estranhos usando o nome da loja.\n\n## Dicas para você\n- Use uma senha forte e diferente da que você usa em outros sites.\n- Confira se o endereço do site está correto antes de entrar na sua conta.\n\nViu algo suspeito? Fale com a gente pelo WhatsApp."},"politica-de-privacidade":{"titulo":"Política de privacidade","texto":"Esta política explica quais dados a Dred Stil (CNPJ 12.157.291/0001-05) coleta, por que coleta e quais são os seus direitos, de acordo com a Lei Geral de Proteção de Dados (LGPD — Lei 13.709/2018).\n\n## Dados que coletamos\n- **Cadastro:** nome, e-mail, telefone (opcional) e senha criptografada.\n- **Uso da loja:** os produtos que você curtiu.\n- **Carrinho:** fica salvo apenas no seu navegador até você finalizar a compra.\n- **Pedidos:** os produtos, quantidades e valores de cada pedido, ligados à sua conta quando você está conectado.\n\n## Para que usamos\n- Criar e manter a sua conta e mostrar os seus favoritos e pedidos.\n- Atender pedidos, trocas e dúvidas.\n- Cumprir obrigações legais e fiscais.\n\nNão vendemos nem compartilhamos seus dados com terceiros para fins de propaganda.\n\n## Cookies\nUsamos apenas um cookie essencial, que mantém você conectado à sua conta. Não usamos cookies de rastreamento ou publicidade.\n\n## Seus direitos\nVocê pode pedir a qualquer momento acesso, correção ou exclusão dos seus dados, além de informações sobre como eles são tratados. Basta falar com a gente pelo WhatsApp informado no rodapé.\n\n## Por quanto tempo guardamos\nMantemos os dados enquanto sua conta estiver ativa ou pelo tempo exigido por lei. Depois disso, eles são apagados.\n\n## Alterações\nEsta política pode ser atualizada. A versão em vigor é sempre a publicada nesta página."},"termos-de-uso":{"titulo":"Termos de uso","texto":"Ao usar o site da Dred Stil você concorda com os termos abaixo. Leia com atenção.\n\n## Sobre a loja\nEste site pertence à Dred Stil (CNPJ 12.157.291/0001-05), com loja física na Av. Maria Antonieta, 354, Pinhais/PR.\n\n## Conta\n- Você é responsável por manter sua senha em segurança e pelas ações feitas na sua conta.\n- As informações do cadastro devem ser verdadeiras e atualizadas.\n- Podemos suspender contas usadas de forma abusiva ou fraudulenta.\n\n## Produtos e preços\n- Fazemos o possível para que fotos, cores e descrições sejam fiéis, mas pode haver pequenas variações de tela.\n- Preços e disponibilidade podem mudar sem aviso. O valor válido é o confirmado no fechamento do pedido.\n\n## Pedidos\nO pedido é registrado no site e confirmado no atendimento pelo WhatsApp, onde combinamos pagamento e entrega. Trocas e devoluções seguem a página [Trocas e devoluções](/trocas-e-devolucoes).\n\n## Conteúdo\nMarca, logotipo, fotos e textos do site pertencem à Dred Stil e não podem ser usados sem autorização.\n\n## Privacidade\nO tratamento dos seus dados segue a nossa [Política de privacidade](/politica-de-privacidade)."}}'::jsonb)
on conflict (chave) do nothing;

-- Atualiza o catálogo exposto pela Data API do Supabase após o commit.
notify pgrst, 'reload schema';

commit;
