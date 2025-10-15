# Project-7-Blue-Green-Deployment-with-Jenkins-SonarQube-Nexus-EKS

Project Overview
Infrastructure:

Four EC2 instances manually launched for:

Main Server
Jenkins
SonarQube
Nexus
Terraform (from GitHub) provisions the EKS cluster on AWS.

Key Features
Zero Downtime → Users stay connected even during deployments.
Blue-Green Rollouts → Deploy to idle (Green) environment, then switch traffic from Blue.
Safe Rollbacks → Roll back instantly by redirecting traffic back to Blue.
CI/CD Automation → Jenkins handles build, test, and deployment pipelines.
Quality Gates → SonarQube ensures only clean, maintainable code is deployed.
Artifact Management → Nexus stores and versions all build outputs.
Tools & Technologies
AWS EC2 → Servers for Jenkins, Nexus, SonarQube, and Main server
Terraform → Infrastructure as Code for AWS EKS
AWS EKS (Kubernetes) → Container orchestration for Blue/Green deployments
Jenkins → CI/CD automation server
SonarQube → Code quality and static analysis
Nexus → Artifact repository manager
Route 53 → DNS management for custom domain mapping
Architecture
Architecture Diagram

