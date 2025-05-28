import asyncio
import websockets
import json

# Guarda el último estado de controles
control_state = {
    "up": False,
    "down": False,
    "left": False,
    "right": False,
    "brake": False,
    "shift": False
}

async def handler(websocket):
    print("Cliente conectado.")
    try:
        async for message in websocket:
            try:
                data = json.loads(message)
                for key in control_state:
                    if key in data:
                        control_state[key] = data[key]
                print("Estado de control:", control_state)
            except json.JSONDecodeError:
                print("Mensaje no es JSON:", message)
    except websockets.exceptions.ConnectionClosed:
        print("Cliente desconectado.")

async def main():
    async with websockets.serve(handler, "localhost", 8765):
        print("Servidor WebSocket escuchando en ws://localhost:8765")
        await asyncio.Future()  # Ejecuta indefinidamente

if __name__ == "__main__":
    asyncio.run(main())
