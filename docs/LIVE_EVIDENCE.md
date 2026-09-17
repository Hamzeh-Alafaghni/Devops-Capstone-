# Live deployment evidence

Status: in progress on 2026-09-17. Do not treat pending items as completed.

## Account and resource preservation

- AWS account: `678419966897`; region: `us-east-1`.
- Repository: `Hamzeh-Alafaghni/Devops-Capstone-` (trailing hyphen required).
- Existing VPC `vpc-0b16400807d701b71` and its internet gateway are read-only data sources.
- Four new subnet ranges: `10.0.10.0/24` through `10.0.13.0/24`.
- Existing `k3s-workers-asg`, its workers, and `ecommerce-db` remain outside the new Terraform state.
- The existing database is in a different VPC and has not been changed or migrated.
- Bootstrap apply: 6 added, 0 changed, 0 destroyed.
- Application plan: 51 to add, 0 to change, 0 to destroy.
- Remote state: encrypted/versioned S3 with a DynamoDB lock table.

## Checks

- [x] Local Compose images, PostgreSQL, smoke and concurrency regressions.
- [x] Terraform validation and both mock-provider tests.
- [x] Workflow lint, Bash syntax and 12 Kubernetes schema checks.
- [x] GitHub variables and environment restrictions configured.
- [ ] Application Terraform apply completed.
- [ ] SSM access, NAT connectivity and k3s nodes ready.
- [ ] Self-hosted deployment runner registered and online.
- [ ] Real main commit passes CI, Terraform and CD.
- [ ] ALB target health and public application smoke test.
- [ ] HPA scales under measured request load.
- [ ] Demo evidence captured and new application resources torn down.

Bootstrap state remains in `terraform/bootstrap/terraform.tfstate` and must not be committed.
