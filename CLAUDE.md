# CLAUDE.md — GC-Pedidos

Guia do projeto para o Claude (e para qualquer pessoa que for mexer no código). Leia antes de alterar qualquer arquivo.

## 1. O que é o projeto

**GC-Pedidos** é um aplicativo para o **gerente de compras** controlar o estoque, descobrir o que está faltando e **enviar o pedido ao vendedor do fornecedor pelo WhatsApp**.

Fluxo principal:

1. O gerente cria a conta (foto, nome completo, WhatsApp, endereço, função, e-mail e senha) e confirma o e-mail.
2. Cadastra produtos numa tabela estilo Excel. **Total em estoque = quantidade 1 (entrada) − quantidade 2 (saída).**
3. Cadastra os **fornecedores** (nome da empresa + WhatsApp do vendedor).
4. Vincula cada produto a um fornecedor na própria tabela. O produto aparece automaticamente na tela de pedido daquele fornecedor, sempre atualizado.
5. Em **Novo pedido**, escolhe o fornecedor, marca os produtos, ajusta as quantidades e envia pelo WhatsApp.
6. Cada envio vai para o **Histórico**, que permite reenviar.

Interface em **português do Brasil**. Público: pequenos comércios e equipes de compras, principalmente no celular.

## 2. Arquitetura

Aplicativo web estático (PWA) que fala direto com o **Supabase**: banco **Postgres**, **Auth** (e-mail e senha) e **Realtime**. Não há servidor próprio.

```
Navegador/PWA ──(supabase-js, chave publishable + JWT do usuário)──► Supabase
                                                                       ├─ Auth (login, confirmação, recuperação de senha)
                                                                       ├─ Postgres + Row Level Security
                                                                       └─ Realtime (sincroniza aparelhos)
```

Variantes do projeto:

| Pasta/arquivo | O que é | Status |
|---|---|---|
| `gc-pedidos-supabase/` | **Versão atual**: login e banco no Supabase | Evoluir aqui |
| `gc-pedidos-site/` | Versão anterior, 100% local (`localStorage`) | Congelada |
| Artifact no claude.ai | Demonstração dentro do Claude (`window.claude`) | Não usar como base |

Nunca copie código que use `window.claude` / `claude.use(...)` para a versão com Supabase.

## 3. Estrutura de arquivos (versão atual)

```
gc-pedidos-supabase/
├── index.html            # App inteiro: HTML + CSS + JS
├── config.js             # URL do projeto e chave publishable (única coisa a editar para ligar o app)
├── manifest.json         # PWA: nome, cores, ícones
├── sw.js                 # Service worker (rede primeiro; nunca guarda chamadas ao Supabase)
├── icons/                # 192, 512 e maskable 512
├── supabase/
│   └── schema.sql        # Tabelas, RLS, trigger de perfil, Realtime
└── LEIA-ME-SUPABASE.md   # Passo a passo de configuração
CLAUDE.md
```

Decisão deliberada: **um único `index.html`, sem build e sem framework.** Qualquer pessoa publica arrastando a pasta. Só introduza ferramentas de build se houver motivo forte (empacotar para a Play Store, testes, TypeScript).

## 4. Stack e dependências

- JavaScript puro (ES2020), CSS com variáveis, telas montadas com template strings em `innerHTML`.
- **@supabase/supabase-js 2.104.1** (UMD) via `https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.104.1/dist/umd/supabase.js`, global `window.supabase`.
- **SheetJS 0.18.5** via cdnjs, só para exportar `.xlsx`.
- **IBM Plex Sans** (Google Fonts) com `system-ui` de reserva.
- WhatsApp por link `https://wa.me/<número>?text=<mensagem>`.

Regras para dependências: sempre **versão exata** na URL (nunca `@2` ou `latest`), de preferência com mais de duas semanas de publicada, e só de hosts já usados (jsdelivr, cdnjs).

## 5. Banco de dados (`supabase/schema.sql`)

| Tabela | Colunas principais |
|---|---|
| `profiles` | `id` (= `auth.users.id`), `nome`, `tel`, `endereco`, `funcao`, `foto` (data URL JPEG 160 px) |
| `suppliers` | `id`, `owner`, `nome`, `whatsapp` |
| `products` | `id`, `owner`, `nome`, `marca`, `q1`, `d1`, `q2`, `d2`, `minimo`, `supplier_id` (FK, `on delete set null`) |
| `orders` | `id`, `owner`, `supplier_name`, `supplier_wa`, `items` (jsonb `[{nome, marca, q}]`), `txt`, `created_at` |

