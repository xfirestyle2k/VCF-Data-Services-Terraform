terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}

provider "kubernetes" {
  config_path = "dsm-admin.kubeconfig"
}

resource "kubernetes_manifest" "terra-pg-cluster" {
  manifest = {
    "apiVersion" = "databases.dataservices.vmware.com/v1alpha1"
    "kind" = "PostgresCluster"
    "metadata" = {
      "name" = "terra-pg-cluster"
      "namespace" = "default"
      "annotations" = {
        "dsm.vmware.com/owner" = "admin@vmware.com"
      }
      "labels": {
        "dsm.vmware.com/aria-automation-instance": "Instance"
        "dsm.vmware.com/created-in": "terraform"
        "dsm.vmware.com/aria-automation-project" = "Terraform-Test"
      }
    }
    "spec" = {
      "replicas" = 1
      "version" = "16.4"
      "storageSpace" = "30G"
      "vmClass" = {
        "name" = "small"
      }
      "infrastructurePolicy" = {
        "name" = "wld-db-01"
      }
      "storagePolicyName" = "vSAN Default Storage Policy"
      "backupLocation" = {
        "name" = "database-backup"
      }
      "backupConfig" = {
        "backupRetentionDays" = 7
        "schedules" = [
          {
            "name" = "full-weekly"
            "type" = "full"
            "schedule" = "0 0 * * 0"
          },
          {
            "name" = "incremental-daily"
            "type" = "incremental"
            "schedule" = "0 0 * * *"
          }
        ]
      }
    }
  }
  computed_fields = [
    "spec.version",
    "metadata.labels",
    "metadata.annotations"
    ]
  wait {
    condition {
      type = "Ready"
      status = "True"
    }
  }
  timeouts {
    create = "30m"
    delete = "15m"
  }
}

####### Outputs for follow-up scripts #######

output "postgres_cluster_dbname" {

  value = kubernetes_manifest.terra-pg.manifest.spec.databaseName

}

####### Outputs from status section #######

data "kubernetes_resources" "resource_output" {
  api_version    = "databases.dataservices.vmware.com/v1alpha1"
  kind           = "PostgresCluster"
}

output "host_ip" {
  value = data.kubernetes_resources.resource_output.objects.1.status.connection.host
}
