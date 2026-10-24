variable "region" {
  description = "AWS region. ap-south-1 (Mumbai) keeps data in India and close to users."
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "production or staging (also APP_ENV)."
  type        = string
  default     = "production"
  validation {
    condition     = contains(["production", "staging"], var.environment)
    error_message = "environment must be production or staging."
  }
}

variable "domain" {
  description = "Root domain, e.g. greenroot.in. Creates api.<domain>, admin.<domain>, files.<domain>."
  type        = string
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone for var.domain. Empty = you create the DNS records yourself (see outputs)."
  type        = string
  default     = ""
}

variable "alarm_email" {
  description = "Email that receives CloudWatch alarms (confirm the SNS subscription mail)."
  type        = string
}

variable "instance_type" {
  description = "API host. t4g.small (2 vCPU, 2 GB, Graviton) runs API + Redis + Caddy comfortably at launch."
  type        = string
  default     = "t4g.small"
}

variable "db_instance_class" {
  description = "RDS class. db.t4g.micro is the cheapest; move to db.t4g.small when CPU credits run low."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Initial RDS storage (GB); grows automatically up to db_max_allocated_storage."
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  type    = number
  default = 100
}

variable "db_multi_az" {
  description = "Standby in a second AZ (doubles the DB cost). Off at launch; PITR covers data loss."
  type        = bool
  default     = false
}

variable "db_backup_retention_days" {
  description = "Automated backups + point-in-time recovery window."
  type        = number
  default     = 14
}

variable "logical_backup_retention_days" {
  description = "Daily pg_dump copies kept in S3 (off the database host)."
  type        = number
  default     = 35
}

variable "log_retention_days" {
  type    = number
  default = 90
}

variable "api_image_tag" {
  description = "Image tag the host runs (deploy.sh updates it on each release)."
  type        = string
  default     = "latest"
}

variable "github_repository" {
  description = "owner/repo allowed to push API images to ECR via GitHub OIDC (empty = no CI role)."
  type        = string
  default     = "meherchaitanyabandaru/greenroot-api"
}

variable "admin_allowed_cidrs" {
  description = "Optional: CIDRs allowed to use ADMIN accounts (office/VPN). Empty = anywhere."
  type        = list(string)
  default     = []
}