- `owner` tem `default auth.uid()`: o app **não envia** `owner` ao inserir.
- **Row Level Security ligado em todas as tabelas.** Cada usuário só lê e escreve linhas com `owner = auth.uid()` (perfil: `id = auth.uid()`). A política de `products` também exige que `supplier_id` seja de um fornecedor do mesmo dono.
- Um trigger em `auth.users` cria o `profiles` a partir de `raw_user_meta_data` (`nome`, `tel`, `endereco`, `funcao`). **A foto não vai nos metadados** (inflaria o JWT): fica em `localStorage` (`gc_pending_foto`) e é gravada no perfil no primeiro login.
- `products`, `suppliers` e `orders` estão na publicação `supabase_realtime`.
- Pedidos guardam `supplier_name` e `supplier_wa` copiados, para o histórico continuar correto se o fornecedor mudar ou for excluído.

Regras de negócio:

- **Total** = `(+q1||0) − (+q2||0)` (`tot(p)`); pode ser negativo (vermelho).
- **Faltam** = `max(minimo − total, 0)`; se > 0 o total fica laranja e a quantidade sugerida no pedido já vem preenchida (mínimo 1).
- Vínculo produto ↔ fornecedor é só `products.supplier_id`; a tela de pedido filtra por ele.
- WhatsApp: remove não-dígitos; com **11 dígitos ou menos** adiciona `55` (função `waUrl`).

**Alterações de esquema:** crie sempre um novo arquivo SQL (ex.: `supabase/migrations/002_xxx.sql`) e aplique no SQL Editor; nunca edite o `schema.sql` já aplicado sem registrar a migração. Toda tabela nova nasce com RLS e políticas.

## 6. Autenticação

- `signUp` com e-mail e senha (`options.data` = nome, tel, endereco, funcao; `emailRedirectTo` = endereço do site).
- Com confirmação de e-mail ligada, `signUp` volta sem sessão: o app avisa e leva ao login. E-mail já cadastrado volta com `identities` vazio.
- `signInWithPassword`; `signOut`; `resetPasswordForEmail` com `redirectTo` = endereço do site.
- Ao voltar do link de recuperação, o evento `PASSWORD_RECOVERY` abre a tela `newpass`, que chama `updateUser({ password })`.
- Controle de sessão em `sb.auth.onAuthStateChange`. **Não faça chamadas ao Supabase diretamente dentro desse callback**: use `setTimeout(fn, 0)` (ver `enterApp`).
- Mensagens de erro do Supabase passam por `trad()` e viram texto em português.
- **Site URL e Redirect URLs** do Supabase precisam apontar para o endereço publicado, senão os links dos e-mails não voltam ao app.

## 7. Telas e código

`view`: `loading`, `login`, `register`, `forgot`, `newpass`, `app`. Dentro de `app`, `tab`: `estoque`, `fornecedores`, `pedido`, `historico`, `perfil`. Se `config.js` não foi preenchido, aparece `renderSetup()`.

Estado em memória: `USER` (usuário do Auth) e `S = { profile, products, suppliers, orders }`, carregado por `loadAll()`.

Funções-chave: `loadAll`, `enterApp`, `subscribeRT`/`schedReload` (Realtime), `queueSave` (salva produto com atraso de 600 ms), `logOrder`, `exportXlsx`, `waUrl`, `esc`, `toast`, `dlFile`, `render`.

Padrões que **devem** ser mantidos:

- Editar célula da tabela de estoque **não re-renderiza** a tabela: atualiza o objeto local, chama `queueSave(p)` e muda só a célula de total (não perde o foco).
- `schedReload` **não recarrega** enquanto houver salvamentos pendentes (`timers`) ou campo em edição; tenta de novo depois.
- Toda escrita confere `error` e avisa com `toast`; o estado local só muda quando o banco confirma (exceto edição de célula, que é otimista e mostra "Salvando…/Salvo").
- Sem `<form>`; usar `onclick`/`onchange`.

## 8. Convenções

- **Todo texto vindo do usuário passa por `esc()`** antes de entrar em `innerHTML` ou atributos.
- Interface em português do Brasil, minúsculas de frase, verbos diretos nos botões; a mesma ação mantém o mesmo nome do botão ao aviso. Erros dizem o que houve e como corrigir, sem pedir desculpas.
- Textos visíveis usam `’` e `“ ”`; em código, aspas retas.
- Mobile primeiro; tabela dentro de contêiner com `overflow-x: auto`.
- **Segredos:** só a chave `sb_publishable_...` (ou a `anon` legada) pode aparecer no código. **Nunca** `secret`/`service_role`, nem senha do banco, em arquivo do site ou do repositório.

