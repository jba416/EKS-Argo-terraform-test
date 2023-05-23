resource "aws_security_group" "eks" {
    name        = "${var.cluster_name} eks cluster"
    description = "Allow traffic"
    vpc_id      = var.VPC

    ingress {
      description      = "World"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }

    egress {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }

    tags = merge({
      Name = "EKS ${var.cluster_name}",
      "kubernetes.io/cluster/${var.cluster_name}": "owned"
    }, var.tags)
}



 
module "eks" {
    source = "terraform-aws-modules/eks/aws"
    version = "18.19.0"

    cluster_name                    = var.cluster_name
    cluster_version                 = "1.26"
    cluster_endpoint_private_access = true
    cluster_endpoint_public_access  = true
    cluster_additional_security_group_ids = [aws_security_group.eks.id]

    vpc_id     = var.VPC
    subnet_ids = var.private_subnets


    eks_managed_node_groups = {
      green = {
        min_size     = 0
        max_size     = 1
        desired_size = 1

        instance_types = [var.instance_type]
        capacity_type  = "SPOT"
        labels = var.tags 
        taints = {
        }
        tags = var.tags
        security_group_rules = {
          ingress = {
          description = "rule for http"
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
          type = "ingress"
          
          }
          egress = {
          description = "rule for http"
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
          type = "egress"
          }
        }
      
      }
    }
    tags = var.tags
}

module "lb_role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "${var.cluster_name}_eks_lb"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
      command     = "aws"
    }
  }
}

resource "kubernetes_service_account" "service-account" {
  depends_on = [
    module.lb_role
  ]
  metadata {
    name = "aws-load-balancer-controller"
    namespace = "kube-system"
    
    labels = {
        "app.kubernetes.io/name"= "aws-load-balancer-controller"
        "app.kubernetes.io/component"= "controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = module.lb_role.iam_role_arn
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
  }
}

resource "helm_release" "lb" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  depends_on = [
    kubernetes_service_account.service-account, module.eks
  ]

  set {
    name  = "region"
    value = "us-east-1"
  }

  set {
    name  = "vpcId"
    value = var.VPC
  }

  set {
    name  = "image.repository"
    value = "602401143452.dkr.ecr.eu-west-2.amazonaws.com/amazon/aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  set {
    name  = "ingressClass"
    value = "alb"
  }
}
resource "kubernetes_namespace" "app-test" {
  depends_on = [module.eks]
  metadata {
    
    annotations = {
      name = "app-test"
    }

    labels = {
      app = "app-test"
    }

    name = "app-test"
  }
  
} 
resource "kubernetes_namespace" "argocd" {
  depends_on = [module.eks]
  metadata {
    
    annotations = {
      name = "argocd"
    }

    labels = {
      app = "argocd"
    }

    name = "argocd"
  }
  
} 
resource "time_sleep" "wait_30_seconds" {
  depends_on = [module.eks]
  create_duration = "120s"
 
}

resource "helm_release" "argocd" {
  depends_on = [time_sleep.wait_30_seconds, helm_release.lb]
  namespace        = "argocd"
  create_namespace = false
  name             = var.release_name
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version

  # Helm chart deployment can sometimes take longer than the default 5 minutes
  timeout = var.timeout_seconds

  # If values file specified by the var.values_file input variable exists then apply the values from this file
  # else apply the default values from the chart
/*   values = [
    "${file("application-1.yaml")}"
  ] */
   set_sensitive {
    name  = "configs.secret.argocdServerAdminPassword"
    value = var.admin_password == "" ? "" : bcrypt(var.admin_password)
  }

  set {
    name  = "configs.params.server\\.insecure"
    value = var.insecure 
  }

  set {
    name  = "dex.enabled"
    value = var.enable_dex == true ? true : false
  }
  set {
    name  = "configs.params.server\\.rootpath"
    value = "argo"
  } 
}
#aca empieza lo nuevo de argo
resource "helm_release" "argocd-apps" {
  depends_on = [helm_release.argocd, helm_release.lb]
  chart      = "argocd-apps"
  name       = "argocd-apps"
  namespace  = "argocd"
  repository = "https://argoproj.github.io/argo-helm"

  # (6)
  values = [
    file("/application-1.yaml")
  ]
}
resource "helm_release" "argocd-apps-api" {
  depends_on = [helm_release.argocd, helm_release.lb]
  chart      = "argocd-apps"
  name       = "argocd-apps-api"
  namespace  = "argocd"
  repository = "https://argoproj.github.io/argo-helm"

  # (6)
  values = [
    file("/application-2.yaml")
  ]
}
#ingress for argo
locals {
  group_name = "argo-group"
  default_annotations = {
    "kubernetes.io/ingress.class" = "nginx"
    #"alb.ingress.kubernetes.io/backend-protocol" = "HTTPS"
    "alb.ingress.kubernetes.io/scheme" = "internet-facing"
    "alb.ingress.kubernetes.io/subnets"  = "subnet-, subnet-"
    "alb.ingress.kubernetes.io/target-type" = "ip"
    "kubernetes.io/ingress.class" = "alb"
    "nginx.ingress.kubernetes.io/force-ssl-redirect" = "false"

  }
   annotations = merge(local.default_annotations, var.annotations)
}
resource "kubernetes_ingress_v1" "argo" {
  depends_on = [helm_release.argocd, helm_release.lb]
  count = var.api_version == "networking/v1" ? 1 : 0

  metadata {
    name        = "argo-lb"
    annotations = local.annotations
    namespace   = "argocd"
  }

  spec {
    
    rule {
      #host = var.hostname
      http {

        dynamic "path" {
          for_each = var.path
          content {
            backend {
              service {
                name = path.value["service_name"]
                port {
                  number = path.value["service_port"]
                }
              }
            }
            path = path.value["path"]
            path_type =  "Prefix"
          }
        }

      }
    }
  }
}

