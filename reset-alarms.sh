#!/bin/bash
# Vuelve el estado de las alarmas de CloudWatch a OK para permitir que se disparen de nuevo

ENVIRONMENT="${1:-prod}"

for ALARM in "${ENVIRONMENT}-unicorn-rentals-errors" "${ENVIRONMENT}-unicorn-rentals-duration" "${ENVIRONMENT}-unicorn-rentals-throttles"; do
    echo "Reiniciando $ALARM a OK..."
    aws cloudwatch set-alarm-state \
        --alarm-name "$ALARM" \
        --state-value OK \
        --state-reason "Manual reset of production alarms"
done

echo "✅ Todas las alarmas reiniciadas. Se vuelven a evaluar en el próximo período de 60s."
