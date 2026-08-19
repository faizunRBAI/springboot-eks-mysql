output "vpc_id" {
  description = "VPC ID (used by the destroy workflow to remove the K8s-created NLB)."
  value       = aws_vpc.main.id
}

output "eks_cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = aws_eks_cluster.main.endpoint
}

output "ecr_repository_url" {
  description = "ECR repository URL (used by the build_push stage)."
  value       = aws_ecr_repository.app.repository_url
}

output "database_jdbc_url" {
  description = "JDBC connection URL consumed by the configure stage."
  value       = "jdbc:mysql://${aws_db_instance.mysql.address}:3306/appdb?useSSL=true&serverTimezone=UTC&characterEncoding=utf8mb4"
  sensitive   = true
}

output "database_username" {
  description = "RDS MySQL username."
  value       = aws_db_instance.mysql.username
  sensitive   = true
}

output "database_password" {
  description = "RDS MySQL password."
  value       = random_password.db.result
  sensitive   = true
}
