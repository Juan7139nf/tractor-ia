import websockets
import asyncio
import json
import numpy as np
from keras.models import Sequential
from keras.layers import Dense
from collections import deque
import random
import time
import matplotlib.pyplot as plt

class TractorAgent:
    def __init__(self):
        self.model = self._build_model()
        self.memory = deque(maxlen=2000)
        self.gamma = 0.95    # Factor de descuento
        self.epsilon = 1.0   # Exploración inicial
        self.epsilon_min = 0.01
        self.epsilon_decay = 0.995
        self.batch_size = 32
        self.train_interval = 4
        
        # Métricas para gráficas
        self.episode_rewards = []
        self.episode_lengths = []
        self.epsilon_history = []
        self.progress_history = []

    def _build_model(self):
        """Crea el modelo de la red neuronal"""
        model = Sequential([
            Dense(24, input_dim=7, activation='relu'),  # 7 inputs del estado
            Dense(24, activation='relu'),
            Dense(3, activation='linear')  # [aceleración, dirección, freno]
        ])
        model.compile(loss='mse', optimizer='adam')
        return model

    def remember(self, state, action, reward, next_state, done):
        """Almacena experiencias en memoria"""
        self.memory.append((state, action, reward, next_state, done))

    def act(self, state):
        """Selecciona acción: exploración o explotación con comportamiento por defecto"""
        if np.random.rand() <= self.epsilon:
            # Comportamiento exploratorio con prioridad en avanzar y girar
            acceleration = random.uniform(0.5, 1.0)    # Priorizar acelerar
            steering = random.uniform(-0.8, 0.8)       # Giros moderados
            brake = random.uniform(0, 0.1)             # Freno mínimo
            return (acceleration, steering, brake)
        
        state = np.array(state).reshape(1, -1)
        act_values = self.model.predict(state, verbose=0)
        
        # Si el modelo no está entrenado o da valores muy bajos, usar comportamiento por defecto
        if np.all(np.abs(act_values[0]) < 0.1):
            # Comportamiento por defecto: avanzar y girar suavemente
            acceleration = 0.7  # Acelerar moderadamente
            steering = random.uniform(-0.3, 0.3)  # Giro suave aleatorio
            brake = 0.0  # No frenar
            return (acceleration, steering, brake)
        
        # Asegurar que los valores estén en los rangos correctos
        acceleration = np.clip(act_values[0][0], 0, 1)
        steering = np.clip(act_values[0][1], -1, 1)
        brake = np.clip(act_values[0][2], 0, 0.2)
        
        # Priorizar aceleración si es muy baja
        if acceleration < 0.3:
            acceleration = 0.5
        
        return (acceleration, steering, brake)

    def replay(self):
        """Entrena con experiencias pasadas"""
        if len(self.memory) < self.batch_size:
            return

        minibatch = random.sample(self.memory, self.batch_size)
        states = np.array([x[0] for x in minibatch])
        targets = self.model.predict(states, verbose=0)

        for i, (state, action, reward, next_state, done) in enumerate(minibatch):
            target = reward
            if not done:
                next_state = np.array(next_state).reshape(1, -1)
                Q_future = np.max(self.model.predict(next_state, verbose=0)[0])
                target = reward + Q_future * self.gamma
            
            # Actualizar solo la acción tomada
            targets[i] = action  # Usar la acción completa como target
            targets[i] = np.array([target, target, target])  # Simplificado para este caso

        self.model.fit(states, targets, epochs=1, verbose=0)

    def save_training_plots(self):
        """Genera y guarda gráficas del entrenamiento"""
        fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(15, 10))
        
        # Gráfica 1: Recompensas por episodio
        ax1.plot(self.episode_rewards, 'b-', alpha=0.7)
        ax1.set_title('Recompensas por Episodio')
        ax1.set_xlabel('Episodio')
        ax1.set_ylabel('Recompensa Total')
        ax1.grid(True, alpha=0.3)
        
        # Promedio móvil de recompensas
        if len(self.episode_rewards) > 10:
            window = min(20, len(self.episode_rewards))
            moving_avg = np.convolve(self.episode_rewards, np.ones(window)/window, mode='valid')
            ax1.plot(range(window-1, len(self.episode_rewards)), moving_avg, 'r-', linewidth=2, label='Promedio Móvil')
            ax1.legend()
        
        # Gráfica 2: Epsilon (exploración) vs tiempo
        ax2.plot(self.epsilon_history, 'g-')
        ax2.set_title('Decaimiento de Epsilon (Exploración)')
        ax2.set_xlabel('Episodio')
        ax2.set_ylabel('Epsilon')
        ax2.grid(True, alpha=0.3)
        
        # Gráfica 3: Duración de episodios
        ax3.plot(self.episode_lengths, 'purple', alpha=0.7)
        ax3.set_title('Duración de Episodios')
        ax3.set_xlabel('Episodio')
        ax3.set_ylabel('Pasos')
        ax3.grid(True, alpha=0.3)
        
        # Gráfica 4: Progreso máximo por episodio
        ax4.plot(self.progress_history, 'orange')
        ax4.set_title('Progreso Máximo por Episodio (%)')
        ax4.set_xlabel('Episodio')
        ax4.set_ylabel('Progreso (%)')
        ax4.grid(True, alpha=0.3)
        
        plt.tight_layout()
        plt.savefig('training_progress.png', dpi=300, bbox_inches='tight')
        print(f"📊 Gráficas guardadas como 'training_progress.png'")

