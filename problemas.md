# Problemas Encontrados e Soluções

## Data: 2026-01-29

### Problema 1: API Key do OpenRouter não estava sendo configurada
**Erro:**
```
Error: No API key found for provider "anthropic"
```

**Causa:**
O entrypoint.sh estava configurando o auth profile do OpenRouter mas não estava injetando a API key no formato correto.

**Solução Tentada (FALHOU):**
Tentamos adicionar a API key diretamente no JSON de configuração:
```javascript
cfg.auth.profiles['openrouter:default'] = {
  provider: 'openrouter',
  mode: 'token',
  apiKey: process.env.OPENROUTER_API_KEY
};
```

**Resultado:**
O Moltbot rejeitou a configuração com erro:
```
- auth.profiles.openrouter:default: Unrecognized key: "apiKey"
- agents.defaults: Unrecognized key: "authProfile"
```

**Tentativa 1 - Comando CLI (FALHOU):**
Tentamos usar o comando CLI do Moltbot:
```bash
echo "$OPENROUTER_API_KEY" | clawdbot models auth paste-token --provider openrouter --profile-id openrouter:default
```

**Resultado:** Falhou porque o comando CLI precisa do gateway rodando, mas é executado no entrypoint ANTES do gateway iniciar. O diretório `~/.clawdbot/agents/` só é criado quando o gateway inicia.

**Tentativa 2 - Criar arquivo manualmente (SUCESSO):**
Criamos o arquivo auth-profiles.json diretamente no entrypoint.sh:
```bash
# Create agent directory structure
AGENT_DIR="$CONFIG_DIR/agents/main/agent"
AUTH_PROFILES_FILE="$AGENT_DIR/auth-profiles.json"
mkdir -p "$AGENT_DIR"

# Create auth-profiles.json with OpenRouter credentials
cat > "$AUTH_PROFILES_FILE" <<EOF
{
  "openrouter:default": {
    "provider": "openrouter",
    "token": "$OPENROUTER_API_KEY"
  }
}
EOF
chmod 600 "$AUTH_PROFILES_FILE"
```

**Resultado:** ✓ Arquivo criado com sucesso antes do gateway iniciar
**Problema adicional:** Mesmo com o arquivo auth-profiles.json criado, o Clawdbot continuou retornando erro "No API key found for provider 'anthropic'".

**Tentativa 3 - Adicionar auth profile para "anthropic" (FALHOU):**
Criamos também um auth profile "anthropic:default" usando o mesmo token do OpenRouter:
```json
{
  "openrouter:default": {
    "provider": "openrouter",
    "token": "$OPENROUTER_API_KEY"
  },
  "anthropic:default": {
    "provider": "anthropic",
    "token": "$OPENROUTER_API_KEY"
  }
}
```

**Resultado:** ✗ Mesmo erro. O arquivo foi criado corretamente mas o Clawdbot ainda não reconhece as credenciais.

**Tentativa 4 - Usar variável de ambiente ANTHROPIC_API_KEY (EM TESTE):**
Adicionamos exportação da variável de ambiente no entrypoint.sh:
```bash
export ANTHROPIC_API_KEY="$OPENROUTER_API_KEY"
```

**Motivo:** Muitas ferramentas CLI reconhecem variáveis de ambiente automaticamente. Se o Clawdbot reconhecer `ANTHROPIC_API_KEY`, pode usar diretamente sem precisar ler o arquivo auth-profiles.json.

**Resultado:** ✓ Progresso! Não apareceu mais o erro "No API key found". O Clawdbot reconheceu a variável de ambiente `ANTHROPIC_API_KEY`.
**Problema:** Provavelmente travou tentando usar token do OpenRouter na API da Anthropic (incompatível).

**Tentativa 5 - Trocar para modelo Gemini gratuito (FALHOU):**
Mudamos o modelo para `google/gemini-2.0-flash-exp:free` para evitar o conflito de provider.

**Resultado:** ✗ Erro "Unknown model: google/gemini-2.0-flash-exp:free". O Clawdbot não reconhece esse modelo ou o formato `:free`.

---

## Problema Fundamental Identificado

O Clawdbot **não suporta usar OpenRouter como proxy/gateway** para modelos de outros providers. Quando você configura um modelo como `anthropic/claude-sonnet-4-5`, ele tenta conectar DIRETAMENTE à API da Anthropic, não através do OpenRouter.

