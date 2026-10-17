# Instalar a Dred Stil no seu computador

Use Node.js 24 LTS, disponível em https://nodejs.org. O projeto exige Node.js 22 ou superior.

## 1. Criar o banco real

Entre em https://supabase.com/dashboard com a sua conta e crie um projeto para a loja. Guarde a senha do banco no seu gerenciador de senhas; ela não deve ser enviada na conversa.

Quando o projeto estiver pronto, abra **SQL Editor > New query**. Abra no seu editor o arquivo `supabase/instalar-loja-nova.sql` deste ZIP, copie o conteúdo inteiro e execute no SQL Editor uma vez. Ele instala o esquema, as migrações 002–006 e os dados iniciais. Use esse instalador somente em um projeto novo: ele recusa tabelas de uma loja existente.

Esse passo não cria a conta admin nem informa o estoque físico por cor. Antes de vender, revise os contatos, banners, preços e produtos iniciais no painel.

## 2. Criar o .env.local real

Extraia o ZIP inteiro e abra o **Prompt de Comando** na pasta que contém `package.json`. Execute:

```bat
npm ci
npm run configurar
```

O assistente pede a **Project URL** e a **chave secreta do servidor**, disponíveis no painel Supabase em Project Settings > API / API Keys. Use a chave Secret `sb_secret_...` ou JWT `service_role`, não a chave pública `publishable`/`anon`. As entradas ficam ocultas; cole cada valor e pressione Enter.

A configuração real é criada em `.env.local`, com um segredo de sessão gerado automaticamente. Ela fica no seu computador. Não envie esse arquivo para o GitHub ou pelo chat. Se ele já existir, o assistente o preserva: edite-o localmente para corrigir valores.

## 3. Conferir e abrir a loja

```bat
npm run verificar
npm start
```

Corrija os itens marcados como ERRO antes de iniciar. O diagnóstico faz leituras da estrutura e do bucket de fotos; não aplica SQL nem realiza cobranças. A loja fica em http://localhost:5173 enquanto o terminal estiver aberto.

Para cadastrar o dono e entrar no admin, siga a seção **Conta admin** do `README.md`: o comando precisa de e-mail, nome completo, apelido, telefone e senha. No modo local sem Resend, os links de confirmação e códigos de login ficam em `.dev-emails/`.

## Demonstração sem Supabase

Depois de `npm ci`, `npm run demo` abre uma demonstração em http://localhost:5174. Ela usa dados descartáveis, credenciais de acesso em `.dev-emails/admin-demo.txt` e pagamentos simulados. Os dados somem ao reiniciar; essa demonstração não é o banco real da loja.

## Pagamentos reais

A configuração inicial mantém a compra pelo WhatsApp. Para cobrar por cartão, Pix e parcelas no site, ainda é necessário obter suas credenciais e habilitações Getnet e realizar a homologação de `docs/GETNET.md`. O endereço localhost não recebe webhooks externos; a homologação precisa de domínio HTTPS público. Não usar chaves de produção antes dessa etapa.
