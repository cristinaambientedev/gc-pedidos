# GC-Pedidos com Supabase — passo a passo

O app agora guarda tudo no Supabase (banco de dados) e usa o login do Supabase Auth.
Você faz isto uma vez só. Tempo estimado: 15 minutos.

## 1. Criar o projeto no Supabase
1. Acesse supabase.com, crie a conta e clique em **New project**.
2. Dê um nome (ex.: gc-pedidos), crie uma senha forte para o banco (guarde-a) e escolha a região **South America (São Paulo)**.
3. Espere o projeto terminar de ser criado.

## 2. Criar as tabelas
1. No menu lateral, abra **SQL Editor** > **New query**.
2. Abra o arquivo `supabase/schema.sql`, copie tudo, cole e clique em **Run**.
3. Deve aparecer "Success". Isso cria as tabelas, as regras de segurança (cada pessoa só vê os próprios dados) e o perfil automático ao criar conta.

## 3. Copiar a URL e a chave
1. Vá em **Project Settings** > **API Keys** (ou **Data API**, para a URL).
2. Copie a **Project URL** (algo como `https://abcd1234.supabase.co`).
3. Copie a chave **publishable** (começa com `sb_publishable_`).
   Se o seu projeto só mostrar a chave `anon`, clique em **Create new API keys** para gerar a publishable (as chaves antigas continuam funcionando, mas o Supabase vai desativá-las até o fim de 2026).
4. Abra `config.js` e cole os dois valores entre as aspas.

**Nunca** cole no site a chave **secret** nem a **service_role**: elas dão acesso total ao banco.
A chave publishable pode ficar no site; quem protege os dados são as regras de segurança do passo 2.

## 4. Configurar o login (Authentication)
1. **Authentication > URL Configuration**
   - **Site URL:** o endereço do seu site publicado (ex.: `https://gc-pedidos.netlify.app`).
   - **Redirect URLs:** adicione o mesmo endereço (e `http://localhost:8000` se for testar no computador).
   Sem isso, os links de confirmar e-mail e de recuperar senha não voltam para o app.
2. **Authentication > Sign In / Providers > Email**
   - Mantenha "Confirm email" ligado em produção. Para testar rápido, você pode desligar.
3. **E-mails em produção:** o envio padrão do Supabase é muito limitado e serve só para testes. Antes de colocar usuários reais, configure um SMTP próprio em **Authentication > SMTP Settings** (ex.: Resend, Brevo ou o SMTP da sua empresa).
4. Opcional: traduza os modelos de e-mail em **Authentication > Email Templates**.

## 5. Publicar
1. Suba a pasta inteira (`index.html`, `config.js`, `manifest.json`, `sw.js`, `icons`) no Netlify, Cloudflare Pages ou GitHub Pages, como antes.
2. Abra o endereço, crie sua conta, confirme o e-mail e entre.
3. Teste em dois aparelhos com a mesma conta: o que muda em um aparece no outro em poucos segundos.

## Atualizações futuras
Troque `gc-pedidos-sb-v1` por `gc-pedidos-sb-v2` (e assim por diante) em `sw.js` ao publicar uma nova versão.

## Coisas para saber
- **Internet é necessária** para ver e salvar dados. Sem conexão o app abre, mas não carrega o estoque.
- Quem já usou a versão antiga (dados no aparelho) **não tem migração automática**: os dados antigos ficam no navegador e precisam ser digitados de novo, ou me peça um importador a partir da "Cópia" JSON.
- Planos gratuitos do Supabase têm limites e podem pausar projetos sem uso. Confira as regras atuais em supabase.com/pricing antes de usar em produção.
- Faça backup do banco (Database > Backups) conforme o seu plano.
