# <img src="https://raw.githubusercontent.com/kubernetes/kubernetes/master/logo/logo.png" width="28" /> Kubernetes KinD HA Lab

![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?logo=kubernetes&logoColor=white)
![kind](https://img.shields.io/badge/kind-3D3D3D?logo=kubernetes&logoColor=white)
![Elasticsearch](https://img.shields.io/badge/Elasticsearch-005571?logo=elasticsearch&logoColor=white)
![Wazuh](https://img.shields.io/badge/Wazuh-3585F9?logoColor=white)
![CI](https://github.com/Anne-LaureS/Kubernetes-Kind-HA-Lab/actions/workflows/grafana-deploy.yml/badge.svg)

---
  
### *Cluster multi‑nœuds, ingress, déploiements v1/v2, services et monitoring complet*

Ce projet met en place un environnement Kubernetes local **reproductible**, basé sur **KinD** (Kubernetes in Docker), avec :

- un **cluster HA** (1 control-plane + 2 workers)  
- un **Ingress NGINX** fonctionnel  
- deux versions d’une application (v1 / v2)  
- un **Service** + **Ingress** pour exposer l’app  
- un **stack de monitoring complet** (Prometheus, Grafana, Alertmanager) via kube‑prometheus‑stack  
- **Elasticsearch** + **Metricbeat** pour la santé du cluster ES lui-même  
- un **SIEM Wazuh** (manager, indexer, dashboard) déployé en single-node sur le cluster

Ce lab est conçu pour l’expérimentation et la démonstration de concepts Kubernetes dans un environnement maîtrisé.

<p align="center">
  <img src="screenshots/dashboard.png" width="90%" alt="Dashboard Grafana Kubernetes HA Overview" />
</p>

---

### 📑 Sommaire

1. [Architecture du projet](#️-1-architecture-du-projet)
2. [Prérequis](#-2-prérequis)
3. [Cloner le repository](#-3-cloner-le-repository-github-dans-wsl)
4. [Structure du repo](#-4-structure-du-repo)
5. [Création du cluster KinD HA](#-5-création-du-cluster-kind-ha)
6. [Installation de l'Ingress NGINX](#-6-installation-de-lingress-nginx)
7. [Déploiement des applications v1 et v2](#-7-déploiement-des-applications-v1-et-v2)
8. [Installation du monitoring](#-8-installation-du-monitoring-kubeprometheusstack)
9. [Elasticsearch et Metricbeat](#-9-installation-delasticsearch-et-metricbeat)
10. [Accès à Grafana](#-10-accès-à-grafana)
11. [Dashboard personnalisé](#️-11-dashboard-personnalisé-cluster-overview)
12. [Installation de Wazuh (SIEM)](#️-12-installation-de-wazuh-siem)
13. [Mettre le labo en pause / le reprendre](#️-13-mettre-le-labo-en-pause--le-reprendre)
14. [Nettoyage](#-14-nettoyage-du-cluster-et-des-images-docker-inutiles)

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

### 🔹 SIEM
- **Wazuh manager** (master + worker) → collecte et analyse d'événements de sécurité
- **Wazuh indexer** → stockage (fork d'OpenSearch, cluster distinct de l'Elasticsearch de la section 9)
- **Wazuh dashboard** → visualisation des alertes de sécurité

---

# 🧰 2. Prérequis

- Docker Desktop  (WSL Integration -> Ubuntu activé)
- kubectl  
- KinD  
- Helm  
- WSL Ubuntu
- **~7-8 Go de RAM disponibles** pour Docker Desktop une fois tout le lab démarré (3 nœuds + stack
  de monitoring + Elasticsearch + Wazuh) — voir section 13 pour mettre le lab en pause entre deux
  utilisations

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
│   ├── deploy-grafana.sh
│   └── deploy-wazuh.sh
├── .github/
│   └── workflows/
│       └── grafana-deploy.yml
├── monitoring/
│   ├── elasticsearch.yaml
│   ├── elasticsearch-datasource.yaml
│   └── metricbeat.yaml
├── wazuh/
│   ├── kustomization.yml
│   ├── base/
│   ├── certs/                  (générés localement, non commités)
│   ├── secrets/
│   ├── wazuh_managers/
│   └── indexer_stack/
├── wazuh-envs/
│   └── kind-env/
│       ├── kustomization.yml
│       ├── storage-class.yaml
│       ├── indexer-resources.yaml
│       └── wazuh-resources.yaml
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

⚠️ **Sous WSL + VS Code (Remote-WSL)** : `http://127.0.0.1:8081` peut rester inaccessible depuis le
navigateur Windows (`ERR_CONNECTION_REFUSED`) même si `curl` réussit *depuis WSL* et que le port
apparaît "vert" dans l'onglet **PORTS** de VS Code — le relais localhost WSL→Windows ne suit pas
toujours un port-forward `kubectl` lancé en arrière-plan. Solution qui fonctionne à coup sûr :

```bash
# 1. Relancer le port-forward en écoutant sur toutes les interfaces, pas juste 127.0.0.1
kubectl -n monitoring port-forward --address 0.0.0.0 svc/monitoring-grafana 8081:80

# 2. Récupérer l'IP de la VM WSL (change à CHAQUE redémarrage de WSL, donc à revérifier à chaque
#    session — ne jamais la coder en dur, cf. le piège équivalent avec l'IP EC2 en TP7)
hostname -I
```

Puis ouvrir `http://<IP-WSL>:8081` (ex. `http://172.24.188.82:8081`) depuis le navigateur Windows.
⚠️ Ceci écoute sur toutes les interfaces réseau, pas seulement en local — le dashboard devient
accessible à tout le réseau local tant que le port-forward tourne ; à ne faire que temporairement, et
à arrêter (`Ctrl+C` / `kill`) une fois la vérification terminée. Même procédure pour tout autre
port-forward de ce lab (Wazuh section 12 inclus).

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

⚠️ Les 4 règles d'alerte (`grafana/alerts/*.json`) pointent vers un dossier `cluster-alerts` (`Cluster
Alerts`) que le script crée automatiquement avant de les provisionner. Ne pas repointer ces règles vers
le dossier `"general"` : c'est un UID réservé par Grafana (impossible d'y créer un vrai objet dossier),
et l'API `ruler` refuse alors l'accès en lecture (`403 access denied to folder`) — bug rencontré et
corrigé une première fois sur ce repo, silencieux tant que personne n'ouvre la page des règles. De même,
le champ de seuil des expressions `type: threshold` doit être `"conditions": [{"evaluator": {"type":
"gt", "params": [...]}}]` — l'ancien format `"thresholds": [{"value": ..., "color": ...}]` est accepté
à la création (aucune erreur du provisioning) mais fait échouer l'évaluation en silence au runtime
(`[sse.parseError] failed to parse expression [C]: threshold expression requires exactly one
condition` dans les logs du pod `monitoring-grafana`).

---

# 🛡️ 12. Installation de Wazuh (SIEM)

Wazuh apporte un SIEM (détection d'événements de sécurité, FIM, analyse de logs) en complément du
stack d'observabilité des sections précédentes. Il tourne dans son propre namespace (`wazuh`) et son
propre cluster d'indexation (**wazuh-indexer**, un fork d'OpenSearch) — indépendant de
l'Elasticsearch de la section 9, ils ne partagent aucune donnée.

Les manifests sont vendorisés depuis le dépôt officiel
[wazuh/wazuh-kubernetes](https://github.com/wazuh/wazuh-kubernetes) (tag `v4.14.7`) dans `wazuh/`.
`wazuh-envs/kind-env/` est un overlay Kustomize ajouté pour ce lab : il remplace le provisioner de
stockage par `rancher.io/local-path` (celui déjà présent sur KinD, à la place de
`microk8s.io/hostpath` utilisé par l'overlay officiel `local-env`) et réduit l'empreinte à 1 réplique
par composant (indexer, manager worker) — suffisant pour une démo single-node et beaucoup plus léger
que le déploiement HA par défaut (3 indexers + 2 workers).

⚠️ Les certificats TLS (`wazuh/certs/`) ne sont **pas commités** — ce sont des clés privées générées
localement à partir des scripts `generate_certs.sh` fournis par Wazuh. Le script de déploiement les
génère automatiquement s'ils sont absents.

```bash
chmod +x scripts/deploy-wazuh.sh
./scripts/deploy-wazuh.sh
```

Le script génère les certificats, applique l'overlay (`kubectl apply -k wazuh-envs/kind-env`) et
attend que les 4 pods (indexer, manager master, manager worker, dashboard) soient prêts — compter
plusieurs minutes, le démarrage de l'indexer (JVM OpenSearch) est le plus long.

Vérifier :

```bash
kubectl -n wazuh get pods
```

### 🔹 Accès au dashboard

```bash
kubectl -n wazuh port-forward --address 127.0.0.1 svc/dashboard 8443:443
```

Ouvrir `https://127.0.0.1:8443` (avertissement certificat auto-signé attendu, à accepter).

⚠️ Si le navigateur Windows renvoie `ERR_CONNECTION_REFUSED` malgré un port-forward actif — problème
courant sous WSL + VS Code — voir la solution (`--address 0.0.0.0` + IP WSL) détaillée en section 10.

Identifiants par défaut (démo officielle Wazuh, communs indexer + dashboard) :

- User : **admin**
- Password : **SecretPassword**

⚠️ Ce sont les identifiants de démonstration publiés tels quels dans le dépôt officiel
`wazuh-kubernetes` (`wazuh/secrets/`) — à changer avant toute exposition au-delà de ce lab local (via
`wazuh/secrets/indexer-cred-secret.yaml` et `wazuh/wazuh_managers/wazuh_conf/` pour l'API manager).

<p align="center">
  <img src="screenshots/wazuh-dashboard.png" width="90%" alt="Dashboard Wazuh" />
</p>

### 🔹 Limitation connue : statut "Offline" sur la page Server APIs

Le badge de statut peut afficher **Offline** dans l'onglet *Server APIs* du dashboard alors que
l'API du manager répond correctement. Cause : sous une pile réseau virtualisée chargée (WSL2 +
Docker Desktop + KinD), le premier appel du dashboard vers l'API du manager (port `55000`) subit
occasionnellement des ré-essais TLS avant d'aboutir, ce qui peut prendre 20 à 30 secondes — largement
au-delà du délai que l'interface attend avant d'afficher Offline (~8 s). L'appel finit par réussir
côté backend (confirmé dans `kubectl -n wazuh logs deploy/wazuh-dashboard`, requêtes `check-api` en
`200` après ce délai) ; ce n'est donc pas un défaut de configuration ni un problème de credentials,
juste un décalage de timeout côté interface sous ces contraintes réseau. Sans impact sur les données
déjà indexées (alertes, FIM, etc.), uniquement sur ce badge de statut.

---

# ⏸️ 13. Mettre le labo en pause / le reprendre

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

# 🧹 14. Nettoyage du cluster et des images Docker inutiles

Contrairement à la pause ci-dessus, ceci **supprime définitivement** le cluster et son état :

```bash
kind delete cluster --name kind
docker system prune -af
```
