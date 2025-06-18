# infrastructure/variables.tf

# Global Settings
variable "project_prefix" {
  description = "A short prefix for naming resources to ensure uniqueness."
  type        = string
  default     = "prab" # Using your provided prefix
}

variable "location_a" {
  description = "Primary Azure region (Active Cluster)"
  type        = string
  default     = "East US" # Your preferred primary region
}

variable "location_b" {
  description = "Secondary Azure region (Passive/DR Cluster)"
  type        = string
  default     = "West US 2" # Your preferred secondary region (paired region recommended)
}

# Resource Group
variable "resource_group_name_a" {
  description = "The name of the primary resource group."
  type        = string
  default     = "prabh18-RG" # Your provided RG name
}

variable "resource_group_name_b" {
  description = "The name of the secondary resource group for DR."
  type        = string
  default     = "prabh18-RG-dr" # Derived from your primary RG name
}

# Networking
variable "vnet_address_space_a" {
  description = "Address space for the primary VNet."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "vnet_address_space_b" {
  description = "Address space for the secondary VNet (must be different from A for peering)."
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "aks_subnet_prefix_a" {
  description = "Address prefix for AKS subnet in Region A."
  type        = list(string)
  default     = ["10.0.0.0/22"] # Large enough for AKS nodes + pods
}

variable "aks_nodepool_subnet_prefix_a" {
  description = "Address prefix for AKS additional node pool subnet in region A"
  type        = list(string)
  default     = ["10.0.16.0/24"]
}


variable "aks_subnet_prefix_b" {
  description = "Address prefix for AKS subnet in Region B."
  type        = list(string)
  default     = ["10.10.0.0/22"]
}

variable "lb_subnet_prefix_a" {
  description = "Address prefix for Load Balancer subnet in Region A."
  type        = list(string)
  default     = ["10.0.4.0/28"] # Small subnet for LB frontend IP
}

variable "lb_subnet_prefix_b" {
  description = "Address prefix for Load Balancer subnet in Region B."
  type        = list(string)
  default     = ["10.10.4.0/28"]
}

variable "bastion_subnet_prefix_a" {
  description = "Address prefix for Azure Bastion Subnet in Region A."
  type        = list(string)
  default     = ["10.0.8.0/27"] # Must be /27 or larger, and named AzureBastionSubnet
}

variable "bastion_subnet_prefix_b" {
  description = "Address prefix for Azure Bastion Subnet in Region B."
  type        = list(string)
  default     = ["10.10.8.0/27"]
}

variable "nat_gateway_subnet_prefix_a" {
  description = "Address prefix for NAT Gateway associated subnet in Region A (for outbound traffic from private resources)."
  type        = list(string)
  default     = ["10.0.12.0/28"]
}

variable "nat_gateway_subnet_prefix_b" {
  description = "Address prefix for NAT Gateway associated subnet in Region B."
  type        = list(string)
  default     = ["10.10.12.0/28"]
}

variable "onprem_vnet_address_space" {
  description = "Address space for the simulated on-premises VNet."
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "onprem_gateway_subnet_address_prefix" {
  description = "Address prefix for the GatewaySubnet in on-prem VNet."
  type        = list(string)
  default     = ["10.1.0.0/27"]
}

# AKS Cluster
variable "kubernetes_version" {
  description = "The Kubernetes version for AKS clusters."
  type        = string
  default     = "1.28.3" # Check for the latest stable version
}

variable "aks_node_count" {
  description = "Number of nodes in the default AKS node pool."
  type        = number
  default     = 1
}

variable "aks_vm_size" {
  description = "VM size for AKS nodes."
  type        = string
  default     = "Standard_D2s_v3"
}

# SQL Database
variable "sql_server_admin_login" {
  description = "Administrator login for SQL Server."
  type        = string
  default     = "sqladminuser"
}

variable "sql_database_name" {
  description = "Name of the SQL database."
  type        = string
  default     = "springbootdb"
}

# ACR SKU
variable "acr_sku" {
  description = "SKU for Azure Container Registry (Basic, Standard, Premium)."
  type        = string
  default     = "Basic"
}
