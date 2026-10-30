# Destrinchar o Produto em Experiência Mobile (Flutter)

Este é o método que separa um aplicativo Flutter premiado (nível Apple Design Award / Dribbble Top) de um app genérico de IA com telas azuis estáticas e botões crus. Em vez de "jogar componentes na tela", partimos do produto e perguntamos: **como esse produto é sentido, tocado e manipulado na palma da mão?**

Na web, o usuário apenas "olha e rola". No mobile, o usuário **segura o dispositivo na mão, toca com o polegar, sente a vibração tátil (haptics), inclina o aparelho e interage com inércia física**.

---

## Passo 1 — Liste o que o produto É no Smartphone

Quebre o produto ou serviço em quatro camadas adaptadas à experiência móvel:

| Camada | Pergunta no Celular | Exemplo (App de Café Especial) |
|---|---|---|
| **Física / Tátil** | Que objetos existem e como viram superfícies na tela? | Grão de café torrado, pacote com zíper, xícara cerâmica, prensa francesa, filtro de papel. |
| **Ação Gestual** | Que gestos naturais o usuário faz no smartphone? | Puxar o zíper do pacote (swipe vertical), moer o grão (giro com dois dedos), despejar água quente (pressão longa com haptic crescente). |
| **Sensorial (Visual + Tátil + Som)** | O que a tela mostra e o que a mão do usuário sente? | Vapor subindo (partículas/shader), gotejamento rítmico, clique tátil seco ao travar a tampa (`HapticFeedback.mediumImpact()`), borbulhas de crema. |
| **Simbólica / Emocional** | Qual a sensação de ter isso no bolso? | Ritual matinal sagrado, pausa reconfortante, sofisticação acessível em 1 toque. |

> **Para Serviços e Softwares:**
> - **Finanças/Investimentos:** O peso do cofre, o clique metálico do cadeado se abrindo, a barra de progresso que se preenche com som e haptic de moeda caindo, a sensação de segurança inabalável.
> - **Fitness/Saúde:** A frequência cardíaca pulsando no ritmo do motor de vibração, anéis de atividade que fecham com explosão elástica de brilho, energia e superação.
> - **E-commerce de Roupas:** Tecido que ondula levemente ao inclinar o celular (parallax giroscópico), cartão de produto que se desdobra como uma etiqueta de tecido.

---

## Passo 2 — Transforme cada item em Cena Interativa Flutter

Para cada item, pergunte: **como isso reage ao polegar, à física do Flutter e aos sensores do celular?**

### Exemplos no Flutter:

1. **Unboxing Tátil do Pacote de Café:**
   - O usuário faz um swipe para baixo no pacote; a aba se abre com física de mola (`SpringSimulation`), acompanhada por uma sequência de haptics leves simulando os dentes do zíper se abrindo.
2. **Moagem Interativa com Rotação (Gesture + Matrix4):**
   - Um disco de moagem gira conforme o usuário faz um gesto circular na tela. A cada quarto de volta, um micro-impacto tátil (`HapticFeedback.selectionClick()`) simula os dentes do moedor quebrando os grãos.
3. **Hero Cinematográfico do Grão à Xícara:**
   - O card do café na listagem se expande organicamente para a tela de preparo usando um `Hero` widget com `flightShuttleBuilder` customizado, onde o grão se transforma suavemente na xícara vaporizante sem nenhum corte seco.
4. **Parallax do Produto com Giroscópio:**
   - Ao mover suavemente o aparelho, o produto flutua em 3D sobre o fundo com reflexos de luz dinâmicos gerados por um Fragment Shader (Impeller).
5. **Vapor e Crema Vivos (Shaders / Rive):**
   - O vapor do café sobe suavemente no topo da tela com um shader de ruído líquido (`.frag`), reagindo se o usuário assoprar ou tocar no topo da tela.

---

## Passo 3 — Apresente o Cardápio de Experiências Mobile

Mostre de 5 a 8 ideias no formato de impacto mobile:

```text
1. Unboxing com Zíper Tátil — O usuário puxa a aba do produto com swipe; o pacote se abre com vibração háptica dente por dente e física de mola. Sensação: prazer sensorial imediato, ritual exclusivo.
2. Card com Parallax 3D — Ao mover o celular ou arrastar o dedo, o produto revela camadas e reflexos metálicos. Sensação: produto premium nas mãos.
3. Transição Hero Morfada — Ao tocar no item, ele se expande fluidamente e ocupa a tela inteira sem tela de carregamento. Sensação: agilidade nativa de 120 FPS.
...
```

Pergunte à pessoa:
- Quais dessas ideias despertam desejo no seu cliente?
- Queremos combinar alguma delas na jornada principal?
- Tem alguma cena própria em mente?

Ajude a detalhar:
- **Momento:** Aparece no Onboarding, no Hero da Home, na transição para o Carrinho ou no Sucesso de Ação?
- **Gesto de Disparo:** Tap com feedback de escala, swipe com inércia, drag contínuo ou inclinação do aparelho?
- **Resposta Tátil:** Qual o nível de haptic (`selectionClick`, `lightImpact`, `heavyImpact`)?
- **Assets Necessários:** Rive `.riv`, vídeo transparente WebP, modelo 3D GLB ou Fragment Shader?

---

## Passo 4 — Escolha a Cena Protagonista

Escolha **UMA** cena protagonista: a experiência de maior impacto tátil e visual que define o aplicativo.
- Nos melhores apps do mundo (como Robinhood, Airbnb, Nike, Duolingo, Revolut), existe sempre **aquele** momento marcante que as pessoas mostram pros amigos.
- As demais cenas são de apoio e harmonia.
- **Regra:** Um protagonista ultra-fluido a 120 FPS com haptics perfeitos vale dez vezes mais do que dezenas de animações desconexas que poluem a tela.

---

## Como cada Ideia vira Realidade no Flutter (Sem Visual Inventado)

| Ideia Mobile | Como Fazer de Verdade no Flutter |
|---|---|
| **Objeto girando / Produto 3D** | Modelo 3D via `flutter_cube` / `model_viewer_plus`, ou sequência de frames WebP de alta taxa em `Image.asset` pré-carregada, ou animação de vetor interativa no **Rive** |
| **Líquido, fumaça, calor, brilho dinâmico** | **Fragment Shader do Impeller** (`.frag` GLSL compilado nativamente), ou animação de ciclo contínuo em **Rive** ou **Lottie** |
| **Partículas, confetes, explosão de pontos** | Pacote `confetti`, ou `CustomPainter` renderizando partículas vetorizadas com controle de física |
| **Expansão de Card para Tela Cheia** | `OpenContainer` do pacote `animations` ou `Hero` customizado com `createRectTween` |
| **Folheamento / Baralho de Cards** | `GestureDetector` com `Transform` aplicando rotação no eixo Z e X com `Matrix4` e `SpringSimulation` |
| **Textura e Profundidade** | Fotos reais recortadas em alta resolução (WebP) combinadas com `BackdropFilter(filter: ImageFilter.blur(...))` e luzes dinâmicas |

> [!CRITICAL]
> **Zero Visual Inventado no Mobile:** Nunca tente "desenhar" um produto real usando `Container` ou ícones de material genéricos. O visual vem de fotografia profissional de estúdio (com fundo transparente), render 3D realista ou vetor vivo de alta precisão em Rive. Se o asset não existir, ele vai diretamente para a Lista de Assets da Carta 2!
