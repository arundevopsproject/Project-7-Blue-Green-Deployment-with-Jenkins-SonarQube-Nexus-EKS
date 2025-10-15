output "cluster_id" {
  value = aws_eks_cluster.engee.id
}

output "node_group_id" {
  value = aws_eks_node_group.engee.id
}

output "vpc_id" {
  value = aws_vpc.engee_vpc.id
}

output "subnet_ids" {
  value = aws_subnet.engee_subnet[*].id
}

