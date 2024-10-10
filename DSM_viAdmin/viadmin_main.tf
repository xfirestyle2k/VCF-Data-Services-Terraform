terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}
provider "kubernetes" {
  config_path = "dsm-viadmin.kubeconfig"
}

resource "kubernetes_manifest" "terraform-ip-pool" {
 manifest = {
   "apiVersion" = "infrastructure.dataservices.vmware.com/v1alpha1"
   "kind" = "IPPool"
   "metadata" = {
     "name" = "terraform-ip-pool"
   }
   "spec" = {
     "addresses" = [
      "10.77.2.200-10.77.2.239"
      ]
     "prefix" = 24
     "gateway" = "10.77.2.1"
   }
 }
 wait {
   condition {
     type = "Ready"
     status = "True"
   }
 }
 timeouts {
  create = "10s"
  delete = "10s"
 }
}

resource "kubernetes_manifest" "terraform-infra-policy" {
  manifest = {
    "apiVersion" = "infrastructure.dataservices.vmware.com/v1alpha1"
    "kind" = "InfrastructurePolicy"
    "metadata" = {
      "name" = "terraform-infra-policy"
    }
    "spec" = {
      "enabled" = true
      "placements" = [
        {
            "datacenter" = "Datacenter"
            "cluster" = "VSAN-Cluster"
            "portGroups" = [
                "Management"
            ]
        }
      ]
      "storagePolicies" = [
        "vSAN Default Storage Policy"
      ]
      "ipRanges" = [
        {
          "poolName" = "terraform-ip-pool"
          "portGroups" = [
            {
                "datacenter" = "Datacenter"
                "name" = "Management"
            }
          ]
        }
      ]
      "vmClasses" = [
        {
            "name" = "small"
        },
        {
            "name" = "medium"
        },
        {
            "name" = "large"
        }
      ]
    }
  }
  depends_on = [ kubernetes_manifest.terraform-ip-pool ]
  wait {
    condition {
      type = "Ready"
      status = "True"
    }
  }
  timeouts {
    create = "20s"
    delete = "10s"
  }
}
