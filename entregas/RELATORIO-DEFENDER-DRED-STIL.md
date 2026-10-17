# Investigação do alerta do Defender — Dred Stil

Atualizado em 17/10/2026 13:13 (horário de Brasília).

## Resultado e limite

O ClamAV não detectou ameaças no ZIP entregue nem no arquivo `serve.js` separado. A revisão estática também não encontrou evidência concreta de Trojan. Isso não confirma que a detecção do Microsoft Defender seja falsa e não autoriza ignorar, excluir ou desativar sua proteção.

O Defender do usuário detectou `Trojan:Script/Ulthar.A!ml` em `serve.js` dentro do ZIP e informou falha na quarentena. A detecção do Defender continua pendente de esclarecimento.

## Identificação do material exato

- ZIP: `dred-stil-codigo-completo.zip`, 3.012.496 bytes, 153 arquivos.
- SHA-256 ZIP: `b3de70fa7bb2792af9abbb109684106338f7204f36c57a7f2c75c3cf9bec04e3`.
- Arquivo apontado: `serve.js`, 365 bytes.
- SHA-256 `serve.js`: `d63fc6fd533e6ebec87055f3c5a2d313261d0cf2f6005f76f400429568875180`.
- O `serve.js` é idêntico, byte a byte, ao arquivo de mesmo nome do ZIP original enviado pelo usuário.
- O código do projeto e o ZIP não foram modificados para alterar ou evitar a detecção.

## Varredura antivírus realizada

- ClamAV 1.5.4.
- Base de assinaturas 28150, datada de 11/10/2026; 3.628.164 assinaturas conhecidas. Essa base não inclui necessariamente ameaças catalogadas após essa data.
- Imagem do projeto ClamAV: `clamav/clamav:stable`, fixada no digest `sha256:638d90201ee7ee6a82d249a2fc23b132e578673b5f1f2766852b127676ca1ef6`.
- Varredura de arquivos compactados ativada. Foram analisados o ZIP e, separadamente, o arquivo sinalizado.
- Código de saída: 0, sem avisos ou erros na execução válida.
- Contêiner sem rede, sem capacidades extras, com os arquivos montados somente para leitura; o código da loja não foi executado durante a análise.
- Nenhum arquivo do usuário foi enviado a um serviço de análise externo. Apenas o antivírus oficial e suas bases foram baixados para análise local.
- A primeira tentativa não teve permissão para ler as amostras e analisou zero arquivos. Ela foi descartada como resultado de segurança. A execução válida abaixo usou o mesmo UID dos arquivos e efetivamente os leu.

Saída da execução válida:

```text
/audit/loja.zip: OK
/amostras/serve.js: OK

----------- SCAN SUMMARY -----------
Known viruses: 3628164
Engine version: 1.5.4
Scanned directories: 0
Scanned files: 2
Infected files: 0
Data scanned: 7.35 MiB
Data read: 2.87 MiB (ratio 2.56:1)
Time: 15.889 sec (0 m 15 s)
Start Date: 2026:10:17 16:12:44
End Date:   2026:10:17 16:13:00
```

Os horários da saída bruta do contêiner estão em UTC. O horário no início deste relatório está em Brasília.

## Revisão estática adicional

Foi revisada a cadeia de inicialização do `serve.js`, com 40 módulos locais transitivos, os manifests de dependências, o conteúdo exato do ZIP e os formatos dos arquivos de imagens/fontes.

Não foram encontrados comandos de shell, `eval`, `new Function`, persistência no Windows, executáveis disfarçados ou ofuscação evidente. As integrações de rede identificadas correspondem a Supabase, Getnet, Melhor Envio, Resend e Focus NFe. Essa revisão não prova ausência de malware nas dependências nem substitui a avaliação do Defender.

Conteúdo do arquivo apontado, para revisão humana:

```javascript
// Inicia a loja localmente: node serve.js  (porta padrão 5173; mude com PORT=...)
// As chaves ficam em .env.local (copie de .env.example).
try {
  process.loadEnvFile(require('path').join(__dirname, '.env.local'));
} catch {
  console.warn('Arquivo .env.local não encontrado: usando só as variáveis de ambiente do sistema.');
}
require('./server').iniciar();
```

## Próximos passos com o Windows e a Microsoft

1. Manter o item bloqueado. Não restaurar da quarentena, não criar exclusões e não desativar a proteção.
2. Atualizar as definições do Microsoft Defender em Segurança do Windows e executar uma verificação completa do computador, especialmente porque o alerta mostrou falha na quarentena.
3. Solicitar a revisão da detecção pelo portal oficial: https://www.microsoft.com/en-us/wdsi/filesubmission . O portal pode exigir login em uma conta Microsoft e uma amostra para análise. Este relatório e o link do ZIP identificam precisamente o material; não compartilhar credenciais ou dados da loja.
4. Informar o nome da ameaça, ambos os hashes, a data da detecção e que houve resultado diferente no ClamAV. Não apresentar a revisão como falso positivo já confirmado.
5. Conferir a resposta da Microsoft ou uma nova avaliação do Defender atualizado antes de recomendar a execução do pacote.

Texto para acompanhar o pedido de revisão:

> Solicito revisão da detecção Trojan:Script/Ulthar.A!ml em serve.js, arquivo de inicialização de uma loja Node.js. O arquivo de 365 bytes carrega .env.local pelo recurso nativo process.loadEnvFile e inicia o servidor local. O SHA-256 do arquivo é d63fc6fd533e6ebec87055f3c5a2d313261d0cf2f6005f76f400429568875180. O ZIP entregue tem SHA-256 b3de70fa7bb2792af9abbb109684106338f7204f36c57a7f2c75c3cf9bec04e3. O arquivo é idêntico ao do projeto original, a revisão estática não encontrou código malicioso e o ClamAV 1.5.4/base28150 (11/10/2026) não detectou ameaças. A detecção do Defender não foi ignorada e solicito análise da Microsoft para esclarecer a divergência.

Não houve envio automático à Microsoft: este ambiente não tem acesso à conta Microsoft do usuário e o portal não foi acessível pela política de rede. O documento prepara a revisão; não é uma resposta da Microsoft.
