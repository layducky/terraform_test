#!/bin/bash
set -e

# === Config ===
NAMESPACE="ingress-nginx"
CLUSTER_NAME="moodle-aks"
RESOURCE_GROUP="moodle-rg"

# === Functions ===
install_az() {
    echo "📥 Installing Azure CLI..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
}

install_kubectl() {
    echo "📥 Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
}

install_helm() {
    echo "📥 Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
}

# === Check & install tools ===
for cmd in az kubectl helm; do
  if ! command -v $cmd &> /dev/null; then
    echo "⚠️ '$cmd' not found, installing..."
    case $cmd in
      az) install_az ;;
      kubectl) install_kubectl ;;
      helm) install_helm ;;
    esac
  else
    echo "✅ $cmd is already installed."
  fi
done

# === Azure login check ===
echo "🔐 Checking Azure login..."
if ! az account show &> /dev/null; then
  az login
fi

# === Get AKS credentials ===
echo "🔗 Getting AKS credentials..."
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --overwrite-existing

# === Install Helm repo ===
echo "📦 Adding/updating Helm repo..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# === Create namespace ===
echo "📁 Creating namespace '$NAMESPACE'..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# === Deploy NGINX Ingress Controller ===
echo "🚀 Installing NGINX Ingress Controller..."
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace $NAMESPACE \
  --set controller.replicaCount=1 \
  --set controller.nodeSelector."kubernetes\.io/os"=linux \
  --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux \
  --set controller.admissionWebhooks.patch.nodeSelector."kubernetes\.io/os"=linux \
  --wait

# === Wait for external IP ===
echo "🌐 Waiting for ingress external IP..."
EXTERNAL_IP=""
while [ -z "$EXTERNAL_IP" ]; do
  EXTERNAL_IP=$(kubectl get svc ingress-nginx-controller -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  [ -z "$EXTERNAL_IP" ] && sleep 5
done

echo "✅ Ingress Controller is ready: $EXTERNAL_IP"
