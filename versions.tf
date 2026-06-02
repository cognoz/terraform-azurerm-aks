terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.80.0, < 5.0.0"
    }
    # Used to generate a stable suffix when the caller doesn't supply a name.
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}
