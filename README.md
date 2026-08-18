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
├── app/
│   ├── v1/
│          ├── index.html
│          ├── Dockerfile
│   └── v2/
│          ├── index.html
│          ├── Dockerfile
├── grafana/
│   ├── alerts/
│          ├──cpu-cluster.json
│          ├──http-rps.json
│          ├──latency-p95.json
│          ├──ram-cluster.json
│   └── contact-points/
│          ├──email.json
│   └── notification-policies/
│          ├──default.json
│   └── dashboard.json
├── scripts/
│    ├── deploy-grafana.sh
├── .github/
│       ├── workflows/
│       └── grafana-deploy.yml
├── monitoring/
│   ├── elasticsearch.yaml
│   ├── metricbeat.yaml
├── manifests/
│   ├── configmap-v1.yaml
│   ├── configmap-v2.yaml
│   ├── demo-v1.yaml
│   ├── demo-v2.yaml
│   ├── hpa-demo-v1.yaml
│   ├── hpa-v2.yaml
│   └── ingress.yaml
│  
└── README.md
```

---

# 🚀 4. Création du cluster KinD HA

Le fichier `kind-config.yaml` définit un cluster multi‑nœuds.

Créer le cluster :

```bash
kind create cluster --name ha-cluster --config kind-config.yaml
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

---

# 6. ♾ Cloner le repository GitHub dans WSL

```bash
cd ~
sudo git clone https://github.com/Anne-LaureS/kubernetes-kind-ha-lab.git
cd kubernetes-kind-ha-lab
```

---

# 📦 7. Déploiement des applications v1 et v2

```bash
docker build -t demo:v1 app/v1
kind load docker-image demo:v1 --name ha-cluster
kubectl label node ha-cluster-control-plane ingress-ready=true
kubectl get pods -l app=demo-v1
kubectl apply -f manifests/demo-v1.yam

docker build -t demo:v2 app/v2
kind load docker-image demo:v1 --name ha-cluster
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

# 📈 9. Accès à Grafana

```
kubectl -n monitoring port-forward pod/prom-grafana-7bcf667bd9-b5bbk 8080:3000
curl http://127.0.0.1:8080

```

Identifiants par défaut :

- User : **admin**
- **Password** révcupéré via -> kubectl get secret -n monitoring prom-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo

### 🔹 Dashboards inclus automatiquement

- Kubernetes / Compute Resources  
- Kubernetes / Networking  
- Node Exporter  
- Prometheus Overview  
- Grafana Overview  

---

# 🛠️ 10. Dashboard personnalisé (Cluster Overview)
  
Il inclut :

- CPU cluster  
- RAM cluster  
- CPU par node  
- RAM par node  
- Pods par node  
- Latence Ingress P95  
- Requêtes HTTP

### 🔹 Structure du dossier Grafana pour automatiser les Dashboards 

```
kubernetes-kind-ha-lab/
├── grafana/
|   ├── dashboard.json
|   ├── alerts/
|         ├── cpu-cluster.json
|         ├── ram-cluster.json
|         ├── latency-p95.json
|         ├── http-rps.json
|   ├── contact-points/
|         └── email.json
|   └── notification-policies/
|         └── default.json
└── scripts/
|      └── deploy-grafana.sh/
├── .github/
│       ├── workflows/
│       └── grafana-deploy.yml
```

Pour déployer le script Bash afin d'automatiser les dashboards :
```
chmod +x scripts/deploy-grafana.sh
./scripts/deploy-grafana.sh
API_KEY="$API_KEY" ./scripts/deploy-grafana.sh
```

---

# 🧹 11. Nettoyage du cluster et des images Docker inutiles

```bash
kind delete cluster --name ha-cluster
docker system prune -af
```
