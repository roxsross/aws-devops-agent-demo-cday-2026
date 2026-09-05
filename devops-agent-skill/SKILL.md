---
name: billing-cost-analysis
description: >
  Procedimientos de investigación para analizar el impacto en costos de AWS
  durante un incidente: detección de anomalías de costo, correlación de picos
  de gasto y recomendaciones de mitigación con conciencia de costo. Usá esta
  skill cuando investigues incidentes que puedan tener implicancias económicas,
  como invocaciones de Lambda descontroladas, throttling de DynamoDB, picos
  inesperados de tráfico, o cuando el usuario pregunte por el impacto en costos
  de una caída o una degradación. Usala también al recomendar mitigaciones,
  para tener en cuenta las contrapartidas de costo.
---

# Análisis de facturación y costos

Usá esta skill para analizar el impacto en costos durante una investigación de
incidentes y dar recomendaciones de remediación con conciencia de costo, a
través de las herramientas MCP de Billing & Cost Management.


## Paso 1: Correlacionar los costos con el incidente

Después de identificar los servicios de AWS afectados, consultá los datos de
costo para la ventana de tiempo del incidente:

1. Usá `cost_explorer` con `getCostAndUsage`, granularidad diaria y la
   dimensión `SERVICE` para detectar picos de gasto en el día del incidente.
2. Usá `cost_anomaly` sobre las últimas 48 horas para detectar patrones de
   gasto inusuales que puedan estar relacionados con el incidente.


## Paso 2: Revisar el estado de optimización de los recursos

Cuando el incidente involucra recursos de cómputo (Lambda, EC2, ECS, RDS):

1. Usá `compute_optimizer` para verificar si los recursos afectados están
   sub-aprovisionados o sobre-aprovisionados. Esto muchas veces revela la
   causa raíz.
2. Usá `cost_optimization` para ver si ya existen recomendaciones para los
   recursos afectados: puede ser que el arreglo ya esté documentado.


## Paso 3: Estimar el costo de la mitigación

Antes de recomendar aumentos de capacidad (por ejemplo, más WCUs de DynamoDB o
más memoria para el Lambda):

1. Usá `cost_explorer` con `getCostAndUsage` filtrado al servicio específico
   para ver la línea de base del gasto actual.
2. Usá `aws_pricing` para consultar los costos unitarios de los cambios
   propuestos, así podés incluir el impacto económico estimado en la
   recomendación.
3. Compará alternativas (por ejemplo, DynamoDB aprovisionado vs on-demand, o
   Lambda de 128MB vs 512MB) y presentá la contrapartida de costo.


## Paso 4: Resumir el impacto en costos

Al cerrar la investigación, incluí una sección de impacto en costos con:

1. Costo estimado del incidente (invocaciones de más, cómputo desperdiciado,
   reintentos provocados por throttling, etc.)
2. Costo de la mitigación recomendada (estimación mensual)
3. Cualquier oportunidad de optimización de costos que se haya descubierto
   durante la investigación
