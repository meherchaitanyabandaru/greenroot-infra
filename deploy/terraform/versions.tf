terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Keep state in S3 (create the bucket once by hand, versioned + encrypted):
  #   terraform init -backend-config="bucket=<your-tf-state-bucket>" \
  #                  -backend-config="key=greenroot/prod.tfstate" -backend-config="region=ap-south-1"
  backend "s3" {
    encrypt = true
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = "greenroot"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# CloudFront certificates must live in us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  default_tags {
    tags = {
      Project     = "greenroot"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
