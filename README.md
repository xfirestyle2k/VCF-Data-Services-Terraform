# VCF-Data-Services-Terraform

## Introduction
Automation is the essence of efficiency and scalability in today’s fast-paced technological landscape; Terraform is one of the most popular IaC tools because it’s regarded as the prime catalyst to managing and provisioning infrastructure, and Infrastructure as Code [IaC] has greatly contributed to the transformation of this process. This paper discusses how integration of Data Services Manager (DSM) into Terraform can simplify management of your data service deployments and their processes.

## Getting Started
I will not go into details on how to deploy Data Services Manager. I expect DSM is deployed, the vCenter plugin activated and 1 DSM User was created.
Data Services Manager uses Kubernetes under-the-hood, that said we are using the official Kubernetes provider from Terraform. This makes it even easier to integrate DSM into a current environment. We differentiate between a viAdmin and a DSM User. viAdmin is responsible for the Infrastructure Policy, IP Pool and Storage Policy which will be used by the DSM User to deploy the Databases. We will create our first Infrastructure Policy and use it afterwards to deploy a PostgreSQL Database.


## Using Terraform as a viAdmin
Before we start, we need to download the viAdmin API Kubeconfig. Let’s login to the vCenter with any Admin User. Navigate to the vCenter -> Configure -> Data Services Manager -> Infrastructure Policy and click on the top right “Download DSM API Kubeconfig” and save it to a dedicated folder. I will rename the Kubeconfig to “dsm-viadmin.kubeconfig”.

Next we need to create a Terraform file. I will call it “viadmin_main.tf” and add the official Kubernetes Provider and define the config_path which will be the kubeconfig file we downloaded. We will split this section into smaller code snippets to make it more understandable, I will add the full code at the end.

```
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

Lets run a ‘terraform init’ to initiate the provider.
➜  DSM_viAdmin terraform init

Initializing the backend...

Initializing provider plugins...
- Finding hashicorp/kubernetes versions matching ">= 2.0.0"...
- Installing hashicorp/kubernetes v2.31.0...
- Installed hashicorp/kubernetes v2.31.0 (signed by HashiCorp)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

Success! Terraform is initialized and we can continue. 

To be able to create an Infrastructure Policy we require an IP pool which we will create with Terraform. We use the kubernetes_manifest Resource and add the following code to the tf file.


```
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
```

Please adjust Name, Addresses, Prefix and Gateway based on your environment/needs.

With ‘terraform apply’ we can now create the IP Pool which is required. 


```
Plan: 1 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

kubernetes_manifest.terraform-ip-pool: Creating...
kubernetes_manifest.terraform-ip-pool: Creation complete after 1s

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

Let's continue on that, next we need to define the infrastructure policy. 

In the next snippet we use the kubernetes_manifest Resource which we give the same name as the name we would like to call the Infrastructure Policy and define the apiVersion, kind and as a metadata item, we define the name of the Infrastructure Policy we would like to create. In the spec area we define the placement of the future databases like the Datacenter, cluster/Resourcepool, and portgroup which we would like to use.

```
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
```

Moving to the next snippet, we focus on the available storage Policy, this could be any of the existing Storage Policies, like the vSAN Default Storage Policy, you can add multiple Storage Policies.
For the ipRanges, we provide the previously created PoolName and as portGroup we provide the datacenter where it can be found and the name of the PortGroup.

```
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
```

Last, we define the available vmClasses. By default there are 3 preconfigured, which we will use. We add them by only adding the name of the Class. At the end we are only adding a few conditions like a timeout and a dependency on the terraform IP Pool which we created. 

```
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

```


Success!! We created our first Infrastructure Policy. We can always make changes by adding new IP Pools or VM Classes.

In the next Section, we will take a look at the DSM side of the house and we will use Terraform to deploy our first Database using the Infrastructure Policy we just created.

## Using Terraform as a DSM User

Like before, we need to download the DSM API Kubeconfig. Lets login to the DSM Console with any DSM User or Admin. Click the User icon in the upper right, select “Download DSM API Kubeconfig” and save it to a dedicated folder. I will rename the downloaded Kubeconfig to “dsm-admin.kubeconfig”.


We using again the same Kubernetes Provider and define the new config_path to the newly downloaded dsm-admin.kubeconfig

```
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
```

