# sfikAI

## Environnement de travail

Tout le développement se fait dans le conteneur Docker de [`sim-env/`](sim-env/README.md) :
Ubuntu 22.04 · ROS 2 Humble · MAVROS · Gazebo Harmonic · ArduPilot SITL (CPU uniquement).

```bash
git clone https://github.com/myriaddao339-tech/sfikAI.git
cd sfikAI/sim-env
./sim.sh build      # une seule fois, ~30-50 min
./sim.sh gazebo     # terminal 1
./sim.sh sitl       # terminal 2
./sim.sh mavros     # terminal 3
```

Installation de Docker, commandes et dépannage : voir [`sim-env/README.md`](sim-env/README.md).
