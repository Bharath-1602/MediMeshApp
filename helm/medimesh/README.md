# 🏥 MediMesh Helm Chart — Complete Walkthrough

## ✅ What Was Done

Helmified the entire MediMesh microservices architecture into a **completely separate** Helm chart at `./helm/medimesh/`. 

- **Zero existing files were modified**
- Deploys to **`medimesh-helm`** namespace (isolated from your existing `medimesh` namespace)

---

## 📁 Helm Chart Folder Structure

```
helm/medimesh/
├── Chart.yaml                              # Chart metadata (name, version, description)
├── values.yaml                             # All configurable values (grouped by service)
├── README.md                               # This file — usage guide
└── templates/
    ├── _helpers.tpl                        # Reusable helper templates
    ├── NOTES.txt                           # Post-install instructions
    ├── namespace.yaml                      # medimesh-helm namespace
    ├── configmap.yaml                      # Non-sensitive config (service URLs, env vars)
    ├── secret.yaml                         # Sensitive config (JWT, MongoDB creds - base64)
    ├── frontend-deployment.yaml            # Frontend Deployment + ClusterIP Service + Sidecar
    ├── bff-deployment.yaml                 # BFF (Backend-For-Frontend) Deployment
    ├── backend-deployments.yaml            # All 9 backend microservice Deployments (range loop)
    ├── cluster-ip-services.yaml            # All ClusterIP Services (backend + BFF)
    ├── mongodb-statefulset.yaml            # MongoDB 3-Node StatefulSet + Headless Service
    ├── mongodb-rs-init-job.yaml            # MongoDB ReplicaSet Initialization Job
    ├── nfs-storageclass.yaml               # NFS Dynamic StorageClass (nfs-dynamic-helm)
    ├── nfs-provisioner-deployment.yaml     # NFS Subdir External Provisioner
    ├── nfs-rbac.yaml                       # ServiceAccount, ClusterRole, Role, Bindings
    ├── gateway.yaml                        # kGateway + HTTPRoute (all microservice routes)
    └── hpa.yaml                            # HorizontalPodAutoscaler (frontend)
```

---

## 🔒 Namespace Isolation Strategy

Since your existing `medimesh` namespace is already running, the Helm chart uses **`medimesh-helm`** with renamed cluster-scoped resources:

| Resource Type | Existing (medimesh) | Helm (medimesh-helm) |
|---|---|---|
| **Namespace** | `medimesh` | `medimesh-helm` |
| **StorageClass** | `nfs-dynamic` | `nfs-dynamic-helm` |
| **Provisioner** | `medimesh/nfs-subdir-...` | `medimesh-helm/nfs-subdir-...` |
| **ClusterRole** | `nfs-client-provisioner-runner` | `nfs-client-provisioner-helm-runner` |
| **ClusterRoleBinding** | `run-nfs-client-provisioner` | `run-nfs-client-provisioner-helm` |
| **MongoDB ReplicaSet** | `rs0` | `rs0-helm` |
| **RS Init Job** | `mongodb-rs-init` | `mongodb-rs-init-helm` |
| **Gateway** | `medimesh-gateway` | `medimesh-helm-gateway` |
| **HTTPRoute** | `medimesh-routes` | `medimesh-helm-routes` |
| **NFS Path** | `/srv/nfs/medimesh` | `/srv/nfs/medimesh-helm` |

> ⚠️ Both namespaces can **coexist** on the same cluster without conflicts.

---

## 🚀 STEP-BY-STEP: Helm Installation & Usage Guide

---

### Step 0: Check if Helm is Already Installed

Run on your **master node** (or wherever you run kubectl):

```bash
helm version
```

**If you see output like this → Helm is installed ✅ — skip to Step 2:**
```
version.BuildInfo{Version:"v3.x.x", ...}
```

**If you get "command not found" → go to Step 1.**

---

### Step 1: Install Helm (if not installed)

#### Option A: Linux (your AWS EC2 master node) ← Most likely this one
```bash
# Download and install Helm 3
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version
```

#### Option B: Windows (your local machine)
```powershell
# Using Chocolatey
choco install kubernetes-helm

# OR using Scoop
scoop install helm

# Verify installation
helm version
```

#### Option C: macOS
```bash
brew install helm
helm version
```

---

### Step 2: Prepare the NFS Server

On your **NFS/HAProxy EC2 instance**, create the new NFS directory:

```bash
# Create the new NFS share directory for Helm deployment
sudo mkdir -p /srv/nfs/medimesh-helm
sudo chown nobody:nogroup /srv/nfs/medimesh-helm
sudo chmod 777 /srv/nfs/medimesh-helm

# Add to NFS exports (if not using wildcard)
echo '/srv/nfs/medimesh-helm *(rw,sync,no_subtree_check,no_root_squash)' | sudo tee -a /etc/exports
sudo exportfs -ra
```

---

### Step 3: Update the NFS Server IP in values.yaml

Find your NFS server's private IP:
```bash
# On your NFS/HAProxy EC2 instance:
hostname -I | awk '{print $1}'
```

Then edit `helm/medimesh/values.yaml` — find and update this section:
```yaml
nfs:
  server:
    # ⚠️  REPLACE with your NFS server's PRIVATE IP
    ip: "172.31.XX.XX"   # ← Put your actual private IP here
    path: "/srv/nfs/medimesh-helm"
```

---

### Step 4: Copy Helm Chart to Master Node

```bash
# Option A: SCP from local to master node
scp -r -i your-key.pem helm/medimesh/ ubuntu@<MASTER_IP>:~/MediMesh/helm/medimesh/

# Option B: If using git
git add helm/
git commit -m "Add Helm chart for MediMesh"
git push
# Then on master node:
git pull
```

