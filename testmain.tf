# infrastructure/main.tf

provider "azurerm" {
  features {}
}

# Fetch current client configuration for tenant_id and object_id
data "azurerm_client_config" "current" {}

# --- Resource Groups (One for each region) ---
resource "azurerm_resource_group" "rg_a" {
  name     = var.resource_group_name_a
  location = var.location_a
  tags = {
    environment = "prod-active"
  }
}

# --- Azure Key Vault & Secret Setup (Typically in primary region) ---
# Central Key Vault to store secrets like SQL admin password
resource "azurerm_key_vault" "main" {
  name                        = "${var.project_prefix}-keyvault"
  location                    = azurerm_resource_group.rg_a.location
  resource_group_name         = azurerm_resource_group.rg_a.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 7
  purge_protection_enabled    = true

  # Access policy for the Terraform executor (your Service Principal/User)
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    secret_permissions = ["get", "list", "set", "delete"] # Added delete for full management
  }
  # Additional access policy for AKS Managed Identity to GET secrets later
  # This will be added once AKS is defined and its principal_id is known.
}

# Generate a random password for SQL Server admin
resource "random_password" "sql_admin" {
  length  = 16
  special = true
  min_special = 1
  override_special = "!@#$%^&*"
}

# Store SQL admin password in Key Vault
resource "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "sql-admin-password"
  value        = random_password.sql_admin.result
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
}


# --- Networking Setup (Region A - Active) ---
resource "azurerm_virtual_network" "vnet_a" {
  name                = "${var.project_prefix}-vnet-${azurerm_resource_group.rg_a.location}"
  address_space       = var.vnet_address_space_a
  location            = azurerm_resource_group.rg_a.location
  resource_group_name = azurerm_resource_group.rg_a.name
}

resource "azurerm_subnet" "aks_subnet_a" {
  name                 = "${var.project_prefix}-aks-subnet-${azurerm_resource_group.rg_a.location}"
  resource_group_name  = azurerm_resource_group.rg_a.name
  virtual_network_name = azurerm_virtual_network.vnet_a.name
  address_prefixes     = var.aks_subnet_prefix_a
  # Delegate to AKS. This is important for AKS VNet integration.
  enforce_private_link_endpoint_network_policies = true
  enforce_private_link_service_network_policies  = true
}

#extra subnet for load balancer 
# --- Additional AKS Node Pool Subnet (Region A) ---
resource "azurerm_subnet" "aks_nodepool_subnet_a" {
  name                 = "${var.project_prefix}-aks-nodepool-subnet-${azurerm_resource_group.rg_a.location}"
  resource_group_name  = azurerm_resource_group.rg_a.name
  virtual_network_name = azurerm_virtual_network.vnet_a.name
  address_prefixes     = var.aks_nodepool_subnet_prefix_a
  enforce_private_link_endpoint_network_policies = true
  enforce_private_link_service_network_policies  = true
}


resource "azurerm_subnet" "lb_subnet_a" {
  name                 = "${var.project_prefix}-lb-subnet-${azurerm_resource_group.rg_a.location}"
  resource_group_name  = azurerm_resource_group.rg_a.name
  virtual_network_name = azurerm_virtual_network.vnet_a.name
  address_prefixes     = var.lb_subnet_prefix_a
}

# --- Azure Container Registry (ACR) ---
# Central ACR for both regions, with geo-replication (Premium tier needed for geo-replication)
resource "azurerm_container_registry" "acr" {
  name                = "${var.project_prefix}acr" # ACR name must be globally unique and alphanumeric
  resource_group_name = azurerm_resource_group.rg_a.name
  location            = azurerm_resource_group.rg_a.location
  sku                 = "Premium" # Changed to Premium to enable geo_replication
  admin_enabled       = false # Good practice to keep disabled

  # Enable geo-replication to Region B for DR
 # geo_replication_locations = [azurerm_resource_group.rg_b.location]
}

# --- Azure Kubernetes Service (AKS) Cluster (Region A - Active) ---
resource "azurerm_kubernetes_cluster" "aks_cluster_a" {
  name                = "${var.project_prefix}-aks-cluster-${azurerm_resource_group.rg_a.location}"
  location            = azurerm_resource_group.rg_a.location
  resource_group_name = azurerm_resource_group.rg_a.name
  dns_prefix          = "${var.project_prefix}-aks-a"
  kubernetes_version  = var.kubernetes_version

  # The default node pool will be in aks_subnet_a (sn3 in your diagram logic)
  default_node_pool {
    name                 = "systempool" # Renamed to systempool for clarity
    node_count           = var.aks_node_count
    vm_size              = var.aks_vm_size
    vnet_subnet_id       = azurerm_subnet.aks_subnet_a.id # This is your initial sn3
    os_disk_size_gb      = 30
    type                 = "System" # Mark as System node pool
    enable_auto_scaling  = true
    min_count            = 1
    max_count            = 3 # Example max count
  }

  # Identity for the AKS cluster (Managed Service Identity)
  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin     = "azure" # Azure CNI for VNet integration
    service_cidr       = "10.0.16.0/20" # CIDR for Kubernetes services
    dns_service_ip     = "10.0.16.10" # DNS service IP (within service_cidr)
    docker_bridge_cidr = "172.17.0.1/16" # Bridge CIDR
    load_balancer_sku  = "standard" # Use Standard LB for internal/external
  }

  tags = {
    environment = "prod-active"
  }
}

