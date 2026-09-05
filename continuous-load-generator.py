#!/usr/bin/env python3
"""
Generador de carga continua para la demo de AWS DevOps Agent

Este script genera carga continua de fondo para mantener patrones de error
realistas que DevOps Agent pueda analizar.
"""

import requests
import json
import time
import random
import threading
import argparse
import signal
import sys
import os
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor
from queue import Queue

class ContinuousLoadGenerator:
    def __init__(self, api_url, base_rps=5, max_workers=10, baseline=False):
        self.api_url = api_url
        self.base_rps = base_rps  # Pedidos por segundo de base
        self.max_workers = max_workers
        self.baseline = baseline  # Modo baseline: ritmo constante, sin picos
        self.running = True
        self.stats = {
            'total_requests': 0,
            'successful_requests': 0,
            'failed_requests': 0,
            'timeout_requests': 0,
            'start_time': time.time()
        }
        self.request_queue = Queue()

        # Tipos de unicornio, para que los datos parezcan reales
        self.unicorn_types = [
            'rainbow', 'sparkle', 'golden', 'silver', 'crystal',
            'fire', 'ice', 'storm', 'forest', 'celestial'
        ]

        # Nombres de clientes, para que los datos parezcan reales
        self.customer_names = [
            'Alice', 'Bob', 'Carol', 'David',
            'Emma', 'Frank', 'Grace', 'Henry',
            'Ivy', 'Jack', 'Kate', 'Leo'
        ]

    def generate_realistic_request(self):
        """Genera datos realistas de un pedido de alquiler"""
        payload = {
            'id': f'rental-{int(time.time())}-{random.randint(1000, 9999)}',
            'unicorn_type': random.choice(self.unicorn_types),
            'customer_name': random.choice(self.customer_names),
            'rental_duration': random.randint(1, 8),  # horas
            'location': random.choice(['Central Park', 'Golden Gate Park', 'Hyde Park', 'Millennium Park']),
            'data': f'Rental request at {datetime.now().isoformat()}'
        }
        # En modo baseline, mantener los payloads mínimos para no activar
        # los caminos de escritura por lote que provocan throttling
        if self.baseline:
            payload['rental_duration'] = 1
        return payload

    def make_request(self):
        """Hace un pedido individual a la API"""
        if not self.running:
            return

        payload = self.generate_realistic_request()
        request_id = payload['id']

        try:
            start_time = time.time()
            response = requests.post(
                self.api_url,
                json=payload,
                timeout=35,  # Un poco más que el timeout del Lambda
                headers={'Content-Type': 'application/json'}
            )
            duration = time.time() - start_time

            self.stats['total_requests'] += 1

            if response.status_code == 200:
                self.stats['successful_requests'] += 1
                if random.random() < 0.1:  # Loguea el 10% de los pedidos exitosos
                    print(f"✓ {request_id}: Success ({duration:.2f}s)")
            else:
                self.stats['failed_requests'] += 1
                print(f"✗ {request_id}: Error {response.status_code} ({duration:.2f}s)")

        except requests.exceptions.Timeout:
            self.stats['timeout_requests'] += 1
            self.stats['total_requests'] += 1
            print(f"⏰ {request_id}: Timeout (30s+)")
        except Exception as e:
            self.stats['failed_requests'] += 1
            self.stats['total_requests'] += 1
            if random.random() < 0.2:  # Loguea el 20% de las excepciones
                print(f"✗ {request_id}: Exception - {str(e)}")

    def traffic_pattern(self):
        """Genera patrones de tráfico realistas a lo largo del día"""
        # Modo baseline: tráfico plano y constante, sin picos ni caídas
        if self.baseline:
            return 1.0

        current_hour = datetime.now().hour

        # Patrón de horario laboral (más tráfico de 9 a 18)
        if 9 <= current_hour <= 18:
            base_multiplier = 2.0
        elif 19 <= current_hour <= 22:  # Pico de la tarde
            base_multiplier = 1.5
        else:  # Noche/madrugada
            base_multiplier = 0.5

        # Algo de azar para picos realistas
        spike_chance = random.random()
        if spike_chance < 0.05:  # 5% de probabilidad de pico de tráfico
            multiplier = base_multiplier * random.uniform(3, 5)
            print(f"🚀 ¡Pico de tráfico detectado! Multiplicador: {multiplier:.1f}x")
        elif spike_chance < 0.1:  # 5% de probabilidad de caída de tráfico
            multiplier = base_multiplier * 0.3
            print(f"📉 Caída de tráfico detectada. Multiplicador: {multiplier:.1f}x")
        else:
            multiplier = base_multiplier * random.uniform(0.8, 1.2)

        return max(0.1, multiplier)  # Multiplicador mínimo de 0.1x

    def worker_thread(self):
        """Hilo trabajador que procesa los pedidos"""
        with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            while self.running:
                try:
                    # Calcula los RPS actuales según el patrón de tráfico
                    current_multiplier = self.traffic_pattern()
                    current_rps = self.base_rps * current_multiplier

                    # Envía pedidos según los RPS actuales
                    requests_this_second = max(1, int(current_rps))
                    delay_between_requests = 1.0 / requests_this_second

                    for _ in range(requests_this_second):
                        if not self.running:
                            break
                        executor.submit(self.make_request)
                        time.sleep(delay_between_requests)

                    # Duerme lo que queda del segundo
                    time.sleep(max(0, 1.0 - (requests_this_second * delay_between_requests)))

                except Exception as e:
                    print(f"Error en el hilo trabajador: {e}")
                    time.sleep(1)

    def stats_reporter(self):
        """Reporta estadísticas cada tanto"""
        while self.running:
            time.sleep(60)  # Reporta cada minuto
            if self.stats['total_requests'] > 0:
                runtime = time.time() - self.stats['start_time']
                success_rate = (self.stats['successful_requests'] / self.stats['total_requests']) * 100
                avg_rps = self.stats['total_requests'] / runtime

                print(f"\n📊 Estadísticas (tiempo corriendo: {runtime/60:.1f}m):")
                print(f"   Pedidos totales: {self.stats['total_requests']}")
                print(f"   Tasa de éxito: {success_rate:.1f}%")
                print(f"   Fallidos: {self.stats['failed_requests']}")
                print(f"   Timeouts: {self.stats['timeout_requests']}")
                print(f"   RPS promedio: {avg_rps:.2f}")
                print("-" * 40)

    def start(self):
        """Arranca el generador de carga continua"""
        mode = "BASELINE (constante, solo tráfico exitoso)" if self.baseline else "NORMAL (patrones realistas con picos)"
        print(f"🎯 Arrancando el generador de carga continua")
        print(f"🔗 API URL: {self.api_url}")
        print(f"📈 RPS de base: {self.base_rps}")
        print(f"🔧 Modo: {mode}")
        print(f"👥 Workers máximos: {self.max_workers}")
        print("=" * 60)
        print("Ctrl+C para detener")
        print("")

        # Arranca el hilo trabajador
        worker = threading.Thread(target=self.worker_thread, daemon=True)
        worker.start()

        # Arranca el hilo que reporta estadísticas
        stats_thread = threading.Thread(target=self.stats_reporter, daemon=True)
        stats_thread.start()

        try:
            # Mantiene vivo el hilo principal
            while self.running:
                time.sleep(1)
        except KeyboardInterrupt:
            print("\n🛑 Deteniendo el generador de carga...")
            self.running = False

        # Estadísticas finales
        runtime = time.time() - self.stats['start_time']
        print(f"\n📊 Estadísticas finales:")
        print(f"   Tiempo corriendo: {runtime/60:.1f} minutos")
        print(f"   Pedidos totales: {self.stats['total_requests']}")
        print(f"   Tasa de éxito: {(self.stats['successful_requests']/max(1,self.stats['total_requests']))*100:.1f}%")
        print(f"   RPS promedio: {self.stats['total_requests']/runtime:.2f}")

