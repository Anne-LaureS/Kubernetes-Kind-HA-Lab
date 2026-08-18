# <img src="https://raw.githubusercontent.com/kubernetes/kubernetes/master/logo/logo.png" width="28" /> Kubernetes KinD HA Lab

![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?logo=kubernetes&logoColor=white)
![kind](https://img.shields.io/badge/kind-3D3D3D?logo=kubernetes&logoColor=white)
![CI](https://github.com/Anne-LaureS/Kubernetes-Kind-HA-Lab/actions/workflows/grafana-deploy.yml/badge.svg)

---
  
### *Cluster multi‑nœuds, ingress, déploiements v1/v2, services et monitoring complet*

Ce projet met en place un environnement Kubernetes local **reproductible**, basé sur **KinD** (Kubernetes in Docker), avec :

- un **cluster HA** (1 control-plane + 2 workers)  
- un **Ingress NGINX** fonctionnel  
- deux versions d’une application (v1 / v2)  
- un **Service** + **Ingress** pour exposer l’app  
- un **stack de monitoring complet** (Prometheus, Grafana, Alertmanager) via kube‑prometheus‑stack  

Ce lab est conçu pour l’expérimentation et la démonstration de concepts Kubernetes dans un environnement maîtrisé.

<p align="center">
  <img src="screenshots/dashboard.png" width="90%" alt="Dashboard Grafana Kubernetes HA Overview" />
</p>
<p align="center"><i>Dashboard personnalisé : CPU/RAM cluster et par nœud, pods par nœud, latence Ingress P95.</i></p>

<p align="center">
  <img src="screenshots/alert-rule.png" width="90%" alt="Règles d'alerte Grafana" />
</p>
<p align="center"><i>Règles d'alerte actives (dont les 4 règles custom du repo) avec leur état en direct.</i></p>

<p align="center">
  <img src="screenshots/elasticsearch.png" width="90%" alt="Dashboard Elasticsearch Cluster Health" />
</p>
<p align="center"><i>Santé d'Elasticsearch (auto-monitoring via Metricbeat) : documents, taille de l'index, JVM heap, CPU.</i></p>

---

# 🏗️ 1. Architecture du projet

### 🔹 Cluster KinD HA
- 1 node **control-plane**  
- 2 nodes **workers**  
- réseau Docker interne  
- Ingress exposé via NodePort

### 🔹 Applications
- `app-v1`  
- `app-v2`  
- Service ClusterIP  
- Ingress HTTP (domaines locaux)

### 🔹 Observabilité
- **Prometheus** → collecte des métriques  
- **Grafana** → visualisation  
- **Alertmanager** → gestion des alertes
- **Elasticsearch**  

---

# 🧰 2. Prérequis

- Docker Desktop  (WSL Integration -> Ubuntu activé)
- kubectl  
- KinD  
- Helm  
- WSL Ubuntu

---

# 📚 3. Structure du repo

```
kubernetes-kind-ha-lab/
├── kind-config.yaml
├── ingress-servicemonitor.yaml
├── .gitignore
├── app/
│   ├── v1/
│   │   ├── index.html
│   │   └── Dockerfile
│   └── v2/
│       ├── index.html
│       └── Dockerfile
├── grafana/
│   ├── dashboard.json
│   ├── elasticsearch-dashboard.json
│   ├── alerts/
│   │   ├── cpu-cluster.json
│   │   ├── http-rps.json
│   │   ├── latency-p95.json
│   │   └── ram-cluster.json
│   ├── contact-points/
│   │   └── email.json
│   └── notification-policies/
│       └── default.json
├── scripts/
│   └── deploy-grafana.sh
├── .github/
│   └── workflows/
│       └── grafana-deploy.yml
├── monitoring/
│   ├── elasticsearch.yaml
│   ├── elasticsearch-datasource.yaml
│   └── metricbeat.yaml
├── manifests/
│   ├── configmap-v1.yaml
│   ├── configmap-v2.yaml
│   ├── demo-v1.yaml
│   ├── demo-v2.yaml
│   ├── hpa-demo-v1.yaml
│   ├── hpa-v2.yaml
│   └── ingress.yaml
├── screenshots/
│   ├── dashboard.png
│   ├── alert-rule.png
│   └── elasticsearch.png
└── README.md
```

---

# 🚀 4. Création du cluster KinD HA

Le fichier `kind-config.yaml` définit un cluster multi‑nœuds.

Créer le cluster :

```bash
kind create cluster --config kind-config.yaml
```

Vérifier :

```bash
kubectl get nodes
```

---

# 🌐 5. Installation de l’Ingress NGINX

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

Vérification :

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

Ce manifeste n'active pas les métriques Prometheus par défaut. Pour que les panels "Latence Ingress
P95" / "Requêtes HTTP (RPS)" du dashboard Grafana affichent des données, il faut les activer et
appliquer le `ServiceMonitor` du repo :

```bash
kubectl -n ingress-nginx patch deployment ingress-nginx-controller --type=json -p='[
  {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--enable-metrics=true"},
  {"op": "add", "path": "/spec/template/spec/containers/0/ports/-", "value": {"name": "metrics", "containerPort": 10254, "protocol": "TCP"}}
]'
kubectl -n ingress-nginx patch service ingress-nginx-controller --type=json -p='[
  {"op": "add", "path": "/spec/ports/-", "value": {"name": "metrics", "port": 10254, "targetPort": "metrics", "protocol": "TCP"}}
]'
kubectl apply -f ingress-servicemonitor.yaml
```

⚠️ Le manifeste "kind" ne fixe pas le pod du contrôleur sur le nœud `control-plane` — or c'est le seul
nœud sur lequel `kind-config.yaml` mappe les ports hôte `8080`/`443`. Après un redémarrage/rollout, le
pod peut être replanifié sur un worker et rendre `http://127.0.0.1:8080` inaccessible
(`Connection reset by peer`). Fixer explicitement le nœud :

```bash
kubectl -n ingress-nginx patch deployment ingress-nginx-controller --type=json -p='[
  {"op": "add", "path": "/spec/template/spec/nodeSelector/kubernetes.io~1hostname", "value": "kind-control-plane"}
]'
```

---

# 6. ♾ Cloner le repository GitHub dans WSL

```bash
cd ~
git clone https://github.com/Anne-LaureS/kubernetes-kind-ha-lab.git
cd kubernetes-kind-ha-lab
```

---

# 📦 7. Déploiement des applications v1 et v2

```bash
docker build -t demo:v1 app/v1
kind load docker-image demo:v1 --name kind
kubectl label node kind-control-plane ingress-ready=true
kubectl apply -f manifests/demo-v1.yaml
kubectl get pods -l app=demo-v1

docker build -t demo:v2 app/v2
kind load docker-image demo:v2 --name kind
kubectl apply -f manifests/demo-v2.yaml

kubectl apply -f manifests/ingress.yaml
kubectl apply -f manifests/hpa-demo-v1.yaml 
```

---

# 📊 8. Installation du monitoring (kube‑prometheus‑stack)

Ajouter le repo Helm :

```bash
sudo snap install helm --classic
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

Installer le stack :

```bash
helm install prom prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

Vérifier :

```bash
kubectl -n monitoring get pods
```

---

# 🔎 9. Installation d'Elasticsearch et Metricbeat

```bash
kubectl apply -f monitoring/elasticsearch.yaml
kubectl apply -f monitoring/metricbeat.yaml
```

Vérifier :

```bash
kubectl -n monitoring get pods -l app=elasticsearch
kubectl -n elastic get pods
```

Metricbeat surveille Elasticsearch lui-même (santé cluster, JVM, index) et renvoie ces métriques dans
Elasticsearch — mais sans source de données Grafana dédiée, ces données restent invisibles. Ajouter la
datasource :

```bash
kubectl apply -f monitoring/elasticsearch-datasource.yaml
```

⚠️ Ne pas fixer de `uid` explicite sur cette datasource dans le manifeste — un `uid` correspondant au nom
du type (`elasticsearch`) fait échouer le provisioning Grafana (`Datasource provisioning error: data
source not found`). Laisser Grafana en générer un automatiquement.

Le dashboard **"Elasticsearch – Cluster Health"** (`grafana/elasticsearch-dashboard.json`, importé par
`deploy-grafana.sh`) affiche : documents et taille de l'index au niveau cluster, utilisation JVM heap et
CPU du nœud.

---

# 📈 10. Accès à Grafana

Le port hôte `8080` est déjà réservé par `kind-config.yaml` pour l'ingress (voir section 4) — utiliser
un autre port local pour Grafana, par exemple `8081` :

```
kubectl -n monitoring port-forward --address 127.0.0.1 svc/monitoring-grafana 8081:80
curl http://127.0.0.1:8081

```

Identifiants par défaut :

- User : **admin**
- **Password** récupéré via -> kubectl -n monitoring get secret monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo

### 🔹 Dashboards inclus automatiquement

- Kubernetes / Compute Resources  
- Kubernetes / Networking  
- Node Exporter  
- Prometheus Overview  
- Grafana Overview  

---

# 🛠️ 11. Dashboard personnalisé (Cluster Overview)
  
Il inclut :

- CPU cluster  
- RAM cluster  
- CPU par node  
- RAM par node  
- Pods par node  
- Latence Ingress P95  
- Requêtes HTTP

### 🔹 Automatiser les dashboards

Fichiers concernés : `grafana/` (dashboards, alertes, contact points, notification policies),
`scripts/deploy-grafana.sh` et `.github/workflows/grafana-deploy.yml` — voir l'arborescence complète en
section 3.

Pour déployer le script Bash afin d'automatiser les dashboards (nécessite une clé API Grafana et une
adresse email de notification — `contact-points/email.json` utilise `${ALERT_EMAIL}`) :
```bash
chmod +x scripts/deploy-grafana.sh
export GRAFANA_URL="http://127.0.0.1:8081"   # doit correspondre au port du port-forward (section 9)
export API_KEY="ta-cle-api-grafana"
export ALERT_EMAIL="ton-email@exemple.com"
./scripts/deploy-grafana.sh
```

---

# 🧹 12. Nettoyage du cluster et des images Docker inutiles

```bash
kind delete cluster --name kind
docker system prune -af
```
