"""Handler de Lambda que envuelve el servidor MCP de AWS Billing & Cost Management."""

import os
import sys

import boto3
from mcp.client.stdio import StdioServerParameters
from mcp_lambda import APIGatewayProxyEventHandler, StdioServerAdapterRequestHandler


def _get_server_params():
    """Arma los parámetros del servidor con credenciales frescas en cada invocación."""
    session = boto3.Session()
    credentials = session.get_credentials()
    if credentials is None:
        raise RuntimeError("No se pudieron obtener las credenciales de AWS del entorno de ejecución")
    resolved = credentials.get_frozen_credentials()

    # El servidor MCP de billing crea los directorios 'sessions/' y 'logs/' relativos
    # a la ruta donde está instalado su paquete. En Lambda, /var/task es de solo lectura.
    # Solución: creamos directorios escribibles en /tmp y usamos un script envoltorio
    # que parchea las rutas antes de importar el servidor.
    os.makedirs("/tmp/sessions", exist_ok=True)
    os.makedirs("/tmp/logs", exist_ok=True)

    # Envoltorio de Python que parchea las rutas del filesystem ANTES de importar el
    # servidor. El servidor MCP de billing crea 'sessions/' y 'logs/' relativos a la
    # ruta de su paquete durante el import del módulo. Interceptamos os.makedirs para
    # redirigir cualquier escritura en /var/task hacia /tmp.
    #
    # Nota: el codigo de este envoltorio se mantiene en ASCII a proposito, porque se
    # ejecuta con `python -c` y no queremos depender del encoding del entorno.
    wrapper_code = """
import os, sys

# Intercepta os.makedirs para redirigir las rutas /var/task a /tmp
_original_makedirs = os.makedirs
def _patched_makedirs(name, *args, **kwargs):
    if '/var/task' in str(name) and ('/sessions' in str(name) or '/logs' in str(name)):
        name = str(name).replace('/var/task/awslabs', '/tmp')
    return _original_makedirs(name, *args, **kwargs)
os.makedirs = _patched_makedirs

# Tambien parchea os.mkdir, para la creacion de directorios por esa via
_original_mkdir = os.mkdir
def _patched_mkdir(name, *args, **kwargs):
    if '/var/task' in str(name) and ('/sessions' in str(name) or '/logs' in str(name)):
        name = str(name).replace('/var/task/awslabs', '/tmp')
    return _original_mkdir(name, *args, **kwargs)
os.mkdir = _patched_mkdir

# Parchea Path.mkdir, para el uso de pathlib
from pathlib import Path
_original_path_mkdir = Path.mkdir
def _patched_path_mkdir(self, *args, **kwargs):
    s = str(self)
    if '/var/task' in s and ('/sessions' in s or '/logs' in s):
        new_path = Path(s.replace('/var/task/awslabs', '/tmp'))
        return _original_path_mkdir(new_path, *args, **kwargs)
    return _original_path_mkdir(self, *args, **kwargs)
Path.mkdir = _patched_path_mkdir

# Asegura que existan los directorios en /tmp
os.makedirs('/tmp/sessions', exist_ok=True)
os.makedirs('/tmp/logs', exist_ok=True)

# Parchea open() para redirigir las escrituras bajo /var/task/awslabs/(sessions|logs)
import builtins
_original_open = builtins.open
def _patched_open(file, *args, **kwargs):
    s = str(file)
    if '/var/task' in s and ('/sessions' in s or '/logs' in s):
        file = s.replace('/var/task/awslabs', '/tmp')
    return _original_open(file, *args, **kwargs)
builtins.open = _patched_open

# Ahora si, importa y arranca el servidor
from awslabs.billing_cost_management_mcp_server.server import main
main()
"""

    return StdioServerParameters(
        command=sys.executable,
        args=["-c", wrapper_code],
        env={
            "AWS_REGION": os.environ.get("AWS_REGION_NAME", "us-east-1"),
            "AWS_DEFAULT_REGION": os.environ.get("AWS_REGION_NAME", "us-east-1"),
            "AWS_ACCESS_KEY_ID": resolved.access_key,
            "AWS_SECRET_ACCESS_KEY": resolved.secret_key,
            "AWS_SESSION_TOKEN": resolved.token or "",
            "FASTMCP_LOG_LEVEL": "ERROR",
            "FASTMCP_LOG_FILE": "/tmp/logs/billing-mcp-server.log",
        },
    )


def handler(event, context):
    """Punto de entrada del Lambda — refresca las credenciales en cada invocación."""
    server_params = _get_server_params()
    request_handler = StdioServerAdapterRequestHandler(server_params)
    event_handler = APIGatewayProxyEventHandler(request_handler)
    return event_handler.handle(event, context)
