terraform {
  // Specifies the required providers and versions for Helm and Kubernetes.
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.22.0"
    }
  }
}

provider "kubernetes" {
  // Configures the Kubernetes provider to use a specific kubeconfig file and context.
  config_path    = "~/.kube/config"
  config_context = "docker-desktop"  // Replace with your actual context name
}

provider "helm" {
  // Configures the Helm provider to use the same kubeconfig and context as Kubernetes.
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "docker-desktop"  // Replace with your actual context name
  }
}

resource "random_password" "redis_password" {
  // Generates a random password for Redis without special characters, 16 characters long.
  length  = 16
  special = false
}

resource "random_password" "mongo_password" {
  // Generates a random password for MongoDB without special characters, 16 characters long.
  length  = 16
  special = false
}

resource "random_password" "postgresql_password" {
  // Generates a random password for postgresql without special characters, 16 characters long.
  length  = 16
  special = false
}

locals {
  // Constructs the MongoDB connection URL, injecting the generated password.
  mongo_url = format(
    "mongodb://root:%s@tyk-mongo-mongodb.tyk.svc.cluster.local:27017/tyk_analytics?authSource=admin",
    random_password.mongo_password.result
  )
}

locals {
  postgres_url = format(
    "host=tyk-portal-postgres-postgresql.tyk.svc.cluster.local port=5432 dbname=portal user=postgres password=%s sslmode=disable",
    random_password.postgresql_password.result
  )
}

resource "kubernetes_namespace" "tyk" {
  // Creates the 'tyk' namespace if it does not already exist.
  metadata {
    name = "tyk"
  }
}

resource "helm_release" "mongo" {
  // Deploys MongoDB using Helm from the specified repository and chart version.
  name             = "tyk-mongo"
  repository       = "https://marketplace.azurecr.io/helm/v1/repo"  // Official Bitnami repo
  chart            = "mongodb"
  version          = "10.0.5"  // Specified version of MongoDB chart
  namespace        = kubernetes_namespace.tyk.metadata[0].name
  create_namespace = false  // Namespace created separately above

  // Configures the replica set and root password for MongoDB.
  set {
    name  = "replicaSet.enabled"
    value = "true"
  }

  set {
    name  = "auth.rootPassword"
    value = random_password.mongo_password.result
  }
}

resource "helm_release" "redis" {
  // Deploys Redis using Helm from the Bitnami repository and specified chart version.
  name             = "tyk-redis-data"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "redis"
  version          = "19.0.2"
  namespace        = "tyk"
  create_namespace = false  // Reuses the existing 'tyk' namespace

  // Sets the password for Redis.
  set {
    name  = "auth.password"
    value = random_password.redis_password.result
  }
}

resource "helm_release" "tyk_portal_postgres" {
  // Deploys MongoDB using Helm from the specified repository and chart version.
  name             = "tyk-portal-postgres"
  repository       = "https://charts.bitnami.com/bitnami" // Official Bitnami repo
  chart            = "postgresql"
  namespace        = "tyk"
  version          = "12.12.10"
  create_namespace = false  // Namespace created separately above

  // Configures the replica set and root password for MongoDB.
  set {
    name  = "auth.database"
    value = "portal"
  }

 set {
    name  = "global.postgresql.auth.password"
    value = random_password.postgresql_password.result
  }
  
}


resource "helm_release" "tyk" {
  // Deploys the Tyk stack using Helm from the Tyk Helm chart repository.
  name       = "tyk"
  repository = "https://helm.tyk.io/public/helm/charts"
  chart      = "tyk-stack"
  namespace  = "tyk"
  create_namespace = false

  // Loads custom configuration from a values file.
  values = [
    file("values.yaml")
  ]

  // Overrides specific values for Redis and MongoDB credentials in the Tyk stack.
  set {
    name  = "global.redis.pass"
    value = random_password.redis_password.result
  }

  set {
    name  = "global.mongo.mongoURL"
    value = local.mongo_url  // Injects MongoDB URL with password
  }

   set {
    name  = "tyk-dev-portal.database.connectionString"
    value = local.postgres_url  // Injects MongoDB URL with password
  }

  // Specifies dependencies to ensure MongoDB and Redis are deployed before Tyk.
  depends_on = [
    helm_release.mongo,
    helm_release.redis,
    helm_release.tyk_portal_postgres,
  ]
}

resource "kubernetes_service" "dashboard_nodeport" {
  // Defines a NodePort service for the Tyk dashboard, making it accessible externally.
  metadata {
    labels = {
      app = "dashboard-svc-tyk-tyk-dashboard"
    }
    name      = "dashboard-svc-tyk-tyk-dashboard-nodeport"
    namespace = "tyk"
  }

  spec {
    type = "NodePort"  // Service type for external access

    selector = {
      app = "dashboard-tyk-tyk-dashboard"  // Label selector for Tyk dashboard pods
    }

    port {
      port        = 3000     // External service port
      target_port = 3000     // Target port on the Tyk dashboard pod
    }
  }

  // Ensures Tyk is deployed before creating the NodePort service.
  depends_on = [
    helm_release.tyk,
  ]
}

resource "kubernetes_service" "gateway_nodeport" {
  // Defines a NodePort service for the Tyk gateway, making it accessible externally.
  metadata {
    labels = {
      app = "gateway-svc-tyk-tyk-gateway"
    }
    name      = "gateway-svc-tyk-tyk-gateway-nodeport"
    namespace = "tyk"
  }

  spec {
    type = "NodePort"  // Service type for external access

    selector = {
      app = "gateway-tyk-tyk-gateway"  // Label selector for Tyk gateway pods
    }

    port {
      port        = 8080     // External service port
      target_port = 8080     // Target port on the Tyk gateway pod
    }
  }

  // Ensures Tyk is deployed before creating the NodePort service.
  depends_on = [
    helm_release.tyk,
  ]
}

resource "kubernetes_service" "dev_portal_nodeport" {
  // Defines a NodePort service for the Tyk gateway, making it accessible externally.
  metadata {
    labels = {
      app = "dev-portal-svc-tyk-tyk-dev-portal"
    }
    name      = "dev-portal-svc-tyk-tyk-dev-portal-nodeport"
    namespace = "tyk"
  }

  spec {
    type = "NodePort"  // Service type for external access

    selector = {
      app = "tyk-tyk-dev-portal"  // Label selector for Tyk gateway pods
    }

    port {
      port        = 3001     // External service port
      target_port = 3001     // Target port on the Tyk gateway pod
    }
  }

  // Ensures Tyk is deployed before creating the NodePort service.
  depends_on = [
    helm_release.tyk,
  ]
}

output "dashboard_nodeport_url" {
  // Outputs the URL for accessing the Tyk dashboard service.
  value       = "http://localhost:${kubernetes_service.dashboard_nodeport.spec.0.port.0.node_port}"
  description = "The accessible URL for the Tyk dashboard service."
}

output "gateway_nodeport_url" {
  // Outputs the URL for accessing the Tyk gateway service.
  value       = "http://localhost:${kubernetes_service.gateway_nodeport.spec.0.port.0.node_port}/hello"
  description = "The accessible URL for the Tyk gateway service."
}


output "dev-portal_nodeport_url" {
  // Outputs the URL for accessing the Tyk gateway service.
  value       = "http://localhost:${kubernetes_service.dev_portal_nodeport.spec.0.port.0.node_port}"
  description = "The accessible URL for the Tyk Dev Portal service."
}