provider "tfe" {
  hostname = "${var.tfe_hostname}"
  token    = "${var.tfe_token}"
  version  = "~> 0.4"
}

terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "hashicorp-v2"

    workspaces {
      name = "tfe-policies-example"
    }
  }
}

variable "tfe_token" {}

variable "tfe_hostname" {
  description = "The domain where your TFE is hosted."
  default     = "app.terraform.io"
}

variable "tfe_organization" {
  description = "The TFE organization to apply your changes to."
  default     = "example_corp"
}

data "tfe_workspace_ids" "all" {
  names        = ["*"]
  organization = "${var.tfe_organization}"
}

locals {
  workspaces = "${data.tfe_workspace_ids.all.external_ids}" # map of names to IDs
}


resource "tfe_policy_set" "global" {
  name         = "global"
  description  = "Policies that should be enforced on ALL infrastructure."
  organization = "${var.tfe_organization}"
  global       = true

  policy_ids = [
    "${tfe_sentinel_policy.passthrough.id}",
    #"${tfe_sentinel_policy.aws-block-allow-all-cidr.id}",
    #"${tfe_sentinel_policy.azurerm-block-allow-all-cidr.id}",
    #"${tfe_sentinel_policy.gcp-block-allow-all-cidr.id}",
    #"${tfe_sentinel_policy.aws-restrict-instance-type-default.id}",
    #"${tfe_sentinel_policy.azurerm-restrict-vm-size.id}",
    #"${tfe_sentinel_policy.gcp-restrict-machine-type.id}",
    
  ]
}

resource "tfe_policy_set" "production" {
  name         = "production"
  description  = "Policies that should be enforced on production infrastructure."
  organization = "${var.tfe_organization}"

  policy_ids = [
    "${tfe_sentinel_policy.aws-restrict-instance-type-prod.id}",
    "${tfe_sentinel_policy.allowed-amis.id}",
    "${tfe_sentinel_policy.aws-block-allow-all-cidr.id}",
    "${tfe_sentinel_policy.s3-acl-encryption.id}",
    
    
  ]

  workspace_external_ids = [
    "${local.workspaces["app01-prod"]}",
  ]
}

resource "tfe_policy_set" "development" {
  name         = "development"
  description  = "Policies that should be enforced on development or scratch infrastructure."
  organization = "${var.tfe_organization}"

  policy_ids = [
    "${tfe_sentinel_policy.aws-restrict-instance-type-dev.id}",
    "${tfe_sentinel_policy.no-internet-gateways.id}",
    "${tfe_sentinel_policy.allowed-subnets.id}",
    "${tfe_sentinel_policy.s3-acl-encryption.id}",
  ]

  workspace_external_ids = [
    "${local.workspaces["app01-dev"]}",
  ]
}

resource "tfe_policy_set" "staging" {
  name         = "staging"
  description  = "Policies that should be enforced on staging infrastructure."
  organization = "${var.tfe_organization}"

  policy_ids = [
    "${tfe_sentinel_policy.aws-restrict-instance-type-dev.id}",
    "${tfe_sentinel_policy.no-internet-gateways.id}",
    "${tfe_sentinel_policy.allowed-subnets.id}",
    "${tfe_sentinel_policy.s3-acl-encryption.id}",
  ]

  workspace_external_ids = [
    "${local.workspaces["app01-staging"]}",
  ]
}

resource "tfe_policy_set" "aws-development" {
  name         = "aws-development"
  description  = "Policies that should be enforced on development infrastructure."
  organization = "${var.tfe_organization}"

  policy_ids = [
    "${tfe_sentinel_policy.enforce-tags.id}",
  ]

  workspace_external_ids = [
    "${local.workspaces["hashi-stack"]}",
  ]
}

resource "tfe_policy_set" "sentinel" {
  name         = "sentinel"
  description  = "Policies that watch the watchman. Enforced only on the workspace that manages policies."
  organization = "${var.tfe_organization}"

  policy_ids = [
    "${tfe_sentinel_policy.tfe_policies_only.id}",
  ]

  workspace_external_ids = [
    "${local.workspaces["tfe-policies"]}",
  ]
}

# Test/experimental policies:

resource "tfe_sentinel_policy" "passthrough" {
  name         = "passthrough"
  description  = "Just passing through! Always returns 'true'."
  organization = "${var.tfe_organization}"
  policy       = "${file("./passthrough.sentinel")}"
  enforce_mode = "advisory"
}

# Sentinel management policies:

resource "tfe_sentinel_policy" "tfe_policies_only" {
  name         = "tfe_policies_only"
  description  = "The Terraform config that manages Sentinel policies must not use the authenticated tfe provider to manage non-Sentinel resources."
  organization = "${var.tfe_organization}"
  policy       = "${file("./tfe_policies_only.sentinel")}"
  enforce_mode = "hard-mandatory"
}

# Networking policies:

