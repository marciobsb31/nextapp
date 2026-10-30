# De Referências a Wireframe Interativo em Flutter

Quando a pessoa envia prints de outros aplicativos, telas do Mobbin, projetos premiados do Dribbble ou referências da Apple App Store, nosso papel não é copiar: é **decodificar os princípios de engenharia e design mobile e traduzi-los em arquitetura de widgets Flutter**.

---

## 1. Como Analisar Prints e Referências Mobile

Analise a referência e devolva para a pessoa em 6 blocos objetivos:

1. **Arquitetura de Navegação:**
   - Como o usuário se desloca? (Barra inferior flutuante, carrossel de páginas `PageView`, folhas modais que sobem da base `ModalBottomSheet` ou navegação em abas superiores).
2. **Decomposição em Widgets Flutter:**
   - Qual a espinha dorsal de cada tela? (ex: `CustomScrollView` com `SliverAppBar` elástico no topo + `SliverList` com cartões de bordas contínuas).
3. **Ergonomia e Área do Polegar:**
   - Onde o designer posicionou o botão de decisão principal? Está na zona de toque fácil ou exige esticar o dedo?
4. **Tipografia e Contraste em Telas Pequenas:**
   - Como o layout lida com títulos curtos de impacto versus blocos de leitura? O contraste resiste à luz do sol direta?
5. **Movimento e Gestos Implícitos:**
   - Que tipo de transição está implícito no print? (Se há um elemento recortado saindo da borda, indica um carrossel horizontal `CarouselView`; se um card tem sombra pronunciada, indica expansão via `Hero` ou `OpenContainer`).
6. **O que Aproveitar e o que Adaptar:**
   - Conecte sempre com o Briefing da Carta 1: *"A referência usa um visual futurista escuro que funciona perfeitamente para o seu público gamer, mas vamos descer o botão de ação para a base da tela para facilitar o uso com uma só mão."*

---

## 2. O Wireframe Interativo em Flutter (`wireframe.dart`)

Em mobile, wireframes estáticos em PDF ou imagens do Figma não mostram como o app realmente "pesa" na mão. A entrega da Carta 2 inclui um **Wireframe Flutter Interativo em código real**:

### Características do Wireframe Flutter:
- **Código em Arquivo Único (`wireframe.dart`):** Fácil de colar no projeto e rodar imediatamente (`flutter run -d chrome` ou no celular).
- **Superfícies em Tons de Cinza:**
  - Fundo neutro (`#0D0D11`).
  - Containers e cartões em cinza escuro (`#1A1A22` e `#2A2A36`).
  - Bordas e divisores sutis (`#333344`).
- **Textos Reais do Briefing:**
  - **Zero "Lorem Ipsum":** Títulos, subtítulos, argumentos de valor e CTAs já escritos com base nas dores e desejos levantados na Carta 1. O texto é metade da conversão.
- **Caixas de Assets com Nomes Reais:**
  - Caixas cinzas com o nome exato do arquivo escrito no centro (ex: `[assets/images/produto-hero.webp]`), nas proporções corretas de tela, para não quebrar o layout quando a imagem final for inserida.
- **Alvos de Toque Reais:**
  - Botões já com altura mínima de 52 dp e preenchimento de toque seguro.

---

## 3. A Simulação de Movimento (Validando o Ritmo)

Após o wireframe estrutural, integre a **Simulação de Movimento** direto no código Flutter:

1. **Transições de Telas Ativas:**
   - Toque em um card e veja a tela de detalhes se abrir com uma transição suave de `Hero` ou `SlideTransition`.
2. **Bottom Sheet Funcional:**
   - O botão de filtro ou opções já abre uma `DraggableScrollableSheet` que desliza de baixo para cima respondendo ao toque.
3. **Haptics nos Botões:**
   - Mesmo em blocos cinzas, o botão já vibra levemente (`HapticFeedback.lightImpact()`) ao ser tocado no celular físico.

> [!TIP]
> **Por que a Simulação em Flutter Evita Retrabalho:**
> Quando a pessoa segura o smartphone e sente a velocidade da transição, o tamanho da fonte na mão real e a facilidade de tocar no botão com o polegar, ela aprova a **estrutura e o ritmo** com total segurança. Qualquer mudança estrutural feita aqui leva minutos; depois de aplicar estilização e shaders, custaria horas!