# Grant AKS SystemAssigned Managed Identity access to ACR (AcrPull role)
resource "azurerm_role_assignment" "aks_acr_pull_a" {
  principal_id         = azurerm_kubernetes_cluster.aks_cluster_a.identity[0].principal_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
}

# Grant AKS Managed Identity access to Key Vault secrets (to pull DB creds later)
resource "azurerm_key_vault_access_policy" "aks_kv_policy_a" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = azurerm_kubernetes_cluster.aks_cluster_a.identity[0].tenant_id
  object_id    = azurerm_kubernetes_cluster.aks_cluster_a.identity[0].principal_id

  secret_permissions = ["get", "list"] # Allow AKS to get secrets (like DB credentials)
}

# --- Azure SQL Server + Database (Region A - Primary) ---
resource "azurerm_mssql_server" "sql_server_a" {
  name                         = "${var.project_prefix}sqlservera"
  resource_group_name          = azurerm_resource_group.rg_a.name
  location                     = azurerm_resource_group.rg_a.location
  version                      = "12.0" # SQL Server 2019 (15.0) or 2022 (16.0) is more common now. "12.0" is older. Let's stick to 12.0 as per your sample.
  administrator_login          = var.sql_server_admin_login
  administrator_login_password = azurerm_key_vault_secret.sql_admin_password.value
  minimum_tls_version          = "1.2"
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_mssql_database" "sql_db_a" {
  name        = var.sql_database_name
  server_id   = azurerm_mssql_server.sql_server_a.id
  sku_name    = "Standard_S0" # Basic is too limited. S0 is a common dev/test starting point. Consider S1/S2 or higher for prod.
  collation   = "SQL_Latin1_General_CP1_CI_AS" # Common collation
  read_scale  = false # No read replicas for primary in a failover group
}

# Firewall rule to allow Azure services to access SQL server (useful for App Services, Functions etc)
resource "azurerm_mssql_firewall_rule" "sql_server_a_azure_services" {
  name                = "AllowAzureServices"
  server_id           = azurerm_mssql_server.sql_server_a.id
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

# Firewall rule to allow traffic from AKS subnet (Service Endpoint)
# This is preferred over public IP firewall rules for secure connectivity
resource "azurerm_mssql_virtual_network_rule" "sql_vnet_rule_a" {
  name                = "${var.project_prefix}-sql-vnet-rule-a"
  server_id           = azurerm_mssql_server.sql_server_a.id
  subnet_id           = azurerm_subnet.aks_subnet_a.id
  ignore_missing_vnet_service_endpoint = false
}

# --- Azure Standard Load Balancer (Region A) ---
resource "azurerm_public_ip" "load_balancer_pip_a" {
  name                = "${var.project_prefix}-lb-pip-${azurerm_resource_group.rg_a.location}"
  location            = azurerm_resource_group.rg_a.location
  resource_group_name = azurerm_resource_group.rg_a.name
  allocation_method   = "Static"
  sku                 = "Standard" # Standard SKU is required for AKS Basic Load Balancer integration and zone redundancy
}

resource "azurerm_lb" "main_lb_a" {
  name                = "${var.project_prefix}-lb-${azurerm_resource_group.rg_a.location}"
  location            = azurerm_resource_group.rg_a.location
  resource_group_name = azurerm_resource_group.rg_a.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "LoadBalancerFrontend"
    public_ip_address_id = azurerm_public_ip.load_balancer_pip_a.id
  }
}

resource "azurerm_lb_backend_address_pool" "backend_pool_a" {
  name                = "backend-pool"
  loadbalancer_id     = azurerm_lb.main_lb_a.id
}

resource "azurerm_lb_probe" "http_probe_a" {
  name                = "http-probe"
  loadbalancer_id     = azurerm_lb.main_lb_a.id
  protocol            = "Tcp" # Or Http if your Ingress Controller is already listening on this port with health check
  port                = 80    # Assuming your Ingress Controller will listen on 80
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "http_lb_rule_a" {
  name                           = "http-rule"
  loadbalancer_id                = azurerm_lb.main_lb_a.id
  protocol                       = "Tcp" # Or Http
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "LoadBalancerFrontend"
  backend_address_pool_ids        = [azurerm_lb_backend_address_pool.backend_pool_a.id]
  probe_id                       = azurerm_lb_probe.http_probe_a.id
  disable_outbound_snat          = true # Recommended for AKS with NAT Gateway
}

