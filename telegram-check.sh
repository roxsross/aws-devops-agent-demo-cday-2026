#!/bin/bash
# Verifica el bot de Telegram antes de la demo y ayuda a encontrar el chat ID.
#
# Uso:
#   export TELEGRAM_BOT_TOKEN="123456:ABC-DEF..."
#   ./telegram-check.sh                 # verifica el bot y lista los chats que le escribieron
#   export TELEGRAM_CHAT_ID="-1001234567890"
#   ./telegram-check.sh                 # ademas manda un mensaje de prueba al chat
#
# El token nunca se imprime en pantalla.
set -uo pipefail

TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-}"
API="https://api.telegram.org/bot${TOKEN}"

if [ -z "$TOKEN" ]; then
    echo "❌ Falta TELEGRAM_BOT_TOKEN."
    echo ""
    echo "   Para crear el bot:"
    echo "   1. Abrí un chat con @BotFather en Telegram"
    echo "   2. Mandá /newbot y seguí los pasos"
    echo "   3. Copiá el token que te da y exportalo:"
    echo "      export TELEGRAM_BOT_TOKEN=\"123456:ABC-DEF...\""
    exit 1
fi

if ! command -v jq > /dev/null 2>&1; then
    echo "⚠️  jq no está instalado, la salida va a verse como JSON crudo."
    echo "   Instalalo con: brew install jq"
    echo ""
    JQ="cat"
else
    JQ="jq"
fi

echo "🔍 Verificando el token del bot..."
BOT_INFO=$(curl -s --max-time 10 "${API}/getMe")

if ! echo "$BOT_INFO" | grep -q '"ok":true'; then
    echo "❌ El token no es válido. Respuesta de Telegram:"
    # Filtra el token por si Telegram lo devolviera en algun mensaje de error
    echo "$BOT_INFO" | sed "s/${TOKEN}/<TOKEN-OCULTO>/g"
    exit 1
fi

if [ "$JQ" = "jq" ]; then
    BOT_NAME=$(echo "$BOT_INFO" | jq -r '.result.username')
    echo "✅ Bot válido: @${BOT_NAME}"
else
    echo "✅ Bot válido."
fi

echo ""
echo "📋 Chats que le escribieron al bot (de acá sale el chat ID):"
UPDATES=$(curl -s --max-time 10 "${API}/getUpdates")

if [ "$JQ" = "jq" ]; then
    FOUND=$(echo "$UPDATES" | jq -r '
        [.result[].message.chat // .result[].channel_post.chat]
        | unique_by(.id)
        | .[]
        | "   \(.id)\t\(.type)\t\(.title // .username // .first_name // "sin nombre")"
    ')
    if [ -z "$FOUND" ]; then
        echo "   (ninguno todavía)"
        echo ""
        echo "   Telegram solo muestra chats con actividad reciente. Para que aparezca:"
        echo "   - Chat directo: mandale cualquier mensaje al bot"
        echo "   - Grupo: agregá el bot al grupo y escribí algo"
        echo "   - Canal: agregá el bot como administrador y publicá algo"
        echo "   Después volvé a correr este script."
    else
        echo "$FOUND"
    fi
else
    echo "$UPDATES"
fi

if [ -z "$CHAT_ID" ]; then
    echo ""
    echo "ℹ️  Para probar el envío, exportá el chat ID y volvé a correr:"
    echo "   export TELEGRAM_CHAT_ID=\"<el id de arriba>\""
    exit 0
fi

echo ""
echo "📤 Mandando mensaje de prueba a $CHAT_ID..."
TEXT=$(printf '%s' "🚨 <b>Prueba de la demo</b>
<code>prod-unicorn-rentals-errors</code>

Si estás leyendo esto, el bot está listo para la charla.

🤖 <i>DevOps Agent va a arrancar la investigación cuando se dispare la alarma de verdad.</i>")

RESULT=$(curl -s --max-time 10 -X POST "${API}/sendMessage" \
    -H 'Content-Type: application/json' \
    --data-binary "$(jq -n --arg c "$CHAT_ID" --arg t "$TEXT" \
        '{chat_id: $c, text: $t, parse_mode: "HTML", disable_web_page_preview: true}' \
        2>/dev/null || printf '{"chat_id":"%s","text":"Prueba de la demo","parse_mode":"HTML"}' "$CHAT_ID")")

if echo "$RESULT" | grep -q '"ok":true'; then
    echo "✅ Mensaje enviado. Miralo en Telegram."
    echo ""
    echo "🎯 Ya podés desplegar con Telegram:"
    echo "   export TELEGRAM_BOT_TOKEN=\"...\"   # el que ya tenés exportado"
    echo "   export TELEGRAM_CHAT_ID=\"$CHAT_ID\""
    echo "   ./deploy.sh"
else
    echo "❌ No se pudo enviar. Respuesta de Telegram:"
    echo "$RESULT" | sed "s/${TOKEN}/<TOKEN-OCULTO>/g"
    echo ""
    echo "   Causa más común: el bot no es miembro del chat, o el chat ID está mal."
    echo "   Para canales el ID arranca con -100."
    exit 1
fi
