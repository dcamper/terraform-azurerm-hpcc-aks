# To have a dns zone and an A record, included in your apply, the following 3
# variables, i.e. 'a_record_name', 'dns_zone_name', and 
# dns_zone_resource_group_name must be set to non-blank or non-null values.
#-----------------------------------------------------------------------------

# Name of the A record, of following dns zone, where the ecl watch ip is placed
# This A record will be created and therefore should not exist in the following
# dns zone.
# Example entry: "my-product". This should be something project specific rather
# than something generic.

a_record_name=""

#-----------------------------------------------------------------------------

# Name of an existing dns zone.
# Example entry: "hpcczone.us-hpccsystems-dev.azure.lnrsg.io"

dns_zone_name=""

#-----------------------------------------------------------------------------

# Name of the resource group of the above dns zone.
# Example entry: "app-dns-prod-eastus2"

dns_zone_resource_group_name=""

#------------------------------------------------------------------------------

# Abbreviated product name, suitable for use in Azure naming.
# Must be 3-16 characters in length, all lowercase letters or numbers, no spaces.
# Value type: string
# Example entry: "my-product"

product_name="sample"

#------------------------------------------------------------------------------

# The version of HPCC Systems to install.
# Only versions in nn.nn.nn format are supported.
# Value type: string

hpcc_version="8.6.14"

#------------------------------------------------------------------------------

# Enable ROXIE?
# This will also expose port 8002 on the cluster.
# Value type: boolean
# Example entry: false

enable_roxie=false

#------------------------------------------------------------------------------

# Enable RBAC and AD integration for AKS?
# This provides additional security for accessing the Kubernetes cluster and settings (not HPCC Systems' settings).
# Value type: boolean
# Recommended value: true
# Example entry: true

enable_rbac_ad=false

#------------------------------------------------------------------------------

# Enable code security?
# If true, only signed ECL code will be allowed to create embedded language functions, use PIPE(), etc.
# Value type: boolean
# Example entry: false

enable_code_security=true

#------------------------------------------------------------------------------

# The number of Thor workers to allocate.
# Must be 1 or more.

thor_num_workers=2

#------------------------------------------------------------------------------

# The maximum number of simultaneous Thor jobs allowed.
# Must be 1 or more.

thor_max_jobs=2

#------------------------------------------------------------------------------

# The amount of storage reserved for the landing zone in gigabytes.
# Must be 1 or more.
# If a storage account is defined (see below) then this value is ignored.

storage_lz_gb=25

#------------------------------------------------------------------------------

# The amount of storage reserved for data in gigabytes.
# Must be 1 or more.
# If a storage account is defined (see below) then this value is ignored.

storage_data_gb=100

#------------------------------------------------------------------------------

# Map of name => value tags that can will be associated with the cluster.
# Format is '{"name"="value" [, "name"="value"]*}'.
# The 'name' portion must be unique.
# To add no tags, use '{}'.
# Value type: map of string

extra_tags={}

#------------------------------------------------------------------------------

# The VM size for each node in the HPCC Systems node pool.
# Recommend "Standard_B4ms" or better.
# See https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-general for more information.
# Value type: string

node_size="Standard_B8ms"

#------------------------------------------------------------------------------

# The maximum number of VM nodes to allocate for the HPCC Systems node pool.
# Must be 2 or more.
# Value type: integer

max_node_count=4

#------------------------------------------------------------------------------

# Email address of the administrator of this HPCC Systems cluster.
# Value type: string
# Example entry: "jane.doe@hpccsystems.com"

admin_email="jane.doe@hpccsystems.com"

#------------------------------------------------------------------------------

# Name of the administrator of this HPCC Systems cluster.
# Value type: string
# Example entry: "Jane Doe"

admin_name="Jane Doe"

#------------------------------------------------------------------------------

# Username of the administrator of this HPCC Systems cluster.
# Value type: string
# Example entry: "jdoe"

admin_username="jdoe"

#------------------------------------------------------------------------------

# The Azure region abbreviation in which to create these resources.
# Must be one of ["eastus", "eastus2", "centralus"].
# Value type: string
# Example entry: "eastus"

azure_region="centralus"

#------------------------------------------------------------------------------

# Map of name => CIDR IP addresses that can administrate this AKS.
# Format is '{"name"="cidr" [, "name"="cidr"]*}'.
# The 'name' portion must be unique.
# To add no CIDR addresses, use '{}'.
# The corporate network and your current IP address will be added automatically, and these addresses will have access to the HPCC cluster as a user.
# Value type: map of string

admin_ip_cidr_map={}

#------------------------------------------------------------------------------

# List of explicit CIDR addresses that can access this HPCC Systems cluster.
# To allow public access, specify "0.0.0.0/0".
# To add no CIDR addresses, use '[]'.
# Value type: list of string

hpcc_user_ip_cidr_list=[]

#------------------------------------------------------------------------------

# If you are attaching to an existing storage account, put its name here.
# Leave as an empty string if you do not have a storage account.
# If you put something here then you must also define a resource group for the storage account.
# Value type: string
# Example entry: "my-product-sa"

storage_account_name=""

#------------------------------------------------------------------------------

# If you are attaching to an existing storage account, put its resource group name here.
# Leave as an empty string if you do not have a storage account.
# If you put something here then you must also define a name for the storage account.
# Value type: string

storage_account_resource_group_name=""

#==============================================================================
# Optional settings
#==============================================================================

# The global image name of the HPCC docker image to deploy.
# Must be one of ["platform-core", "platform-ml", "platform-gnn"].
# Default value: "platform-core"

# hpcc_image_name="platform-core"

#------------------------------------------------------------------------------

# The Kubernetes namespace in which to install the HPCC modules (if enabled).
# Default value: "default"

# hpcc_namespace="default"

#------------------------------------------------------------------------------

# If true, premium ($$$) storage will be used for the following storage shares: Dali.
# OPTIONAL, defaults to false.

enable_premium_storage=false

#------------------------------------------------------------------------------

# If you would like to use htpasswd to authenticate users to the cluster, enter
# the filename of the htpasswd file.  This file should be uploaded to the Azure
# 'dllsshare' file share in order for the HPCC processes to find it.
# A corollary is that persistent storage is enabled.
# An empty string indicates that htpasswd is not to be used for authentication.
# Example entry: "htpasswd.txt"

authn_htpasswd_filename=""
