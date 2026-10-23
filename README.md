# 💎 OuroGest — Sistema Web de Gestão e Vendas para Joalherias

Sistema web Multi-loja (SaaS) para venda de ouro sob medida: cálculo de gramas pela medida geométrica e quilate, registro de vendas com controle de parcelamento, acompanhamento de etapas de produção e entregas, ajuste de peso final na balança e lembretes de recompra e cobrança via WhatsApp.

**Versão da Documentação:** 1.2 (23/10/2026)

---

## 🚀 Stack e Tecnologias

- **Front-end e Rotas:** Next.js (App Router) com TypeScript
- **Estilização:** Tailwind CSS (Paleta dourado, grafite e marfim) + Lucide Icons
- **Banco de Dados:** MariaDB (suporte a Stored Procedures, Triggers, Views e colunas calculadas)
- **Acesso ao Banco:** `mysql2/promise` (Pool de conexões, suporte a `CALL` e transações)
- **Autenticação e Sessão:** `bcryptjs` (hash de senhas) e `iron-session` (cookie HTTP-Only criptografado)
- **Validação:** Zod (no cliente e no servidor)
- **Infraestrutura:** Docker / Docker Compose

---

## 💳 Modelo de Uso SaaS: Teste Grátis (Trial) e Assinatura

O **OuroGest** opera no modelo Multi-loja (SaaS), garantindo isolamento total onde cada conta enxerga apenas os dados da própria joalheria (`loja_id`):

1. **Cadastro com Teste Grátis (7 dias):** Ao criar uma conta em `/cadastro`, a joalheria nasce automaticamente com `status_assinatura = 'trial'` e prazo `trial_expira_em` definido para **7 dias** a partir do cadastro.
2. **Acesso Liberado:** Lojas com `status_assinatura = 'ativa'` ou em `'trial'` dentro do prazo de 7 dias acessam todas as telas operacionais normalmente.
3. **Bloqueio Automático por Vencimento (`middleware.ts`):** Se o prazo do `trial` expirar (data atual maior que `trial_expira_em`) ou se o status for `'vencida'` ou `'bloqueada'`, o `middleware.ts` impede o acesso às telas operacionais e redireciona o usuário logado para `/assinatura` (para pagamento/ativação com o suporte).
4. **Preservação de Dados:** Nenhum dado da joalheria é apagado quando o teste grátis vence.

---

## 🗄️ Modelo de Dados (MariaDB)

O banco de dados `ourogest` utiliza chaves compostas com `loja_id` para impedir o cruzamento de registros entre lojas diferentes:

### Tabelas (`db/schema.sql`)
1. **`lojas`**: Cadastro da joalheria, `status_assinatura` (`'trial'`, `'ativa'`, `'vencida'`, `'bloqueada'`) e `trial_expira_em`.
2. **`usuarios`**: Login com e-mail único, hash da senha, vínculo com a loja e papel (`'dono'` ou `'funcionario'`).
3. **`configuracoes`**: Cotação do ouro 24k, mão de obra padrão, dias para recompra e tolerância de peso.
4. **`clientes`**: Nome, telefone e data do último contato (`ultimo_contato`).
5. **`vendas`**: Peça, quilate, gramas estimadas, valor, etapa da produção, modalidade de pagamento, preço do grama no dia, peso final, ajuste de peso e valor final (coluna calculada).
6. **`parcelas`**: Pagamentos combinados (tipo, valor, vencimento, data/valor pagos e forma de pagamento).
7. **`vendas_historico`**: Auditoria de cada mudança de etapa da produção (quem alterou, quando e motivo).

### Stored Procedures (`CALL`) e Views
- **Procedures:** `gerar_parcelas`, `registrar_pagamento`, `sugerir_ajuste_peso`, `registrar_peso_final`, `mover_etapa` e `desfazer_peso_final`.
- **Views:** `vendas_financeiro` (total pago, saldo e status), `lembretes_recompra` e `lembretes_cobranca`.

---

## 📋 Plano de Desenvolvimento (Roadmap)

- [ ] **Fase 1 — Base:**
  - [x] Projeto Next.js, variáveis de ambiente (`.env.local`) e container MariaDB no Docker
  - [x] Camada de conexão e transações SQL (`lib/db.ts`)
  - [x] Hash de senhas e controle de sessão criptografada (`lib/auth.ts`)
  - [x] Proteção global de rotas (`middleware.ts`)
  - [ ] Alinhamento do banco (`db/schema.sql`) e sessão com o modelo de Trial de 7 dias
  - [ ] Telas e rotas de Login, Cadastro (Trial), `/assinatura` e Menu Lateral
- [ ] **Fase 2 — Calculadora:** `lib/calculo.ts` com testes, tela `/calculadora` e `/configuracoes`
- [ ] **Fase 3 — Vendas e Pagamentos:** Nova venda, `gerar_parcelas`, lista, detalhe, `registrar_pagamento` e indicadores
- [ ] **Fase 4 — Produção:** Quadro Kanban (`/producao`), `mover_etapa`, devolução com motivo, peso final e ajuste
- [ ] **Fase 5 — Lembretes e Papéis:** Recompra, cobrança, links de WhatsApp e restrições por papel (`dono` vs `funcionario`)
- [ ] **Fase 6 — Acabamento:** Responsividade mobile, estados de carregamento/erro e validações com Zod
- [ ] **Fase 7 — Publicação:** Deploy via Docker Compose + Caddy (HTTPS) e rotina de backup