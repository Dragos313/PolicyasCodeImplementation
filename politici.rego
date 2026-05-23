package azure.securitate

import future.keywords.if
import future.keywords.contains

# VALORI DEFAULT
default allow := false

# --- 1. SENZORI DE DETECTIE ---

eroare_locatie if {
    some i
    resource := input.resource_changes[i]
    resource.change.after.location
    resource.change.after.location != "swedencentral"
}

ssh_periculos if {
    some i
    resource := input.resource_changes[i]
    resource.type == "azurerm_network_security_group"
    regula := resource.change.after.security_rule[_]
    regula.destination_port_range == "22"
    regula.source_address_prefix == "*"
}

storage_public if {
    some i
    resource := input.resource_changes[i]
    resource.type == "azurerm_storage_account"
    resource.change.after.public_network_access_enabled == true
}

kv_public if {
    some i
    resource := input.resource_changes[i]
    resource.type == "azurerm_key_vault"
    resource.change.after.public_network_access_enabled == true
}

# --- 2. COLECTARE MESAJE (Partial Rules) ---

vulnerabilitati contains msg if {
    eroare_locatie
    msg := "GDPR: Locatie nepermisa detectata (permis doar swedencentral)!"
}

vulnerabilitati contains msg if {
    ssh_periculos
    msg := "CRITIC: Portul 22 (SSH) este deschis catre Internet!"
}

vulnerabilitati contains msg if {
    storage_public
    msg := "SECURITATE: Storage Account are accesul public activat!"
}
# Regula pentru Key Vault (Adauga in sectiunea de colectare mesaje)
vulnerabilitati contains msg if {
    kv_public
    msg := "CRITIC: Key Vault are accesul public activat!"
}

# Regula pentru Tag-uri (Senzor + Mesaj setat strict pe Key Vault)
vulnerabilitati contains msg if {
    some i
    resource := input.resource_changes[i]
    resource.type == "azurerm_key_vault"
    tags := resource.change.after.tags
    not tags.Departament
    not tags.CostCenter
    msg := "GUVERNANTA: Lipsesc tag-urile obligatorii (Departament/CostCenter)!"
}

# --- 3. VERDICTUL FINAL ---
allow if count(vulnerabilitati) == 0