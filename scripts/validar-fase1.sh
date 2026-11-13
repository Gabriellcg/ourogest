#!/usr/bin/env bash
# Validação ponta a ponta da Fase 1 (cadastro, login, sessão, trial, logout).
#
# Pré-requisitos: app rodando (npm run dev) e MariaDB com o db/schema.sql carregado.
#
# Uso:
#   BASE=http://localhost:3000 \
#   SQL_CMD="docker exec ourogest_db mariadb -uroot -proot_password_segura ourogest -N -e" \
#   bash scripts/validar-fase1.sh
#
# SQL_CMD é o comando que executa um SQL (a query vai como último argumento).
# Sem SQL_CMD, os testes que precisam alterar/consultar o banco são pulados.

BASE="${BASE:-http://localhost:3000}"
SQL_CMD="${SQL_CMD:-}"
S="$(date +%s)"
SENHA="SenhaForte123"
TMP="$(mktemp -d)"
PASS=0; FAIL=0; SKIP=0

ok()   { PASS=$((PASS+1)); echo "  ✔ $1"; }
ko()   { FAIL=$((FAIL+1)); echo "  ✘ $1 | esperado: $2 | obtido: $3"; }
eq()   { if [ "$2" = "$3" ]; then ok "$1"; else ko "$1" "$2" "$3"; fi; }
has()  { case "$3" in *"$2"*) ok "$1";; *) ko "$1" "contém '$2'" "${3:0:120}";; esac; }
hasnt(){ case "$3" in *"$2"*) ko "$1" "não contém '$2'" "contém";; *) ok "$1";; esac; }
skip() { SKIP=$((SKIP+1)); echo "  - (pulado: sem SQL_CMD) $1"; }
secao(){ echo; echo "== $1"; }
sql()  { $SQL_CMD "$1"; }

# req JAR [args do curl...] -> CODE, BODY, REDIR, HEAD
req() {
  local jar="$1"; shift
  local out
  out=$(curl -s -o "$TMP/body" -D "$TMP/head" -w '%{http_code}|%{redirect_url}' -c "$jar" -b "$jar" "$@")
  CODE="${out%%|*}"; REDIR="${out#*|}"; BODY="$(cat "$TMP/body")"; HEAD="$(cat "$TMP/head")"
}
post() { local jar="$1" url="$2" json="$3"; req "$jar" -X POST -H 'Content-Type: application/json' -d "$json" "$BASE$url"; }
cadastro_json() { echo "{\"loja_nome\":\"$1\",\"nome\":\"$2\",\"email\":\"$3\",\"senha\":\"$4\"}"; }
path_of() { echo "${1#"$BASE"}"; }

JA="$TMP/a.jar"; JB="$TMP/b.jar"; JANON="$TMP/anon.jar"
EA="validacao+a$S@teste.com"; EB="validacao+b$S@teste.com"
LA="Validacao Loja A $S"; LB="Validacao Loja B $S"

secao "Servidor"
req "$JANON" "$BASE/login"; eq "GET /login responde 200" 200 "$CODE"

secao "Cadastro: validações (devem ser recusadas)"
post "$JANON" /api/cadastro "$(cadastro_json "$LA" "Maria Souza" "email-invalido" "$SENHA")"; eq "e-mail inválido -> 400" 400 "$CODE"
post "$JANON" /api/cadastro "$(cadastro_json "$LA" "Maria Souza" "$EA" "curta")"; eq "senha < 8 -> 400" 400 "$CODE"
post "$JANON" /api/cadastro "$(cadastro_json "X" "Maria Souza" "$EA" "$SENHA")"; eq "nome da loja < 2 -> 400" 400 "$CODE"
post "$JANON" /api/cadastro "$(cadastro_json "$LA" "Ana" "$EA" "$SENHA")"; eq "seu nome < 4 -> 400" 400 "$CODE"
post "$JANON" /api/cadastro '{}'; eq "corpo vazio -> 400" 400 "$CODE"
post "$JANON" /api/cadastro '{json quebrado'; eq "JSON malformado -> 400" 400 "$CODE"

secao "Cadastro: loja A"
post "$JA" /api/cadastro "$(cadastro_json "$LA" "Maria Souza" "$EA" "$SENHA")"
eq "cadastro válido -> 201" 201 "$CODE"
has "resposta traz status trial" '"status_assinatura":"trial"' "$BODY"
has "usuário criado como dono" '"papel":"dono"' "$BODY"
hasnt "resposta NÃO traz a senha/hash" 'senha' "$BODY"
has "cookie de sessão HttpOnly" 'HttpOnly' "$HEAD"
has "cookie com SameSite=lax" "samesite=lax" "$(echo "$HEAD" | tr 'A-Z' 'a-z')"
post "$JANON" /api/cadastro "$(cadastro_json "Outra Loja" "Maria Souza" "$EA" "$SENHA")"; eq "e-mail repetido -> 409" 409 "$CODE"
post "$JANON" /api/cadastro "$(cadastro_json "Outra Loja" "Maria Souza" "$(echo "$EA" | tr 'a-z' 'A-Z')" "$SENHA")"; eq "e-mail repetido em MAIÚSCULAS -> 409" 409 "$CODE"

