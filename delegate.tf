# Fetch AWS account details
data "aws_caller_identity" "current" {}

# Fetch AWS EKS Cluster Details (AFTER creation)
data "aws_eks_cluster" "eks" {
  name       = aws_eks_cluster.eks.name
  depends_on = [aws_eks_cluster.eks]
}

# Get AWS EKS Cluster Authentication (for kubectl access)
data "aws_eks_cluster_auth" "eks" {
  name       = aws_eks_cluster.eks.name
  depends_on = [aws_eks_cluster.eks]
}

# Kubernetes Provider (Using AWS EKS Cluster Authentication)
provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

# Helm Provider (Using AWS EKS Authentication)
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.eks.endpoint
    token                  = data.aws_eks_cluster_auth.eks.token
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  }
}

# Wait for EKS Cluster and Node Group to be ready
resource "time_sleep" "wait_for_nodes" {
  depends_on       = [aws_eks_cluster.eks, aws_eks_node_group.eks_nodes]
  create_duration  = "30s"
}

# Deploy Harness Delegate Module (AFTER EKS Cluster is Ready)
module "delegate" {
  source          = "harness/harness-delegate/kubernetes"
  version        = "0.1.8"

  account_id      = "ucHySz2jQKKWQweZdXyCog"
  delegate_token  = "NTRhYTY0Mjg3NThkNjBiNjMzNzhjOGQyNjEwOTQyZjY="
  delegate_name   = "terraform-delegate"
  deploy_mode     = "KUBERNETES"
  namespace       = "harness-delegate-ng"
  manager_endpoint = "https://app.harness.io"
  delegate_image  = "harness/delegate:25.02.85300"
  replicas        = 1
  upgrader_enabled = true

  depends_on      = [
    aws_eks_cluster.eks, 
    aws_eks_node_group.eks_nodes,
    time_sleep.wait_for_nodes
  ]
}
