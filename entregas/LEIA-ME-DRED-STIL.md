# Dred Stil: instalar e configurar no computador

## Versão atual

[Baixar o projeto completo com instalação assistida](https://github.com/Nukics/Nukics/raw/refs/heads/entrega-dred-stil-2026-10-17/entregas/dred-stil-instalacao-local.zip).

- [Comece aqui: criar Supabase e gerar .env.local](PRIMEIROS-PASSOS.md).
- [SQL único, somente para projeto Supabase novo](instalar-loja-nova.sql).
- [Resultado dos 125 testes da instalação anterior à alteração de rótulo](testes-instalacao-limpa.log).

O usuário informou que ainda não criou um projeto Supabase. Nenhum banco real foi criado nem recebeu migrações por esta entrega. Os testes usam banco descartável e pagamentos simulados; pagamentos reais dependem da homologação Getnet.

Instale Node.js 24 LTS e as dependências com `npm ci`. Depois de criar o projeto e executar o SQL, use `npm run configurar` para informar a URL e a chave secreta do Supabase no próprio computador. O comando cria `.env.local` privado com segredos de sessão aleatórios e não sobrescreve configurações existentes. Não envie a chave ou esse arquivo ao GitHub ou à conversa.

Depois execute `npm run verificar` e `npm start`; abra http://localhost:5173. Para uma demonstração sem banco real, use `npm run demo` e http://localhost:5174.

O ZIP mantém todas as mudanças anteriores: banners, logo, rodapé, carregamento, Atacado, Destaques horizontais, estoque independente por cor, categorias movíveis e Getnet incorporada. Corrige também a instalação e a edição de uma cor já vinculada a um estoque, impedindo perda silenciosa do controle de peças.

Pacote atual: 164 arquivos, 3050134 bytes. SHA-256: `b414eb8024ff61987e7edd914ca18777a0b6edaa946292335705eb5fce109210`.

A varredura independente do pacote anterior à troca de UF por ESTADO, com ClamAV 1.5.4/base 28150 de 11/10/2026 não detectou ameaças; isso não é garantia de ausência de malware nem uma avaliação do Microsoft Defender. O usuário informou ter resolvido o alerta do Defender antes desta etapa. O [relatório histórico](RELATORIO-DEFENDER-DRED-STIL.md) refere-se à versão anterior e seu hash original; não é uma análise deste pacote novo.

As credenciais reais não são incluídas no ZIP. Antes de vender, confira os contatos, produtos, saldos físicos por cor, envio de e-mails e habilitações Getnet. Esta entrega não publica o site em produção.

Atualização do checkout: o campo antes chamado UF agora mostra ESTADO, com PR como exemplo. As mensagens de validação também usam Estado. A chave interna `uf` e o formato de duas letras foram preservados. Os dois arquivos passaram na verificação de sintaxe; a suíte completa não foi repetida para esta alteração de texto.