async def train_agent(max_episodes=10):
    agent = TractorAgent()
    episode = 0
    
    # Configuración de conexión
    ws_config = {
        'ping_interval': None,
        'close_timeout': 1,
        'max_size': 2**20  # 1MB para mensajes grandes
    }

    print(f"🚜 Iniciando entrenamiento del agente tractor (máximo {max_episodes} episodios)")
    print("=" * 60)

    while episode < max_episodes:
        try:
            print(f"\n🎮 Episodio {episode + 1}/{max_episodes} | ε={agent.epsilon:.3f}")
            async with websockets.connect('ws://localhost:8765', **ws_config) as ws:
                print("✅ Conexión establecida con Godot")
                
                # Paso 1: Recibir estado inicial
                state_data = await ws.recv()
                state = json.loads(state_data)
                obs = state['observation']
                total_reward = 0
                max_progress = 0
                steps = 0
                
                MAX_STEPS_PER_EPISODE = 500

                while not state['done'] and steps < MAX_STEPS_PER_EPISODE:
                    # Paso 2: Seleccionar acción
                    acceleration, steering, brake = agent.act(obs)
                    action = {
                        "acceleration": float(acceleration),
                        "steering": float(steering),
                        "brake": float(brake),
                        "four_wheel_drive": False,
                        "reset_episode": False
                    }
                    
                    # Paso 3: Enviar acción
                    await ws.send(json.dumps(action))
                    
                    # Paso 4: Recibir nuevo estado
                    next_state_data = await ws.recv()
                    next_state = json.loads(next_state_data)
                    next_obs = next_state['observation']
                    
                    # Paso 5: Almacenar experiencia
                    reward = next_state['reward']
                    done = next_state['done']
                    agent.remember(obs, [acceleration, steering, brake], reward, next_obs, done)
                    
                    # Paso 6: Entrenar
                    if len(agent.memory) > agent.batch_size and steps % agent.train_interval == 0:
                        agent.replay()
                    
                    # Actualizar métricas
                    state = next_state
                    obs = next_obs
                    total_reward += reward
                    steps += 1
                    
                    # Rastrear progreso máximo
                    if 'info' in state and 'progress' in state['info']:
                        max_progress = max(max_progress, state['info']['progress'])
                    
                    # Mostrar progreso cada 100 pasos
                    if steps % 100 == 0:
                        current_progress = state.get('info', {}).get('progress', 0)
                        print(f"⏩ Paso {steps} | Recompensa: {total_reward:.1f} | Progreso: {current_progress:.1f}%")
                
                # Fin del episodio - guardar métricas
                episode += 1
                agent.episode_rewards.append(total_reward)
                agent.episode_lengths.append(steps)
                agent.epsilon_history.append(agent.epsilon)
                agent.progress_history.append(max_progress)
                
                # Actualizar epsilon
                agent.epsilon = max(agent.epsilon_min, agent.epsilon * agent.epsilon_decay)
                
                # Mostrar resumen del episodio
                print(f"🏁 Episodio {episode} completado:")
                print(f"   └─ Recompensa total: {total_reward:.1f}")
                print(f"   └─ Pasos: {steps}")
                print(f"   └─ Progreso máximo: {max_progress:.1f}%")
                print(f"   └─ Epsilon actual: {agent.epsilon:.3f}")
                
                # Mostrar estadísticas cada 10 episodios
                if episode % 10 == 0:
                    avg_reward = np.mean(agent.episode_rewards[-10:])
                    avg_progress = np.mean(agent.progress_history[-10:])
                    print(f"\n📊 Estadísticas últimos 10 episodios:")
                    print(f"   └─ Recompensa promedio: {avg_reward:.1f}")
                    print(f"   └─ Progreso promedio: {avg_progress:.1f}%")
                
        except websockets.exceptions.ConnectionClosed as e:
            print(f"🔌 Conexión cerrada: {e.code} - {e.reason}")
            print("⌛ Esperando 3 segundos antes de reconectar...")
            await asyncio.sleep(3)
            continue
            
        except Exception as e:
            print(f"⚠️ Error en episodio {episode + 1}: {type(e).__name__}: {str(e)}")
            print("⌛ Esperando 3 segundos antes de continuar...")
            await asyncio.sleep(3)
            continue

    # Entrenamiento completado
    print("\n" + "=" * 60)
    print("🎉 ENTRENAMIENTO COMPLETADO")
    print("=" * 60)
    
    # Guardar modelo final
    model_filename = 'tractor_model_final.h5'
    agent.model.save(model_filename)
    print(f"💾 Modelo final guardado como: {model_filename}")
    
    # Mostrar estadísticas finales
    if agent.episode_rewards:
        best_reward = max(agent.episode_rewards)
        best_episode = agent.episode_rewards.index(best_reward) + 1
        avg_reward = np.mean(agent.episode_rewards)
        final_progress = max(agent.progress_history) if agent.progress_history else 0
        
        print(f"\n📈 ESTADÍSTICAS FINALES:")
        print(f"   ├─ Total de episodios: {len(agent.episode_rewards)}")
        print(f"   ├─ Mejor recompensa: {best_reward:.1f} (Episodio {best_episode})")
        print(f"   ├─ Recompensa promedio: {avg_reward:.1f}")
        print(f"   ├─ Mejor progreso: {final_progress:.1f}%")
        print(f"   └─ Epsilon final: {agent.epsilon:.3f}")
    
    # Generar gráficas
    print("\n📊 Generando gráficas de entrenamiento...")
    agent.save_training_plots()
    
    print("\n✅ Proceso de entrenamiento finalizado exitosamente!")
    return agent

if __name__ == "__main__":
    try:
        # Cambiar max_episodes según necesites
        agent = asyncio.run(train_agent(max_episodes=50))
    except KeyboardInterrupt:
        print("\n🛑 Entrenamiento detenido manualmente")
        print("💾 Los datos recopilados hasta ahora se mantendrán...")
    except Exception as e:
        print(f"\n❌ Error crítico en el entrenamiento: {type(e).__name__}: {str(e)}")