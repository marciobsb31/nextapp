# Tecnologias, Bibliotecas e Caminhos Flutter

Explicamos cada tecnologia mobile com palavras simples, sempre associada a um efeito visual ou benefício do app. A pessoa não precisa ser arquiteta de software sênior para entender o que cada peça faz no ecossistema Flutter.

---

## 1. O Básico do Flutter (O que é o quê)

- **Flutter:** O motor que desenha a interface pixel por pixel na tela do smartphone a 60 ou 120 quadros por segundo, gerando um app nativo para iOS e Android com o mesmo código.
- **Dart:** A linguagem que dá vida e lógica aos botões, cálculos e transições.
- **Impeller:** O novíssimo motor gráfico do Flutter (substituto do Skia). Ele compila todos os efeitos e shaders antes do app rodar, eliminando 100% dos engasgos (*jank*) de animação no iOS e no Android.
- **Widgets:** Os blocos de construção físicos. Tudo na tela é um Widget: o texto, o botão, a sombra, o espaçamento e a animação.

---

## 2. Pacotes Essenciais do App Imersivo Flutter

| Pacote | Para que serve no App | Exemplo de Uso Real |
|---|---|---|
| **`flutter_animate`** | Motor fluente de animações encadeadas com zero boilerplate. | Fazer títulos entrarem em cascata com fade, escala e mola elástica em 1 linha de código. |
| **`animations`** (Google) | Transições canônicas do Material Design (Container Transform, Shared Axis). | O card se expande e vira a tela inteira sem solavancos (`OpenContainer`). |
| **`rive`** | Vetores interativos com máquina de estados (*State Machine*). | Mascote animado que olha pro campo de senha; botão que vira spinner e depois checkmark vivo. |
| **`lottie`** | Animações de vetor pré-renderizadas de alta complexidade. | Explosão de confetes ao fechar uma compra; ilustrações comemorativas no Onboarding. |
| **`smooth_page_indicator`** | Indicadores de página táteis e elásticos para carrosséis. | As bolinhas que se esticam como líquido elástico ao deslizar o Onboarding. |
| **`cached_network_image`** | Cache inteligente de imagens na memória e no disco. | Fotos de produtos carregando instantaneamente sem tela cinza e com shimmer suave. |
| **`flutter_shaders`** | Suporte direto a Fragment Shaders (`.frag` GLSL do Impeller). | Gradientes líquidos vivos em movimento de fundo com performance de GPU pura. |
| **`flutter/services.dart`** | Motor nativo de vibração física (*Haptics*). | O clique tátil que a mão sente ao tocar em qualquer botão ou chave do app. |
| **`google_fonts`** | Carregamento dinâmico e empacotamento de tipografia de elite. | Fontes com personalidade (*Plus Jakarta Sans*, *Outfit*) prontas para uso. |
| **`supabase_flutter`** | Conector oficial para **PostgreSQL**, Auth, Realtime e Storage. | Consulta tipada, streaming de dados em tempo real e segurança de banco no mobile. |
| **`dio`** | Cliente HTTP robusto para APIs REST conectadas ao PostgreSQL. | Interceptors de token JWT, cancelamento de requisições e retry automático. |

---

## 3. Os Dois Caminhos de Construção no Mobile

### Caminho Leve (Protótipo Instantâneo / Demo Executável)
- **Foco:** Leigos, validação rápida de clientes ou testes imediatos.
- **Como funciona:** Um único arquivo `main.dart` totalmente autocontido, com todos os widgets, design system, animações e telas de exemplo reunidos.
- **Como rodar e testar:**
  - Rodar direto no navegador com `flutter run -d chrome` para ver a interface funcionando na hora.
  - Ou abrir no emulador/celular físico sem precisar de configurações complexas de arquitetura.
- **Deploy de Teste:** O app pode ser compilado para Flutter Web (`flutter build web`) e publicado no Netlify Drop ou Vercel em 30 segundos, permitindo que o cliente abra um link no celular e sinta a navegação antes de instalar qualquer arquivo!

### Caminho Pro (Aplicativo de Produção para as Lojas)
- **Foco:** Aplicativo real escalável pronto para publicação na Apple App Store e Google Play Store.
- **Estrutura Modular (Feature-First):**
  - `lib/core/` (tokens do design system, temas, utilitários de haptics, extensões).
  - `lib/features/[nome_da_feature]/` (dividido em `presentation/`, `domain/`, `data/`).
- **Gerenciamento de Estado Reativo:**
  - `flutter_riverpod` (robusto, imutável e sem dependência de `BuildContext`) ou `signals_flutter` (reatividade instantânea com performance extrema).
- **Assets de Produção:**
  - Ícones do app gerados para todas as resoluções com `flutter_launcher_icons`.
  - Splash screen nativa sem tela branca com `flutter_native_splash`.
- **Publicação:**
  - Android: `flutter build appbundle --release` (para a Google Play Console).
  - iOS: `flutter build ipa --release` (para o Apple TestFlight e App Store Connect).

---

## 4. O Padrão Oficial: Flutter + Banco de Dados PostgreSQL

O **PostgreSQL** é o banco relacional de código aberto mais avançado e confiável do mundo. Para aplicativos móveis, ele oferece confiabilidade transacional (ACID), suporte a documentos JSON semiestruturados (`JSONB`), extensões poderosas (como `PostGIS` para geolocalização e `pgvector` para inteligência artificial) e extrema escalabilidade.

### A Regra de Ouro de Segurança Mobile com PostgreSQL

