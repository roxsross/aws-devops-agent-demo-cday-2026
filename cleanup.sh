#!/bin/bash

# Demo de AWS DevOps Agent - Script de limpieza
# Borra los recursos creados por deploy.sh (y opcionalmente el servidor MCP).
set -e

STACK_NAME="unicorn-rentals"
MCP_STACK_NAME="bcm-mcp-server"

echo "🧹 Limpiando el entorno Unicorn Rentals"
echo "================================================"

# Verificar que el AWS CLI esté configurado
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ El AWS CLI no está configurado. Ejecutá 'aws configure' primero."
    exit 1
fi

echo "✅ AWS CLI configurado"

# Borrar el stack principal
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" > /dev/null 2>&1; then
    echo "🗑️  Borrando el stack '$STACK_NAME'..."
    aws cloudformation delete-stack --stack-name "$STACK_NAME"
    echo "⏳ Esperando que se complete el borrado..."
    aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME"
    echo "✅ Stack '$STACK_NAME' borrado."
else
    echo "ℹ️  El stack '$STACK_NAME' no existe. Nada que borrar."
fi

# Borrar el stack del servidor MCP (si está desplegado)
if aws cloudformation describe-stacks --stack-name "$MCP_STACK_NAME" > /dev/null 2>&1; then
    echo "🗑️  Borrando el stack '$MCP_STACK_NAME'..."
    aws cloudformation delete-stack --stack-name "$MCP_STACK_NAME"
    echo "⏳ Esperando que se complete el borrado..."
    aws cloudformation wait stack-delete-complete --stack-name "$MCP_STACK_NAME"
    echo "✅ Stack '$MCP_STACK_NAME' borrado."
else
    echo "ℹ️  El stack '$MCP_STACK_NAME' no existe (opcional). Se omite."
fi

# Borrar el archivo de entorno generado localmente
if [ -f demo-environment.env ]; then
    rm -f demo-environment.env
    echo "🧹 Archivo local demo-environment.env eliminado."
fi

echo ""
echo "✅ ¡Limpieza completa!"
