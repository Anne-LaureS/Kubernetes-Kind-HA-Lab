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

---

### 📑 Sommaire

1. [Architecture du projet](#1-architecture-du-projet)
2. [Prérequis](#2-prérequis)
3. [Cloner le repository](#3-cloner-le-repository-github-dans-wsl)
4. [Structure du repo](#4-structure-du-repo)
5. [Création du cluster KinD HA](#5-création-du-cluster-kind-ha)
6. [Installation de l'Ingress NGINX](#6-installation-de-lingress-nginx)
7. [Déploiement des applications v1 et v2](#7-déploiement-des-applications-v1-et-v2)
8. [Installation du monitoring](#8-installation-du-monitoring-kubeprometheusstack)
9. [Elasticsearch et Metricbeat](#9-installation-delasticsearch-et-metricbeat)
10. [Accès à Grafana](#10-accès-à-grafana)
11. [Dashboard personnalisé](#11-dashboard-personnalisé-cluster-overview)
12. [Mettre le labo en pause / le reprendre](#12-mettre-le-labo-en-pause--le-reprendre)
13. [Nettoyage](#13-nettoyage-du-cluster-et-des-images-docker-inutiles)
14. [Incidents rencontrés (et corrigés)](#14-incidents-rencontrés-et-corrigés)

*(si un lien ne saute pas au bon endroit, la table des matières native de GitHub — icône ☰ en haut à
gauche du fichier — fonctionne toujours comme filet de sécurité)*

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
- **~4-5 Go de RAM disponibles** pour Docker Desktop une fois tout le lab démarré (3 nœuds + stack
  de monitoring + Elasticsearch) — voir section 12 pour mettre le lab en pause entre deux utilisations

---

# ♾ 3. Cloner le repository GitHub dans WSL

Les sections suivantes utilisent des fichiers de ce repo (`kind-config.yaml`, `manifests/`,
`monitoring/`...) — cloner en premier :

```bash
cd ~
git clone https://github.com/Anne-LaureS/kubernetes-kind-ha-lab.git
cd kubernetes-kind-ha-lab
```

---

# 📚 4. Structure du repo

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

# 🚀 5. Création du cluster KinD HA

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

# 🌐 6. Installation de l’Ingress NGINX

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
```

ℹ️ Le `ServiceMonitor` lui-même (`ingress-servicemonitor.yaml`) s'applique **après** la section 8 —
son CRD (`monitoring.coreos.com/v1`) est fourni par `kube-prometheus-stack`, pas encore installé à ce
stade. L'appliquer maintenant échoue avec `no matches for kind "ServiceMonitor"`.

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

Installer le stack — **le nom de release doit être `monitoring`** (les sections suivantes, et
notamment `svc/monitoring-grafana` en section 10, en dépendent) :

```bash
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

Vérifier :

```bash
kubectl -n monitoring get pods
```

Une fois tous les pods `Running`, appliquer le `ServiceMonitor` de l'ingress (voir note section 6) :

```bash
kubectl apply -f ingress-servicemonitor.yaml
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

<p align="center">
  <img src="screenshots/elasticsearch.png" width="90%" alt="Dashboard Elasticsearch Cluster Health" />
</p>

---

# 📈 10. Accès à Grafana

Le port hôte `8080` est déjà réservé par `kind-config.yaml` pour l'ingress (voir section 5) — utiliser
un autre port local pour Grafana, par exemple `8081` :

```bash
kubectl -n monitoring port-forward --address 127.0.0.1 svc/monitoring-grafana 8081:80
curl http://127.0.0.1:8081
```

Identifiants par défaut :

- User : **admin**
- Password :
  ```bash
  kubectl -n monitoring get secret monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
  ```

### 🔹 Dashboards inclus automatiquement

- Kubernetes / Compute Resources  
- Kubernetes / Networking  
- Node Exporter  
- Prometheus Overview  
- Grafana Overview  

---

# 🛠️ 11. Dashboard personnalisé (Cluster Overview)

> Une fois importé (voir "Automatiser les dashboards" ci-dessous), il apparaît dans Grafana sous le
> titre **"Kubernetes – HA Overview (advanced + alerts)"** (uid `k8s_ha_overview`) — pas littéralement
> "Cluster Overview", qui n'est que le nom descriptif utilisé dans ce README. Accès direct :
> `http://127.0.0.1:8081/d/k8s_ha_overview`.

Il inclut :

- CPU cluster  
- RAM cluster  
- CPU par node  
- RAM par node  
- Pods par node  
- Latence Ingress P95  
- Requêtes HTTP

<p align="center">
  <img src="screenshots/alert-rule.png" width="90%" alt="Règles d'alerte Grafana" />
</p>
<p align="center"><i>Règles d'alerte actives (dont les 4 règles custom du repo, section suivante) avec leur état en direct.</i></p>

### 🔹 Automatiser les dashboards

Fichiers concernés : `grafana/` (dashboards, alertes, contact points, notification policies),
`scripts/deploy-grafana.sh` et `.github/workflows/grafana-deploy.yml` — voir l'arborescence complète en
section 4.

Pour déployer le script Bash afin d'automatiser les dashboards (nécessite une clé API Grafana et une
adresse email de notification — `contact-points/email.json` utilise `${ALERT_EMAIL}`) :
```bash
chmod +x scripts/deploy-grafana.sh
export GRAFANA_URL="http://127.0.0.1:8081"   # doit correspondre au port du port-forward (section 10)
export API_KEY="ta-cle-api-grafana"
export ALERT_EMAIL="ton-email@exemple.com"
./scripts/deploy-grafana.sh
```

La clé API s'obtient dans Grafana → **Administration → Users and access → Service accounts** →
*Add service account* (rôle Admin) → *Add service account token*.

---

# ⏸️ 12. Mettre le labo en pause / le reprendre

Le cluster (control-plane + 2 workers + registry mirror) consomme plusieurs Go de RAM en continu.
S'il n'est pas utilisé, on peut le stopper sans rien perdre (config, dashboards, données) — les
conteneurs Docker sont juste arrêtés, pas supprimés :

```bash
# Mettre en pause (libère la RAM)
docker stop kind-worker kind-worker2 kind-control-plane kind-cloud-provider kind-registry-mirror

# Reprendre plus tard, état identique
docker start kind-worker kind-worker2 kind-control-plane kind-cloud-provider kind-registry-mirror
```

⚠️ Si le réseau Docker `kind` a été supprimé entre-temps (ex: `docker network prune`), ce redémarrage
échoue avec `network ... not found` — irrécupérable. Dans ce cas, repartir de la section 5
(`kind delete cluster` puis `kind create cluster`).

---

# 🧹 13. Nettoyage du cluster et des images Docker inutiles

Contrairement à la pause ci-dessus, ceci **supprime définitivement** le cluster et son état :

```bash
kind delete cluster --name kind
docker system prune -af
```

---

# 🚧 14. Incidents rencontrés (et corrigés)

Ce lab a été reconstruit de zéro plusieurs fois en conditions réelles — les incidents suivants ont été
rencontrés puis corrigés, et sont documentés ici plutôt que passés sous silence :

| Incident | Symptôme | Correction |
|---|---|---|
| `docker network prune` supprime le réseau `kind` pendant une pause du lab | Les conteneurs stoppés refusent de redémarrer (`network ... not found`), irrécupérable | Toujours filtrer `docker network prune` par nom/label plutôt que de l'exécuter à l'aveugle sur un environnement avec plusieurs projets Docker actifs ; en cas d'incident, repartir de la section 5 (`kind delete cluster` + `kind create cluster`) |
| Nom de release Helm incohérent avec le reste de la doc (`prom` vs `monitoring`) | `svc/monitoring-grafana` (section 10) introuvable après une install avec le mauvais nom de release | Fixé : le nom de release doit être `monitoring` (section 8) |
| `ServiceMonitor` appliqué avant l'installation du stack de monitoring | `no matches for kind "ServiceMonitor"` — le CRD n'existe pas encore | Réordonné : le `ServiceMonitor` s'applique après `helm install monitoring ...` (section 8), pas dans la section 6 |
| Dashboard custom introuvable dans Grafana en cherchant "Cluster Overview" | Le dashboard existe (import réussi) mais porte un titre différent dans l'interface | Documenté le vrai titre et l'URL directe dans la section 11 |

Aucun de ces incidents n'a fait perdre de données de configuration (tout est versionné dans ce repo) —
seul l'état *live* du cluster a dû être reconstruit à chaque fois.
