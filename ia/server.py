import asyncio
import websockets
import json
import random

async def handler(websocket):
    print("✅ Cliente conectado")
    try:
        current_state = {
            "acceleration": 0,
            "steering": 0.0,
            "brake": False,
            "four_wheel_drive": True
        }

        while True:
            # Cada 2 segundos, genera nuevos valores aleatorios
            current_state["acceleration"] = random.choice([-1, 0, 1])  # retroceso, neutro o avance
            current_state["steering"] = random.uniform(-1.0, 1.0)      # gira de un lado a otro
            current_state["brake"] = random.choice([True, False])      # frena o no
            current_state["four_wheel_drive"] = random.choice([True, False])

            # Envía el mismo estado 20 veces (0.1s * 20 = 2s)
            for _ in range(20):
                await websocket.send(json.dumps(current_state))
                await asyncio.sleep(0.1)
    except websockets.ConnectionClosed:
        print("❌ Cliente desconectado")

async def main():
    async with websockets.serve(handler, "localhost", 8765):
        print("Servidor WebSocket iniciado en ws://localhost:8765")
        try:
            await asyncio.Future()  # Run forever
        except asyncio.CancelledError:
            print("🛑 Servidor detenido manualmente.")

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("🚪 Cerrando servidor...")
