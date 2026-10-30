# Repertório de Efeitos e Animações no Flutter (120 FPS)

O objetivo central da experiência mobile de elite: **o aplicativo se comporta como um objeto físico vivo na mão do usuário.** Cada tela entra com coreografia orquestrada, responde aos gestos do polegar com inércia real, fornece feedback tátil e transita para a próxima sem nenhum corte seco ou tela branca.

---

## 1. Base de Fluidez e Feedback Físico (Obrigatório em todo App)

- **120 FPS / ProMotion Fluido:** Com o motor **Impeller** nativo do Flutter, não há "shader compilation jank". As animações rodam a 60 FPS estáveis ou 120 FPS em telas de alta taxa.
- **Feedback Háptico Obrigatório (Haptics):**
  - Ao tocar num botão primário: `HapticFeedback.lightImpact();`
  - Ao rolar por itens de uma régua ou picker: `HapticFeedback.selectionClick();`
  - Ao confirmar uma ação crítica (pagamento, envio): `HapticFeedback.mediumImpact();`
  - Ao ocorrer um erro de validação: sequência rápida com `HapticFeedback.heavyImpact();`
- **Física de Mola Natural:**
  - Em iOS e Android, usar `BouncingScrollPhysics()` ou molas simuladas com `SpringSimulation(SpringDescription(...))`. A inércia deve respeitar a velocidade de soltura do dedo do usuário.
- **Acessibilidade:**
  - Respeitar `MediaQuery.of(context).disableAnimations` — se o usuário ativou a redução de movimento no sistema operacional, reduza transições complexas para fades simples instantâneos.

---

## 2. Entradas & Coreografias de Tela (Staggered Animations)

Elementos nunca "aparecem do nada" de uma vez só na tela. Eles entram em cascata ritmada:

1. **Entrada em Cascata (Stagger):**
   - Primeiro o cabeçalho/avatar entra, 60ms depois o título, 60ms depois o card em destaque, 60ms depois a listagem, e por fim o CTA inferior flutuante.
   - **Com `flutter_animate`:**
     ```dart
     Text('Seu Resumo Semanal')
       .animate()
       .fadeIn(duration: 400.ms, curve: Curves.easeOut)
       .slideY(begin: 0.2, end: 0, curve: Curves.easeOutBack),
     ```
2. **Revelação por Máscara (`ClipRRect` expansivo):**
   - A imagem ou card de destaque se expande a partir de um retângulo compacto até ocupar o espaço desejado, com raio de borda que se suaviza durante a expansão.
3. **Contadores e Dados Vivos:**
   - Números de métricas, saldos e pontuações nunca aparecem estáticos: sobem rolando suavemente de zero até o valor final (`TweenAnimationBuilder<double>` ou `AnimatedFlipCounter`).

---

## 3. Transições Cinematográficas entre Telas (Continuidade Contínua)

Elimine pushs de tela sem personalidade. O aplicativo deve fluir como um único filme contínuo:

1. **Hero Morphing Cinematográfico:**
   - O card do produto na listagem se expande suavemente e vira a tela inteira com o widget `Hero`:
     ```dart
     Hero(
       tag: 'product_${item.id}',
       createRectTween: (begin, end) => MaterialRectArcTween(begin: begin, end: end),
       flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
         return AnimatedBuilder(
           animation: animation,
           builder: (context, child) {
             return ClipRRect(
               borderRadius: BorderRadius.circular(lerpDouble(24, 0, animation.value)!),
               child: toHeroContext.widget,
             );
           },
         );
       },
       child: ProductCardWidget(item: item),
     )
     ```
2. **Container Transform (`OpenContainer` do pacote `animations`):**
   - O card se transforma organicamente na tela de destino, mantendo o usuário orientado no espaço físico da aplicação.
3. **Shared Axis Transition (Eixo Z, X ou Y):**
   - Transição no Eixo X para passos de Onboarding (próximo / anterior).
   - Transição no Eixo Y para abertura de filtros e modais expansivos.
   - Transição no Eixo Z (zoom) para entrar em categorias profundas.
4. **Drag-to-Dismiss Interativo:**
   - Na tela de detalhes ou visualizador de imagem, o usuário puxa o conteúdo para baixo. Conforme o dedo desce, a tela reduz sutilmente de escala e fica translúcida; ao soltar além do limiar, a tela fecha com mola e haptic leve.

---

## 4. Gestos e Física Interativa no Flutter

O polegar comanda a experiência através de superfícies reativas:

1. **SliverAppBar Elástica com Parallax e Blur:**
   - No topo de telas ricas (`CustomScrollView`), a imagem do topo se estende com zoom no overscroll (`stretch: true`) e se desfoque progressivamente (`ImageFilter.blur`) conforme o usuário rola para cima, fixando o título discretamente.
