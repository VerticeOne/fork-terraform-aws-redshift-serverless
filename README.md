# AWS - Redshift Serverless - Terraform Module
Terraform module for creating Redshift Serverless Clusters (AutomateTheCloud model)

***

## Usage
```hcl
module "redshift_serverless" {
  source    = "../"

  details = {
    scope       = "Demo"
    purpose     = "Redshift Serverless"
    environment = "dev"
    additional_tags = {
      "Project"   = "Project Name"
      "ProjectID" = "123456789"
      "Contact"   = "David Singer - david.singer@example.com"
    }
  }

  name    = "demo-redshift-serverless-dev"
  db_name = "demo"

  encryption = {
    enabled = true
    # kms_key_id = "alias/data"
  }

  port = 5439

  credentials = {
    master = {
      username = "test"
      # password = "test1234"
    }
  }
  
  base_capacity = null
  enhanced_vpc_routing = true
  publicly_accessible = false

  security_group_rules = [
    {
      source      = "10.0.0.0/8"
      description = "CIDR Test"
    }
  ]

  permissions = {
    athena = {
      enabled = true
    }
    s3 = {
      read = {
        all = true
        bucket_arns = [
          "arn:aws:s3:::udw-warehouse-dev",
          "arn:aws:s3:::udw-warehouse-test",
          "arn:aws:s3:::udw-warehouse-qa",
          "arn:aws:s3:::udw-warehouse-prd",
        ]
      }
      write = {
        bucket_arns = [
          "arn:aws:s3:::udw-staging-dev",
          "arn:aws:s3:::udw-staging-test",
          "arn:aws:s3:::udw-staging-qa",
          "arn:aws:s3:::udw-staging-prd",
        ]
      }
    }
  }

  vpc_id = "vpc-0ba12df8e07227277"
  subnet = {
    network_tag = "private"
    # ids = ["subnet-0e087adc52d800da3"]
  }
}
```

***

## Inputs
| Name | Description | Type | Default |
|------|-------------|:----:|:-------:|
| `base_capacity` | Base Capacity | `number` | `8` |
| `credentials` | Credentials | `any` | |
| `db_name` | Database Name | `string` | |
| `encryption` | Encryption | `any` | |
| `enhanced_vpc_routing` | Enhanced VPC Routing | `bool` | `true` |
| `name` | Name | `string` | |
| `permissions` | Permissions | `any` | |
| `port` | Port | `number` | `5439` |
| `publicly_accessible` | Publicly Accessible | `bool` | `false` |
| `security_group_rules` | Security Group Rules | `any` | |
| `subnet` | Subnet Info | `any` | |
| `vpc_id` | VPC ID | `string` | |

## Inputs (Details)
| Name | Description | Type | Default |
|------|-------------|:----:|:-------:|
| `details.scope` | (Required) Scope Name - What does this object belong to? (Organization Name, Project, etc) | `string` | |
| `details.scope_abbr` | (Optional) Scope [Abbreviation](#Abbreviations) Override | `string` | |
| `details.purpose` | (Required) Purpose Name - What is the purpose or function of this object, or what does this object serve? | `string` | |
| `details.purpose_abbr` | (Optional) Purpose [Abbreviation](#Abbreviations) Override | `string` | |
| `details.environment` | (Required) Environment Name | `string` | |
| `details.environment_abbr` | (Optional) Environment [Abbreviation](#Abbreviations) Override | `string` | |
| `details.additional_tags` | (Optional) [Additional Tags](#Additional-Tags) for resources | `map` | `[]` |

***

## Outputs
All outputs from this module are mapped to a single output named `metadata` to make it easier to capture all of the relevant metadata that would be useful when referenced by other stacks (requires only a single output reference in your code, instead of dozens!)

| Name | Description |
|:-----|:------------|
| `details.scope.name` | Scope name |
| `details.scope.abbr` | Scope abbreviation |
| `details.scope.machine` | Scope machine-friendly abbreviation |
| `details.purpose.name` | Purpose name |
| `details.purpose.abbr` | Purpose abbreviation |
| `details.purpose.machine` | Purpose machine-friendly abbreviation |
| `details.environment.name` | Environment name |
| `details.environment.abbr` | Environment abbreviation |
| `details.environment.machine` | Environment machine-friendly abbreviation |
| `details.tags` | Map of tags applied to all resources |
| `aws.account.id` | AWS Account ID |
| `aws.region.name` | AWS Region name, example: `us-east-1` |
| `aws.region.abbr` | AWS Region four letter abbreviation, example: `use1` |
| `aws.region.description` | AWS Region description, example: `US East (N. Virginia)` |
| `iam.role` | IAM - Role |
| `redshift_serverless.namespace` | Redshift Serverless - Namespace |
| `redshift_serverless.workgroup` | Redshift Serverless - Workgroup |
| `security_group` | Security Group |

***

## Notes

### Abbreviations
* When generating resource names, the module converts each identifier to a more 'machine-friendly' abbreviated format, removing all special characters, replacing spaces with underscores (_), and converting to lowercase. Example: 'Demo - Module' => 'demo_module'
* Not all resource names allow underscores. When those are encountered, the detail identifier will have the underscore removed (test_example => testexample) automatically. This machine-friendly abbreviation is referred to as 'machine' within the module.
* The abbreviations can be overridden by suppling the abbreviated names (ie: scope_abbr). This is useful when you have a long name and need the created resource names to be shorter. Some resources in AWS have shorter name constraints than others, or you may just prefer it shorter. NOTE: If specifying the Abbreviation, be sure to follow the convention of no spaces and no special characters (except for underscore), otherwise resoure creation may fail.

### Additional Tags
* You can specify additional tags for resources by adding to the `details.additional_tags` map.
```
additional_tags = {
  "Example"         = "Extra Tag"
  "Project"         = "Project Name"
  "CostCenter"      = "123456"
}
```

***

## Terraform Versions
Terraform ~> 1.11.0 is supported.

## Provider Versions
| Name | Version |
|------|---------|
| aws | `~> 5.93` |