> [!CRITICAL]
> **NUNCA conecte o aplicativo Flutter diretamente à porta TCP 5432 do PostgreSQL.**
> Embutir a string de conexão do Postgres (`postgres://user:password@host:5432/db`) dentro do código do app é uma vulnerabilidade grave. Qualquer pessoa com o arquivo `.apk` ou `.ipa` consegue descompilar o aplicativo e obter acesso total de administrador ao seu banco de dados. Além disso, as redes móveis de celular (4G/5G) sofrem constantes quedas de conexão, o que esgota o pool de conexões do servidor em poucos minutos.

---

### Os 3 Caminhos Recomendados para Usar PostgreSQL no Flutter

#### Caminho 1: Supabase (PostgreSQL Gerenciado + RLS) — *O Padrão Ouro para Flutter*
O Supabase **É** PostgreSQL real puro na nuvem, com todas as camadas modernas necessárias para aplicativos móveis:
- **Row Level Security (RLS):** As regras de acesso são escritas diretamente no SQL do Postgres (ex: `auth.uid() = user_id`). O usuário do app só lê e edita o que é dele, garantindo segurança absoluta.
- **PostgREST Nativo:** O Supabase expõe automaticamente o seu PostgreSQL via APIs REST e GraphQL de alta performance.
- **PostgreSQL CDC (Change Data Capture) em Tempo Real:** Sempre que uma linha da tabela é inserida ou modificada no PostgreSQL, o Flutter recebe a alteração instantaneamente via WebSocket.
- **SDK Oficial:** Pacote `supabase_flutter` com tipagem limpa e integração nativa com o ciclo de vida do Flutter.

**Exemplo de Consulta Reativa a 120 FPS no Flutter:**
```dart
// Stream em tempo real direto da tabela 'pedidos' do PostgreSQL:
Stream<List<Map<String, dynamic>>> getPedidosStream() {
  return Supabase.instance.client
      .from('pedidos')
      .stream(primaryKey: ['id'])
      .eq('usuario_id', Supabase.instance.client.auth.currentUser!.id)
      .order('criado_em', ascending: false);
}
```

---

#### Caminho 2: Backend Próprio (API REST ou GraphQL) conectada ao PostgreSQL
Se a sua empresa já possui um servidor PostgreSQL dedicado em infraestrutura própria (AWS RDS, DigitalOcean, Hetzner ou servidor local):
- **Arquitetura:** `App Flutter` ➔ `API HTTPS (Dart Frog, NestJS, Go, FastAPI)` ➔ `PostgreSQL (Porta 5432 com PgBouncer)`.
- **Autenticação:** O Flutter envia um token `Bearer JWT` nos cabeçalhos HTTP com o pacote `dio`.
- **Pool de Conexões:** O backend gerencia o pool de conexões com o Postgres de forma estável, protegendo o banco contra sobrecarga.

---

#### Caminho 3: Arquitetura Offline-First (Sincronização Local com PostgreSQL)
Ideal para apps que precisam funcionar 100% no elevador, no modo avião ou em áreas rurais sem sinal de internet:
- **No Smartphone:** O app salva e lê dados instantaneamente a 120 FPS em um banco local relacional SQLite/Drift (`drift` package) ou Isar.
- **Sincronização em Segundo Plano:** Motores como **PowerSync** ou **ElectricSQL** sincronizam automaticamente os deltas locais com o PostgreSQL na nuvem assim que a conexão de internet for restabelecida.

---

## 5. Boas Práticas de Modelagem PostgreSQL para Apps Mobile

Ao criar as tabelas no PostgreSQL para o seu aplicativo Flutter, siga este padrão de excelência:

1. **Use `UUID` como Chave Primária:**
   - Em vez de inteiros sequenciais (`id SERIAL`), use `id UUID DEFAULT gen_random_uuid() PRIMARY KEY`. Isso permite que o aplicativo mobile crie novos registros enquanto estiver offline sem risco de colisão de IDs quando reconectar.
2. **Datas com Fuso Horário Obrigatórias:**
   - Sempre utilize `TIMESTAMPTZ` (ex: `criado_em TIMESTAMPTZ DEFAULT now() NOT NULL`). Smartphones estão espalhados por diferentes fusos horários; `TIMESTAMPTZ` normaliza tudo em UTC.
3. **Campos `JSONB` para Configurações Flexíveis:**
   - Use colunas `JSONB` para armazenar preferências dinâmicas de interface, temas do usuário ou metadados de transações sem precisar alterar o esquema SQL a cada atualização do app.
4. **Índices de Busca Rápida (Trigramas):**
   - Para buscas instantâneas no campo de texto (`TextField`) com auto-complete fluido, ative a extensão `pg_trgm` no PostgreSQL e crie um índice `GIN`:
     ```sql
     CREATE EXTENSION IF NOT EXISTS pg_trgm;
     CREATE INDEX idx_produtos_busca ON produtos USING gin (nome gin_trgm_ops);
     ```

---

## 6. Tabela Comparativa de Necessidades de Back-end

| Necessidade do App | Solução com PostgreSQL | Complemento Mobile |
|---|---|---|
| **Cadastro, Login e Banco na Nuvem** | **Supabase (PostgreSQL)** ou **API própria conectada ao Postgres** | `supabase_flutter` ou `dio` |
| **Dados em Tempo Real (Chat, Status)** | **Postgres CDC via WebSockets** (Supabase Realtime) | StreamBuilder / Riverpod StreamProvider |
| **Funcionamento Offline sem Internet** | **Drift (Local) ➔ PostgreSQL (Nuvem)** com sync | `drift` + `powersync_flutter` |
| **Notificações Push (Engajamento)** | Webhooks no PostgreSQL disparando eventos | **Firebase Cloud Messaging (FCM)** ou **OneSignal** |
| **Monetização / Assinaturas (Paywall)** | Tabelas `planos` e `assinaturas` no PostgreSQL | **RevenueCat** (`purchases_flutter`) com Webhook no banco |
