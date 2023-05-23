variable "cluster_name" {
  description = "The region where the resources will be deployed"
  type        = string
  default     = "cluster-dev"
}

variable "name" {
  description = "name"
  type        = string
  default     = null
}
variable "region" {
  description = "The region where the resources will be deployed"
  type        = string
  default     = "us-east-1"
}

variable "eks_version" {
  description = "eks version to use"
  default     = "1.26"
  type        = string
}

variable "instance_type" {
  description = "Instance type to use"
  default     = "m5.large"
  type        = string
}

variable "subnets" {
  description = "List of all the public subnets"
  default     = ["subnet-","subnet-","subnet-"]
  type        = list(string)
}

variable "private_subnets" {
  description = "List of all the private subnets"
  default     = ["subnet-", "subnet-"]
  type        = list(string)
}



variable "VPC" {
  description = "List of vpc"
  default     = "vpc-"
  type        = string
}

variable "project" {
  description = "project name"
  default     = "eks-"
  type        = string
}



variable "tags" {
  description = "tags"
  type        = map(string)
  default     = {}
}


#Argo Variables
variable "timeout_seconds" {
  type        = number
  description = "Helm chart deployment can sometimes take longer than the default 5 minutes. Set a custom timeout here."
  default     = 800 # 10 minutes
}
variable "release_name" {
  type        = string
  description = "Helm release name"
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "Version of ArgoCD chart to install"
  type        = string
  default     = "5.34.1" # See https://artifacthub.io/packages/helm/argo/argo-cd for latest version(s)
}

variable "admin_password" {
  description = "Default Admin Password"
  type        = string
  default     = ""
}


variable "values_file" {
  description = "The name of the ArgoCD helm chart values file to use"
  type        = string
  default     = "values.yaml"
}

variable "enable_dex" {
  type        = bool
  description = "Enabled the dex server?"
  default     = true
}

variable "insecure" {
  type        = bool
  description = "Disable TLS on the ArogCD API Server?"
  default     = true
}
#lb variables
variable "path" {
  type = list(object({
    service_name = string
    service_port = string
    path         = string
  }))
  default = [
    {
      service_name = "argocd-server"
      service_port = "80"
      path         = "/argo"
    }
  ]
}
variable "annotations" {
  type    = any
  default = {}
}
variable "api_version" {
  type        = string
  default     = "networking/v1"
  description = "The api version of ingress, can be networking/v1 and extensions/v1beta1 for now"
}