def signal_handler(sig, frame):
    """Maneja Ctrl+C de forma ordenada"""
    print('\n🛑 Señal de interrupción recibida. Deteniendo...')
    sys.exit(0)

def main():
    # Carga sola el archivo de entorno si API_URL no está definida
    if not os.environ.get('API_URL') and os.path.exists('demo-environment.env'):
        import subprocess
        result = subprocess.run(
            ['bash', '-c', 'source demo-environment.env && env'],
            capture_output=True, text=True
        )
        for line in result.stdout.splitlines():
            if '=' in line:
                key, _, value = line.partition('=')
                if key in ('API_URL', 'LAMBDA_NAME', 'TABLE_NAME', 'STACK_NAME'):
                    os.environ[key] = value

    parser = argparse.ArgumentParser(description='Generador de carga continua para la demo de AWS DevOps Agent')
    parser.add_argument('--api-url', default=os.environ.get('API_URL'), help='URL del API Gateway (por defecto toma $API_URL de demo-environment.env)')
    parser.add_argument('--rps', type=float, default=5.0, help='Pedidos por segundo de base (por defecto: 5)')
    parser.add_argument('--workers', type=int, default=10, help='Cantidad máxima de workers concurrentes (por defecto: 10)')
    parser.add_argument('--duration', type=int, help='Correr durante la cantidad de minutos indicada (por defecto: indefinidamente)')
    parser.add_argument('--baseline', action='store_true', help='Modo baseline: ritmo constante, sin picos — genera tráfico exitoso y limpio')

    args = parser.parse_args()

    if not args.api_url:
        parser.error('--api-url es obligatorio (o definí la variable de entorno API_URL / desplegá con deploy.sh primero)')

    # Configura el manejador de señales para un apagado ordenado
    signal.signal(signal.SIGINT, signal_handler)

    generator = ContinuousLoadGenerator(
        api_url=args.api_url,
        base_rps=args.rps,
        max_workers=args.workers,
        baseline=args.baseline
    )

    if args.duration:
        print(f"⏱️  Va a correr durante {args.duration} minutos")
        # Arranca el generador en un hilo aparte
        import threading
        gen_thread = threading.Thread(target=generator.start)
        gen_thread.daemon = True
        gen_thread.start()

        # Espera la duración indicada
        time.sleep(args.duration * 60)
        generator.running = False
        print(f"\n⏰ Se completaron los {args.duration} minutos. Deteniendo...")
    else:
        generator.start()

if __name__ == '__main__':
    main()
