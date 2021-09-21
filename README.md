# Deploy HPCC Systems on Azure under Kubernetes

This is a slightly-opinionated Terraform module for deploying an HPCC Systems cluster on Azure.  The goal is to provide a simple method for deploying a cluster from scratch, with only the most important options to consider.

The HPCC Systems cluster this module creates uses ephemeral storage (meaning, the storage will be deleted if the cluster is deleted) unless a predefined storage account is cited.  See the `storage_account_name` and `storage_account_resource_group_name` options below.

## Requirements

* This is a Terraform module, so you need to have Terraform installed on your system.  Instructions for downloading and installing Terraform can be found at [https://www.terraform.io/downloads.html](https://www.terraform.io/downloads.html).

* The Kubernetes client (kubectl) is also required so you can inspect and manage the Azure Kubernetes cluster.  Instructions for download and installing that can be found at [https://kubernetes.io/releases/download/](https://kubernetes.io/releases/download/).  Make sure you have version 1.22.0 or later.

* To work with Azure, you will need to install the Azure Command Line tools.  Instructions can be found at [https://docs.microsoft.com/en-us/cli/azure/install-azure-cli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli).

## Installing/Using This Module

1. If necessary, login to Azure.
	* From the command line, this is usually accomplished with the `az login` command.
1. Clone this repo to your local system.
1. Issue `terraform init` to initialize the Terraform modules.
1. Decide how you want to supply option values to the module during invocation.  There are two possibilities:
	1. Invoke the `terraform apply` command and enter values for each option as Terraform prompts for it, then enter `yes` at the final prompt to begin building the cluster.
	1. **Recommended:**  Create a `terraform.tfvars` file containing the values for each option, invoke `terraform apply`, then enter `yes` at the final prompt to begin building the cluster.  The easiest way to create that initial file is to copy the sample at [examples/sample.tfvars](examples/sample.tfvars) and name it `terraform.tfvars`.
1. After the Kubernetes cluster is deployed, your local `kubectl` tool can be used to interact with it.  At some point during the deployment `kubectl` will acquire the login credentials for the cluster and it will be the current context (so any `kubectl` commands you enter will be directed to that cluster by default).

## Available Options

The following options should be set in your `terraform.tfvars` file:

|Option|Description|
|:-----|:----------|
| `product_name` | Abbreviated product name, suitable for use in Azure naming. Must be 2-24 characters in length, all lowercase, no spaces, only dashes for punctuation. Value type: string. Example entry: "my-product" |
| `hpcc_version` | The version of HPCC Systems to install. Only versions in nn.nn.nn format are supported. Value type: string. |
| `enable_roxie` | Enable ROXIE? This will also expose port 8002 on the cluster. Value type: boolean. |
| `enable_elk` | Enable ELK (Elasticsearch, Logstash, and Kibana) Stack? This will also expose port 5601 on the cluster. Value type: boolean. |
| `enable_rbac_ad` | Enable RBAC and AD integration for AKS? This provides additional security for accessing the Kubernetes cluster and settings (not HPCC Systems' settings). Value type: boolean. Recommended value: true |
| `enable_code_security` | Enable code security? If true, only signed ECL code will be allowed to create embedded language functions, use PIPE(), etc. Value type: boolean. |
| `thor_num_workers` | The number of Thor workers to allocate. Must be 1 or more. Value type: number. |
| `thor_max_jobs` | The maximum number of simultaneous Thor jobs allowed. Must be 1 or more. Value type: number. |
| `storage_lz_gb` | The amount of storage reserved for the landing zone in gigabytes. Must be 1 or more.  Value type: number. |
| `storage_data_gb` | The amount of storage reserved for data in gigabytes. Must be 1 or more.  Value type: number. |
| `extra_tags` | Map of name => value tags that can will be associated with the cluster. Format is `{"name"="value" [, "name"="value"]*}`. The `name` portion must be unique. To add no tags, use `{}`. Value type: map of string. |
| `node_size` | The VM size for each node in the HPCC Systems node pool. Recommend "Standard\_B4ms" or better. See [https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-general](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-general) for more information. Value type: string. |
| `max_node_count` | The maximum number of VM nodes to allocate for the HPCC Systems node pool. Must be 2 or more. Value type: number.|
| `admin_email` | Email address of the administrator of this HPCC Systems cluster. Value type: string. |
| `admin_name` | Name of the administrator of this HPCC Systems cluster. Value type: string. |
| `admin_username` | Username of the administrator of this HPCC Systems cluster. Value type: string. |
| `azure_region` | The Azure region abbreviation in which to create these resources. Must be one of ["eastus2", "centralus"]. Value type: string. |
| `admin_ip_cidr_map` | Map of name => CIDR IP addresses that can administrate this AKS. Format is `{"name"="cidr" [, "name"="cidr"]*}`. The `name` portion must be unique. To add no CIDR addresses, use `{}`. The corporate network and your current IP address will be added automatically, and these addresses will have access to the HPCC cluster as a user. Value type: map of string. |
| `hpcc_user_ip_cidr_list` | List of additional CIDR addresses that can access this HPCC Systems cluster. To add no CIDR addresses, enter `[]`. Value type: list of string. |
| `storage_account_name` | If you are attaching to an existing storage account, put its name here. Leave as an empty string if you do not have a storage account. If you put something here then you must also define a resource group for the storage account. Value type: string. |
| `storage_account_resource_group_name` | If you are attaching to an existing storage account, put its resource group name here. Leave as an empty string if you do not have a storage account. If you put something here then you must also define a name for the storage account. Value type: string. |

## Recommendations

* Do create a `terraform.tfvars` file.  Terraform automatically uses it for `terraform apply` and `terraform plan` commands.  If you don't name it exactly that name, you can supply the filename with a `-var-file` option but you will have to remember to always site that file for the future (if you want to update the cluster, or destroy it).  It is easier to just let Terraform find the file.
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
		* Delete all Terraform state files using `rm *.tfstate`
	* Then, of course, fix whatever caused the deployment to fail.
* If want to completely reset Terraform, issue `rm -rf .terraform* *.tfstate*` and then `terraform init`.
