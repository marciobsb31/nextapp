# Diagnóstico — PDV Market mobile

Leitura feita no código de `D:\pdvmarket` e no aplicativo que já existe em `D:\pdvmarket\aplicativo`. Este projeto, em `D:\netxtapp`, consome a mesma API. Não abre o PostgreSQL.

## Arquitetura encontrada

- API Spring Boot em `http://localhost:9000`.
- PostgreSQL do contrato em `localhost:5434`, base `pdvmarket`, um schema `tenant_*` por contrato.
- Painel Angular em `http://localhost:5000`.
- Autenticação: `POST /api/auth/login` com `{email, password}`. A resposta traz `token`, `tenantId` e `user.perfil`.
- Perfis: `SUPER_ADMIN`, `TENANT_ADMIN`, `OPERADOR`, `CLIENTE`.
- O JWT carrega o contrato. Para quem não é superadministrador, um `X-Tenant-ID` diferente do token não troca o schema. O aplicativo não envia esse cabeçalho.
- E-mail não confirmado, acesso inativo e contrato suspenso bloqueiam o login, com os códigos `EMAIL_NAO_CONFIRMADO`, `ACESSO_INATIVO` e `CONTRATO_SUSPENSO`.
- Conta do aplicativo: `GET /api/app/eu`. A loja do cliente vem do vínculo no servidor, não de um id escolhido na tela.
- Catálogo da unidade da sessão: `GET /api/app/produtos`, `GET /api/app/categorias`, `GET /api/app/produtos/destaques`, `GET /api/app/promocoes`.
- Pedido: `POST /api/app/carrinho/simular` e `POST /api/app/pedidos`. O pagamento confirmado continua no backend.
- Módulos do contrato: `LOJA` e `SMART_ACCESS`. O perfil exclusivo grava `LOJA` desligada e `SMART_ACCESS` ligada (`ModuloService.definirExclusivo`).
- Descoberta pública: `GET /api/publico/lojas/proximas?lat&lng` e `GET /api/publico/lojas?cep=`. O raio sai de `plataforma_acesso.raio_km`. O piso configurável é 0,5 km. O valor gravado no modelo, quando ninguém altera, é 5 km. O aplicativo mostra o raio que a API devolve e não filtra 500 metros por conta própria.
- A loja só aparece na busca se o módulo `CADASTRO_APP` estiver ativo e ela tiver coordenada.
- O vínculo de conta nova é `POST /api/publico/moradores/conta`. O servidor só aceita a loja se ela estiver na lista daquele CEP. A lista do GPS não cria conta.
- Smart Access administrativo: `/api/smart-access`. A abertura passa por `POST /comandos` e `POST /comandos/{id}/executar`. Há auditoria em `smart_auditoria` e decisão em `smart_comando` (`PENDENTE`, `AUTORIZADO`, `EXECUTADO`, `NEGADO`).

## O que esta etapa já usa

- Login, esqueci a senha e encerramento de sessão.
- Cofre do token no armazenamento seguro do aparelho.
- Leitura de `GET /api/app/eu` e do catálogo da unidade da sessão.
- Busca por CEP e por GPS, sem vínculo automático.
- Cadastro só da loja que o CEP devolveu, com aceite local dos termos e confirmação de e-mail exigida pelo login.

## Lacunas reais, sem endpoint equivalente seguro

1. Cliente com perfil `CLIENTE` é barrado fora de `/api/app/`, `/api/auth/`, `/api/publico/` e `/api/perfil/`. `/api/smart-access` não entra nessa lista. A conta de cliente recebe `PERFIL_SEM_ACESSO`.
2. Contrato só Smart Access recebe `SOMENTE_SMART_ACCESS` nas rotas de loja, e `/api/app/eu` também cai nessa regra. O cliente exclusivo não tem hoje uma rota de sessão para listar as próprias portas.
3. `POST /api/smart-access/comandos` aceita `clienteId` no corpo. Quem tem acesso administrativo pode indicar outra pessoa. A abertura do cliente precisa de uma rota nova, por exemplo `POST /api/app/smart-access/abrir`, que use o cliente da sessão, ignore id enviado pelo aparelho e revalide na execução.
4. A maioridade hoje compara `clientes`/`smart_pessoa.data_nascimento` com `idade_minima`. Isso não é uma verificação de identidade. Não vou tratar a data digitada no aplicativo como prova.
5. QR isolado não pode abrir a porta. O fluxo existente manda o id do dispositivo ao servidor. Falta amarrar esse id à sessão do cliente, com proteção contra repetição do comando já decidido. O comando repetido já responde conflito.
6. Carrinho por loja, foto de estoque, fornecedor, cupom administrativo, push e alertas preditivos já têm peças no backend (`/api/app/pedidos`, `/api/produtos/ler-ficha`, `/api/compras/reposicao`, `/api/cupons`, `/api/app/notificacoes`). Entram nas etapas seguintes, sempre pela API, sem saldo nem preço calculados no aplicativo.

## Riscos

- Duplicar o aplicativo de `D:\pdvmarket\aplicativo` criaria duas regras. Este projeto reutiliza os mesmos caminhos.
- Mostrar Smart Access na interface sem a rota de sessão abriria um botão que o servidor recusa ou, pior, usaria o endpoint administrativo. O botão não entra até a extensão do item 3.
- O raio de 500 metros do pedido não é o valor padrão do banco. Mudar o padrão aqui quebraria a regra comercial já configurável.

## Plano

1. Feito nesta etapa: fundação, sessão, descoberta e catálogo da unidade autenticada.
2. Carrinho e pedido em `/api/app/pedidos`, com aviso ao trocar de unidade.
3. Extensão mínima do Smart Access para o cliente da sessão, com auditoria já existente.
4. Gestão: dashboard `/api/app/admin/dashboard`, estoque, fornecedor, cupom e bloqueio, só com o perfil que a API já exige.
