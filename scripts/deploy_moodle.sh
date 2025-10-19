#!/bin/bash
set -e

# === Config ===
NAMESPACE="moodle"
CLUSTER_NAME="moodle-aks"
RESOURCE_GROUP="moodle-rg"
EXTERNAL_IP=""
DESTROY_SCRIPT="./destroy_moodle.sh"

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

rollback() {
  echo "❌ Deployment failed. Running rollback..."
  if [ -f "$DESTROY_SCRIPT" ]; then
    bash "$DESTROY_SCRIPT"
  else
    echo "⚠️ Rollback script not found at $DESTROY_SCRIPT"
  fi
  exit 1
}

# === Check & install tools ===
for cmd in az kubectl; do
  if ! command -v $cmd &> /dev/null; then
    echo "⚠️ '$cmd' not found, installing..."
    case $cmd in
      az) install_az ;;
      kubectl) install_kubectl ;;
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

# === Create namespace ===
echo "📁 Creating namespace '$NAMESPACE'..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# === Wait for Ingress external IP ===
echo "🌐 Waiting for Ingress controller external IP..."
for i in {1..20}; do
  EXTERNAL_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  if [ -n "$EXTERNAL_IP" ]; then
    echo "✅ Ingress External IP: $EXTERNAL_IP"
    break
  fi
  echo "⏳ Waiting for external IP... (retrying in 5s, attempt $i/20)"
  sleep 5
done

if [ -z "$EXTERNAL_IP" ]; then
  echo "❌ Failed to get external IP for Ingress controller. Rolling back..."
  rollback
fi

# === Deploy order ===
DEPLOY_ORDER=("0_secret.yaml" "1_moodle_pvc.yaml" "2_psql_db.yaml" "3_moodle.yaml" "4_moodle_ingress.yaml")

echo ""
echo "🛠️ Deploying Moodle and PostgreSQL..."
for f in "${DEPLOY_ORDER[@]}"; do
  if [ -f "$f" ]; then
    echo "📝 Applying $f..."
    kubectl apply -f "$f" --namespace=$NAMESPACE
  else
    echo "⚠️ Warning: $f not found, skipping..."
  fi
done

# === Wait for pods to be ready ===
echo ""
echo "⏳ Waiting for PostgreSQL to be ready (timeout 300s)..."
if ! kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=300s; then
  echo "❌ PostgreSQL failed to become ready."
  rollback
fi

echo "⏳ Waiting for Moodle to be ready (timeout 300s)..."
if ! kubectl wait --for=condition=ready pod -l app=moodle -n $NAMESPACE --timeout=300s; then
  echo "❌ Moodle failed to become ready."
  rollback
fi

# === Success ===
echo ""
echo "✅ Deployment Complete!"
echo ""
echo "=== Access Information ==="
echo "🌐 Ingress IP: $EXTERNAL_IP"
echo "📝 Access URL: http://$EXTERNAL_IP"
echo ""
echo "=== Moodle Admin Credentials ==="
echo "   Username: admin"
echo "   Password: admin123"
echo ""
echo "📊 Check deployment status:"
echo "   kubectl get pods -n $NAMESPACE"
echo "   kubectl get svc -n $NAMESPACE"
echo "   kubectl get ingress -n $NAMESPACE"
echo ""
echo "📋 Check logs:"
echo "   kubectl logs -n $NAMESPACE deployment/postgres"
echo "   kubectl logs -n $NAMESPACE deployment/moodle"
