admin = {
  name  = "dcamper"
  email = "dan.camper@lexisnexisrisk.com"
}

api_server_authorized_ip_ranges = {
  "alpharetta" = "66.241.32.0/19"
  "boca"       = "209.243.48.0/20"
  "arjuna"     = "137.119.84.121/32"
  # Your current public IP will be appended
}

metadata = {
  project             = "play"
  product_name        = "play"
  business_unit       = "infra"
  environment         = "sandbox"
  market              = "us"
  product_group       = "play"
  resource_group_type = "app"
  sre_team            = "solutionslab"
  subscription_type   = "dev"
}

tags = { "justification" = "testing" }

resource_group = {
  unique_name = false
  location    = "eastus2"
}

node_pools = {
  system = {
    vm_size             = "Standard_B2s"
    node_count          = 1
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 2
  }

  addpool1 = {
    vm_size             = "Standard_B4ms"
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 2
  }

  addpool2 = {
    vm_size             = "Standard_B4ms"
    enable_auto_scaling = true
    min_count           = 0
    max_count           = 2
  }
}

hpcc = {
  version   = "8.2.16"
  namespace = "default"
  name      = "myhpcck8s"
  # chart     = ""
  values    = ["./customizations/esp.yaml", "./customizations/roxie.yaml"]
}

storage = {
  storage_account_name = ""
  resource_group_name  = ""
  # subscription_id     = ""
  # chart  = ""
  values = ["./customizations/storage.yaml"]
}

elk = {
  enable = false
  name   = "myhpccelk"
  # chart  = ""
  # values = ""
}

expose_services = true
auto_connect = true

# Optional Attributes
# -------------------
# expose_services - Expose ECLWatch and ELK to the internet. This can be unsafe and may not be supported by your organization. 
# Setting this to true can cause eclwatch service to stick in a pending state. Only use this if you know what you are doing.
# Example: expose_services = true

# image_root - Root of the image other than hpccsystems
# Example: image_root = "foo"

# image_name - Name of the image other than platform-core
# Example: image_name = "bar"

# image_version - Version of the image
# Example: image_version = "bar"

# auto_connect - Automatically connect to the kubernetes cluster from the host machine.
# Example: auto_connect = true 

# disable_helm - Disable Helm deployments by Terraform. This is reserved for experimentation with other deployment tools like Flux2.
# Example: disable_helm = false 

# disable_naming_conventions - Disable naming conventions
# Example: disable_naming_conventions = true 
