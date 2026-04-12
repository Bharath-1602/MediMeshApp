# 🏥 MediMesh CI Pipeline — Complete Guide

> **Continuous Integration pipeline for all 11 MediMesh microservices using GitHub Actions.**

---

## 📑 Table of Contents

- [Pipeline Overview](#-pipeline-overview)
- [Pipeline Architecture](#-pipeline-architecture)
- [Pre-requisites](#-pre-requisites)
- [Step-by-Step: How to Set Up & Run](#-step-by-step-how-to-set-up--run)
- [Pipeline Stages Explained](#-pipeline-stages-explained)
- [Understanding Image Tags](#-understanding-image-tags)
- [File Structure](#-file-structure)
- [How to Read Pipeline Results](#-how-to-read-pipeline-results)
- [Merging to Main](#-merging-to-main)
- [Troubleshooting](#-troubleshooting)
- [Secrets Reference](#-secrets-reference)

---

## 🔄 Pipeline Overview

The CI pipeline runs **5 sequential stages** across **all 11 microservices**:

| Stage | Tool | Purpose |
|-------|------|---------|
| ① **Code Quality** | SonarQube | Static code analysis for bugs, smells, vulnerabilities |
| ② **Dependency Scan** | Snyk | Check npm dependencies for known vulnerabilities |
| ③ **Docker Build** | Docker Buildx | Build Docker images for all 11 services (parallel) |
| ④ **Image Scan** | Trivy | Scan built container images for OS/library vulnerabilities |
| ⑤ **Docker Push** | Docker Hub | Push passing images with SHA tag + `latest` |

**Email notifications** are sent at every failure gate and on final success.

---

## 🏗️ Pipeline Architecture

```
 ┌─────────────────┐
 │  ① SonarQube    │  Code quality scan (full repo)
 │  Code Quality   │
 └────────┬────────┘
          │
 ┌────────▼────────┐
 │  ② Snyk         │  Dependency vulnerability scan (all 11 services)
 │  Dependency Scan│
 └────────┬────────┘
          │
 ┌────────▼────────────────────────────────────────────┐
 │  ③ Docker Build (Matrix — 11 parallel jobs)         │
 │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐     │
 │  │ auth │ │ user │ │doctor│ │ appt │ │vitals│ ... │
 │  └──────┘ └──────┘ └──────┘ └──────┘ └──────┘     │
 └────────┬────────────────────────────────────────────┘
          │
 ┌────────▼────────────────────────────────────────────┐
 │  ④ Trivy Image Scan (Matrix — 11 parallel jobs)     │
 │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐     │
 │  │ auth │ │ user │ │doctor│ │ appt │ │vitals│ ... │
 │  └──────┘ └──────┘ └──────┘ └──────┘ └──────┘     │
 └────────┬────────────────────────────────────────────┘
          │
 ┌────────▼────────────────────────────────────────────┐
 │  ⑤ Docker Push (Matrix — 11 parallel jobs)          │
 │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐     │
 │  │ auth │ │ user │ │doctor│ │ appt │ │vitals│ ... │
 │  └──────┘ └──────┘ └──────┘ └──────┘ └──────┘     │
 └────────┬────────────────────────────────────────────┘
          │
 ┌────────▼────────┐
 │  ✅ Success      │  Email notification with full summary
 │  Notification    │
 └─────────────────┘
```

### Microservices Covered

| # | Service | Docker Image | Build Context |
|---|---------|-------------|---------------|
| 1 | Auth | `bharath44623/medimesh_medimesh-auth` | `services/medimesh-auth` |
| 2 | User | `bharath44623/medimesh_medimesh-user` | `services/medimesh-user` |
| 3 | Doctor | `bharath44623/medimesh_medimesh-doctor` | `services/medimesh-doctor` |
| 4 | Appointment | `bharath44623/medimesh_medimesh-appointment` | `services/medimesh-appointment` |
| 5 | Vitals | `bharath44623/medimesh_medimesh-vitals` | `services/medimesh-vitals` |
| 6 | Pharmacy | `bharath44623/medimesh_medimesh-pharmacy` | `services/medimesh-pharmacy` |
| 7 | Ambulance | `bharath44623/medimesh_medimesh-ambulance` | `services/medimesh-ambulance` |
| 8 | Complaint | `bharath44623/medimesh_medimesh-complaint` | `services/medimesh-complaint` |
| 9 | Forum | `bharath44623/medimesh_medimesh-forum` | `services/medimesh-forum` |
| 10 | BFF | `bharath44623/medimesh_medimesh-bff` | `medimesh-bff` |
| 11 | Frontend | `bharath44623/medimesh_medimesh-frontend` | `medimesh-frontend` |

---

## ✅ Pre-requisites

### 1. GitHub Secrets (Must Be Set Already)

Go to **GitHub Repo → Settings → Secrets and variables → Actions** and verify all 9 secrets are configured:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `DOCKERHUB_USERNAME` | Docker Hub username | `bharath44623` |
| `DOCKERHUB_TOKEN` | Docker Hub access token (not password) | `dckr_pat_xxxxx` |
| `SONARQUBE_TOKEN` | SonarQube authentication token | `sqp_xxxxx` |
| `SONARQUBE_URL` | SonarQube server URL (your EC2 instance) | `http://3.x.x.x:9000` |
| `SNYK_TOKEN` | Snyk API token | `xxxxxxxx-xxxx-xxxx-xxxx` |
| `SMTP_USERNAME` | Gmail address for sending emails | `you@gmail.com` |
| `SMTP_PASSWORD` | Gmail App Password (NOT your Gmail password) | `xxxx xxxx xxxx xxxx` |
| `ALERT_EMAIL` | Email address to receive notifications | `you@gmail.com` |
| `KUBE_CONFIG` | Kubernetes config (for future CD pipeline) | Base64-encoded kubeconfig |

### 2. SonarQube Server Setup

Since you have SonarQube running on a separate EC2 instance:

1. **Ensure the SonarQube EC2 security group** allows inbound traffic on port `9000` from GitHub Actions IP ranges
2. **Create a project** on your SonarQube server:
   - Go to `http://<your-sonar-ec2-ip>:9000`
   - Click **"Create Project"**
   - Set Project Key to: **`Bharath-1602_MediMeshApp`** (must match `sonar-project.properties`)
   - Set Display Name to: **`MediMesh`**
3. **Generate a token**: Go to **My Account → Security → Generate Token**
   - Copy the token and set it as the `SONARQUBE_TOKEN` GitHub secret

### 3. Gmail App Password

If using Gmail for SMTP notifications:
1. Enable **2-Factor Authentication** on your Google account
2. Go to [Google App Passwords](https://myaccount.google.com/apppasswords)
3. Generate an app password for "Mail"
4. Use this 16-character password as your `SMTP_PASSWORD` secret

### 4. Snyk Account

1. Sign up at [snyk.io](https://snyk.io)
2. Go to **Account Settings → API Token**
3. Copy the token and set it as `SNYK_TOKEN`

---

## 🚀 Step-by-Step: How to Set Up & Run

### Step 1: Create the Feature Branch

```bash
# Make sure you're on main and up to date
git checkout main
git pull origin main

# Create and switch to the ci-pipeline feature branch
git checkout -b feature/ci-pipeline
```

### Step 2: Verify the Files Created

The following files should be in your project:

```
MediMeshApp/
├── .github/
│   └── workflows/
│       └── ci.yml                  ← CI Pipeline (GitHub Actions)
├── sonar-project.properties        ← SonarQube configuration
├── CI_README.md                    ← This file
└── ... (existing project files)
```

### Step 3: Stage and Commit

```bash
# Stage the new CI files
git add .github/workflows/ci.yml
git add sonar-project.properties
git add CI_README.md

# Commit
git commit -m "feat: add CI pipeline with SonarQube, Snyk, Docker Build, Trivy & Push

- GitHub Actions CI with 5 sequential stages
- Matrix strategy for building all 11 microservices in parallel
- SonarQube code quality analysis
- Snyk dependency vulnerability scanning
- Trivy container image scanning (HIGH/CRITICAL)
- Docker Hub push with SHA-based tagging
- Email notifications on failure and success"
```

### Step 4: Push the Feature Branch

```bash
git push -u origin feature/ci-pipeline
```

### Step 5: Watch the Pipeline

1. Go to **https://github.com/Bharath-1602/MediMeshApp/actions**
2. You should see the **"CI Pipeline"** workflow running
3. Click on it to watch each stage in real-time

### Step 6: Create a Pull Request (Optional)

```bash
# Or do this via GitHub UI
# Go to: https://github.com/Bharath-1602/MediMeshApp/compare/main...feature/ci-pipeline
```

### Step 7: Merge to Main

Once the pipeline passes on `feature/ci-pipeline`:

```bash
# Switch to main
git checkout main
git pull origin main

# Merge the feature branch
git merge feature/ci-pipeline

# Push to main
git push origin main
```

Or merge via GitHub Pull Request UI (recommended).

---

## 🔍 Pipeline Stages Explained

### ① SonarQube — Code Quality Analysis

- **What it does**: Scans your entire codebase for code smells, bugs, security vulnerabilities, and maintainability issues
- **Config file**: `sonar-project.properties` (at repo root)
- **Scans**: All 11 microservice source directories
- **Excludes**: `node_modules/`, `build/`, K8s manifests, Helm charts
- **Failure**: Sends email to `ALERT_EMAIL`

### ② Snyk — Dependency Vulnerability Scan

- **What it does**: Installs `npm` dependencies for all 11 services, then scans for known vulnerabilities
- **Severity threshold**: `high` (only fails on HIGH or CRITICAL vulnerabilities)
- **Multi-project**: Uses `--all-projects` to scan all `package.json` files
- **Artifact**: Uploads `snyk-*.json` report as a workflow artifact

### ③ Docker Build — Build All Images (Matrix)

- **What it does**: Builds Docker images for all 11 microservices **in parallel** using GitHub Actions matrix strategy
- **Tag**: Uses git short SHA (e.g., `abc1234`) or git tag if present (e.g., `v1.2.0`)
- **Artifact**: Each built image is saved as a `.tar` file and uploaded as a workflow artifact
- **Retention**: Image artifacts are automatically deleted after 1 day

### ④ Trivy — Container Image Vulnerability Scan (Matrix)

- **What it does**: Downloads each Docker image artifact, loads it, and scans for OS-level and library vulnerabilities
- **Severity**: Only fails on `CRITICAL` and `HIGH` vulnerabilities
- **Ignores**: Unfixed vulnerabilities (no patch available yet)
- **Parallel**: Scans all 11 images simultaneously

### ⑤ Docker Push — Publish to Docker Hub (Matrix)

- **What it does**: Pushes all successfully scanned images to Docker Hub
- **Tags pushed**: Both the SHA tag and `latest`
- **Condition**: Only runs on `push` and `workflow_dispatch` events (NOT on pull requests)
- **Login**: Uses `DOCKERHUB_USERNAME` + `DOCKERHUB_TOKEN`

---

## 🏷️ Understanding Image Tags

| Trigger | Tag Example | Description |
|---------|-------------|-------------|
| Push to branch | `abc1234` | Git short SHA (7 characters) |
| Git tag `v1.2.0` | `v1.2.0` | Semantic version from the tag |
| Pull request | `abc1234` | SHA tag (images are NOT pushed for PRs) |

**Every push also tags `latest`**, so your Docker Hub will always have:
- `bharath44623/medimesh_medimesh-auth:abc1234` (specific version)
- `bharath44623/medimesh_medimesh-auth:latest` (latest version)

---

## 📁 File Structure

```
MediMeshApp/
├── .github/
│   └── workflows/
│       └── ci.yml                    ← 📄 Main CI pipeline workflow
│                                       (SonarQube → Snyk → Build → Trivy → Push)
│
├── sonar-project.properties          ← 📄 SonarQube project configuration
│                                       (project key, sources, exclusions)
│
├── CI_README.md                      ← 📄 This documentation file
│
├── services/                         ← 📂 Backend microservices (9 services)
│   ├── medimesh-auth/
│   ├── medimesh-user/
│   ├── medimesh-doctor/
│   ├── medimesh-appointment/
│   ├── medimesh-vitals/
│   ├── medimesh-pharmacy/
│   ├── medimesh-ambulance/
│   ├── medimesh-complaint/
│   └── medimesh-forum/
│
├── medimesh-bff/                     ← 📂 Backend-for-Frontend service
├── medimesh-frontend/                ← 📂 React frontend (CRA + Nginx)
├── k8s/                              ← 📂 Kubernetes manifests
├── helm/                             ← 📂 Helm charts
└── haproxy/                          ← 📂 HAProxy load balancer config
```

---

## 📊 How to Read Pipeline Results

### In GitHub Actions UI

1. Go to **https://github.com/Bharath-1602/MediMeshApp/actions**
2. Click on the latest workflow run
3. You'll see the pipeline graph:

```
✅ SonarQube Scan
    └── ✅ Snyk Vulnerability Scan
            └── ✅ Build — auth        ✅ Build — user     ... (11 parallel)
                    └── ✅ Trivy — auth     ✅ Trivy — user  ... (11 parallel)
                            └── ✅ Push — auth      ✅ Push — user   ... (11 parallel)
                                    └── ✅ Pipeline Success Notification
```

### Understanding Status Icons

| Icon | Meaning |
|------|---------|
| ✅ | Stage passed successfully |
| ❌ | Stage failed (check logs, email sent) |
| ⏭️ | Stage skipped (dependency failed or condition not met) |
| 🔄 | Stage currently running |

### Email Notifications

- **On Failure**: You'll receive an email with the exact stage that failed, the branch, commit SHA, and a link to the workflow logs
- **On Success**: You'll receive a summary email listing all 11 images pushed with their tags

---

## 🔀 Merging to Main

### Option A: Via GitHub Pull Request (Recommended)

1. Push your `feature/ci-pipeline` branch
2. Go to GitHub → **Pull Requests** → **New Pull Request**
3. Set base: `main` ← compare: `feature/ci-pipeline`
4. Wait for the CI pipeline to pass (green checkmark)
5. Click **"Merge pull request"**
6. Delete the feature branch

### Option B: Via Command Line

```bash
# Ensure feature branch CI passes first!

# Switch to main
git checkout main
git pull origin main

# Merge with a descriptive commit
git merge --no-ff feature/ci-pipeline -m "Merge feature/ci-pipeline: Add CI pipeline"

# Push
git push origin main

# Clean up
git branch -d feature/ci-pipeline
git push origin --delete feature/ci-pipeline
```

---

## 🔧 Troubleshooting

### ❌ SonarQube Scan Fails

| Issue | Solution |
|-------|----------|
| Connection refused | Ensure your SonarQube EC2 security group allows inbound on port 9000 from `0.0.0.0/0` (or GitHub Actions IPs) |
| Authentication failed | Regenerate token on SonarQube and update `SONARQUBE_TOKEN` secret |
| Project not found | Create the project on SonarQube with key `Bharath-1602_MediMeshApp` |
| SonarQube server is down | SSH into your EC2 and restart: `sudo systemctl restart sonarqube` |

### ❌ Snyk Scan Fails

| Issue | Solution |
|-------|----------|
| High/Critical vulnerabilities found | Run `npx snyk test` locally, fix with `npx snyk fix` or update dependencies |
| Authentication error | Verify `SNYK_TOKEN` is correct |
| No package.json found | Ensure all 11 services have `package.json` files |

### ❌ Docker Build Fails

| Issue | Solution |
|-------|----------|
| Dockerfile not found | Ensure each service has a `Dockerfile` in its directory |
| npm install fails | Check `package.json` for invalid dependencies |
| Build context too large | Add/update `.dockerignore` files in each service |

### ❌ Trivy Scan Fails

| Issue | Solution |
|-------|----------|
| HIGH/CRITICAL vulnerabilities | Update base image in Dockerfile (e.g., `node:18-alpine` → `node:20-alpine`) |
| Image not found | Check that the Docker Build stage succeeded and artifacts were uploaded |

### ❌ Docker Push Fails

| Issue | Solution |
|-------|----------|
| Authentication failed | Verify `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`. Use an access token, not password |
| Repository doesn't exist | Docker Hub auto-creates repos on first push — ensure your account has permissions |
| Push skipped on PR | This is intentional — images are only pushed on direct pushes, not PRs |

### ❌ Email Notifications Not Arriving

| Issue | Solution |
|-------|----------|
| No emails received | Check spam folder; verify `ALERT_EMAIL` secret |
| SMTP authentication error | Ensure `SMTP_PASSWORD` is a Gmail **App Password**, not your Gmail password |
| Gmail security block | Enable 2FA and regenerate the App Password |

---

## 🔑 Secrets Reference

| Secret | Where to Get It |
|--------|----------------|
| `DOCKERHUB_USERNAME` | Your Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub → Account Settings → Security → New Access Token |
| `SONARQUBE_TOKEN` | SonarQube → My Account → Security → Generate Token |
| `SONARQUBE_URL` | Your SonarQube EC2 public IP/URL (e.g., `http://3.x.x.x:9000`) |
| `SNYK_TOKEN` | Snyk → Account Settings → General → API Token |
| `SMTP_USERNAME` | Your Gmail address |
| `SMTP_PASSWORD` | Google → App Passwords → Generate (requires 2FA) |
| `ALERT_EMAIL` | The email address to receive CI notifications |
| `KUBE_CONFIG` | `cat ~/.kube/config \| base64` on your K8s master node |

---

## 📝 Notes

- **Pull Requests**: The pipeline runs all stages (SonarQube, Snyk, Build, Trivy) but does **NOT** push images to Docker Hub. This lets you validate code quality without polluting your registry.
- **Matrix Strategy**: All 11 microservices are built, scanned, and pushed **in parallel**, making the pipeline significantly faster than sequential builds.
- **`fail-fast: false`**: If one service fails to build, the other 10 will continue building. This gives you a complete picture of which services have issues.
- **Image Artifacts**: Built Docker images are saved as workflow artifacts with a 1-day retention. This allows the Trivy scan and Push stages to access the images without rebuilding.
- **`KUBE_CONFIG`**: This secret is reserved for a future **CD (Continuous Deployment)** pipeline and is not used in the current CI workflow.

---

> **Built for MediMesh** — A Hospital Management Microservices Platform 🏥
