# PROGRESS.md — iac-terraform-ansible (Project 2)

## Project

Infrastructure-as-Code implementation of the VProfile stack using Terraform (infrastructure provisioning) and Ansible (configuration management).

Automates the same VPC, EC2, IAM, and service configuration built manually in Project 1 (`aws-lift-and-shift`), replacing approximately 40 manual AWS CLI commands and userdata scripts with declarative, reproducible code.

## Portfolio Context

This is Project 2 of 5 planned portfolio projects.

Portfolio sequence:

- ✅ Project 1 — `aws-lift-and-shift` (CLOSED)
- 🟢 Project 2 — `iac-terraform-ansible` (CURRENT)
- Project 3 — `cicd-pipeline-vprofile`
- Project 4 — `aws-paas-migration`
- Project 5 — `k8s-gitops-vprofile`

The full roadmap and project rationale live in the master portfolio prompt. This file records only the implementation state of Project 2.

## Current Phase

**Phase 1 — Terraform Foundation: NOT YET STARTED**

Planning and architecture decisions are approved. No AWS infrastructure has been provisioned yet.

## Project Baseline

Project 2 intentionally reproduces the **verified architecture from Project 1** before introducing Infrastructure-as-Code improvements.

The goal is feature parity first, automation second:

- Same networking architecture.
- Same IAM model.
- Same four application services.
- Same Secrets Manager integration.
- Same security group boundaries.

Architectural improvements (modules, remote state, ALB, Interface VPC Endpoints, Route 53, etc.) are treated as later enhancements rather than changing the baseline implementation.

## Key Decisions

### Infrastructure Decisions

- Terraform provisions AWS infrastructure.
- Ansible configures operating systems and application services.
- No userdata scripts for service installation; configuration happens through Ansible roles after instance creation.
- Local Terraform state (`terraform.tfstate`) for portfolio simplicity; S3 remote backend documented later as the production alternative.
- Flat Terraform files first; modular refactor deferred until fundamentals are complete.
- Project 1 EC2 instances will be terminated instead of imported into Terraform state.
- No ALB or Interface VPC Endpoints during Phase 1 scope.

### Security Decisions

- Reuse Project 1 Secrets Manager secrets:
  - `vprofile/db/admin-password`
  - `vprofile/rmq/test-password`
- No hardcoded credentials committed to the repository.
- Maintain the same least-privilege IAM model established in Project 1.

### Engineering Process Decisions

**Verification-first rule:**

> Nothing is marked COMPLETE until verified against live AWS state or successful tool output.

Implementation alone is not completion. Verification evidence is recorded before updating `PROGRESS.md`.

### Terraform Safety Decisions

- Terraform state remains local for this portfolio project and is excluded from Git.
- Review `terraform plan` before every apply.
- Review and explicitly approve destructive changes before `terraform destroy`.
- Pin Terraform provider versions and commit `.terraform.lock.hcl` when appropriate.
- Record the Terraform version used by the project.

### Terraform / Ansible Boundary

Terraform owns infrastructure:

- VPC
- subnets
- routing
- security groups
- IAM
- EC2

Ansible owns post-boot configuration:

- packages
- service configuration
- application configuration
- service startup
- idempotent changes

No duplicated ownership unless a documented reason exists.

### Ansible Connectivity

Before implementing roles, choose and document the connection method used to reach private EC2 instances.

The connection method must fit the approved AWS architecture and must not introduce public SSH access merely for convenience.

## Completed Work

*No implementation work completed yet.*

Phase 1 begins with repository setup and Terraform networking.

## Implementation Phases

| Phase | Focus | Deliverables |
|-------|-------|-------------|
| Phase 1 | Terraform networking & IAM | VPC, subnets, route tables, Internet Gateway, security groups, IAM roles, successful `terraform validate` and `terraform plan`. |
| Phase 2 | Terraform EC2 infrastructure | MariaDB, Memcached, RabbitMQ, Tomcat instances defined in Terraform. |
| Phase 3 | Terraform apply & verification | Infrastructure created, AWS state verified against Terraform state. |
| Phase 4 | Ansible roles | Roles for MariaDB, Memcached, RabbitMQ, and Tomcat. |
| Phase 5 | Ansible execution & idempotency | Successful playbook execution and zero-change second run verification. |
| Phase 6 | Reproducibility & documentation | Destroy → recreate → verify test, README, architecture, decisions, incidents, and course coverage documentation. |

