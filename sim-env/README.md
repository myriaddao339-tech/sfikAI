# sim-env : environnement de simulation drone (Docker)

Une image Docker prête à l'emploi pour simuler un drone ArduPilot :

| Brique | Version |
|---|---|
| OS | Ubuntu 22.04 (image `osrf/ros:humble-desktop`) |
| ROS 2 | Humble + **MAVROS** (+ `cv_bridge`, `image_transport`) |
| Gazebo | **Harmonic** (gz-sim 8) + bindings Python `gz.transport13` / `gz.msgs10` |
| ArduPilot | **SITL Copter**, commit épinglé `9bbfed9c91` |
| Plugin | `ardupilot_gazebo`, commit épinglé `082a0fe` |
| Outils | MAVProxy, OpenCV, NumPy, GStreamer |

**Aucun GPU requis** : le rendu passe par le processeur (Mesa llvmpipe).
Le dossier est **autonome** : tu peux le copier n'importe où, aucun chemin n'est codé en dur.

---

## 1. Installer Docker (une seule fois)

### Sous Linux (Ubuntu)

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

Ferme ta session puis rouvre-la (ou lance `newgrp docker`), puis vérifie avec :

```bash
docker run --rm hello-world
```

### Sous Windows (WSL 2)

1. Dans un PowerShell **administrateur** :
   ```powershell
   wsl --install -d Ubuntu-22.04
   ```
2. Redémarre, ouvre **Ubuntu**, puis suis la partie *Linux* ci-dessus dans ce terminal.
3. Si `docker` répond *Cannot connect to the Docker daemon*, lance `sudo service docker start`.

Toutes les commandes suivantes se tapent **dans le terminal Ubuntu**, jamais dans PowerShell.
Les fenêtres Gazebo s'affichent directement sous Windows 11 (WSLg).

---

## 2. Construire l'image (une seule fois)

```bash
cd sim-env
./sim.sh build
```

Compte **30 à 50 minutes** : SITL et le plugin sont compilés. Il faut internet et environ 20 Go libres.
Le résultat est l'image `sim-env:1` (7 Go).

Prévois au moins **8 Go de RAM** : une simulation complète (Gazebo avec fenêtre, SITL et MAVROS) en utilise environ 1,5 Go.

---

## 3. Lancer une simulation

Ouvre **3 terminaux**, tous dans le dossier `sim-env/` :

| Terminal | Commande | Rôle |
|---|---|---|
| 1 | `./sim.sh gazebo` | Gazebo, avec le monde de démo `iris_runway.sdf` |
| 2 | `./sim.sh sitl` | ArduPilot SITL, avec la console MAVProxy |
| 3 | `./sim.sh mavros` | MAVROS, qui expose le drone dans ROS 2 |

Le conteneur démarre tout seul à la première commande.
Dès que SITL affiche `EKF3 IMU0 is using GPS` (ou `IMU1`), après environ 30 s, tu peux tester dans le terminal 2 :

```
mode guided
arm throttle
takeoff 5
```

Le drone décolle dans Gazebo. Pour tout arrêter : `Ctrl-C` dans chaque terminal, puis `./sim.sh stop`.

---

## 4. Toutes les commandes

| Commande | Effet |
|---|---|
| `./sim.sh build` | Construit l'image |
| `./sim.sh start` | Démarre le conteneur en arrière-plan |
| `./sim.sh shell` | Ouvre un terminal dans le conteneur (ROS 2 déjà sourcé) |
| `./sim.sh gazebo [monde.sdf]` | Lance Gazebo (monde par défaut : `iris_runway.sdf`) |
| `./sim.sh sitl [options]` | Lance SITL ; les options vont à `sim_vehicle.py` (`-w` réinitialise les paramètres) |
| `./sim.sh mavros` | Lance MAVROS sur `udp://:14555@` (topics `/mavros/...`) |
| `./sim.sh exec <commande>` | Exécute une commande dans le conteneur, par ex. `./sim.sh exec ros2 topic list` |
| `./sim.sh status` | Indique si le conteneur tourne |
| `./sim.sh stop` | Arrête le conteneur |

Options, à placer **devant** la commande :

| Variable | Exemple | Effet |
|---|---|---|
| `SIM_WS` | `SIM_WS=~/mon_projet ./sim.sh start` | Dossier monté dans `/workspace` (défaut : `sim-env/workspace`) |
| `HEADLESS` | `HEADLESS=1 ./sim.sh gazebo` | Gazebo sans fenêtre (plus léger) |
| `GCS_IP` | `GCS_IP=192.168.1.20 ./sim.sh sitl` | Envoie aussi MAVLink vers une station sol sur `<ip>:14550` |
| `SITL_LOCATION` | `SITL_LOCATION=48.85,2.35,35,0 ./sim.sh sitl` | Point de départ `lat,lon,alt,cap` (défaut : CMAC, Australie) |