resource "tfe_sentinel_policy" "aws-block-allow-all-cidr" {
  name         = "aws-block-allow-all-cidr"
  description  = "Avoid nasty firewall mistakes (AWS version)"
  organization = "${var.tfe_organization}"
  policy       = "${file("./aws-block-allow-all-cidr.sentinel")}"
  enforce_mode = "hard-mandatory"
}

resource "tfe_sentinel_policy" "azurerm-block-allow-all-cidr" {
  name         = "azurerm-block-allow-all-cidr"
  description  = "Avoid nasty firewall mistakes (Azure version)"
  organization = "${var.tfe_organization}"
  policy       = "${file("./azurerm-block-allow-all-cidr.sentinel")}"
  enforce_mode = "hard-mandatory"
}

resource "tfe_sentinel_policy" "gcp-block-allow-all-cidr" {
  name         = "gcp-block-allow-all-cidr"
  description  = "Avoid nasty firewall mistakes (GCP version)"
  organization = "${var.tfe_organization}"
  policy       = "${file("./gcp-block-allow-all-cidr.sentinel")}"
  enforce_mode = "hard-mandatory"
}

#Example Policies//----------------------------------------------------

resource "tfe_sentinel_policy" "no-internet-gateways" {
  name         = "no-internet-gateways"
  description  = "Policy to prevent creation of AWS internet gateways"
  organization = "${var.tfe_organization}"
  policy       = "${file("./no-internet-gateways.sentinel")}"
  enforce_mode = "hard-mandatory"
}

resource "tfe_sentinel_policy" "allowed-subnets" {
  name         = "allowed-subnets"
  description  = "Policy to enforce only approved AWS subnets"
  organization = "${var.tfe_organization}"
  policy       = "${file("./allowed-subnets.sentinel")}"
  enforce_mode = "hard-mandatory"
}
#-------------------------------------------------------------------//

# Compute instance policies:

resource "tfe_sentinel_policy" "aws-restrict-instance-type-dev" {
  name         = "aws-restrict-instance-type-dev"
  description  = "Limit AWS instances to approved list (for dev infrastructure)"
  organization = "${var.tfe_organization}"
  policy       = "${file("./aws-restrict-instance-type-dev.sentinel")}"
  enforce_mode = "soft-mandatory"
}

resource "tfe_sentinel_policy" "aws-restrict-instance-type-prod" {
  name         = "aws-restrict-instance-type-prod"
  description  = "Limit AWS instances to approved list (for prod infrastructure)"
  organization = "${var.tfe_organization}"
  policy       = "${file("./aws-restrict-instance-type-prod.sentinel")}"
  enforce_mode = "soft-mandatory"
}

resource "tfe_sentinel_policy" "aws-restrict-instance-type-default" {
  name         = "aws-restrict-instance-type-default"
  description  = "Limit AWS instances to approved list"
  organization = "${var.tfe_organization}"
  policy       = "${file("./aws-restrict-instance-type-default.sentinel")}"
  enforce_mode = "soft-mandatory"
}

resource "tfe_sentinel_policy" "azurerm-restrict-vm-size" {
  name         = "azurerm-restrict-vm-size"
  description  = "Limit Azure instances to approved list"
  organization = "${var.tfe_organization}"
  policy       = "${file("./azurerm-restrict-vm-size.sentinel")}"
  enforce_mode = "soft-mandatory"
}

resource "tfe_sentinel_policy" "gcp-restrict-machine-type" {
  name         = "gcp-restrict-machine-type"
  description  = "Limit GCP instances to approved list"
  organization = "${var.tfe_organization}"
  policy       = "${file("./gcp-restrict-machine-type.sentinel")}"
  enforce_mode = "soft-mandatory"
}

#Example policy//--------------------------------------------------------

resource "tfe_sentinel_policy" "allowed-amis" {
  name         = "allowed-amis"
  description  = "Policy to enforce only approved ami's"
  organization = "${var.tfe_organization}"
  policy       = "${file("./allowed-amis.sentinel")}"
  enforce_mode = "hard-mandatory"
}
#------------------------------------------------------------------------//

# Storage Policies: 

#Example policy//---------------------------------------------------------

resource "tfe_sentinel_policy" "s3-acl-encryption" {
  name         = "s3-acl-encryption"
  description  = "Policy for acl & s3 buckets server side encryption"
  organization = "${var.tfe_organization}"
  policy       = "${file("./s3-acl-encryption.sentinel")}"
  enforce_mode = "hard-mandatory"
}
#--------------------------------------------------------------------------//

# Tag Policies

resource "tfe_sentinel_policy" "enforce-tags" {
  name         = "enforce-tags"
  description  = "Policy to enforce instances have tags"
  organization = "${var.tfe_organization}"
  policy       = "${file("./enforce-tags.sentinel")}"
  enforce_mode = "hard-mandatory"
}