secao "Cadastro: o que ficou gravado no banco"
if [ -n "$SQL_CMD" ]; then
  eq "loja nasceu em trial" "trial" "$(sql "SELECT status_assinatura FROM lojas WHERE nome='$LA'")"
  eq "prazo do trial = 7 dias" "7" "$(sql "SELECT DATEDIFF(trial_expira_em, criado_em) FROM lojas WHERE nome='$LA'")"
  eq "configuracoes criada para a loja" "1" "$(sql "SELECT COUNT(*) FROM configuracoes c JOIN lojas l ON l.id=c.loja_id WHERE l.nome='$LA'")"
  eq "senha guardada como hash bcrypt" "1" "$(sql "SELECT senha_hash LIKE '\$2%' AND senha_hash <> '$SENHA' FROM usuarios WHERE email='$EA'")"
  eq "e-mail gravado em minúsculas" "$EA" "$(sql "SELECT email FROM usuarios WHERE email='$EA'")"
  eq "apenas 1 loja com esse nome (rejeitados não criaram lojas)" "1" "$(sql "SELECT COUNT(*) FROM lojas WHERE nome IN ('$LA','Outra Loja')")"
else skip "conferência das tabelas"; fi

secao "Cadastro: duas requisições simultâneas com o mesmo e-mail"
J1="$TMP/c1.jar"; J2="$TMP/c2.jar"; EC="validacao+c$S@teste.com"; LC="Validacao Loja C $S"
( curl -s -o /dev/null -w '%{http_code}\n' -X POST -H 'Content-Type: application/json' -c "$J1" -d "$(cadastro_json "$LC" "Carlos Lima" "$EC" "$SENHA")" "$BASE/api/cadastro" > "$TMP/r1" ) &
( curl -s -o /dev/null -w '%{http_code}\n' -X POST -H 'Content-Type: application/json' -c "$J2" -d "$(cadastro_json "$LC" "Carlos Lima" "$EC" "$SENHA")" "$BASE/api/cadastro" > "$TMP/r2" ) &
wait
R="$(cat "$TMP/r1" "$TMP/r2" | sort | tr '\n' ' ')"
eq "uma criou (201) e a outra foi recusada (409)" "201 409 " "$R"
if [ -n "$SQL_CMD" ]; then
  eq "sem loja órfã após a corrida" "1" "$(sql "SELECT COUNT(*) FROM lojas WHERE nome='$LC'")"
else skip "checagem de loja órfã"; fi

secao "Cadastro: loja B (isolamento entre lojas)"
post "$JB" /api/cadastro "$(cadastro_json "$LB" "Bruno Alves" "$EB" "$SENHA")"; eq "cadastro da loja B -> 201" 201 "$CODE"

secao "Login"
rm -f "$JA"
post "$JA" /api/login "{\"email\":\"$EA\",\"senha\":\"$SENHA\"}"; eq "login correto -> 200" 200 "$CODE"
has "login devolve a loja certa" "$LA" "$BODY"
post "$JANON" /api/login "{\"email\":\"$EA\",\"senha\":\"errada123\"}"; eq "senha errada -> 401" 401 "$CODE"; MSG1="$BODY"
post "$JANON" /api/login "{\"email\":\"naoexiste+$S@teste.com\",\"senha\":\"$SENHA\"}"; eq "e-mail inexistente -> 401" 401 "$CODE"
eq "mesma mensagem para senha errada e e-mail inexistente" "$MSG1" "$BODY"
post "$JANON" /api/login "{\"email\":\"$EA\",\"senha\":\"' OR '1'='1\"}"; eq "tentativa de SQL injection na senha -> 401" 401 "$CODE"
post "$JANON" /api/login "{\"email\":\"$EA\",\"senha\":\"\"}"; eq "senha vazia -> 400" 400 "$CODE"
post "$JANON" /api/login "{\"email\":\"nao-e-email\",\"senha\":\"x\"}"; eq "e-mail inválido -> 400" 400 "$CODE"
post "$JANON" /api/login '{quebrado'; eq "JSON malformado -> 400" 400 "$CODE"
post "$TMP/upper.jar" /api/login "{\"email\":\"$(echo "$EA" | tr 'a-z' 'A-Z')\",\"senha\":\"$SENHA\"}"; eq "login com e-mail em MAIÚSCULAS -> 200" 200 "$CODE"
if [ -n "$SQL_CMD" ]; then
  sql "UPDATE usuarios SET ativo=0 WHERE email='$EB'" >/dev/null
  post "$JANON" /api/login "{\"email\":\"$EB\",\"senha\":\"$SENHA\"}"; eq "usuário inativo -> 401" 401 "$CODE"
  sql "UPDATE usuarios SET ativo=1 WHERE email='$EB'" >/dev/null
else skip "usuário inativo"; fi

