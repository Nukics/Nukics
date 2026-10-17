# Código completo Dred Stil

> **Alerta em investigação:** o Defender bloqueou o ZIP como `Trojan:Script/Ulthar.A!ml`, indicando `serve.js`. A revisão estática e uma varredura independente com ClamAV não encontraram ameaças; a base do ClamAV é de 11/10/2026. Isso não confirma falso positivo. Mantenha o bloqueio e consulte o [relatório com resultados e próximos passos](RELATORIO-DEFENDER-DRED-STIL.md).

Arquivo: `dred-stil-codigo-completo.zip` — 153 arquivos, 3,012,496 bytes.

Inclui Destaques com rolagem horizontal, estoque independente por cor, movimentação de categorias, banners, logo, página Atacado e integração Getnet.

Validado localmente com 100 testes automatizados e testes no navegador. Pagamentos reais Getnet ainda dependem das credenciais próprias e da homologação.

Antes de usar o novo código na loja, aplique no Supabase as migrações 005 e 006 incluídas no ZIP e cadastre as quantidades reais por cor. O guia está em `docs/ESTOQUE-CORES-CATEGORIAS.md`. Nenhuma migração foi aplicada no banco real por esta entrega.

O ZIP contém somente `.env.example`, sem credenciais de ambiente.

SHA-256: `b3de70fa7bb2792af9abbb109684106338f7204f36c57a7f2c75c3cf9bec04e3`
