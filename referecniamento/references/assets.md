# Assets Mobile no Flutter — Otimização, Resoluções e IA

Regra inegociável da experiência mobile de elite: **zero visual improvisado ou amador.** Produtos, personagens, texturas e ilustrações vêm de fotografia real em alta resolução com fundo transparente, renderizações 3D realistas ou vetores vivos interativos (Rive). O Flutter é capaz de desenhar na tela com precisão cirúrgica, desde que os assets respeitem as densidades de tela e a memória do smartphone.

---

## 1. Resoluções Mobile & Estrutura de Pastas no Flutter

Diferente da web onde uma única imagem esticada pode bastar, os smartphones possuem telas de altíssima densidade de pixels (Retina, AMOLED, 400+ DPI). Se você usar uma imagem em baixa resolução, ela fica borrada; se carregar um arquivo gigante de 8K, o app engasga a memória RAM e pode ser encerrado pelo sistema operacional.

O Flutter gerencia densidades automaticamente quando você organiza a pasta `assets/`:

```text
assets/
  ├── images/
  │    ├── produto-hero.webp         (Resolução base @1x, ex: 400x400)
  │    ├── 2.0x/
  │    │    └── produto-hero.webp    (Resolução @2x, ex: 800x800 - iPhones padrão)
  │    └── 3.0x/
  │         └── produto-hero.webp    (Resolução @3x, ex: 1200x1200 - iPhones Pro / Top Android)
  ├── rive/
  │    └── animacao-sucesso.riv      (Vetor vivo interativo com State Machine)
  ├── lottie/
  │    └── confetes-celebração.json  (Animação vetorial leve)
  └── shaders/
       └── mesh_gradient.frag        (Fragment Shader GLSL do Impeller)
```

No `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/images/
    - assets/rive/
    - assets/lottie/
    - assets/shaders/
```

---

## 2. Formatos Recomendados para Apps de Alta Performance

| Formato | Onde Usar | Por que Usar no Mobile |
|---|---|---|
| **WebP Transparente** | Fotos reais de produtos, pessoas e embalagens | Até 80% mais leve que PNG, com canal alfa (fundo transparente) perfeito e decodificação ultrarrápida. |
| **Rive (`.riv`)** | Ícones de navegação, botões interativos, mascotes | Arquivos minúsculos (< 60 KB), vetoriais em tempo real, 120 FPS cravados e reagem a toques do usuário via State Machine. |
| **Lottie (`.json`)** | Celebrações, confetes, ilustrações ricas de Onboarding | Animação vetorial pura exportada do After Effects que não perde definição em nenhuma tela. |
| **SVG (`.svg`)** | Ícones de interface simples (seta, busca, fechar, engrenagem) | Vetores puros com `flutter_svg`. Nunca desenhe ícones com caracteres ou emojis! |
| **Fragment Shader (`.frag`)** | Gradientes líquidos vivos, vidros foscos dinâmicos | Roda diretamente na GPU através do motor Impeller com zero consumo de CPU. |

---

## 3. Lista de Assets Mobile (Entrega da Carta 2)

Durante a Carta 2, monte uma tabela rigorosa que o cliente ou desenvolvedor possa acompanhar:

| Arquivo | O que é | Formato e Resolução | Onde Conseguir / Como Gerar | Tela do App |
|---|---|---|---|---|
| `hero-tenis-lado.webp` | Tênis flutuando com sombra de contato | WebP transparente (@1x, @2x, @3x) | Foto do produto → recorte de fundo limpo | Onboarding / Home |
| `avatar-mascote.riv` | Mascote com State Machine piscando e sorrindo | Arquivo Rive (`.riv`), < 50KB | Rive Community ou criado no Rive Studio | Onboarding / Perfil |
| `sucesso-compra.json` | Explosão de moedas e brilhos | Lottie JSON, < 100KB | LottieFiles (filtrar por gratuitos ou criar) | Modal de Sucesso |
| `fundo-liquido.frag` | Shader de gradiente vivo orgânico | Código GLSL (`.frag`) | Shader compilado para Impeller | Fundo de todas as telas |

---

## 4. Onde Conseguir Assets de Qualidade Profissional

- **Fotografia Real:** Unsplash, Pexels, bancos proprietários da marca. Sempre busque em inglês com termos de fotografia de produto: `"studio lighting"`, `"macro product photography"`, `"isolated black background"`, `"side view"`.
- **Rive Community:** Milhares de animações interativas prontas com State Machines gratuitas (`rive.app/community`).
- **LottieFiles:** Animações prontas para estados de sucesso, alerta, carregamento e celebração (`lottiefiles.com`).
- **Fontes Oficiais:** Google Fonts via pacote `google_fonts`.

---

## 5. Gerar Assets Imersivos com IA (Prompts Prontos)

Quando o asset não existir fisicamente, forneça o **prompt pronto** para geração com IA, especificando iluminação de estúdio e isolamento:

### Exemplo — Foto de Produto para App Mobile:
```text
Clean studio product photograph of a modern matte black coffee dripper, floating mid-air, 
dramatic rim lighting, soft reflections, pure transparent background / solid black background, 
high-end industrial design, 8k resolution, shot on Hasselblad, crisp focus --no shadows on background
```

### Exemplo — Ícone 3D Estilizado para Onboarding:
```text
3D icon of a glowing golden credit card with metallic holographic chips, isometric perspective, 
soft rounded corners, Apple-style premium aesthetic, ray tracing render, claymorphism and glass texture, 
isolated on plain background, 4k
```

---

## 6. Otimização e Tratamento Rápido de Arquivos

- **Remoção de Fundo Instantânea:** use ferramentas de remoção de fundo com IA para isolar o produto com bordas perfeitas e sem halos brancos.
- **Conversão para WebP:** Converta PNGs pesados para WebP com 85% de qualidade (visualmente idêntico, fração do peso).
- **Controle de Peso do App:** A pasta `assets/` do aplicativo final nunca deve ultrapassar 15 MB a 25 MB. Apps muito pesados para baixar na rede móvel (4G/5G) sofrem alta taxa de desistência na App Store e Google Play.

---

## 7. Placeholder Responsável no Wireframe

Enquanto o asset definitivo está sendo buscado ou renderizado, utilize no código Flutter um placeholder com a mesma proporção e o **nome exato do arquivo**:

```dart
Container(
  height: 220,
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.05),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Colors.white.withOpacity(0.1)),
  ),
  alignment: Alignment.center,
  child: Text(
    '[assets/images/hero-tenis-lado.webp]',
    style: TextStyle(color: Colors.white54, fontSize: 13, fontFamily: 'monospace'),
  ),
)
```

Nunca substitua por um desenho improvisado com `Icons.image` que acaba sendo esquecido na versão final!
