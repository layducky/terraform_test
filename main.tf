terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id 
}

# 1. Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}


# 2. AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "moodle-aks"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "moodle-aks-dns"

  default_node_pool {
    name       = "nodepool1"
    node_count = 1
    vm_size    = "Standard_B2s"
  }

  identity {
    type = "SystemAssigned"
  }

  linux_profile {
    admin_username = var.admin_username

    ssh_key {
      key_data = file(var.ssh_public_key)
    }
  }

  network_profile {
    network_plugin     = "azure"
    load_balancer_sku  = "standard"
  }

  tags = {
    environment = "dev"
    project     = "moodle"
  }
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}
