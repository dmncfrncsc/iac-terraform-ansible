# Course Coverage Matrix

This matrix records course concepts that this project actually implements and verifies; it does not claim coverage of the entire syllabus. Status categories follow the portfolio guidance: **Fully demonstrated**, **Partially demonstrated**, **Not demonstrated**, or **Not portfolio-relevant**.

| Course topic | Project | Implementation | Evidence | Status |
|---|---|---|---|---|
| Terraform Infrastructure as Code | Project 2 | Terraform declares the network, instances, IAM, endpoints, security groups, DHCP options, and DNS. A full destroy/recreate was performed. | `terraform/`; `PROGRESS.md` Phase 6; `NOTES.md` Sessions 1–9, 19–20. | Fully demonstrated |
| Terraform versions, providers, variables, outputs | Project 2 | Version constraints, AWS provider constraint, CIDR/AZ/region variables, and VPC/subnet outputs. | `terraform/versions.tf`, `variables.tf`, `outputs.tf`. | Fully demonstrated |
| VPC, subnets, route tables, Internet Gateway | Project 2 | One VPC, two public subnet routes through an IGW, one private subnet, and no general private-subnet internet route. | `terraform/main.tf`; destroy/recreate evidence in `PROGRESS.md`. | Fully demonstrated |
| EC2, AMI selection, instance profiles | Project 2 | Four AL2023 `t3.micro` instances in the private subnet; AMI filter excludes the minimal variant without SSM agent. | `terraform/ec2.tf`, `iam.tf`; `NOTES.md` Sessions 9 and 19. | Fully demonstrated |
| IAM roles and policies | Project 2 | EC2 role/profile includes SSM, scoped Secrets Manager, and read-only S3 artifact policies. | `terraform/iam.tf`; SSM/Ansible verification in `PROGRESS.md`. | Partially demonstrated — account-specific ARNs remain, and controller lookups need control-node permissions. |
| Security groups and tier boundaries | Project 2 | Backend ports accept ingress from the app SG; SSM endpoint SG accepts HTTPS from service SGs. Egress is unrestricted; an ALB SG exists but no ALB is deployed. | `terraform/security_groups.tf`; `NOTES.md` Sessions 15–16. | Partially demonstrated — inbound is tiered; egress is broad and the ALB path is absent. |
| Systems Manager Session Manager | Project 2 | Private instances use SSM endpoints and the managed instance policy; Ansible connects with `aws_ssm`. | `terraform/main.tf`, `iam.tf`, `ansible/inventory/hosts.yml`; `NOTES.md` Sessions 9–11. | Fully demonstrated |
| S3 artifacts and VPC Gateway endpoint | Project 2 | Private instances access artifact files through the S3 Gateway endpoint; a separate S3 bucket relays Ansible SSM transfers. | `terraform/main.tf`, Ansible role tasks, inventory; `NOTES.md` Session 11. | Fully demonstrated |
| Route 53 private DNS and DHCP options | Project 2 | Private zone and DHCP search domain `vprofile.internal`; DNS records reference current EC2 private IPs. | `terraform/main.tf`, Tomcat application template; `NOTES.md` Sessions 15–16 and 20. | Fully demonstrated |
| Secrets Manager integration | Project 2 | Ansible retrieves DB and RabbitMQ secrets and renders application properties at deployment time. | MariaDB, RabbitMQ, Tomcat role tasks and template; `NOTES.md` Session 17. | Fully demonstrated — rendered secrets exist on the Tomcat host with mode `0640`. |
| Ansible inventory, plays, and roles | Project 2 | Static inventory groups four EC2 instances by tier; playbook applies four service roles. | `ansible/inventory/hosts.yml`, `playbook.yml`, `ansible/roles/`. | Fully demonstrated |
| Ansible templates, handlers, modules, become | Project 2 | Roles use package/service modules, templates, line edits, handlers, S3 tasks, Secrets Manager lookups, and privilege escalation. | `ansible/roles/`; `NOTES.md` Sessions 12 and 17. | Fully demonstrated |
| Ansible idempotency | Project 2 | A full second playbook run reported `changed=0, failed=0`; checks guard the schema import and remote GPG key fetch. | `PROGRESS.md` Phase 5; MariaDB/RabbitMQ task files; `NOTES.md` Session 18. | Fully demonstrated |
| Linux and network troubleshooting | Project 2 | Used service state, logs, DNS, TCP checks, AMI inspection, and SSM diagnostics to locate faults. | `NOTES.md` Sessions 9, 11, 15–20; `PROGRESS.md` Known Issues. | Fully demonstrated |
| NAT Gateway and private outbound access | Project 2 | Temporary NAT was used for RabbitMQ's upstream package bootstrap, then removed from code and state. | `NOTES.md` Sessions 14 and 19; `PROGRESS.md` Key Decisions. | Partially demonstrated — manual bootstrap only; no permanent or automated NAT. |
| Application Load Balancer | Project 2 | Only `vprofile-alb-sg` exists; no ALB, listener, or target group. App verification used SSM port forwarding. | `terraform/security_groups.tf`; `PROGRESS.md` Project Baseline. | Not demonstrated |
| Terraform modules and shared remote state | Project 2 | Flat files and local state are used; refactoring and remote state are deferred. | `terraform/`; `PROGRESS.md` Key Decisions. | Not demonstrated |
| CI/CD | Project 2 | No pipeline is implemented; CI/CD is assigned to the next portfolio project. | Repository has no pipeline configuration; portfolio roadmap. | Not demonstrated |
| High availability / multi-AZ application tier | Project 2 | One instance per service, all in one private subnet/AZ; no autoscaling or failover. | `terraform/ec2.tf`, `variables.tf`. | Not demonstrated |
| GCP services | Project 2 | Current portfolio scope is AWS-focused and excludes GCP unless explicitly added. | Master portfolio prompt. | Not portfolio-relevant |

## Verification limits

Verification uses live infrastructure checks, HTTP requests, and Ansible reruns; the repository has no automated test suite. A concept is marked fully demonstrated only when implementation and evidence are recorded.

