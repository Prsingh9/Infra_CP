output "resource_group_name_a" {
  description = "Name of the primary resource group."
  value       = azurerm_resource_group.rg_a.name
}

output "resource_group_name_b" {
  description = "Name of the secondary resource group."
  value       = azurerm_resource_group.rg_b.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault."
  value       = azurerm_key_vault.main.vault_uri
}

output "sql_admin_password_secret_name" {
  description = "Name of the Key Vault secret storing the SQL admin password."
  value       = azurerm_key_vault_secret.sql_admin_password.name
}

output "sql_server_a_fqdn" {
  description = "Fully Qualified Domain Name of the primary SQL Server."
  value       = azurerm_mssql_server.sql_server_a.fully_qualified_domain_name
}

output "sql_server_b_fqdn" {
  description = "Fully Qualified Domain Name of the secondary SQL Server."
  value       = azurerm_mssql_server.sql_server_b.fully_qualified_domain_name
}

output "sql_failover_group_listener_fqdn" {
  description = "Fully Qualified Domain Name of the SQL Failover Group Listener (for application connection string)."
  value       = azurerm_mssql_failover_group.sql_failover_group.read_write_lister_fqdn
}

output "acr_login_server" {
  description = "Login server of the Azure Container Registry."
  value       = azurerm_container_registry.acr.login_server
}

output "aks_cluster_a_name" {
  description = "Name of the primary AKS cluster."
  value       = azurerm_kubernetes_cluster.aks_cluster_a.name
}

output "aks_cluster_b_name" {
  description = "Name of the secondary AKS cluster."
  value       = azurerm_kubernetes_cluster.aks_cluster_b.name
}

output "load_balancer_pip_a" {
  description = "Public IP address of the Azure Standard Load Balancer in Region A."
  value       = azurerm_public_ip.load_balancer_pip_a.ip_address
}

output "load_balancer_pip_b" {
  description = "Public IP address of the Azure Standard Load Balancer in Region B."
  value       = azurerm_public_ip.load_balancer_pip_b.ip_address
}

output "traffic_manager_fqdn" {
  description = "Fully Qualified Domain Name of the Azure Traffic Manager profile."
  value       = azurerm_traffic_manager_profile.main.fqdn
}

output "aks_nodepool_subnet_prefix_a" {
  description = "AKS node pool subnet address prefix for region A"
  value       = var.aks_nodepool_subnet_prefix_a
}
