variable "location" {
  type    = string
  default = "UK South"
}

variable "resource_group_name" {
  type = string
}

variable "container_registry_name" {
  type = string
}

variable "image_name" {
  type = string
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_container_registry" "acr" {
  name                = var.container_registry_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "null_resource" "docker_push" {
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    command = <<-EOT
      sudo docker build ../app -t ${azurerm_container_registry.acr.login_server}/${var.image_name}
      sudo docker login ${azurerm_container_registry.acr.login_server} -u ${azurerm_container_registry.acr.admin_username} -p ${azurerm_container_registry.acr.admin_password}
      sudo docker push ${azurerm_container_registry.acr.login_server}/${var.image_name}
    EOT
  }
  depends_on = [ 
    azurerm_container_registry.acr
  ]
}

resource "azurerm_storage_account" "keyboardleaderboard" {
  name                      = "keyboardleaderboard"
  resource_group_name       = azurerm_resource_group.rg.name
  location                  = azurerm_resource_group.rg.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  enable_https_traffic_only = true
}

resource "azurerm_storage_table" "leaderboard_table" {
  name                 = "keyboardleaderboard"
  storage_account_name = azurerm_storage_account.keyboardleaderboard.name
}

resource "azurerm_storage_share" "aci_caddy_data" {
  name                 = "aci-caddy-data"
  storage_account_name = azurerm_storage_account.keyboardleaderboard.name
  quota                = 5
}

resource "azurerm_storage_share" "aci_caddy_config" {
  name                 = "aci-caddy-config"
  storage_account_name = azurerm_storage_account.keyboardleaderboard.name
  quota                = 5
  depends_on = [ 
    azurerm_storage_share.aci_caddy_data 
  ]
}

resource "azurerm_storage_share" "aci_caddy_file" {
  name                 = "aci-caddy-file"
  storage_account_name = azurerm_storage_account.keyboardleaderboard.name
  quota                = 5
  depends_on = [ 
    azurerm_storage_share.aci_caddy_config 
  ]
}

resource "azurerm_storage_share_file" "aci_caddy_file" {
  name             = "Caddyfile"
  storage_share_id = azurerm_storage_share.aci_caddy_file.id
  source           = "../caddy/Caddyfile"
}

resource "azurerm_container_group" "container" {
  name                = "${var.image_name}-instance"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_address_type     = "Public"
  os_type             = "Linux"
  dns_name_label      = "keyboard-leaderboard"

  depends_on = [
    null_resource.docker_push,
    azurerm_storage_share.aci_caddy_data,
    azurerm_storage_share.aci_caddy_config,
    azurerm_storage_share_file.aci_caddy_file
  ]

  container {
    name   = var.image_name
    image  = "${azurerm_container_registry.acr.login_server}/${var.image_name}"
    cpu    = 0.5
    memory = 0.5

    ports {
      port     = 8000
      protocol = "TCP"
    }
  }

  container {
    name   = "caddy"
    image  = "caddy:latest"
    cpu    = 0.5
    memory = 0.2

    ports {
      port     = 443
      protocol = "TCP"
    }

    ports {
      port     = 80
      protocol = "TCP"
    }

    volume {
      name                 = "data"
      mount_path           = "/data"
      storage_account_name = azurerm_storage_account.keyboardleaderboard.name
      storage_account_key  = azurerm_storage_account.keyboardleaderboard.primary_access_key
      share_name           = azurerm_storage_share.aci_caddy_data.name
    }

    volume {
      name                 = "config"
      mount_path           = "/config"
      storage_account_name = azurerm_storage_account.keyboardleaderboard.name
      storage_account_key  = azurerm_storage_account.keyboardleaderboard.primary_access_key
      share_name           = azurerm_storage_share.aci_caddy_file.name
    }

    volume {
      name                 = "caddy"
      mount_path           = "/etc/caddy"
      read_only            = true
      storage_account_name = azurerm_storage_account.keyboardleaderboard.name
      storage_account_key  = azurerm_storage_account.keyboardleaderboard.primary_access_key
      share_name           = azurerm_storage_share.aci_caddy_file.name
    }

    commands = ["caddy", "run", "--config", "/etc/caddy/Caddyfile"]
  }

  image_registry_credential {
    server   = azurerm_container_registry.acr.login_server
    username = azurerm_container_registry.acr.admin_username
    password = azurerm_container_registry.acr.admin_password
  }
}