As a resource, we use kubernetes_manifest which we name terra-pg-cluster, as metadata we define the name of the deployment, the namespace (which will always be “default”) and as an annotation, we will define the owner of the Database. If you execute it with DSM Admin permissions, you can change the owner to somebody else, but it must be a user which has DSM Permissions. Additionally, we can define labels which will be shown in the UI. 
The following Labels will be shown in the Databases overview “Created in Metadata", which might change in the future, for now labels make it easier for Admins to separate DBs.
"dsm.vmware.com/aria-automation-instance": "Instance"
"dsm.vmware.com/aria-automation-project" = "Terraform-Test"

```
resource "kubernetes_manifest" "terra-pg-cluster" {
 manifest = {
   "apiVersion" = "databases.dataservices.vmware.com/v1alpha1"
   "kind" = "PostgresCluster"
   "metadata" = {
     "name" = "terra-pg-cluster"
     "namespace" = "default"
     "annotations" = {
       "dsm.vmware.com/owner" = "thomas.sauerer@broadcom.com"
     }
     "labels": {
       "dsm.vmware.com/aria-automation-instance": "Instance"
       "dsm.vmware.com/created-in": "terraform"
       "dsm.vmware.com/aria-automation-project" = "Terraform-Test"
     }
   }
```

In the ‘spec’ section we define how many replicas we would like to have. Options are ‘0’ for a single instance, ‘1’ will be a Topology of three with one Primary, one Replica and one Monitor Instance, and ‘3’ will be a Topology of 5 with one Primary, three Replica and one Monitor Instance. Version defines the Postgres or MySQL version, storageSpace is the amount of persistent storage and the vmClass name contains the name of the VM class that you would like to use. 

Next we define the previously created Infrastructure Policy, the Storage Policy we selected in the Infrastructure Policy and the backupLocation.  

```
   "spec" = {
     "replicas" = 1
     "version" = "15.7"
     "storageSpace" = "30G"
     "vmClass" = {
       "name" = "small"
     }
     "infrastructurePolicy" = {
       "name" = "terraform-infra-policy"
     }
     "storagePolicyName" = "vSAN Default Storage Policy"
     "backupLocation" = {
       "name" = "local-backup"
     }
```

Finally, we configure backup. We can set the Backup Retention, so how many days a Backup will be available, and we can schedule both full and incremental backup types. In our example, I do a weekly full and daily incremental backup. It uses the standard cron logic/format for scheduling.

At the end we define computed_fields with spec.version, metadata.labels and metadata.annotations, this is required because we alter values by the API server during ‘apply’. Additionally we add another wait and timeout.

```
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
   create = "20m"
   delete = "15m"
 }
}
```

```
terraform apply
[...]

Plan: 1 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

kubernetes_manifest.terra-pg-cluster: Creating...
kubernetes_manifest.terra-pg-cluster: Still creating... [10s elapsed]
kubernetes_manifest.terra-pg-cluster: Still creating... [6m20s elapsed]
[...]
kubernetes_manifest.terra-pg-cluster: Creation complete after 6m30s

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```


Success! The Postgres DB is deployed and it is ready to connect.

## Day 2 Operations
Terraform is a stateful language, enabling it to handle day 2 operations such as scaling. This ensures that your infrastructure remains consistent and responsive to changing demands automatically. Let’s change the vmClass from small to large and apply it.

```
     "vmClass" = {
       "name" = "large"
     }
```

