# Ejemplos de uso de las herramientas

## Detectar un pico de costo durante un incidente

Usá `cost_explorer` con granularidad diaria para ver si el costo tuvo un pico el día del incidente:

```json
{
  "operation": "getCostAndUsage",
  "start_date": "2026-04-22",
  "end_date": "2026-04-24",
  "granularity": "DAILY",
  "metrics": ["UnblendedCost"],
  "group_by": "[{\"Type\": \"DIMENSION\", \"Key\": \"SERVICE\"}]"
}
```

## Detectar anomalías de costo

```json
{
  "operation": "cost_anomaly",
  "start_date": "2026-04-20",
  "end_date": "2026-04-24"
}
```

## Revisar el dimensionamiento del Lambda

```json
{
  "operation": "get_lambda_function_recommendations"
}
```

## Consultar precios de DynamoDB para planificar capacidad

Primero obtené el código del servicio:
```json
{
  "operation": "get_service_codes"
}
```

Después consultá los precios:
```json
{
  "operation": "get_pricing_from_api",
  "service_code": "AmazonDynamoDB",
  "region": "us-east-1"
}
```

## Comparar costos mes contra mes

```json
{
  "operation": "getCostAndUsageComparisons",
  "baseline_start_date": "2026-03-01",
  "baseline_end_date": "2026-04-01",
  "comparison_start_date": "2026-04-01",
  "comparison_end_date": "2026-05-01",
  "metric_for_comparison": "UnblendedCost",
  "group_by": "[{\"Type\": \"DIMENSION\", \"Key\": \"SERVICE\"}]"
}
```
