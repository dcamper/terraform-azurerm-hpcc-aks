
# Abbreviated product name, suitable for use in Azure naming.
# Must be 2-24 characters in length, all lowercase, no spaces, only dashes for punctuation.
# Example entry: my-product
product_name="play"

# The version of HPCC Systems to install.
# Only versions in nn.nn.nn format are supported.
hpcc_version="8.2.18"

# Enable ROXIE?
# This will also expose port 8002 on the cluster.
# Example entry: false
enable_roxie=false

# Enable ELK (Elasticsearch, Logstash, and Kibana) Stack?
# This will also expose port 5601 on the cluster.
# Example entry: false
enable_elk=false

# Map of name => value tags that can will be associated with the cluster.
# Format is '{"name"="value" [, "name"="value"]*}'.
# The 'name' portion must be unique.
# To add no tags, enter '{}'.
extra_tags={}

# The VM size for each node in the HPCC Systems node pool.
# Recommend "Standard_B4ms" or better.
# See https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-general for more information.
node_size="Standard_B4ms"

# The maximum number of VM nodes to allocate for the HPCC Systems node pool.
# Must be 2 or more.
max_node_count=2

# Email address of the administrator of this HPCC Systems cluster.
# Example entry: jane.doe@hpccsystems.com
admin_email="dan.camper@lexisnexisrisk.com"

# Name of the administrator of this HPCC Systems cluster.
# Example entry: Jane Doe
admin_name="Dan S. Camper"

# Username of the administrator of this HPCC Systems cluster.
# Example entry: jdoe
admin_username="dcamper"

# The Azure region abbreviation in which to create these resources.
# Must be one of ["eastus2", "centralus"].
# Example entry: eastus2
azure_region="centralus"

# Map of name => CIDR IP addresses that can access the cluster.
# Format is '{"name"="cidr" [, "name"="cidr"]*}'.
# The 'name' portion must be unique.
# To add no CIDR addresses, enter '{}'.
# The corporate network and your current IP address will be added automatically.
authorized_ip_cidr={"arjuna" = "107.213.192.91/32", "bahar" = "68.23.85.231/32", "tombolo" = "3.84.118.57/32"}

# If you are attaching to an existing storage account, enter its name here.
# Leave as an empty string if you do not have a storage account.
# If you enter something here then you must also enter a resource group for the storage account.
# Example entry: my-product-sa
storage_account_name=""

# If you are attaching to an existing storage account, enter its resource group name here.
# Leave as an empty string if you do not have a storage account.
# If you enter something here then you must also enter a name for the storage account.
storage_account_resource_group_name=""
