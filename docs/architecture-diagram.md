# Implemented architecture

```mermaid
flowchart TB
  browser[Browser] --> alb[Public ALB HTTP :80]
  subgraph vpc[VPC across two availability zones]
    subgraph public[Public subnets]
      alb
      nat[NAT EC2 instance]
      igw[Internet gateway]
      nat --> igw
    end
    subgraph private[Private subnets]
      cp[k3s control plane + deployment runner]
      workers[Worker ASG: desired 2, maximum 4]
      traefik[Traefik NodePort :30080]
      alb --> workers --> traefik
      traefik --> auth[auth-service :5001]
      traefik --> catalog[catalog-service :5002]
      traefik --> orders[orders-service :5003]
      traefik --> frontend[Nginx React frontend :80]
      orders -->|authenticated stock changes| catalog
      auth --> db[(RDS PostgreSQL 15)]
      catalog --> db
      orders --> db
      cp --> workers
      cp --> nat
      workers --> nat
    end
  end
  github[GitHub Actions] -->|OIDC| ci[Hosted CI: test and build]
  ci --> ecr[Four ECR repositories: SHA tags]
  github -->|OIDC| tf[Terraform plan/apply]
  tf --> state[(S3 state + DynamoDB lock)]
  tf --> vpc
  github -->|trusted successful main push| cp
  ecr --> workers
  secrets[Secrets Manager: RDS-managed password] -->|hourly sync| cp
  cp -->|Kubernetes Secrets| auth
  cp -->|Kubernetes Secrets| catalog
  cp -->|Kubernetes Secrets| orders
```

All application resources are in namespace `marketly`. HPA controls 2–4 orders
replicas using CPU metrics. One shared signing key supports local JWT verification
and authenticated inventory updates. Database credentials are injected at deployment
and refreshed by a systemd timer; ECR pull credentials refresh hourly.

The root module composes all eight required modules. Nodes have no public IPs or
SSH rules and use SSM for operator access. Workers are registered automatically
with the ALB target group through the ASG attachment. Traefik uses cluster-wide
service routing, so NodePort traffic can reach pods on another node.

This diagram describes the configuration, not proof of a live deployment.
`aws-architecture.svg` and `.png` remain the original assignment reference;
this Markdown diagram is the current implementation source of truth. RDS native
backups are configured; separate S3 database exports are not implemented.

For the recorded deployment, the existing capstone VPC and internet gateway
were reused as read-only data sources because the region's VPC quota was full.
Terraform created isolated subnet ranges `10.0.10.0/24`–`10.0.13.0/24` and
separate route tables/security groups. The original workers and database remain
outside this state. See `LIVE_EVIDENCE.md` for deployment and teardown records.
