# <img src="https://raw.githubusercontent.com/kubernetes/kubernetes/master/logo/logo.png" width="28" /> Kubernetes Kind HA Lab

---
  
### *Cluster multi‑nœuds, ingress, déploiements v1/v2, services et monitoring complet*

Ce projet met en place un environnement Kubernetes local **hautement reproductible**, basé sur **kind** (Kubernetes in Docker), avec :

- un **cluster HA** (1 control-plane + 2 workers)  
- un **Ingress NGINX** fonctionnel  
- deux versions d’une application (v1 / v2)  
- un **Service** + **Ingress** pour exposer l’app  
- un **stack de monitoring complet** (Prometheus, Grafana, Alertmanager) via kube‑prometheus‑stack  

Ce lab est conçu pour l’expérimentation et la démonstration de concepts Kubernetes dans un environnement maîtrisé.

---

# 🏗️ 1. Architecture du projet

### 🔹 Cluster kind HA
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

---

# 🧰 2. Prérequis

- Docker Desktop  
- kubectl  
- kind  
- helm  
- VS Code recommandé
- WSL Ubuntu

---

# 🚀 3. Création du cluster kind HA

Le fichier `kind-config.yaml` définit un cluster multi‑nœuds.

Créer le cluster :

```bash
kind create cluster --config kind-config.yaml
```

Vérifier :

```bash
kubectl get nodes -o wide
```

---

# 🌐 4. Installation de l’Ingress NGINX

```bash
kubectl apply -f ingress-nginx.yaml
```

Vérification :

```bash
kubectl -n ingress-nginx get pods
```

---

# 📦 5. Déploiement des applications v1 et v2

```bash
kubectl apply -f app-v1.yaml
kubectl apply -f app-v2.yaml
kubectl apply -f ingress.yaml
```

Tester l’accès :

```bash
curl http://app.localdev.me
```

---

# 📊 6. Installation du monitoring (kube‑prometheus‑stack)

Ajouter le repo Helm :

```bash
sudo snap install helm --classic
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
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

# 📈 7. Accès à Grafana

### 🔹 Via Ingress

```
http://grafana.localdev.me
```

Identifiants par défaut :

- **admin / prom-operator**

### 🔹 Dashboards inclus automatiquement

- Kubernetes / Compute Resources  
- Kubernetes / Networking  
- Node Exporter  
- Prometheus Overview  
- Grafana Overview  

---

# 🛠️ 8. Dashboard personnalisé (Cluster Overview)
  
Il inclut :

- CPU cluster  
- RAM cluster  
- CPU par node  
- RAM par node  
- Pods par node  
- Latence Ingress P95  
- Requêtes HTTP  

---

# 🧹 9. Nettoyage du cluster

```bash
kind delete cluster --name kind-ha
```

---

# 📚 10. Structure du repo

```
kubernetes-kind-ha-lab/
├── kind-config.yaml
├── ingress-nginx.yaml
├── app-v1.yaml
├── app-v2.yaml
├── ingress.yaml
└── README.md
```
