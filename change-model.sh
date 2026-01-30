#!/bin/bash
# Script para alterar o modelo do Moltbot
# Uso: ./change-model.sh "openrouter/anthropic/claude-sonnet-4.5"

if [ -z "$1" ]; then
  echo "❌ Erro: Especifique o modelo"
  echo ""
  echo "Uso: $0 <modelo>"
  echo ""
  echo "⚠️  IMPORTANTE: Use o prefixo openrouter/ antes do nome do modelo!"
  echo ""
  echo "Exemplos de modelos disponíveis via OpenRouter:"
  echo "  - openrouter/anthropic/claude-sonnet-4.5 (recomendado)"
  echo "  - openrouter/anthropic/claude-3.5-sonnet (rápido)"
  echo "  - openrouter/openai/gpt-4o (código)"
  echo "  - openrouter/google/gemini-2.0-flash-exp (gratuito)"
  echo "  - openrouter/meta-llama/llama-3.3-70b-instruct (gratuito)"
  echo "  - openrouter/deepseek/deepseek-r1 (gratuito)"
  echo ""
  echo "Exemplo: $0 \"openrouter/anthropic/claude-sonnet-4.5\""
  exit 1
fi

MODEL="$1"

echo "🔧 Alterando modelo para: $MODEL"

docker exec moltbot sh -c "cat > /tmp/change-model.js << 'EOJS'
const fs = require('fs');
const configPath = '/home/moltbot/.clawdbot/clawdbot.json';
const cfg = JSON.parse(fs.readFileSync(configPath, 'utf8'));

cfg.agents = cfg.agents || {};
cfg.agents.defaults = cfg.agents.defaults || {};
cfg.agents.defaults.model = { primary: '$MODEL' };

fs.writeFileSync(configPath, JSON.stringify(cfg, null, 2));
console.log('✅ Modelo alterado para: $MODEL');
EOJS
node /tmp/change-model.js"

echo ""
echo "🔄 Reiniciando container..."
docker compose restart

echo ""
echo "✅ Pronto! Modelo alterado para: $MODEL"
echo ""
echo "🌐 Acesse: http://localhost:18789/chat?token=moltbot-s3cr3t-2026-xyz"
