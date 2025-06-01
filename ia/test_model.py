import numpy as np
from keras.models import load_model
import websockets
import asyncio
import json

class TractorTester:
    def __init__(self, model_path='tractor_model_final.h5'):
        """Inicializa el tester con el modelo entrenado"""
        try:
            self.model = load_model(model_path)
            print(f"✅ Modelo cargado exitosamente: {model_path}")
        except Exception as e:
            print(f"❌ Error cargando modelo: {e}")
            print("🤖 Usando comportamiento por defecto")
            self.model = None
        
        # Variables para giros consecutivos
        self.current_steering = 0.0
        self.steering_duration = 0
        self.max_steering_duration = 30  # Pasos que mantiene el giro
        self.min_steering_duration = 15  # Mínimo de pasos para cambiar

    def get_consecutive_steering(self):
        """Genera giros consecutivos manteniendo dirección por varios pasos"""
        # Si no hay giro activo o se acabó la duración, generar nuevo giro
        if self.steering_duration <= 0:
            self.current_steering = np.random.choice([-0.8, -0.6, 0.6, 0.8])  # Giros fuertes fijos
            self.steering_duration = np.random.randint(self.min_steering_duration, self.max_steering_duration)
        
        # Decrementar duración y mantener el giro
        self.steering_duration -= 1
        return self.current_steering

    def predict_action(self, obs):
        """Predice acción usando el modelo o comportamiento por defecto"""
        if self.model is None:
            # Comportamiento por defecto: avanzar y girar fuerte consecutivo
            acceleration = 0.7
            steering = self.get_consecutive_steering()
            brake = 0.0
            return [acceleration, steering, brake]
        
        try:
            obs = np.array(obs).reshape(1, -1)
            action = self.model.predict(obs, verbose=0)[0]
            
            # Asegurar rangos correctos
            acceleration = np.clip(action[0], 0, 1)
            steering = np.clip(action[1], -1, 1)
            brake = np.clip(action[2], 0, 0.2)
            
            # Si el modelo predice acelerar muy poco, usar comportamiento por defecto
            if acceleration < 0.3:
                acceleration = 0.7
                steering = self.get_consecutive_steering() if abs(steering) < 0.1 else steering
                brake = 0.0
            
            return [acceleration, steering, brake]
            
        except Exception as e:
            print(f"⚠️ Error en predicción: {e}")
            # Fallback a comportamiento por defecto
            return [0.7, np.random.uniform(-0.8, 0.8), 0.0]

async def test_model(model_path='tractor_model_final.h5'):
    """Función principal para testear el modelo"""
    tester = TractorTester(model_path)
    
    # Configuración de conexión
    ws_config = {
        'ping_interval': None,
        'close_timeout': 1,
        'max_size': 2**20
    }
    
    episode = 1
    total_reward = 0
    steps = 0
    
    print(f"🚜 Iniciando prueba del modelo: {model_path}")
    print("=" * 50)
    
    try:
        async with websockets.connect('ws://localhost:8765', **ws_config) as ws:
            print("✅ Conexión establecida con Godot")
            
            while True:
                try:
                    # Recibir estado
                    state_data = await ws.recv()
                    state = json.loads(state_data)
                    obs = state['observation']
                    
                    # Si es el inicio de un nuevo episodio
                    if state.get('done', False) and steps > 0:
                        print(f"\n🏁 Episodio {episode} completado:")
                        print(f"   └─ Recompensa total: {total_reward:.1f}")
                        print(f"   └─ Pasos: {steps}")
                        if 'info' in state and 'progress' in state['info']:
                            print(f"   └─ Progreso: {state['info']['progress']:.1f}%")
                        
                        # Reiniciar contadores
                        episode += 1
                        total_reward = 0
                        steps = 0
                        print(f"\n🎮 Iniciando episodio {episode}")
                    
                    # Predecir acción
                    action = tester.predict_action(obs)
                    
                    # Enviar acción
                    await ws.send(json.dumps({
                        "acceleration": float(action[0]),
                        "steering": float(action[1]),
                        "brake": float(action[2]),
                        "four_wheel_drive": False,
                        "reset_episode": state.get('done', False)
                    }))
                    
                    # Actualizar métricas
                    if 'reward' in state:
                        total_reward += state['reward']
                    steps += 1
                    
                    # Mostrar progreso cada 100 pasos
                    if steps % 100 == 0:
                        current_progress = state.get('info', {}).get('progress', 0)
                        print(f"⏩ Paso {steps} | Recompensa: {total_reward:.1f} | Progreso: {current_progress:.1f}%")
                
                except websockets.exceptions.ConnectionClosed:
                    print("🔌 Conexión cerrada por el servidor")
                    break
                except json.JSONDecodeError as e:
                    print(f"⚠️ Error decodificando JSON: {e}")
                    continue
                except Exception as e:
                    print(f"⚠️ Error en el bucle principal: {e}")
                    continue
                    
    except Exception as e:
        print(f"❌ Error de conexión: {e}")
        return False
    
    return True

if __name__ == "__main__":
    import sys
    
    # Usar argumento de línea de comandos o valor por defecto
    model_path = sys.argv[1] if len(sys.argv) > 1 else 'tractor_model_final.h5'
    
    print(f"🔧 Modelo a probar: {model_path}")
    
    try:
        asyncio.run(test_model(model_path))
    except KeyboardInterrupt:
        print("\n🛑 Prueba detenida manualmente")
    except Exception as e:
        print(f"\n❌ Error crítico: {e}")