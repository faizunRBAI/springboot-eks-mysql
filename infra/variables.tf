variable "project_name" {
  description = "Branch-scoped project name — used as a prefix for all resources."
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version (standard support window)."
  type        = string
  default     = "1.33"
}

variable "node_instance_type" {
  description = "EC2 instance type for the EKS managed node group."
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes (HPA headroom)."
  type        = number
  default     = 4
}

variable "db_instance_class" {
  description = "RDS instance class for MySQL."
  type        = string
  default     = "db.t4g.micro"
}

variable "app_replicas" {
  description = "Number of application pod replicas."
  type        = number
  default     = 2
}
