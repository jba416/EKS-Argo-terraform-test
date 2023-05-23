terraform {
  backend "local" {
    path = "./terraform/terraform.state"
  }
  required_version = ">= 0.13.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.72"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.4.1"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.9.0"
    }
    argocd = {
      source  = "oboukili/argocd"
      version = ">= 5.3.0"
    }

  }
}

