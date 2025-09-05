terraform {
  required_version = "~> 1.11.0"
}

##-----------------------------------------------------------------------------
# Providers
provider "aws" {
  alias  = "example"
  region = "us-east-1"
}

##-----------------------------------------------------------------------------
# Module: Redshift Serverless
module "redshift_serverless" {
  source = "../"

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

  base_capacity        = null
  enhanced_vpc_routing = true
  publicly_accessible  = false

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

##-----------------------------------------------------------------------------
# Outputs
output "metadata" {
  description = "Metadata"
  value       = module.redshift_serverless.metadata
}