---

### Step 5: Validate the Chart (helm lint)

On your **master node**, navigate to the project root (`MediMesh/`):

```bash
cd ~/MediMesh

# Lint the chart for syntax errors
helm lint ./helm/medimesh
```

**Expected output:**
```
==> Linting ./helm/medimesh
[INFO] Chart.yaml: icon is recommended
1 chart(s) linted, 0 chart(s) failed
```

---

### Step 6: Dry Run (Preview all rendered YAML without deploying)

```bash
# Preview what will be created
helm template medimesh ./helm/medimesh --namespace medimesh-helm

# OR simulate the full install process
helm install medimesh ./helm/medimesh --namespace medimesh-helm --dry-run --debug
```

---

### Step 7: Install the Chart (First Deployment) 🎯

```bash
# Install the MediMesh Helm chart into medimesh-helm namespace
helm install medimesh ./helm/medimesh --namespace medimesh-helm --create-namespace
```

**Expected output:**
```
NAME: medimesh
LAST DEPLOYED: <timestamp>
NAMESPACE: medimesh-helm
STATUS: deployed

═══════════════════════════════════════════════════════════
  🏥 MediMesh Helm Chart — Deployed Successfully!
═══════════════════════════════════════════════════════════
  ✅ Frontend, BFF, 9 Backend Services, MongoDB, NFS, Gateway, HPA
```

---

### Step 8: Verify Deployment ✅

```bash
# Check all pods in the NEW namespace
kubectl get pods -n medimesh-helm

# Check all services
kubectl get svc -n medimesh-helm

# Check MongoDB StatefulSet
kubectl get statefulset -n medimesh-helm

# Check PVCs
kubectl get pvc -n medimesh-helm

# Check HPA
kubectl get hpa -n medimesh-helm

# Check Gateway
kubectl get gateway -n medimesh-helm
kubectl get httproute -n medimesh-helm

# Watch pods come up in real-time
kubectl get pods -n medimesh-helm -w

# ✅ Verify BOTH namespaces coexist peacefully
kubectl get namespaces | grep medimesh
# Expected output:
#   medimesh        Active   ...
#   medimesh-helm   Active   ...
```

---

### Step 9: Upgrade (After Making Changes to values.yaml)

```bash
# Upgrade with updated values
helm upgrade medimesh ./helm/medimesh --namespace medimesh-helm

# Override specific values inline
helm upgrade medimesh ./helm/medimesh --namespace medimesh-helm \
  --set frontend.replicas=4 \
  --set global.imageTag=v1.2.0

# Check release status
helm status medimesh -n medimesh-helm

# View release history
helm history medimesh -n medimesh-helm
```

---

### Step 10: Rollback / Uninstall

```bash
# View release history (to find revision number)
helm history medimesh -n medimesh-helm

# Rollback to a specific revision
helm rollback medimesh 1 -n medimesh-helm

# ──────────────────────────────────────────────
# UNINSTALL (removes ALL resources in medimesh-helm)
# ──────────────────────────────────────────────
helm uninstall medimesh -n medimesh-helm

# Optionally delete the namespace too
kubectl delete namespace medimesh-helm
```

> ⚠️ `helm uninstall` will only remove resources in `medimesh-helm`. Your existing `medimesh` namespace remains **completely untouched**.

---

## 🔄 Quick Reference Commands Table

| Action | Command |
|---|---|
| **Check Helm** | `helm version` |
| **Lint** | `helm lint ./helm/medimesh` |
| **Dry run** | `helm template medimesh ./helm/medimesh --namespace medimesh-helm` |
| **Install** | `helm install medimesh ./helm/medimesh -n medimesh-helm --create-namespace` |
| **Upgrade** | `helm upgrade medimesh ./helm/medimesh -n medimesh-helm` |
| **Status** | `helm status medimesh -n medimesh-helm` |
| **History** | `helm history medimesh -n medimesh-helm` |
| **Rollback** | `helm rollback medimesh <revision> -n medimesh-helm` |
| **Uninstall** | `helm uninstall medimesh -n medimesh-helm` |
| **List releases** | `helm list -n medimesh-helm` |

---

## 📝 Environment-Specific Overrides

Create separate values files for different environments:

```bash
# Develop environment
helm install medimesh ./helm/medimesh -n medimesh-helm -f values-dev.yaml

# Staging environment
helm install medimesh ./helm/medimesh -n medimesh-helm -f values-staging.yaml
```

Example `values-dev.yaml` (put next to `values.yaml`):
```yaml
global:
  environment: development

frontend:
  replicas: 1

backendDefaults:
  replicas: 1

mongodb:
  replicas: 1

hpa:
  enabled: false

gateway:
  enabled: false
```

---

## ✅ Final Verification Checklist

- [x] 16 template files created in `helm/medimesh/templates/`
- [x] All resource names, labels, selectors, and ports preserved
- [x] Deploys to isolated `medimesh-helm` namespace
- [x] Cluster-scoped resources renamed to avoid conflicts
- [x] MongoDB StatefulSet with headless service + RS init job
- [x] NFS provisioner + RBAC + StorageClass (all `-helm` suffixed)
- [x] kGateway + HTTPRoute with all 11 routes
- [x] Frontend HPA with configurable thresholds
- [x] BFF with envFrom configmap
- [x] User service with extra env vars (DOCTOR/AMBULANCE/PHARMACY)
- [x] Log sidecar on frontend
- [x] Init containers waiting for MongoDB on all backends
- [x] **Zero existing files modified**
- [x] **Both namespaces coexist on the same cluster**
