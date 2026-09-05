#!/bin/bash
# Vuelve el estado de las alarmas de CloudWatch a OK para que puedan dispararse de nuevo.
# Útil entre ensayos de la demo: si una alarma quedó en ALARM, no vuelve a notificar.

ENVIRONMENT="${1:-prod}"

for ALARM in "${ENVIRONMENT}-unicorn-rentals-errors" "${ENVIRONMENT}-unicorn-rentals-duration" "${ENVIRONMENT}-unicorn-rentals-throttles"; do
    echo "Reiniciando $ALARM a OK..."
    aws cloudwatch set-alarm-state \
        --alarm-name "$ALARM" \
        --state-value OK \
        --state-reason "Reinicio manual de las alarmas de produccion para ensayar la demo"
done

echo "✅ Todas las alarmas reiniciadas. Se vuelven a evaluar en el próximo período de 60s."
