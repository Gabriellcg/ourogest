💍 OuroGest — Sistema SaaS Multi-Loja para Gestão de Joalherias
O OuroGest é uma aplicação web moderna do tipo SaaS (Software as a Service) desenvolvida sob medida para a gestão completa e isolada de múltiplas lojas do ramo joalheiro. O projeto foca em alto desempenho, segurança de dados e arquitetura centralizada.

🚀 Tecnologias Utilizadas (Tech Stack)
Framework: Next.js (App Router com TypeScript)

Estilização: Tailwind CSS

Banco de Dados: MariaDB 10.11 (executado via Docker em ambiente WSL 2)

Driver de Conexão: mysql2/promise (com suporte a Prepared Statements contra SQL Injection)

Segurança e Autenticação: bcryptjs (hash de senhas) e iron-session (sessões criptografadas baseadas em cookies)

Validação: Zod

🏛️ Arquitetura e Decisões de Projeto
Isolamento Multi-Loja (Multi-Tenant): Estrutura de banco de dados relacional desenhada para garantir que os dados de cada joalheria fiquem estritamente segregados.

Centralização do Banco (lib/db.ts): Toda a comunicação com o MariaDB é unificada por meio de um Pool de Conexões otimizado, prevenindo vazamentos de conexões (connection leaks) e gerando transações seguras (transactions com rollback automático).

Segurança Rigorosa:

Utilização exclusiva de um usuário restrito da aplicação (ourogest_app), evitando o uso do usuário administrador (root).

Gerenciamento estrito de segredos e credenciais via variáveis de ambiente (.env.local), mantidos fora do controle de versão.

📋 Estrutura do Banco de Dados
O sistema conta com uma estrutura robusta contendo:

7 Tabelas Principais: lojas, usuarios, configuracoes, clientes, vendas, parcelas, vendas_historico.

Views e Procedures: Automatizações em nível de banco para relatórios financeiros, lembretes de recompra e controle de cobranças pendentes.

⚙️ Como Executar o Projeto Localmente
Clone o repositório:

Bash
git clone https://github.com/Gabriellcg/ourogest.git
cd ourogest
Instale as dependências:

Bash
npm install
Configure as variáveis de ambiente:
Crie um arquivo .env.local na raiz com base nas orientações de configuração do banco e da sessão.

Inicie o banco de dados via Docker:

Bash
docker compose up -d
Execute o servidor de desenvolvimento:

Bash
npm run dev
Acesse http://localhost:3000 no seu navegador.