# Deploy Moodle LMS on Azure AKS with Terraform & Helm

## Overview

This project uses Terraform, Azure AKS, kubectl, and Helm to deploy Moodle LMS on a managed Kubernetes cluster. PostgreSQL is deployed as a container within the cluster with persistent storage via PVCs.

## Prerequisites

- Azure CLI
- Terraform
- kubectl
- Helm
- SSH key (for Terraform to create AKS admin)

## Quick Start

### Step 0: Azure Login

```bash
az login
```
This will open a browser for authentication.

Set the correct subscription:
```bash
az account set --subscription "<SUBSCRIPTION_ID>"
```

Update `variables.tf` with your subscription ID and other values:
```hcl
variable "subscription_id" {
  default = "YOUR_SUBSCRIPTION_ID"
}
```

### Step 1: Deploy AKS with Terraform



```bash
terraform init
terraform plan
terraform apply -auto-approve
```

Terraform will output the kubeconfig needed for kubectl and Helm to connect.

### Step 2: Deploy NGINX Ingress Controller

```bash
./install_ingress.sh
```

This script will:
- Install Azure CLI, kubectl, Helm if missing
- Get AKS credentials
- Create ingress-nginx namespace
- Deploy NGINX Ingress Controller via Helm
- Wait for external IP

### Step 3: Deploy Moodle & PostgreSQL

```bash
./deploy_moodle.sh
```

This script will:
- Create moodle namespace
- Apply Kubernetes manifests in order

## Project Structure

```
.
├── terraform/
│   ├── .terraform
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars
├── moodle-chart/
├── scripts/
│   ├── 0_secret.yaml
│   ├── 1_moodle_pvc.yaml
│   ├── 2_psql_db.yaml
│   ├── 3_moodle.yaml
│   ├── 4_moodle_ingress.yaml
│   ├── deploy_moodle.sh
│   ├── destroy_moodle.sh
│   └── install_ingress.sh
├── .gitignore
├── terraform.lock.hcl
├── main.tf
├── variables.tf
├── readme.md
├── terraform.tfstate
└── terraform.tfstate.backup
```

## Check Deployment

```bash
# Check pods
kubectl get pods -n moodle

# Check services
kubectl get svc -n moodle

# Check ingress
kubectl get ingress -n moodle

# View logs
kubectl logs -n moodle deployment/postgres
kubectl logs -n moodle deployment/moodle

# Get external IP
kubectl get svc -n ingress-nginx
```

## Troubleshooting

### Check Logs

```bash
kubectl logs -n moodle deployment/postgres
kubectl logs -n moodle deployment/moodle
```

### Check Pod Status

```bash
kubectl get pods -n moodle
```

### Check Ingress External IP

```bash
kubectl get svc -n ingress-nginx
```

### Destroy/Restart Moodle Environment

```bash
./destroy_moodle.sh
./deploy_moodle.sh (Restart)
```

## Default Credentials

**Moodle Admin:**
- Username: admin
- Password: admin123

**Access Moodle at:**
- http://EXTERNAL_IP

## Key Concepts

**Namespaces:** Isolate Moodle (moodle) and Ingress (ingress-nginx) resources to prevent conflicts.