secao "Proteção de rotas (middleware)"
rm -f "$JANON"   # o jar anônimo foi usado em logins acima; recomeça sem cookie
req "$JANON" "$BASE/calculadora"; eq "anônimo em /calculadora -> redireciona" 307 "$CODE"; eq "  ...para /login" "/login" "$(path_of "$REDIR")"
req "$JANON" "$BASE/assinatura"; eq "anônimo em /assinatura -> /login" "/login" "$(path_of "$REDIR")"
req "$JANON" "$BASE/vendas"; eq "anônimo em /vendas -> /login" "/login" "$(path_of "$REDIR")"
req "$JANON" -H 'Cookie: ourogest_session=cookie_falsificado' "$BASE/calculadora"; eq "cookie falsificado -> /login" "/login" "$(path_of "$REDIR")"
req "$JA" "$BASE/calculadora"; eq "logado em /calculadora -> 200" 200 "$CODE"
req "$JA" "$BASE/login"; eq "logado em /login -> /calculadora" "/calculadora" "$(path_of "$REDIR")"
req "$JA" "$BASE/cadastro"; eq "logado em /cadastro -> /calculadora" "/calculadora" "$(path_of "$REDIR")"
req "$JA" "$BASE/assinatura"; eq "trial válido não acessa /assinatura" "/calculadora" "$(path_of "$REDIR")"
req "$JA" "$BASE/"; eq "/ encaminha para o login (e daí para a calculadora)" 307 "$CODE"

secao "Menu lateral e isolamento entre lojas"
req "$JA" "$BASE/calculadora"
BODY_LIMPO="$(echo "$BODY" | sed 's/<!-- -->//g')"   # o React separa textos com comentários
has "loja A vê o próprio nome" "$LA" "$BODY"
has "mostra dias restantes do teste" "Teste grátis: 7 dias restantes" "$BODY_LIMPO"
has "itens futuros aparecem como 'em breve'" "em breve" "$BODY"
hasnt "loja A NÃO vê a loja B" "$LB" "$BODY"
req "$JB" "$BASE/calculadora"
has "loja B vê o próprio nome" "$LB" "$BODY"
hasnt "loja B NÃO vê a loja A" "$LA" "$BODY"

secao "Trial vencido e status de assinatura"
if [ -n "$SQL_CMD" ]; then
  sql "UPDATE lojas SET trial_expira_em = NOW() - INTERVAL 1 DAY WHERE nome='$LA'" >/dev/null
  rm -f "$JA"; post "$JA" /api/login "{\"email\":\"$EA\",\"senha\":\"$SENHA\"}"; eq "login ainda funciona com trial vencido" 200 "$CODE"
  req "$JA" "$BASE/calculadora"; eq "trial vencido em /calculadora -> /assinatura" "/assinatura" "$(path_of "$REDIR")"
  req "$JA" "$BASE/assinatura"; eq "/assinatura abre para trial vencido" 200 "$CODE"
  has "mensagem de teste terminado" "teste grátis de 7 dias terminou" "$BODY"
  eq "dados da loja preservados" "1" "$(sql "SELECT COUNT(*) FROM lojas WHERE nome='$LA'")"

  sql "UPDATE lojas SET status_assinatura='bloqueada' WHERE nome='$LA'" >/dev/null
  rm -f "$JA"; post "$JA" /api/login "{\"email\":\"$EA\",\"senha\":\"$SENHA\"}"
  req "$JA" "$BASE/calculadora"; eq "status bloqueada -> /assinatura" "/assinatura" "$(path_of "$REDIR")"
  req "$JA" "$BASE/assinatura"; has "mensagem de acesso bloqueado" "Acesso bloqueado" "$BODY"

  sql "UPDATE lojas SET status_assinatura='vencida' WHERE nome='$LA'" >/dev/null
  rm -f "$JA"; post "$JA" /api/login "{\"email\":\"$EA\",\"senha\":\"$SENHA\"}"
  req "$JA" "$BASE/calculadora"; eq "status vencida -> /assinatura" "/assinatura" "$(path_of "$REDIR")"

  sql "UPDATE lojas SET status_assinatura='ativa' WHERE nome='$LA'" >/dev/null
  rm -f "$JA"; post "$JA" /api/login "{\"email\":\"$EA\",\"senha\":\"$SENHA\"}"
  req "$JA" "$BASE/calculadora"; eq "assinatura ativa libera /calculadora" 200 "$CODE"
  hasnt "assinatura ativa não mostra aviso de teste" "Teste grátis" "$BODY"
  req "$JA" "$BASE/assinatura"; eq "assinatura ativa não acessa /assinatura" "/calculadora" "$(path_of "$REDIR")"
else skip "cenários de trial vencido / bloqueada / vencida / ativa"; fi

secao "Logout"
post "$JA" /api/logout '{}'; eq "logout -> 200" 200 "$CODE"
req "$JA" "$BASE/calculadora"; eq "após o logout /calculadora -> /login" "/login" "$(path_of "$REDIR")"

if [ -n "$SQL_CMD" ]; then
  sql "DELETE FROM lojas WHERE nome LIKE 'Validacao Loja % $S'" >/dev/null
fi
rm -rf "$TMP"

echo
echo "Resultado: $PASS passaram, $FAIL falharam, $SKIP pulados."
[ "$FAIL" -eq 0 ]