## Resource Reference

*Populated as Terraform provisions resources.*

### Networking

*To be populated during Phase 1.*

### Security Groups

*To be populated during Phase 1.*

### IAM Roles / Instance Profiles

*To be populated during Phase 1.*

### EC2 Instances

*To be populated during Phase 2.*

### Secrets

Reused from Project 1; no new secrets planned.

## Known Issues

None.

Phase 1 has not started.

## Definition of Done

### Terraform

- [ ] Terraform files written.
- [ ] `terraform fmt` produces clean formatting.
- [ ] `terraform validate` succeeds.
- [ ] `terraform plan` reviewed with expected resources only.
- [ ] `terraform apply` provisions infrastructure successfully.
- [ ] AWS infrastructure matches Terraform state.

### Ansible

- [ ] Roles created for Tomcat, MariaDB, Memcached, RabbitMQ.
- [ ] Inventory configured.
- [ ] Playbook executes successfully.
- [ ] Second execution is idempotent (zero changes).

### Verification

- [ ] All four services healthy.
- [ ] Application reachable.
- [ ] Destroy → recreate → verify reproducibility test completed.

### Documentation

- [ ] `README.md`
- [ ] `architecture.md`
- [ ] `decisions.md`
- [ ] `incidents.md`
- [ ] `course-coverage.md`
- [ ] `PROGRESS.md` finalized.

### Repository

- [ ] Clean Conventional Commit history.
- [ ] No secrets committed.
- [ ] `.terraform/`, Terraform state, and sensitive generated files excluded.
- [ ] End-to-end reproducible workflow with minimal manual steps.
- [ ] Final repository hygiene/cleanup checkpoint completed.

## Repository Status

- [ ] GitHub repository `iac-terraform-ansible` created.
- [ ] Local repository initialized.
- [ ] Directory structure created (`terraform/`, `ansible/`, `docs/`).
- [ ] `.gitignore` configured.
- [ ] Terraform provider/version constraints defined.
- [ ] `.terraform.lock.hcl` generated/committed when appropriate.
- [ ] Initial commit pushed.

## Next Step

### Phase 1 — Terraform Foundation

**IN PROGRESS — paused mid-step, resume here:**

Currently setting up tooling before repo creation. Decided to use GitHub CLI (`gh`)
instead of the web UI for repo creation (more realistic DevOps habit, reusable in
later CI/CD-heavy projects).

- `winget` is not available on this machine (confirmed via PowerShell — command not found).
- Installing `gh` via direct MSI download from https://github.com/cli/cli/releases/latest instead.
- Machine architecture confirmed: **AMD64** (via `echo $env:PROCESSOR_ARCHITECTURE` in PowerShell).
- First download attempt grabbed the wrong asset (`gh_2.100.0_windows_arm64.msi`) — install failed
  with "installation package is not supported by this processor type."
- **Resume point:** download `gh_2.100.0_windows_amd64.msi` (correct arch) from the same releases
  page, install it, close and reopen Git Bash completely (PATH won't update in an already-open
  window), then verify with `gh --version`, then run `gh auth login`.

Once `gh` is working, original Phase 1 steps resume unchanged:

1. Create GitHub repository `iac-terraform-ansible` (via `gh repo create`).
2. Clone into the DevOps workspace on **G:** (`G:\Tutorial Folder\DevOpsTutorials\DevOps Project\`, alongside `aws-lift-and-shift`).
3. Initialize repository structure (`terraform/`, `ansible/`, `docs/`).
4. Configure `.gitignore`.
5. Write Terraform networking files:
   - `main.tf`
   - `variables.tf`
   - `outputs.tf`
   - `security_groups.tf`
   - `iam.tf`
6. Run `terraform fmt`, `terraform validate`, and `terraform plan`.

**No `terraform apply` until the initial plan has been reviewed.**

## Assumptions

- Project 1 (`aws-lift-and-shift`) is fully completed and archived.
- AWS CLI configured for IAM user `gitops-terraform`.
- AWS Region: `us-east-1`.
- AWS Account: `747336059892`.
- Terraform installed locally.
- Ansible installed locally.
- Git Bash is the primary shell environment.

## Notes

See `NOTES.md` for chronological study notes and session checkpoints.
