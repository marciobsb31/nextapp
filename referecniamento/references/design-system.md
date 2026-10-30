# Design System Mobile no Flutter

O Design System Mobile não é apenas uma lista de cores e fontes: ele é a **linguagem tátil e visual** que comanda a interação do usuário com o smartphone. Ele nasce do Briefing (Carta 1) e da essência do produto (Carta 2), calibrado especificamente para a anatomia da mão humana e a tela do celular.

---

## 1. Ergonomia Mobile & A Zona do Polegar (Thumb Zone)

Diferente do desktop onde o mouse alcança qualquer pixel sem esforço, no smartphone o **polegar governa**:

- **Zona Confortável (Terço Inferior da Tela):** Onde ficam os botões de ação primária (CTAs flutuantes, barras de navegação, seletores, filtros rápidos e tabs).
- **Zona de Estiramento (Meio da Tela):** Onde ficam os cards de leitura, listas roláveis e dados secundários.
- **Zona Difícil (Topo da Tela):** Onde ficam apenas elementos de contemplação ou apoio (título de cabeçalho, avatar de perfil, indicador de status). Nunca coloque ações críticas de conversão no topo!
- **Alvos de Toque Seguros:** Nenhum botão, ícone ou elemento clicável pode ter menos de **48x48 dp** de área de toque real (use `hitTestBehavior` e padding transparente quando o ícone for menor).
- **Respeito aos Limites Físicos:** Obedecer rigorosamente a `SafeArea` (notch, furo da câmera, Dynamic Island e a barra de gestos inferior do iOS e Android).

---

## 2. O que Definir no Design System Mobile

### Paleta & Luz Dinâmica
- **Superfícies:** 1 fundo principal (frequentemente escuro profundo `#090A0F` ou claro sofisticado `#F8F9FC`), 1 superfície de card/container elevada (`#141721`), 1 superfície flutuante com blur (vidro translúcido).
- **Destaque & Ação (Brand CTA):** 1 cor de impacto com alto contraste para guiar o olho (ex: Laranja Solar `#FF5C00`, Verde Neon Energético `#00F076`, Azul Elétrico `#3861FB`).
- **Texto:** 1 cor primária de máxima legibilidade (WCAG AAA), 1 cor secundária suave para rótulos e dados de apoio, 1 cor desativada.
- **Bordas & Brilhos:** Bordas sutis com gradiente fino (1px) para dar sensação de acabamento de joia em telas OLED.
- **Suporte Nativo a Dark & Light:** Cores organizadas semanticamente para transição perfeita de tema do sistema operacional.

### Tipografia Mobile de Elite
- **Fonte de Título (Display):** Uma fonte com personalidade marcante (ex: *Plus Jakarta Sans*, *Outfit*, *Clash Display*, *Syne* ou *Cabinet Grotesk*).
- **Fonte de Corpo (Body):** Máxima legibilidade em tamanhos pequenos (ex: *Inter*, *DM Sans* ou *Manrope*).
- **Escala Mobile Calibrada:**
  - `Display Large`: 32 a 40 sp (títulos de hero e números de grande impacto).
  - `Title Medium`: 18 a 22 sp (títulos de cards e seções).
  - `Body Medium`: 14 a 16 sp (texto de leitura com altura de linha generosa `height: 1.5`).
  - `Label Small`: 11 a 12 sp (badges, chips e rótulos de métrica em caixa alta sutil).

### Formas, Superfícies e Squircles
- **Curvatura Contínua (Apple Squircle):** No Flutter, em vez do arredondamento circular comum (`BorderRadius.circular(20)`), utilize cantos com curvatura suave contínua:
  ```dart
  shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(32)),
  ```
  Isso entrega o autêntico acabamento dos produtos da Apple e dos apps mais refinados da App Store.
- **Elevação Colorida e Suave:** Nunca use sombras pretas e duras. A sombra deve herdar uma fração da cor do próprio componente com raio de desfoque generoso:
  ```dart
  BoxShadow(
    color: primaryColor.withOpacity(0.25),
    blurRadius: 24,
    offset: const Offset(0, 10),
  ),
  ```

### Movimento & Física (Tokens de Animação)
- **Curvas Canônicas:**
  - Entradas e Aparições: `Curves.easeOutBack` (para o sutil bounce elástico de chegada).
  - Saídas e Dispensas: `Curves.fastLinearToSlowEaseIn`.
  - Transições Contínuas de Tela: `Curves.easeInOutCubicEmphasized`.
