# DevOps Agent Space con Terraform

Provisiona un Agent Space de AWS DevOps Agent como infraestructura: los dos roles IAM (Agent Space y Operator App), el Space y la asociación de la cuenta primaria (monitor). Basado en el [sample oficial de AWS](https://github.com/aws-samples/sample-aws-devops-agent-terraform).

## Requisitos

- Terraform >= 1.0
- AWS CLI configurado con credenciales de la cuenta donde vas a crear el Space
- Provider `awscc` (AWS Cloud Control) — se instala solo con `terraform init`
- Una región soportada por DevOps Agent: `us-east-1`, `us-west-2`, `ap-southeast-2`, `ap-northeast-1`, `eu-central-1`, `eu-west-1`

## Uso

```bash
cd terraform-agent-space
terraform init
terraform plan       # revisá qué va a crear
terraform apply      # escribí 'yes' para confirmar
```

Variables disponibles (todas con default, ver `main.tf`):

| Variable | Default | Descripción |
|---|---|---|
| `aws_region` | `us-east-1` | Región donde se crea el Space |
| `agent_space_name` | `unicorn-rentals-demo` | Nombre del Agent Space |
| `agent_space_description` | (texto) | Descripción del Space |

Ejemplo con valores propios:
```bash
terraform apply -var="agent_space_name=mi-space" -var="aws_region=eu-west-1"
```

Al terminar imprime `agent_space_id` y `agent_space_arn`.

## Después de crear el Space

1. Abrí el Space desde la consola de **DevOps Agent** con el botón **Operator access**.
2. Configurá el **filtro por tag** para acotar qué recursos descubre (por ejemplo `Application = unicorn_rentals`). La asociación se crea con `resources = []` (toda la cuenta); el filtrado fino se ajusta desde la consola del Space.

## Borrar

```bash
terraform destroy
```

## Alternativa: crear el Space desde la consola (sin Terraform)

Este Terraform es opcional. El mismo Agent Space se puede dar de alta a mano: consola de AWS → **DevOps Agent** → **Create Agent Space**. Ahí definís el nombre, elegís el idioma de respuesta del agente, dejás que auto-cree los roles IAM y confirmás.

## Qué se puede y qué no se puede automatizar

- **El Space**: por Terraform (este módulo) **o** por la consola. Las dos formas son válidas.
- **Idioma de respuesta del agente**: el recurso `awscc_devopsagent_agent_space` no expone la propiedad de idioma. Si lo querés en un idioma puntual (p. ej. Spanish - Latin America), configuralo en la consola después de crear el Space.
- **Slack NO se puede automatizar con Terraform.** Requiere OAuth interactivo (instalar la app de Slack y dar consentimiento en el navegador), igual que Datadog. Se conecta a mano desde el Space: **Capabilities → Communications → Slack → Add Slack**, ingresás el Channel ID y creás la asociación (a los canales privados hay que invitar al bot).
- **Integraciones que sí se pueden provisionar por Terraform** (vía `awscc_devopsagent_association` con un registro de servicio): Dynatrace, ServiceNow, Splunk, New Relic, GitLab y PagerDuty. De las que reciben hallazgos como Slack, **ServiceNow y PagerDuty** usan OAuth client credentials (sin navegador), así que esas sí van por código.
- **Webhook** (para disparar investigaciones automáticamente): se genera dentro del Space desde **Capabilities → Webhook → Configure → Generate webhook**, que devuelve la URL y un secreto HMAC. Ese paso es manual (el secreto se muestra una sola vez).

## Recursos que crea este módulo

- `aws_iam_role.agentspace` + política administrada `AIDevOpsAgentAccessPolicy` + inline para el service-linked role de Resource Explorer.
- `aws_iam_role.operator` + política administrada `AIDevOpsOperatorAppAccessPolicy`.
- `awscc_devopsagent_agent_space.main` — el Space con el Operator App.
- `awscc_devopsagent_association.primary` — asocia la cuenta actual en modo `monitor`.