2. **Bottom Sheets Inteligentes (`DraggableScrollableSheet`):**
   - Folhas modais ancoradas na base com múltiplos "snap points" (ex: 20% recolhido, 60% meia tela, 92% expandido). O arraste responde à velocidade do dedo (`velocity`).
3. **Cards com Efeito 3D ao Toque (`Matrix4` + Perspective):**
   - Ao manter o dedo pressionado num card de destaque e movê-lo levemente, o card inclina em 3D seguindo o centro de gravidade do toque:
     ```dart
     Transform(
       transform: Matrix4.identity()
         ..setEntry(3, 2, 0.001) // Perspectiva 3D
         ..rotateX(_tiltX)
         ..rotateY(_tiltY),
       alignment: Alignment.center,
       child: CardWidget(),
     )
     ```
4. **Swipe-to-Action Elástico:**
   - Arrastar itens de lista para a esquerda ou direita com resistência de mola progressiva. Ao atingir o ponto de ativação, dispara um haptic seco indicando que a ação está engatilhada.

---

## 5. Shaders e Renderização Avançada (Flutter Impeller)

Para criar visuais que parecem do futuro e não podem ser imitados por web views básicas:

1. **Fragment Shaders (`.frag` em GLSL):**
   - Efeitos de fundo em movimento perpétuo (Mesh Gradient líquido vivo que ondula suavemente atrás do conteúdo com consumo mínimo de bateria).
   - Efeito de refração de vidro (Frosted Glass realista que distorce a imagem de fundo com luz dinâmica).
2. **`CustomPainter` com Animação de `PathMetric`:**
   - Gráficos vetoriais, linhas de batimento, ondas de áudio ou contornos de progresso desenhados dinamicamente com gradiente e efeito de brilho (*glow*).
3. **Glassmorphism de Alta Fidelidade:**
   - Utilização de `BackdropFilter` com `ImageFilter.blur(sigmaX: 16, sigmaY: 16)`, envolto em um container com borda sutil em gradiente branco semitransparente (`Colors.white.withOpacity(0.15)`).

---

## 6. Micro-interações de Toque & Delighters (A Magia dos Detalhes)

São os micro-detalhes táteis que fazem o usuário amar usar o aplicativo:

1. **Botão Bouncy com Escala Suave:**
   - Ao tocar em qualquer botão ou card, ele encolhe instantaneamente para `scale: 0.96`. Ao soltar, volta para `1.0` com curva elástica (`Curves.easeOutBack`) e haptic tick:
     ```dart
     GestureDetector(
       onTapDown: (_) {
         HapticFeedback.lightImpact();
         _controller.forward();
       },
       onTapUp: (_) => _controller.reverse(),
       onTapCancel: () => _controller.reverse(),
       child: ScaleTransition(scale: _scaleAnimation, child: PrimaryButton(...)),
     )
     ```
2. **Swipe to Confirm (Deslize para Confirmar):**
   - Para ações de compra ou transferência: um botão deslizante onde o usuário arrasta o polegar da esquerda para a direita com vibração contínua que culmina em uma explosão de sucesso.
3. **Confetes & Vitória Háptica:**
   - Ao concluir uma meta, cadastro ou pagamento: explosão de partículas com o pacote `confetti` acompanhada de som suave e sequência de 2 haptics de celebração.
4. **Shimmer Esqueletal de Luxo:**
   - Enquanto os dados carregam, nada de spinners circulares cinzas! Use um esqueleto da própria tela com onda de brilho prateada ou dourada que flui continuamente (`.animate(onPlay: (c) => c.repeat()).shimmer(...)`).

---

## 7. Rive & Vetores Vivos Interativos

- **State Machines no Rive (`.riv`):**
  - Ícones da barra de navegação inferior que ganham vida quando tocados.
  - Mascotes ou avatares que acompanham o preenchimento de formulários (ex: tapam os olhos ao digitar senha, sorriem na validação positiva).
  - Botão de envio que vira um spinner embutido e depois se transforma em um checkmark verde contínuo sem trocar de widget.

---

## 8. Regras de Ouro de Performance (120 FPS Garantidos)

- **Sempre use `const`:** Widgets com construtor `const` nunca são reconstruídos à toa.
- **`RepaintBoundary` em Áreas Críticas:** Isole animações contínuas (como partículas, contadores e shaders) dentro de um `RepaintBoundary` para que a GPU não repinte o restante da tela.
- **Evite Reconstruir a Árvore Toda:** Use `ValueListenableBuilder`, `ListenableBuilder` ou `flutter_riverpod` com seletores pontuais (`ref.watch(provider.select(...))`) em vez de chamar `setState` no widget raiz.
- **Imagens em Cache com Placeholder:** Sempre utilize `cached_network_image` com esqueleto shimmer embutido para carregamento instantâneo da memória.