```
➜  DSM_User terraform apply
kubernetes_manifest.terra-pg-cluster: Refreshing state...

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  ~ update in-place

Terraform will perform the following actions:

  # kubernetes_manifest.terra-pg-cluster will be updated in-place
  ~ resource "kubernetes_manifest" "terra-pg-cluster" {
      ~ manifest = {
          ~ spec       = {
              ~ vmClass              = {
                  ~ name = "small" -> "large"
                }
                # (7 unchanged attributes hidden)
            }
            # (3 unchanged attributes hidden)
        }
      ~ object   = {
          ~ spec       = {
              ~ vmClass              = {
                  ~ name = "small" -> "large"
                }
                # (18 unchanged attributes hidden)
            }
            # (3 unchanged attributes hidden)
        }

        # (2 unchanged blocks hidden)
    }

Plan: 0 to add, 1 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

kubernetes_manifest.terra-pg-cluster: Modifying...
kubernetes_manifest.terra-pg-cluster: Still modifying... [10s elapsed]
kubernetes_manifest.terra-pg-cluster: Still modifying... [20s elapsed]
[...]
kubernetes_manifest.terra-pg-cluster: Still modifying... [7m51s elapsed]
kubernetes_manifest.terra-pg-cluster: Still modifying... [8m1s elapsed]
kubernetes_manifest.terra-pg-cluster: Modifications complete after 8m3s
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

Success! We successfully scaled the Database from a small instance to a large Instance in just a few minutes without disrupting the Database. 

Next we want to increase the number of replicas from one Replica to three Replicas.
```
   "spec" = {
     "replicas" = 3
```

```
➜  DSM_User terraform apply
kubernetes_manifest.terra-pg-cluster: Refreshing state...

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the
following symbols:
  ~ update in-place

Terraform will perform the following actions:

  # kubernetes_manifest.terra-pg-cluster will be updated in-place
  ~ resource "kubernetes_manifest" "terra-pg-cluster" {
      ~ manifest = {
          ~ spec       = {
              ~ replicas             = 1 -> 3
                # (7 unchanged attributes hidden)
            }
            # (3 unchanged attributes hidden)
        }
      ~ object   = {
          ~ spec       = {
              ~ replicas             = 1 -> 3
                # (18 unchanged attributes hidden)
            }
            # (3 unchanged attributes hidden)
        }

        # (2 unchanged blocks hidden)
    }

Plan: 0 to add, 1 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

kubernetes_manifest.terra-pg-cluster: Modifying...
kubernetes_manifest.terra-pg-cluster: Still modifying... [10s elapsed]
[...]
kubernetes_manifest.terra-pg-cluster: Still modifying... [7m0s elapsed]
kubernetes_manifest.terra-pg-cluster: Modifications complete after 7m2s
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```


We successfully increased the number of Replicas and applied a larger vmClass. Please keep in mind scale-up does work, but decreasing the number of Replicas or decreasing the VM_Class is not allowed and will be denied.

## Additional Resources

Since DSM is based on an API, we are able to curl the kubeconfig easily via a shell script. This makes it easy to implement into any Service Catalog. 

Example shell script to request the KUBECONFIG

### viAdmin:

```
VIADMINAUTHHDR=$(curl -k \
   -d '{"username":"'YOUR_VCENTER_ADMIN_CREDS'", "password":"'YOUR_VCENTER_ADMIN_PASSWORD'"}' \
   -H "Content-Type: application/json" -X POST \
   -i -s \
   https://YOUR-DSM-FQDN/provider/plugin/session-using-vc-credentials | grep "Authorization: Bearer ")


curl -k -s \
-H "$VIADMINAUTHHDR" \
-H 'Accept: application/vnd.vmware.dms-v1+octet-stream' \
https://YOUR-DSM-FQDN/provider/gateway-kubeconfig > dsm-viadmin.kubeconfig


export KUBECONFIG=dsm-viadmin.kubeconfig
```

### viAdmin:

```
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
```


### DSM User Kubeconfig:
export DSMADMINAUTHDR=$(curl -k \
 -d '{"email":"YOUR_DSM_USER_CREDS", "password":"YOUR_DSM_USER_PASSWORD"}' \
 -H "Content-Type: application/json" -X POST \
 -i -s \
 https://YOUR-DSM-FQDN/provider/session | grep "Authorization: Bearer ")


curl -k -s \
-H "$DSMADMINAUTHDR" \
-H 'Accept: application/vnd.vmware.dms-v1+octet-stream' \
https://YOUR-DSM-FQDN/provider/gateway-kubeconfig > dsm-admin.kubeconfig


export KUBECONFIG=dsm-admin.kubeconfig

### DSM User Terraform:
```
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
     "replicas" = 3
     "version" = "15.7"
     "storageSpace" = "30G"
     "vmClass" = {
       "name" = "small"
     }
     "infrastructurePolicy" = {
       "name" = "terraform-infra-policy"
     }
     "storagePolicyName" = "vSAN Default Storage Policy"
     "backupLocation" = {
       "name" = "local-backup"
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
```


## Conclusion

Data Services Manager is here to stay and bringing Database-as-a-Service (DBaaS) directly to your own datacenter. By leveraging Kubernetes, the Data Services Manager simplifies the deployment and automation with IaC like Terraform. This Integration allows a seamless and efficient integration into a current environment, enhancing both initial deployment and ongoing day 2 operations. By integrating DSM with Terraform, you can automate and streamline your data service management, ensuring consistency, scalability, and efficiency, thus taking your infrastructure management to the next level.