⚠️ `SIM_WS` n'est lu qu'au **démarrage** du conteneur. Pour changer de dossier : `./sim.sh stop`, puis relance avec la nouvelle valeur.

---

## 5. Travailler sur ton projet

Le dossier `workspace/` (ou celui donné par `SIM_WS`) est partagé avec le conteneur sous `/workspace`.
Les fichiers sont modifiables depuis ton éditeur habituel et visibles immédiatement dans le conteneur.

```
workspace/
├── src/      # paquets ROS 2 (workspace colcon)
├── worlds/   # mondes Gazebo .sdf -> ./sim.sh gazebo mon_monde.sdf
└── models/   # modèles Gazebo, trouvés automatiquement (model://...)
```

Compiler les paquets ROS 2 :

```bash
./sim.sh shell
cd /workspace && colcon build --symlink-install
```

Une fois compilé, le workspace est sourcé automatiquement dans chaque nouveau terminal du conteneur.

Mondes fournis par `ardupilot_gazebo` : `iris_runway.sdf`, `iris_warehouse.sdf`, `gimbal.sdf`, `zephyr_runway.sdf`, etc.
Un monde à toi doit contenir un modèle muni du plugin `ArduPilotPlugin` (par ex. `model://iris_with_ardupilot`) pour que SITL s'y connecte.

---

## 6. Station sol (Mission Planner / QGroundControl)

SITL envoie MAVLink sur deux ports UDP :
- **14550** pour une station sol locale ;
- **14555** pour MAVROS.

- **Station sol sur la même machine Linux** : connecte-la en UDP sur le port 14550, sans rien d'autre.
- **Mission Planner sous Windows, SITL dans WSL** : donne l'adresse de Windows vue depuis WSL.
  ```bash
  GCS_IP=$(ip route show default | awk '{print $3}') ./sim.sh sitl
  ```
  Dans Mission Planner, choisis **UDP**, port **14550**, puis **Connect**. Si rien n'arrive, autorise Mission Planner dans le pare-feu Windows (réseaux privés et publics).
- **Station sol sur un autre PC du réseau** : `GCS_IP=<ip_du_pc> ./sim.sh sitl`.

---

## 7. Copier l'image sur un autre PC (sans internet)

```bash
docker save sim-env:1 | gzip > sim-env.tar.gz     # sur le PC qui a construit l'image
docker load < sim-env.tar.gz                      # sur l'autre PC
```

Copie aussi le dossier `sim-env/` : `sim.sh` est indispensable, l'image seule ne suffit pas.
Les deux PC doivent être en **x86_64**.

---

## 8. Dépannage

| Symptôme | Solution |
|---|---|
| `permission denied ... docker.sock` | `sudo usermod -aG docker $USER`, puis ferme et rouvre ta session |
| Pas de fenêtre Gazebo (Linux) | `xhost +local:root`, puis `./sim.sh stop` et relance |
| Gazebo affiche un monde vide | Un ancien `gz sim` traîne encore : `./sim.sh stop` puis relance |
| SITL répète `No JSON sensor message received` | Gazebo doit tourner **avant** SITL, avec un monde contenant un drone ArduPilot |
| `Arm: Motors: Check frame class and type` | Paramètres d'un ancien essai : relance avec `./sim.sh sitl -w` |
| Gazebo très lent | Normal sur CPU. `HEADLESS=1 ./sim.sh gazebo` retire la fenêtre |
| Fichiers de `workspace/` appartenant à `root` | Le conteneur tourne en root : `sudo chown -R $USER: workspace` |
| Compilation lente sous WSL | Place ton projet dans le disque Linux (`~/...`) plutôt que dans `/mnt/c/...` |

---

## Arborescence

```
sim-env/
├── README.md
├── Dockerfile
├── sim.sh            # toutes les commandes côté hôte
├── scripts/          # copiés dans l'image sous /opt/sim
│   ├── env.sh        # environnement (ROS 2, chemins Gazebo, rendu CPU)
│   ├── gazebo.sh
│   ├── sitl.sh
│   └── mavros.sh
└── workspace/        # ton projet, monté dans /workspace
```

Modifier un script de `scripts/` demande de reconstruire l'image (`./sim.sh build`, quelques secondes grâce au cache).
Pour changer de version d'ArduPilot ou du plugin, modifie `ARDUPILOT_SHA` / `AP_GAZEBO_SHA` dans le `Dockerfile`.
