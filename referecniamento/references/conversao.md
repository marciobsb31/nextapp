# Checklist de Conversão e Retenção Mobile (Flutter)

Em aplicativos móveis, **conversão não é apenas um botão de clique**: é toda a jornada que transforma um download casual em um usuário ativo, engajado e pagante. A desistência em apps ocorre nos primeiros 60 segundos se houver atrito, lentidão ou telas genéricas.

Passe rigorosamente por todos os itens antes de entregar a Carta 4. Apresente o diagnóstico para a pessoa (✅ Aprovado / ⚠️ Ajustado / ❌ Pendência do Cliente).

---

## 1. Primeiro Impacto e Inicialização (Os Primeiros 5 Segundos)

- [ ] **Splash Screen Nativa sem Piscar:** O app abre direto com o logo estilizado (usando a Android 12 Splash API e iOS LaunchScreen), sem tela branca genérica piscando antes do Flutter inicializar.
- [ ] **Cold Start Veloz:** O primeiro frame interativo aparece em menos de 1,8 segundos no 4G/5G.
- [ ] **Proposta de Valor Clara na Primeira Tela:** Quem acabou de baixar entende exatamente o que o aplicativo faz antes de ser forçado a criar qualquer conta.

---

## 2. Onboarding Imersivo & Storytelling

- [ ] **No Máximo 3 a 4 Passos:** Onboardings longos geram desinstalação imediata. Menos é mais.
- [ ] **Indicador de Progresso Vivo:** Utilização de `SmoothPageIndicator` elástico para dar a sensação tátil de avanço a cada deslize.
- [ ] **Botão "Pular" Sempre Acessível:** Permitir que usuários com pressa acessem o valor principal imediatamente.
- [ ] **Micro-interação no Botão de Avançar:** O botão de próximo tem feedback de escala, micro-vibração háptica (`lightImpact`) e texto convidativo ("Descobrir", "Começar agora", não apenas "Próximo").

---

## 3. Pré-permissões Inteligentes (Soft Permissions)

- [ ] **Nunca Chame o Diálogo do Sistema sem Explicar Antes:** Não dispare a janela nativa de Notificações, Câmera ou Localização de surpresa.
- [ ] **Tela/Modal Bonito de Benefício Prévio:** Mostre uma interface elegante com ilustração vetorial e o benefício claro (ex: *"Ative as notificações para ser avisado antes que seus ingressos esgotem"*). Somente quando o usuário tocar em "Permitir" é que o diálogo nativo do iOS/Android é solicitado. A taxa de aceitação salta de 30% para mais de 75%!

---

## 4. Cadastro Sem Fricção (Zero Barreiras)

- [ ] **Login Social em 1 Toque:** Suporte a **Apple Sign-In** e **Google Sign-In** integrados nativamente.
- [ ] **Modo Convidado ("Explorar Primeiro"):** O usuário pode testar e ver os produtos/recursos principais antes de ter que digitar qualquer e-mail ou senha. O cadastro só é exigido no momento em que ele vai salvar algo ou comprar.
- [ ] **Teclados Mobile Apropriados:** Campos numéricos abrem `TextInputType.number`, e-mails abrem `TextInputType.emailAddress`, e os formulários possuem navegação automática com `TextInputAction.next`.

---

## 5. Paywall de Alta Conversão (Monetização)

Se o aplicativo possui plano PRO, assinatura ou compras internas:

- [ ] **Toggle Mensal / Anual em Destaque:** O plano anual vem pré-selecionado com uma badge destacada indicando a economia (ex: *"ECONOMIZE 45%"* ou *"2 MESES GRÁTIS"*).
- [ ] **Lista de Benefícios com Checkmarks Animados:** Cada benefício do plano pago é resumido em uma linha objetiva com ícone destacado.
- [ ] **Garantia & Sem Risco Visíveis:** Frases de tranquilidade logo abaixo do botão: *"Cancele a qualquer momento nas configurações da App Store / Play Store"*.
- [ ] **Depoimento Social na Tela de Pagamento:** Avaliação da loja em destaque (ex: *"⭐ 4.9 — Mais de 12.000 membros ativos"*).
- [ ] **CTA de Compra Magnético:** Botão largo na base da tela com gradiente marcante e texto de impacto: *"Iniciar Teste Gratuito de 7 Dias"* ou *"Desbloquear Acesso Imediato"*.

---

## 6. Checkout & Ações de Pagamento Rápido

- [ ] **Pagamento em 1 Toque:** Suporte nativo a Apple Pay / Google Pay para compras dentro do app.
- [ ] **PIX Mobile Otimizado (Brasil):** Botão "Copiar Código PIX" que copia a chave diretamente para a área de transferência do celular, dispara uma notificação tátil de sucesso e exibe uma contagem regressiva para a confirmação do pagamento.
- [ ] **Celebração no Sucesso:** Após a conclusão, a tela celebra a conquista com animação Lottie/Confetes, vibração e resumo visual do pedido.

---

## 7. Experiência Tátil e Ergonomia Mobile

- [ ] **Respeito à Zona do Polegar:** Todas as ações principais estão localizadas na metade inferior da tela, sem exigir acrobacias com a mão.
- [ ] **Haptics em Todos os Pontos Chave:** Cada toque em botão, troca de aba e ativação de interruptor (*Switch*) devolve uma micro-vibração no dedo do usuário.
- [ ] **Desempenho Estável:** Nenhuma queda de quadros (*dropped frames*) ao rolar listas longas (`ListView.builder` com `itemExtent` calibrado).
- [ ] **Acessibilidade & Dark Mode:** O app se adapta automaticamente ao modo escuro do sistema operacional e respeita escalas de fontes ampliadas sem quebrar ou truncar textos.