- **Durações Padrão:**
  - Micro-interações (toque no botão, seleção de chip): `150ms`.
  - Transições de Componentes (abrir accordion, bottom sheet): `300ms a 400ms`.
  - Transições Cinematográficas entre Telas (Hero, Shared Axis): `500ms a 650ms`.

---

## 3. Implementação Pronta em Dart (`ThemeExtension`)

No Flutter moderno, os tokens personalizados devem ser entregues como um `ThemeExtension` tipado e imutável. Isso permite acessar os tokens em qualquer widget via `Theme.of(context).extension<AppThemeTokens>()!`:

```dart
import 'package:flutter/material.dart';

@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  final Color bgPrimary;
  final Color bgSurface;
  final Color bgGlass;
  final Color accentCTA;
  final Color textPrimary;
  final Color textSecondary;
  final TextStyle displayTitle;
  final TextStyle bodyText;
  final Duration animFast;
  final Duration animNormal;
  final Curve curveSpring;

  const AppThemeTokens({
    required this.bgPrimary,
    required this.bgSurface,
    required this.bgGlass,
    required this.accentCTA,
    required this.textPrimary,
    required this.textSecondary,
    required this.displayTitle,
    required this.bodyText,
    required this.animFast,
    required this.animNormal,
    required this.curveSpring,
  });

  @override
  AppThemeTokens copyWith({
    Color? bgPrimary,
    Color? bgSurface,
    Color? bgGlass,
    Color? accentCTA,
    Color? textPrimary,
    Color? textSecondary,
    TextStyle? displayTitle,
    TextStyle? bodyText,
    Duration? animFast,
    Duration? animNormal,
    Curve? curveSpring,
  }) {
    return AppThemeTokens(
      bgPrimary: bgPrimary ?? this.bgPrimary,
      bgSurface: bgSurface ?? this.bgSurface,
      bgGlass: bgGlass ?? this.bgGlass,
      accentCTA: accentCTA ?? this.accentCTA,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      displayTitle: displayTitle ?? this.displayTitle,
      bodyText: bodyText ?? this.bodyText,
      animFast: animFast ?? this.animFast,
      animNormal: animNormal ?? this.animNormal,
      curveSpring: curveSpring ?? this.curveSpring,
    );
  }

  @override
  AppThemeTokens lerp(ThemeExtension<AppThemeTokens>? other, double t) {
    if (other is! AppThemeTokens) return this;
    return AppThemeTokens(
      bgPrimary: Color.lerp(bgPrimary, other.bgPrimary, t)!,
      bgSurface: Color.lerp(bgSurface, other.bgSurface, t)!,
      bgGlass: Color.lerp(bgGlass, other.bgGlass, t)!,
      accentCTA: Color.lerp(accentCTA, other.accentCTA, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      displayTitle: TextStyle.lerp(displayTitle, other.displayTitle, t)!,
      bodyText: TextStyle.lerp(bodyText, other.bodyText, t)!,
      animFast: t < 0.5 ? animFast : other.animFast,
      animNormal: t < 0.5 ? animNormal : other.animNormal,
      curveSpring: t < 0.5 ? curveSpring : other.curveSpring,
    );
  }
}
```

---

## 4. Anti-Genérico Mobile — O que NUNCA fazer em Flutter

- **`Scaffold` cru com AppBar azul padrão:** É a marca registrada de tutorial de iniciante ou código gerado às cegas por IA.
- **Botões `ElevatedButton` retangulares básicos:** Sem feedback de escala ao toque, sem haptic e sem sombras atmosféricas.
- **`ListTile` cinza com divisória seca:** Use cartões estilizados, espaçamento generoso e cantos contínuos.
- **Diálogos modais `AlertDialog` quadrados do sistema:** Em vez de modais quadrados no meio da tela que quebram a imersão, utilize **Bottom Sheets refinadas** ancoradas na base da tela com cantos arredondados superiores.
- **Textos estáticos sem ritmo:** Textos sem hierarquia clara de peso (`FontWeight.w700` no título vs `FontWeight.w400` no subtítulo) e sem micro-animação de entrada.
- **Telas sem vida (Zero Haptics):** Um app onde o usuário clica e nada vibra fisicamente parece quebrado ou morto.