## 9. Design

Painel de compras sóbrio, azul-petróleo, com verde-WhatsApp só no botão de envio. Tokens em `:root` (com versão escura em `prefers-color-scheme: dark` e `[data-theme="dark"]`): `--bg #eef2f1`, `--sf #fff`, `--ink #12303a`, `--mut #5b727a`, `--ln #d3dfdd`, `--ac #0f766e`, `--wa #128c4a`, `--warn #b45309`, `--bad #b91c1c`. Fonte IBM Plex Sans, corpo 15 px, foco visível, `env(safe-area-inset-*)` respeitado.

## 10. PWA e publicação

- Hospedagem estática com HTTPS (Netlify, Cloudflare Pages, GitHub Pages).
- `sw.js` usa **rede primeiro** e ignora `*.supabase.co` e `wa.me`. **Troque o nome do cache a cada publicação** (`gc-pedidos-sb-v1` → `v2`...).
- Android/Chrome: "Instalar app". iPhone/Safari: "Adicionar à Tela de Início".
- O app precisa de internet para carregar e salvar dados; offline só abre a casca.

## 11. Segurança — checklist antes de publicar

1. RLS ligado nas 4 tabelas (conferir em Table Editor; nenhuma pode aparecer como "RLS disabled").
2. Testar com **duas contas**: a conta B não pode ver nem alterar nada da conta A.
3. Nenhuma chave secret/service_role no código ou no repositório.
4. Site URL e Redirect URLs configurados; SMTP próprio configurado para produção.
5. Política de privacidade publicada (o app guarda nome, telefone, endereço e dados comerciais) — obrigatória para a Play Store, além do formulário de segurança de dados.
6. Foto de perfil limitada a 160 px (guardada como texto no banco); não aumente sem avaliar o tamanho.
7. Os limites e a política de pausa do plano gratuito do Supabase mudam: conferir em supabase.com/pricing.

## 12. Como testar

Sem testes automatizados. Roteiro manual:

1. Servir a pasta (`python3 -m http.server 8000` dentro de `gc-pedidos-supabase`; adicionar `http://localhost:8000` nas Redirect URLs).
2. Criar conta com foto, confirmar e-mail, entrar, sair, recuperar senha pelo link.
3. Criar 2 fornecedores e 3 produtos vinculados a fornecedores diferentes; conferir total e cor do mínimo.
4. Novo pedido: marcar, alterar quantidades, enviar (abre `wa.me` com o texto certo); conferir o Histórico e "Reenviar".
5. Exportar para Excel e abrir o `.xlsx` (abas *Estoque* e *Pedidos*).
6. Abrir a mesma conta em dois aparelhos: editar em um e ver no outro.
7. Criar uma segunda conta e confirmar o isolamento dos dados.
8. Testar em 360 px de largura e no modo escuro.

## 13. Roadmap

1. **Marcar pedido como recebido**: soma a quantidade pedida em `q1` do produto.
2. **Equipes**: várias pessoas da mesma empresa compartilhando o estoque (tabela `companies` + `members`, RLS por empresa).
3. **Google Play**: empacotar o PWA (TWA, via PWABuilder ou Bubblewrap), publicar `/.well-known/assetlinks.json`, taxa única de US$ 25; contas pessoais novas exigem teste fechado com 12 testers por 14 dias (conferir as regras vigentes no Play Console); política de privacidade e formulário de segurança de dados.
4. Importar produtos de planilha; pedido para vários fornecedores de uma vez; alertas de estoque baixo; modo offline com fila de gravações.

## 14. Instruções para o Claude

- Responda e escreva textos da interface em **português do Brasil**.
- Faça mudanças pequenas e cirúrgicas no `index.html`; não reescreva o arquivo inteiro sem pedido.
- Mudou o banco? Entregue o SQL de migração junto, com RLS, e avise onde aplicar.
- Depois de alterar `index.html`, valide a sintaxe do JavaScript (extrair o `<script>` inline e rodar `new Function(...)` no Node) e lembre de **trocar a versão do cache em `sw.js`**.
- Nunca peça nem escreva chave secret, service_role ou senha do banco em arquivos do site.
- Não afirme que o fluxo com Supabase foi testado ao vivo se não houve teste contra um projeto real.
- Para a Play Store e para preços/limites do Supabase, confirme as regras atuais em fontes oficiais, porque mudam.
