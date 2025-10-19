#!/bin/bash
set -e

NAMESPACE="moodle"
CLUSTER_NAME="moodle-aks"
RESOURCE_GROUP="moodle-rg"

az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --overwrite-existing

helm uninstall moodle -n $NAMESPACE || true
kubectl delete namespace $NAMESPACE --ignore-not-found

echo "✅ Moodle uninstalled."
