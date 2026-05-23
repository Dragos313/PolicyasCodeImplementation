# Configurare Provider Azure
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# 1. Grupul de Resurse (Fortam eroare de locatie)
resource "azurerm_resource_group" "rg" {
  name     = "rg-proiect-dragos-pana"
  location = "swedencentral" # <--- "Locatie nepermisa"
  tags = {
    Owner = "Dragos Pana"
  }
}

# 2. Network Security Group (Fortam eroare de SSH deschis global)
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-securitate-critica"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowSSH_All"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix = "82.210.140.50/32" # <--- "Portul 22 deschis"
    destination_address_prefix = "*"
  }
}

# 3. Key Vault (Fortam eroare de Public Access + Lipsa Taguri)
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                        = "kv-proiect-dragos-2026"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  
  public_network_access_enabled = false # <--- "Key Vault public"

  tags = {
    Departament = "IT-Securitate"
    CostCenter  = "CC-1234"
    Owner = "Dragos Pana" # <--- Departament/CostCenter
  }
}




