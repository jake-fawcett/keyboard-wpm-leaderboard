terraform {
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "=0.1.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "tfstate"
    storage_account_name = "tfstate18727"
    container_name       = "tfstate-keyboard-leaderboard"
    key                  = "terraform.tfstate"
  }
}