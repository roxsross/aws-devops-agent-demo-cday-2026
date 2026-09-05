#!/bin/bash
# Despliega el servidor MCP de Billing & Cost Management.
# Requisitos: AWS CLI, Python 3.10 o superior, pip, zip
# No hace falta CDK ni Docker.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

STACK_NAME="bcm-mcp-server"
REGION=$(aws configure get region || echo "us-east-1")
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
S3_BUCKET="bcm-mcp-server-deploy-${ACCOUNT_ID}-${REGION}"

echo "==> Empaquetando las dependencias del Lambda..."
rm -rf lambda/package lambda-package.zip
mkdir -p lambda/package
pip install \
  -r lambda/requirements.txt \
  --target lambda/package \
  --platform manylinux2014_aarch64 \
  --only-binary=:all: \
  --python-version 3.13 \
  -q
cp lambda/index.py lambda/package/

echo "==> Creando el zip de despliegue..."
cd lambda/package
zip -r "$SCRIPT_DIR/lambda-package.zip" . -q
cd "$SCRIPT_DIR"

echo "==> Verificando que exista el bucket de S3..."
if ! aws s3 ls "s3://$S3_BUCKET" 2>/dev/null; then
  aws s3 mb "s3://$S3_BUCKET" --region "$REGION"
  aws s3api put-bucket-versioning --bucket "$S3_BUCKET" --versioning-configuration Status=Enabled
fi

echo "==> Subiendo el paquete del Lambda a S3..."
S3_KEY="lambda-package-$(date +%Y%m%d%H%M%S).zip"
aws s3 cp lambda-package.zip "s3://$S3_BUCKET/$S3_KEY" --quiet

echo "==> Desplegando el stack de CloudFormation..."
aws cloudformation deploy \
  --stack-name "$STACK_NAME" \
  --template-file bcm-mcp-server-template.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    S3Bucket="$S3_BUCKET" \
    S3Key="$S3_KEY" \
    AwsRegionName="$REGION" \
  --no-fail-on-empty-changeset

echo ""
echo "==> Obteniendo los outputs..."
API_KEY_ID=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='ApiKeyId'].OutputValue" \
  --output text)

API_KEY_VALUE=$(aws apigateway get-api-key --api-key "$API_KEY_ID" --include-value --query value --output text)

MCP_URL=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='McpEndpointUrl'].OutputValue" \
  --output text)

echo ""
echo "============================================"
echo "  ¡Servidor MCP desplegado!"
echo "============================================"
echo "  Endpoint: $MCP_URL"
echo "  API Key:  $API_KEY_VALUE"
echo ""
echo "  Para usar en la configuración de DevOps Agent:"
echo "  URL:      $MCP_URL"
echo "  Header:   x-api-key: $API_KEY_VALUE"
echo "============================================"

# Limpieza
rm -f lambda-package.zip
rm -rf lambda/package
