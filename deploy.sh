#!/bin/bash

# Demo de AWS DevOps Agent - Script de despliegue
# Charla: "La última guardia manual" por Roxs
set -e

STACK_NAME="unicorn-rentals"
ENVIRONMENT="prod"
WEBHOOK_URL="${DEVOPS_AGENT_WEBHOOK_URL:-}"
WEBHOOK_SECRET="${DEVOPS_AGENT_WEBHOOK_SECRET:-}"

echo "🚀 Desplegando el entorno Unicorn Rentals"
echo "================================================"

# Verificar que el AWS CLI esté configurado
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ El AWS CLI no está configurado. Ejecutá 'aws configure' primero."
    exit 1
fi

echo "✅ AWS CLI configurado"

# Armar la lista de parámetros
PARAMS="ParameterKey=Environment,ParameterValue=$ENVIRONMENT"
if [ -n "$WEBHOOK_URL" ] && [ -n "$WEBHOOK_SECRET" ]; then
    PARAMS="$PARAMS ParameterKey=DevOpsAgentWebhookUrl,ParameterValue=$WEBHOOK_URL ParameterKey=DevOpsAgentWebhookSecret,ParameterValue=$WEBHOOK_SECRET"
    echo "🔗 Integración por webhook habilitada"
else
    echo "ℹ️  Sin webhook configurado (definí DEVOPS_AGENT_WEBHOOK_URL y DEVOPS_AGENT_WEBHOOK_SECRET para habilitarlo)"
fi

# Verificar si el stack existe y en qué estado está
STACK_STATUS=""
if aws cloudformation describe-stacks --stack-name $STACK_NAME > /dev/null 2>&1; then
    STACK_STATUS=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --query 'Stacks[0].StackStatus' \
        --output text)
    echo "📋 El stack ya existe, con estado: $STACK_STATUS"
fi

# Manejar los distintos estados posibles del stack
if [ "$STACK_STATUS" = "CREATE_FAILED" ] || [ "$STACK_STATUS" = "ROLLBACK_COMPLETE" ]; then
    echo "🗑️  Borrando el stack que quedó fallado..."
    aws cloudformation delete-stack --stack-name $STACK_NAME
    echo "⏳ Esperando que termine el borrado del stack..."
    aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME
    STACK_STATUS=""
fi

if [ -z "$STACK_STATUS" ]; then
    # Crear un stack nuevo
    echo "📦 Creando el stack de CloudFormation..."
    aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --template-body file://cloudformation-template.yaml \
        --capabilities CAPABILITY_NAMED_IAM \
        --parameters $PARAMS \
        --tags Key=Purpose,Value=DevOpsAgent Key=Environment,Value=$ENVIRONMENT Key=auto-delete,Value=never Key=auto-stop,Value=no

    echo "⏳ Esperando que se complete la creación del stack..."
    aws cloudformation wait stack-create-complete --stack-name $STACK_NAME
else
    # Actualizar el stack existente
    echo "🔄 Actualizando el stack de CloudFormation existente..."
    UPDATE_OUTPUT=$(aws cloudformation update-stack \
        --stack-name $STACK_NAME \
        --template-body file://cloudformation-template.yaml \
        --capabilities CAPABILITY_NAMED_IAM \
        --parameters $PARAMS 2>&1) || {
        if echo "$UPDATE_OUTPUT" | grep -q "No updates are to be performed"; then
            echo "✅ El stack ya está actualizado. No hay cambios para aplicar."
        else
            echo "❌ Falló la actualización del stack: $UPDATE_OUTPUT"
            exit 1
        fi
    }

    if echo "$UPDATE_OUTPUT" | grep -q "StackId"; then
        echo "⏳ Esperando que se complete la actualización del stack..."
        aws cloudformation wait stack-update-complete --stack-name $STACK_NAME
    fi
fi

# Obtener los outputs
echo "📋 Obteniendo los outputs del stack..."
API_URL=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiGatewayUrl`].OutputValue' \
    --output text)

LAMBDA_NAME=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`LambdaFunctionName`].OutputValue' \
    --output text)

TABLE_NAME=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`DynamoDBTableName`].OutputValue' \
    --output text)

# Crear el archivo de entorno
cat > demo-environment.env << EOF
# Variables de entorno del entorno Unicorn Rentals
export API_URL="$API_URL"
export LAMBDA_NAME="$LAMBDA_NAME"
export TABLE_NAME="$TABLE_NAME"
export STACK_NAME="$STACK_NAME"
EOF

echo "✅ ¡Despliegue completo!"
echo ""
echo "📊 Detalles del entorno de demo:"
echo "   Nombre del stack: $STACK_NAME"
echo "   URL de la API: $API_URL"
echo "   Función Lambda: $LAMBDA_NAME"
echo "   Tabla DynamoDB: $TABLE_NAME"
echo ""
echo "🎯 Próximos pasos:"
echo "   1. Cargar el entorno: source demo-environment.env"
echo "   2. Instalar dependencias de Python: pip install requests"
echo "   3. Correr el generador de carga: python continuous-load-generator.py --api-url \$API_URL --rps 15 --duration 10"
echo "   4. Mirar las alarmas y las investigaciones de DevOps Agent"
echo ""
echo "🧹 Para limpiar todo: aws cloudformation delete-stack --stack-name $STACK_NAME"
