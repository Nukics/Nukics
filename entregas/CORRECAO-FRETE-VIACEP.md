# Correção da consulta de CEP no checkout publicado

O Console informou que a CSP bloqueia a consulta a `https://viacep.com.br/ws/83331150/json/`. A política precisa permitir essa origem em `connect-src`.

## Aplicar na versão que está publicada

1. No projeto conectado à Vercel, abra `server/index.js` e localize `Content-Security-Policy`.
2. Dentro dessa política, troque apenas este trecho:

   ```text
   connect-src 'self';
   ```

   por:

   ```text
   connect-src 'self' https://viacep.com.br;
   ```

   Preserve os outros domínios que sua versão já tiver em `connect-src`, incluindo os da Getnet. Não altere as demais diretivas.
3. Salve e envie a alteração para a branch conectada à Vercel, ou publique novamente pelo método que você já usa. Um Redeploy isolado sem enviar o código corrigido reutiliza a versão antiga.
4. Quando o novo deploy ficar pronto, abra `/checkout`, pressione Ctrl+Shift+R e calcule o frete novamente.

O [patch pontual](correcao-frete-viacep.patch) contém somente essa mudança. A cópia desta entrega foi corrigida; nenhuma alteração foi aplicada diretamente à Vercel. Como a versão publicada tem consulta ViaCEP que não existe nesta cópia do frontend, prefira aplicar a mudança pontual à sua versão atual para preservar suas alterações.

## Validação local

- 36 testes de checkout e Getnet aprovados.
- Chromium reproduziu o bloqueio com a política anterior; a política corrigida permitiu consultar o ViaCEP usando uma resposta de teste interceptada localmente.
- Origem não autorizada continua bloqueada pelo navegador.
- Checkout Getnet mantém suas origens oficiais e a permissão de consulta de CEP.

Os testes não consultaram ViaCEP, Melhor Envio ou Getnet reais e não validaram o domínio de produção. Este ajuste corrige o bloqueio de CSP informado; cotações reais continuam dependendo da configuração do provedor de frete.