**Opções:**
1. Usar uma chave de API direta da Anthropic (não gratuito)
2. Encontrar modelos que o Clawdbot aceite via OpenRouter
3. Investigar se há configuração para forçar uso de OpenRouter como gateway universal

**Tentativa 6 - Configurar ANTHROPIC_BASE_URL via docker-compose.yml (SUCESSO PARCIAL!):**

Descobrimos na documentação oficial do OpenRouter que é necessário configurar duas variáveis de ambiente:
```bash
ANTHROPIC_API_KEY=$OPENROUTER_API_KEY
ANTHROPIC_BASE_URL=https://openrouter.ai/api/v1
```

Adicionamos essas variáveis no `docker-compose.yml` ao invés de apenas no entrypoint.sh para garantir que sejam passadas ao processo do gateway.

**Resultado:** ✓ **SUCESSO!** As mensagens estão sendo processadas sem erros!

**Evidência dos logs:**
```
"embedded run start: provider=anthropic model=claude-sonnet-4-5"
"embedded run done: durationMs=576 aborted=false"
"message processed: outcome=completed duration=641ms"
```

**Status atual:** Mensagens são processadas com sucesso, mas a resposta não aparece no webchat. Pode ser:
- Bug de visualização do webchat
- Agent rodando em modo silencioso
- Problema de comunicação WebSocket

**Progresso:** ✅ API integrada com OpenRouter funcionando!
**Próximo passo:** Investigar por que a resposta não é exibida no webchat.

---

## SOLUÇÃO FINAL (FUNCIONOU! ✅)

**Data:** 2026-01-29 23:51

**Problema:** O formato do modelo estava incorreto. O Moltbot requer o prefixo `openrouter/` para usar modelos via OpenRouter.

**Configuração correta:**
```bash
# .env
DEFAULT_MODEL=openrouter/anthropic/claude-sonnet-4.5
OPENROUTER_API_KEY=sk-or-v1-...
```

**NÃO é necessário:**
- ❌ ANTHROPIC_API_KEY
- ❌ ANTHROPIC_BASE_URL
- ❌ Configurações manuais de auth-profiles.json

**Formato do modelo:**
- ❌ Errado: `anthropic/claude-sonnet-4-5` (sem prefixo openrouter)
- ❌ Errado: `anthropic/claude-sonnet-4.5` (sem prefixo openrouter)
- ✅ **Correto:** `openrouter/anthropic/claude-sonnet-4.5`

**Evidência de sucesso:**
```
embedded run start: provider=openrouter model=anthropic/claude-sonnet-4.5
embedded run done: durationMs=17354 aborted=false
message processed: outcome=completed duration=17507ms
```

**Status:** ✅ **MOLTBOT NO AR COM OPENROUTER FUNCIONANDO!**

**Documentação oficial:** https://docs.molt.bot/providers/openrouter

---

### Problema 2: Formato incorreto do modelo
**Erro:**
```
Error: Unknown model: openrouter:anthropic/claude-sonnet-4-5
```

**Causa:**
O entrypoint.sh estava adicionando o prefixo `openrouter:` ao nome do modelo.

**Código Incorreto:**
```javascript
cfg.agents.defaults.model = { primary: 'openrouter:' + process.env.DEFAULT_MODEL };
```

**Solução:**
Remover o prefixo e usar o modelo diretamente:
```javascript
cfg.agents.defaults.model = { primary: process.env.DEFAULT_MODEL };
```

O modelo correto é: `anthropic/claude-sonnet-4-5` (sem prefixo)

---

### Problema 3: Docker build cache corrupted
**Erro:**
```
failed to prepare extraction snapshot: parent snapshot does not exist
```

**Causa:**
Cache do Docker corrompido após múltiplos builds.

**Solução:**
```bash
docker system prune -f
docker compose build --no-cache
```

---

## Status Atual

✅ Container iniciado com sucesso
✅ Gateway rodando na porta 18789 (container) / 18790 (host)
✅ Modelo configurado: anthropic/claude-sonnet-4-5
✅ Webchat conectado

⏳ Aguardando teste de mensagem para confirmar que a API key está funcionando corretamente

---

## Próximos Passos

1. Testar envio de mensagem pelo webchat
2. Verificar se o Moltbot responde corretamente usando o OpenRouter
3. Documentar se houver novos erros
