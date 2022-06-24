# Deploy HPCC Systems on Azure under Kubernetes

This is a slightly-opinionated Terraform module for deploying an HPCC Systems cluster on Azure.  The goal is to provide a simple method for deploying a cluster from scratch, with only the most important options to consider.

The HPCC Systems cluster this module creates uses ephemeral storage (meaning, the storage will be deleted if the cluster is deleted) unless a predefined storage account is cited.  See the section titled [Persistent Storage](#persistent_storage), below.

This repo is a fork of the excellent work performed by Godson Fortil.  The original can be found at [https://github.com/hpcc-systems/terraform-azurerm-hpcc-aks](https://github.com/hpcc-systems/terraform-azurerm-hpcc-aks).

## Requirements

* This is a Terraform module, so you need to have Terraform installed on your system.  Instructions for downloading and installing Terraform can be found at [https://www.terraform.io/downloads.html](https://www.terraform.io/downloads.html).

* The Kubernetes client (kubectl) is also required so you can inspect and manage the Azure Kubernetes cluster.  Instructions for download and installing that can be found at [https://kubernetes.io/releases/download/](https://kubernetes.io/releases/download/).  Make sure you have version 1.22.0 or later.

* To work with Azure, you will need to install the Azure Command Line tools.  Instructions can be found at [https://docs.microsoft.com/en-us/cli/azure/install-azure-cli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli).  Even if you think you won't be working with Azure, this module does leverage the command line tools to manipulate network security groups within kubernetes clusters.  TL;DR: Make sure you have the command line tools installed.

* The Azure Command Line tools also requires that the extension 'resource-graph' be installed.  You can do that with the command `az extension add --name resource-graph`.  This command needs to be performed only once.

* This module will create an AKS cluster in your current default Azure subscription.  You can view your current subscriptions, and determine which is the default, using the `az account list --output table` command.  To set a default subscription, use `az account set --subscription "My_Subscription"`.

* To successfully create everything you will need to have Azure's `Contributor` role plus access to `Microsoft.Authorization/*/Write` and `Microsoft.Authorization/*/Delete` permissions on your subscription.  You may have to create a custom role for this.  Of course, Azure's `Owner` role includes everything so if you're the subscription's owner then you're good to go.

## Installing/Using This Module

1. If necessary, login to Azure.
	* From the command line, this is usually accomplished with the `az login` command.
1. Clone this repo to your local system and change current directory.
	* `git clone https://github.com/dcamper/terraform-azurerm-hpcc-aks.git`
	* `cd terraform-azurerm-hpcc-aks`
1. Issue `terraform init` to initialize the Terraform modules.
1. Decide how you want to supply option values to the module during invocation.  There are three possibilities:
	1. Invoke the `terraform apply` command and enter values for each option as Terraform prompts for it, then enter `yes` at the final prompt to begin building the cluster.
	1. **Recommended:**  Create a `terraform.tfvars` file containing the values for each option, invoke `terraform apply`, then enter `yes` at the final prompt to begin building the cluster.  The easiest way to do that is to copy the sample file and then edit the copy:
		* `cp examples/sample.tfvars terraform.tfvars`
	1. Use -var arguments on the command line when executing the terraform tool to set each of the values found in the .tfvars file.  This method is useful if you are driving the creation of the cluster from a script.
1. After the Kubernetes cluster is deployed, your local `kubectl` tool can be used to interact with it.  At some point during the deployment `kubectl` will acquire the login credentials for the cluster and it will be the current context (so any `kubectl` commands you enter will be directed to that cluster by default).

Several items are shown at the end of a successful deployment:
* Azure security advisor recommendations.
	* A new deployment will typically not have anything listed.  Security Advisor runs periodically, and it simply did not have time to generate any recommendations.  When updating an existing cluster, on the other hand, you may see some items appear here.
* Command that configures kubectl to connect to your new Kubernetes cluster.
	* This command was automatically executed; it is provided for information only.
* The name of the resource group that was created during deployment.
	* This is for information only.  You can reference this name when looking at Azure resources, such as from within the Azure Portal.
* The Azure CLI command that can be used to stop the AKS cluster you just deployed.
* The Azure CLI command that can be used to restart the AKS cluster you just deployed.
* The Azure subscription ID under which these resources were created.
* The Azure region in which these resources were created.

## Available Options

Options have data types.  The ones used in this module are:
* string
	* Typical string enclosed by quotes
	* Example
		* `"value"`
* number
	* Integer number; do not quote
	* Example
		* `1234`
* boolean
	* true or false (not quoted)
* map of string
	* List of key/value pairs, delimited by commas
	* Both key and value should be a quoted string
	* Entire map is enclosed by braces
	* Example with two key/value pairs
		* `{"key1" = "value1", "key2" = "value2"}`
	* Empty value is `{}`
* list of string
	* List of values, delimited by commas
	* A value is a quoted string
	* Entire list is enclosed in brackets
	* Example with two values
		* `["value1", "value2"]`
	* Empty value is `[]`

The following options should be set in your `terraform.tfvars` file (or entered interactively, if you choose to not create a file).  Only a few of them have default values (as noted); the rest are required.  The 'Updateable' column indicates whether, for any given option, it is possible to successfully apply the update against an already-running HPCC k8s cluster.

|Option|Type|Description|Updatable|
|:-----|:---|:----------|:-------:|
| `admin_email` | string  | Email address of the administrator of this HPCC Systems cluster. | Y |
| `admin_ip_cidr_map` | map of string  | Map of name => CIDR IP addresses that can administrate this AKS. To add no additional CIDR addresses, use `{}`. The corporate network and your current IP address will be added automatically, and these addresses will have access to the HPCC cluster as a user.  ***This is OPTIONAL, defaulting to an empty string map.*** | Y |
| `admin_name` | string  | Name of the administrator of this HPCC Systems cluster. | Y |
| `admin_username` | string  | Username of the administrator of this HPCC Systems cluster. | N |
| `azure_region` | string  | The Azure region abbreviation in which to create these resources. Must be one of ["eastus", "eastus2", "centralus"]. | N |
| `enable_code_security` | boolean  | Enable code security? If true, only signed ECL code will be allowed to create embedded language functions, use PIPE(), etc. | Y |
| `enable_elk` | boolean  | Enable ELK (Elasticsearch, Logstash, and Kibana) Stack? This will also expose port 5601 on the cluster. | Y |
| `enable_premium_storage` | boolean  | If true, premium ($$$) storage will be used for the following storage shares: Dali.  Requires that `storage_account_name` and `storage_account_resource_group_name` are also set. ***OPTIONAL, defaults to false.*** | N |
| `enable_rbac_ad` | boolean  | Enable RBAC and AD integration for AKS? This provides additional security for accessing the Kubernetes cluster and settings (not HPCC Systems' settings). Recommended value: true | N |
| `enable_roxie` | boolean | Enable ROXIE? This will also expose port 8002 on the cluster. | Y |
| `extra_tags` | map of string  | Map of name => value tags that can will be associated with the cluster. To add no additional tags, use `{}`. ***This is OPTIONAL, defaulting to an empty string map.*** | Y |
| `hpcc_user_ip_cidr_list` | list of string  | List of explicit CIDR addresses that can access this HPCC Systems cluster. To allow public access, specify "0.0.0.0/0". To add no CIDR addresses, use `[]`.  ***This is OPTIONAL, defaulting to an empty string list.*** | Y |
| `hpcc_version` | string | The version of HPCC Systems to install. Only versions in nn.nn.nn format are supported, and the version must be 8.6.0 or higher. | Y |
| `max_node_count` | number  | The maximum number of VM nodes to allocate for the HPCC Systems node pool. Must be 2 or more. | N |
| `node_size` | string  | The VM size for each node in the HPCC Systems node pool. Recommend "Standard\_B4ms" or better. See [https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-general](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-general) for more information. | N |
| `product_name` | string | Abbreviated product name, suitable for use in Azure naming. Must be 2-23 characters in length, all lowercase or numeric characters. | N |
| `storage_account_name` | string  | If you are attaching to an existing storage account, put its name here. Leave as an empty string if you do not have a storage account. If you put something here then you must also define a resource group for the storage account. See [Persistent Storage](#persistent_storage), below.  ***This is OPTIONAL, defaulting to an empty string.*** | N |
| `storage_account_resource_group_name` | string  | If you are attaching to an existing storage account, put its resource group name here. Leave as an empty string if you do not have a storage account. If you put something here then you must also define a name for the storage account. See [Persistent Storage](#persistent_storage), below.  ***This is OPTIONAL, defaulting to an empty string.*** | N |
| `storage_data_gb` | number  | The amount of storage reserved for data in gigabytes. Must be 1 or more. If a storage account is defined (see below) then this value is ignored. | Y |
| `storage_lz_gb` | number  | The amount of storage reserved for the landing zone in gigabytes. Must be 1 or more. If a storage account is defined (see below) then this value is ignored. | Y |
| `thor_max_jobs` | number  | The maximum number of simultaneous Thor jobs allowed. Must be 1 or more. | Y |
| `thor_num_workers` | number | The number of Thor workers to allocate. Must be 1 or more. | Y |

<a name="persistent_storage"></a>
## Persistent Storage

By default, this module creates an HPCC cluster that uses ephemeral storage.  That means that all storage associated with the cluster lives only as long as the Kubernetes cluster lives.  When the storage goes away, so does all of your data.

Persistent storage, where your data will live beyond the lifetime of the Kubernetes cluster, is available.  This is accomplished by creating an Azure storage account prior to running this module, then giving this module the information needed for it to find and use that storage account.

To make the creation of such a storage account easier, another Terraform module is available at [https://github.com/dcamper/terraform-azurerm-hpcc-storage](https://github.com/dcamper/terraform-azurerm-hpcc-storage).  Its setup and use is similar to this module.  Once you define your storage account, enter the appropriate values for `storage_account_name` and `storage_account_resource_group_name` when running this module.

**Note:**  For performance reasons, it is best to create both the storage account and this HPCC cluster in the same Azure region.

## Recommendations

* Do create a `terraform.tfvars` file.  Terraform automatically uses it for `terraform apply` and `terraform plan` commands.  If you don't name it exactly that name, you can supply the filename with a `-var-file` option but you will have to remember to always cite that file for the future (if you want to update the cluster, or destroy it).  It is easier to just let Terraform find the file.
	* If you don't create a .tfvars file at all and just let Terraform prompt you for the options, then updating or destroying an existing cluster will be *much* more difficult (you will have to reenter everything).
* Do not use the same repo clone for different concurrent deployments.
	* Terraform creates state files (*.tfstate) that represent what thinks reality is.  If you try to manage multiple clusters, Terraform will get confused.
	* For each deployed cluster, re-clone the repo to a different directory on your local system.

## Useful Things

* Useful `kubectl` commands once the cluster is deployed:
	* `kubectl get pods`
		* Shows Kubernetes pods for the current cluster.
	* `kubectl get services`
		* Show the current services running on the pods on the current cluster.
	* `kubectl config get-contexts`
		* Show the saved kubectl contexts.  A context contains login and reference information for a remote Kubernetes cluster.  A kubectl command typically relays information about the current context.
	* `kubectl config use-context <ContextName>`
		* Make \<ContextName\> context the current context for future kubectl commands.
	* `kubectl config unset contexts.<ContextName>`
		* Delete context named \<ContextName\>.
		* Note that when you delete the current context, kubectl does not select another context as the current context.  Instead, no context will be current.  You must use `kubectl config use-context <ContextName>` to make another context current.
	* `kubectl get services | grep eclwatch | awk '{match($5,/[0-9]+/); print "ECL Watch: " $4 ":" substr($5, RSTART, RLENGTH)}'`
		* Echos the URL for ECL Watch for a just-deployed cluster.  This assumes that everything is running well.
* Note that `terraform destroy` does not delete the kubectl context.  You need to use `kubectl config unset contexts.<ContextName>` to get rid of the context from your local system.
* If a deployment fails and you want to start over, you have two options:
	* Immediately issue a `terraform destroy` command and let Terraform clean up.
	* Clean up the resources by hand:
		* Delete the Azure resource group manually, such as through the Azure Portal.
			* Note that there are two resource groups, if the deployment got far enough.  Examples:
				* `app-dantest-sandbox-eastus2`
				* `MC_app-dantest-terraform-eastus2-dcamper-default`
			* The first one contains the Kubernetes service that created the second one (services that support Kubernetes).  So, if you delete only the first resource group, the second resource group will be deleted automatically.
		* Delete all Terraform state files using `rm *.tfstate*`
	* Then, of course, fix whatever caused the deployment to fail.
* If want to completely reset Terraform, issue `rm -rf .terraform* *.tfstate*` and then `terraform init`.
* If you are using a storage account and the storage account's file share quotas change, the easiest way to make the currently-running HPCC see the new values is to recreate it.  To recreate HPCC, tell Terraform during apply:  `terraform apply -replace="helm_release.hpcc"`
	* Bonus:  This technique works if HPCC gets into a weird state and you basically need to restart it (but note that you will likely get new IP addresses in the process).
