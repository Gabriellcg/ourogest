-- OuroGest: esquema do banco para MariaDB 10.6 ou superior (recomendado: 10.11 LTS)
--
-- Como executar (o arquivo usa DELIMITER, então rode pelo cliente de linha de comando):
--   mysql -u USUARIO -p -e "CREATE DATABASE ourogest CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
--   mysql -u USUARIO -p ourogest < ourogest-schema-mariadb.sql
-- No phpMyAdmin, cole as partes com DELIMITER usando o campo "Delimitador" da aba SQL.
--
-- IMPORTANTE (diferença para o PostgreSQL/Supabase): o MariaDB não tem segurança por linha.
-- O isolamento entre lojas é responsabilidade da aplicação: toda consulta deve filtrar
-- por loja_id vindo da sessão do usuário, e toda procedure recebe p_loja.
-- Chame as procedures DENTRO de uma transação (START TRANSACTION ... COMMIT).

SET NAMES utf8mb4;

CREATE TABLE lojas (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(150) NOT NULL,
  -- Teste grátis e assinatura: a loja nasce em 'trial' com 7 dias de acesso completo.
  -- Vencido o prazo (ou status 'vencida'/'bloqueada'), o middleware redireciona para /assinatura.
  -- Nenhum dado é apagado quando o teste vence.
  status_assinatura ENUM('trial','ativa','vencida','bloqueada') NOT NULL DEFAULT 'trial',
  trial_expira_em DATETIME NOT NULL DEFAULT (NOW() + INTERVAL 7 DAY),
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Login próprio (no lugar do Supabase Auth). senha_hash guarda argon2 ou bcrypt, nunca a senha.
CREATE TABLE usuarios (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  loja_id BIGINT UNSIGNED NOT NULL,
  nome VARCHAR(150),
  email VARCHAR(190) NOT NULL,
  senha_hash VARCHAR(255) NOT NULL,
  papel ENUM('dono','funcionario') NOT NULL DEFAULT 'dono',
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_usuarios_email (email),
  CONSTRAINT fk_usuarios_loja FOREIGN KEY (loja_id) REFERENCES lojas (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE configuracoes (
  loja_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
  cotacao_ouro_24k DECIMAL(10,2) NOT NULL DEFAULT 650.00,
  mao_de_obra_padrao DECIMAL(10,2) NOT NULL DEFAULT 150.00,
  dias_recompra INT NOT NULL DEFAULT 30,
  tolerancia_gramas DECIMAL(5,2) NOT NULL DEFAULT 0.10,   -- diferença de peso que não gera ajuste
  CONSTRAINT fk_config_loja FOREIGN KEY (loja_id) REFERENCES lojas (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE clientes (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  loja_id BIGINT UNSIGNED NOT NULL,
  nome VARCHAR(150) NOT NULL,
  telefone VARCHAR(30),
  ultimo_contato DATE,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_clientes_loja_id (loja_id, id),            -- permite FK composta (impede misturar lojas)
  KEY ix_clientes_loja_nome (loja_id, nome),
  CONSTRAINT fk_clientes_loja FOREIGN KEY (loja_id) REFERENCES lojas (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE vendas (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  loja_id BIGINT UNSIGNED NOT NULL,
  cliente_id BIGINT UNSIGNED NOT NULL,
  descricao VARCHAR(200) NOT NULL,
  quilate TINYINT UNSIGNED NOT NULL,
  gramas DECIMAL(8,2) NOT NULL DEFAULT 0,                  -- peso estimado pela medida
  valor DECIMAL(12,2) NOT NULL,
  etapa ENUM('pedido','producao','acabamento','pronta','entregue') NOT NULL DEFAULT 'pedido',
  modalidade ENUM('avista','entrada_restante','parcelado') NOT NULL DEFAULT 'avista',
  data_venda DATE NOT NULL DEFAULT (CURRENT_DATE),
  data_entrega DATE NULL,
  preco_grama DECIMAL(10,2) NULL,                          -- preço do ouro (R$/g do quilate) no dia da venda
  gramas_final DECIMAL(8,2) NULL,                          -- peso real, da balança, após a produção
  ajuste_peso DECIMAL(12,2) NOT NULL DEFAULT 0,            -- + excedente cobrado / - desconto
  ajuste_decisao ENUM('cobrar','desconto','sem_ajuste') NULL,
  ajuste_motivo VARCHAR(500) NULL,
  valor_final DECIMAL(12,2) AS (valor + ajuste_peso) STORED,
  UNIQUE KEY uk_vendas_loja_id (loja_id, id),
  KEY ix_vendas_loja_etapa (loja_id, etapa),
  KEY ix_vendas_cliente (cliente_id),
  CONSTRAINT ck_vendas_quilate CHECK (quilate IN (10,14,18,22,24)),
  CONSTRAINT fk_vendas_loja FOREIGN KEY (loja_id) REFERENCES lojas (id) ON DELETE CASCADE,
  CONSTRAINT fk_vendas_cliente FOREIGN KEY (loja_id, cliente_id) REFERENCES clientes (loja_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE vendas_historico (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  venda_id BIGINT UNSIGNED NOT NULL,
  etapa ENUM('pedido','producao','acabamento','pronta','entregue') NOT NULL,
  em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  por BIGINT UNSIGNED NULL,
  motivo VARCHAR(500) NULL,                                -- obrigatório ao devolver a peça (ver mover_etapa)
  KEY ix_historico_venda (venda_id, em),
  CONSTRAINT fk_historico_venda FOREIGN KEY (venda_id) REFERENCES vendas (id) ON DELETE CASCADE,
  CONSTRAINT fk_historico_usuario FOREIGN KEY (por) REFERENCES usuarios (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Parcelas: cada pagamento combinado (entrada, restante, prestações).
-- vencimento NULL = "na entrega" (preenchido quando a venda vira 'entregue').
CREATE TABLE parcelas (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  loja_id BIGINT UNSIGNED NOT NULL,
  venda_id BIGINT UNSIGNED NOT NULL,
  numero INT NOT NULL,
  tipo ENUM('avista','entrada','parcela','restante') NOT NULL,
  valor DECIMAL(12,2) NOT NULL,
  vencimento DATE NULL,
  pago_em DATE NULL,
  valor_pago DECIMAL(12,2) NULL,
  forma ENUM('pix','dinheiro','cartao_debito','cartao_credito','transferencia') NULL,
  UNIQUE KEY uk_parcelas_venda_numero (venda_id, numero),
  KEY ix_parcelas_aberto (loja_id, pago_em, vencimento),
  CONSTRAINT ck_parcelas_valor CHECK (valor > 0),
  CONSTRAINT ck_parcelas_pago CHECK (valor_pago IS NULL OR valor_pago >= 0),
  CONSTRAINT fk_parcelas_venda FOREIGN KEY (loja_id, venda_id) REFERENCES vendas (loja_id, id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DELIMITER $$

-- Histórico de etapas. O usuário e o motivo vêm de variáveis de sessão preenchidas
-- pela procedure mover_etapa. Ao criar uma venda, a aplicação deve fazer antes:
--   SET @ouro_usuario = <id do usuário logado>;
CREATE TRIGGER vendas_ai AFTER INSERT ON vendas FOR EACH ROW
BEGIN
  INSERT INTO vendas_historico (venda_id, etapa, por) VALUES (NEW.id, NEW.etapa, @ouro_usuario);
END$$

CREATE TRIGGER vendas_bu BEFORE UPDATE ON vendas FOR EACH ROW
BEGIN
  IF NEW.etapa <> OLD.etapa THEN
    INSERT INTO vendas_historico (venda_id, etapa, por, motivo)
    VALUES (NEW.id, NEW.etapa, @ouro_usuario, NULLIF(@ouro_motivo, ''));

    IF NEW.etapa = 'entregue' THEN
      IF NEW.data_entrega IS NULL THEN SET NEW.data_entrega = CURRENT_DATE; END IF;
      UPDATE parcelas SET vencimento = NEW.data_entrega
       WHERE venda_id = NEW.id AND vencimento IS NULL AND pago_em IS NULL;
    END IF;

    -- devolvida depois de entregue: limpa a entrega e volta o restante para "na entrega"
    IF OLD.etapa = 'entregue' THEN
      UPDATE parcelas SET vencimento = NULL
       WHERE venda_id = NEW.id AND tipo = 'restante' AND pago_em IS NULL AND vencimento = OLD.data_entrega;
      SET NEW.data_entrega = NULL;
    END IF;
  END IF;
END$$

-- Gera as parcelas de uma venda conforme a modalidade:
--   avista:           1 parcela já paga
--   entrada_restante: entrada hoje + restante na entrega
--   parcelado:        entrada opcional + N prestações mensais
CREATE PROCEDURE gerar_parcelas(
  IN p_loja BIGINT UNSIGNED, IN p_venda BIGINT UNSIGNED, IN p_modalidade VARCHAR(20),
  IN p_entrada DECIMAL(12,2), IN p_num INT, IN p_primeiro DATE)
BEGIN
  DECLARE v_valor DECIMAL(12,2) DEFAULT NULL;
  DECLARE v_data DATE;
  DECLARE v_resto DECIMAL(12,2);
  DECLARE v_base DECIMAL(12,2);
  DECLARE v_venc DATE;
  DECLARE v_total INT;
  DECLARE n INT DEFAULT 0;
  DECLARE i INT DEFAULT 1;

  SELECT valor, data_venda INTO v_valor, v_data FROM vendas WHERE id = p_venda AND loja_id = p_loja;
  IF v_valor IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Venda não encontrada'; END IF;
  IF EXISTS (SELECT 1 FROM parcelas WHERE venda_id = p_venda AND pago_em IS NOT NULL) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Venda já tem pagamentos registrados';
  END IF;

  DELETE FROM parcelas WHERE venda_id = p_venda;
  UPDATE vendas SET modalidade = p_modalidade WHERE id = p_venda AND loja_id = p_loja;

  IF p_modalidade = 'avista' THEN
    INSERT INTO parcelas (loja_id, venda_id, numero, tipo, valor, vencimento, pago_em, valor_pago)
    VALUES (p_loja, p_venda, 1, 'avista', v_valor, v_data, CURRENT_DATE, v_valor);
  ELSE
    SET p_entrada = COALESCE(p_entrada, 0);
    IF p_entrada >= v_valor THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Entrada deve ser menor que o valor da venda';
    END IF;
    IF p_entrada > 0 THEN
      SET n = 1;
      INSERT INTO parcelas (loja_id, venda_id, numero, tipo, valor, vencimento)
      VALUES (p_loja, p_venda, 1, 'entrada', p_entrada, v_data);
    END IF;
    SET v_resto = v_valor - p_entrada;

    IF p_modalidade = 'entrada_restante' THEN
      INSERT INTO parcelas (loja_id, venda_id, numero, tipo, valor, vencimento)
      VALUES (p_loja, p_venda, n + 1, 'restante', v_resto, NULL);
    ELSE
      SET v_total = GREATEST(COALESCE(p_num, 1), 1);
      SET v_base = ROUND(v_resto / v_total, 2);
      SET v_venc = COALESCE(p_primeiro, DATE_ADD(CURRENT_DATE, INTERVAL 30 DAY));
      WHILE i <= v_total DO
        INSERT INTO parcelas (loja_id, venda_id, numero, tipo, valor, vencimento)
        VALUES (p_loja, p_venda, n + i, 'parcela',
                IF(i = v_total, v_resto - v_base * (v_total - 1), v_base),
                DATE_ADD(v_venc, INTERVAL i - 1 MONTH));
        SET i = i + 1;
      END WHILE;
    END IF;
  END IF;
END$$

-- Registra o recebimento de uma parcela (sem valor, paga o valor cheio)
CREATE PROCEDURE registrar_pagamento(
  IN p_loja BIGINT UNSIGNED, IN p_parcela BIGINT UNSIGNED, IN p_forma VARCHAR(20), IN p_valor DECIMAL(12,2))
BEGIN
  UPDATE parcelas SET pago_em = CURRENT_DATE, forma = p_forma, valor_pago = COALESCE(p_valor, valor)
   WHERE id = p_parcela AND loja_id = p_loja AND pago_em IS NULL;
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Parcela não encontrada ou já paga';
  END IF;
END$$

-- Sugestão de ajuste: (peso final - peso estimado) x preço do grama.
-- Positivo = cobrar, negativo = desconto. Dentro da tolerância, a sugestão é 0.
CREATE PROCEDURE sugerir_ajuste_peso(
  IN p_loja BIGINT UNSIGNED, IN p_venda BIGINT UNSIGNED, IN p_gramas_final DECIMAL(8,2))
BEGIN
  SELECT ROUND(p_gramas_final - v.gramas, 2) AS diferenca,
         CASE WHEN ABS(p_gramas_final - v.gramas) <= cf.tolerancia_gramas THEN 0
              ELSE ROUND((p_gramas_final - v.gramas) * COALESCE(v.preco_grama, 0), 2) END AS sugestao,
         (ABS(p_gramas_final - v.gramas) <= cf.tolerancia_gramas) AS dentro_da_tolerancia
    FROM vendas v JOIN configuracoes cf ON cf.loja_id = v.loja_id
   WHERE v.id = p_venda AND v.loja_id = p_loja;
END$$

-- Grava o peso final e o ajuste escolhido (p_ajuste: valor decidido; 0 = sem ajuste)
-- e aplica na última parcela em aberto (ou cria um novo restante na entrega)
CREATE PROCEDURE registrar_peso_final(
  IN p_loja BIGINT UNSIGNED, IN p_venda BIGINT UNSIGNED, IN p_gramas_final DECIMAL(8,2),
  IN p_ajuste DECIMAL(12,2), IN p_motivo VARCHAR(500))
BEGIN
  DECLARE v_found INT DEFAULT 0;
  DECLARE v_decisao VARCHAR(20) DEFAULT NULL;
  DECLARE par_id BIGINT UNSIGNED DEFAULT NULL;
  DECLARE par_valor DECIMAL(12,2) DEFAULT NULL;

  SELECT COUNT(*), MAX(ajuste_decisao) INTO v_found, v_decisao FROM vendas WHERE id = p_venda AND loja_id = p_loja;
  IF v_found = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Venda não encontrada'; END IF;
  IF v_decisao IS NOT NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Peso final já registrado nesta venda';
  END IF;

  IF p_ajuste <> 0 THEN
    SELECT id, valor INTO par_id, par_valor FROM parcelas
     WHERE venda_id = p_venda AND pago_em IS NULL ORDER BY numero DESC LIMIT 1;
    IF p_ajuste > 0 THEN
      IF par_id IS NOT NULL THEN
        UPDATE parcelas SET valor = valor + p_ajuste WHERE id = par_id;
      ELSE
        INSERT INTO parcelas (loja_id, venda_id, numero, tipo, valor, vencimento)
        SELECT p_loja, p_venda, COALESCE(MAX(numero), 0) + 1, 'restante', p_ajuste, NULL
          FROM parcelas WHERE venda_id = p_venda;
      END IF;
    ELSE
      IF par_id IS NULL OR par_valor + p_ajuste <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Desconto maior que o saldo a receber';
      END IF;
      UPDATE parcelas SET valor = valor + p_ajuste WHERE id = par_id;
    END IF;
  END IF;

  UPDATE vendas
     SET gramas_final = p_gramas_final, ajuste_peso = p_ajuste, ajuste_motivo = p_motivo,
         ajuste_decisao = CASE WHEN p_ajuste > 0 THEN 'cobrar' WHEN p_ajuste < 0 THEN 'desconto' ELSE 'sem_ajuste' END
   WHERE id = p_venda AND loja_id = p_loja;
END$$

-- Desfaz o ajuste de peso: tira o excedente (ou devolve o desconto) da parcela em aberto
CREATE PROCEDURE desfazer_peso_final(IN p_loja BIGINT UNSIGNED, IN p_venda BIGINT UNSIGNED)
main: BEGIN
  DECLARE v_found INT DEFAULT 0;
  DECLARE v_decisao VARCHAR(20) DEFAULT NULL;
  DECLARE v_ajuste DECIMAL(12,2) DEFAULT 0;
  DECLARE par_id BIGINT UNSIGNED DEFAULT NULL;
  DECLARE par_valor DECIMAL(12,2) DEFAULT NULL;

  SELECT COUNT(*), MAX(ajuste_decisao), MAX(ajuste_peso) INTO v_found, v_decisao, v_ajuste
    FROM vendas WHERE id = p_venda AND loja_id = p_loja;
  IF v_found = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Venda não encontrada'; END IF;
  IF v_decisao IS NULL THEN LEAVE main; END IF;

  IF v_ajuste <> 0 THEN
    SELECT id, valor INTO par_id, par_valor FROM parcelas
     WHERE venda_id = p_venda AND pago_em IS NULL ORDER BY numero DESC LIMIT 1;
    IF v_ajuste > 0 THEN
      IF par_id IS NULL OR par_valor - v_ajuste < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A parcela do ajuste já foi paga; corrija manualmente';
      END IF;
      IF par_valor - v_ajuste = 0 THEN
        DELETE FROM parcelas WHERE id = par_id;
      ELSE
        UPDATE parcelas SET valor = valor - v_ajuste WHERE id = par_id;
      END IF;
    ELSE
      IF par_id IS NOT NULL THEN
        UPDATE parcelas SET valor = valor - v_ajuste WHERE id = par_id;
      ELSE
        INSERT INTO parcelas (loja_id, venda_id, numero, tipo, valor, vencimento)
        SELECT p_loja, p_venda, COALESCE(MAX(numero), 0) + 1, 'restante', -v_ajuste, NULL
          FROM parcelas WHERE venda_id = p_venda;
      END IF;
    END IF;
  END IF;

  UPDATE vendas SET gramas_final = NULL, ajuste_peso = 0, ajuste_decisao = NULL, ajuste_motivo = NULL
   WHERE id = p_venda AND loja_id = p_loja;
END$$

-- Mover a peça de etapa (para frente ou para trás). Voltar exige motivo.
-- p_desfazer_ajuste = 1: ao devolver uma peça que já teve peso final registrado,
-- remove o ajuste (o peso será pedido de novo ao marcar como pronta).
-- Nunca altere vendas.etapa com UPDATE direto: use sempre esta procedure.
CREATE PROCEDURE mover_etapa(
  IN p_loja BIGINT UNSIGNED, IN p_venda BIGINT UNSIGNED, IN p_etapa VARCHAR(20),
  IN p_motivo VARCHAR(500), IN p_desfazer_ajuste TINYINT, IN p_usuario BIGINT UNSIGNED)
main: BEGIN
  DECLARE v_found INT DEFAULT 0;
  DECLARE v_etapa VARCHAR(20) DEFAULT NULL;
  DECLARE v_decisao VARCHAR(20) DEFAULT NULL;
  DECLARE v_novo INT;
  DECLARE v_atual INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    SET @ouro_motivo = NULL;
    SET @ouro_usuario = NULL;
    RESIGNAL;
  END;

  SELECT COUNT(*), MAX(etapa), MAX(ajuste_decisao) INTO v_found, v_etapa, v_decisao
    FROM vendas WHERE id = p_venda AND loja_id = p_loja;
  IF v_found = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Venda não encontrada'; END IF;

  SET v_novo = FIELD(p_etapa, 'pedido', 'producao', 'acabamento', 'pronta', 'entregue');
  SET v_atual = FIELD(v_etapa, 'pedido', 'producao', 'acabamento', 'pronta', 'entregue');
  IF v_novo = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Etapa inválida'; END IF;
  IF v_novo = v_atual THEN LEAVE main; END IF;
  IF v_novo < v_atual AND COALESCE(TRIM(p_motivo), '') = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Informe o motivo ao devolver a peça';
  END IF;

  IF v_novo < 4 AND p_desfazer_ajuste = 1 AND v_decisao IS NOT NULL THEN
    CALL desfazer_peso_final(p_loja, p_venda);
  END IF;

  SET @ouro_motivo = COALESCE(p_motivo, '');
  SET @ouro_usuario = p_usuario;
  UPDATE vendas SET etapa = p_etapa WHERE id = p_venda AND loja_id = p_loja;
  SET @ouro_motivo = NULL;
  SET @ouro_usuario = NULL;
END$$

DELIMITER ;

-- Views. O MariaDB não filtra por usuário: SEMPRE consulte com WHERE loja_id = ?

-- Situação financeira de cada venda: pago, parcial, em_aberto ou atrasado
CREATE VIEW vendas_financeiro AS
SELECT v.id AS venda_id, v.loja_id, v.valor_final AS valor,
       COALESCE(SUM(p.valor_pago), 0) AS total_pago,
       v.valor_final - COALESCE(SUM(p.valor_pago), 0) AS saldo,
       CASE WHEN v.valor_final - COALESCE(SUM(p.valor_pago), 0) <= 0 THEN 'pago'
            WHEN COALESCE(MAX(p.pago_em IS NULL AND p.vencimento < CURRENT_DATE), 0) = 1 THEN 'atrasado'
            WHEN COALESCE(SUM(p.valor_pago), 0) > 0 THEN 'parcial'
            ELSE 'em_aberto' END AS status_pagamento
  FROM vendas v LEFT JOIN parcelas p ON p.venda_id = v.id
 GROUP BY v.id, v.loja_id, v.valor_final;

-- Cobranças: parcelas vencidas e não pagas
CREATE VIEW lembretes_cobranca AS
SELECT c.loja_id, c.id AS cliente_id, c.nome, c.telefone, v.descricao, p.id AS parcela_id,
       p.valor, p.vencimento, DATEDIFF(CURRENT_DATE, p.vencimento) AS dias_atraso
  FROM parcelas p
  JOIN vendas v ON v.id = p.venda_id
  JOIN clientes c ON c.id = v.cliente_id
 WHERE p.pago_em IS NULL AND p.vencimento < CURRENT_DATE;

-- Recompra: última venda entregue passou do prazo, cliente não foi contatado depois
-- da entrega e não tem parcela em aberto
CREATE VIEW lembretes_recompra AS
SELECT c.loja_id, c.id AS cliente_id, c.nome, c.telefone, v.descricao AS ultima_peca,
       v.data_entrega, DATEDIFF(CURRENT_DATE, v.data_entrega) AS dias_desde_entrega
  FROM clientes c
  JOIN vendas v ON v.cliente_id = c.id AND v.etapa = 'entregue'
   AND v.id = (SELECT v2.id FROM vendas v2
                WHERE v2.cliente_id = c.id AND v2.etapa = 'entregue'
                ORDER BY v2.data_entrega DESC, v2.id DESC LIMIT 1)
  JOIN configuracoes cf ON cf.loja_id = c.loja_id
 WHERE DATEDIFF(CURRENT_DATE, v.data_entrega) >= cf.dias_recompra
   AND (c.ultimo_contato IS NULL OR c.ultimo_contato < v.data_entrega)
   AND NOT EXISTS (SELECT 1 FROM vendas v3 JOIN parcelas p ON p.venda_id = v3.id
                    WHERE v3.cliente_id = c.id AND p.pago_em IS NULL);

-- Acesso liberado? Consulte a cada requisição (ou com cache curto) no middleware.
-- liberado = assinatura 'ativa', ou 'trial' dentro do prazo. Consulte com WHERE loja_id = ?
CREATE VIEW lojas_acesso AS
SELECT id AS loja_id, status_assinatura, trial_expira_em,
       CASE WHEN status_assinatura = 'ativa' THEN 1
            WHEN status_assinatura = 'trial' AND NOW() <= trial_expira_em THEN 1
            ELSE 0 END AS acesso_liberado,
       GREATEST(0, DATEDIFF(trial_expira_em, CURRENT_DATE)) AS dias_restantes_trial
  FROM lojas;
