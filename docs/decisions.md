# Architecture and Implementation Decisions

This ADR-lite log records meaningful decisions made during the project, including their context, alternatives, and trade-offs. It describes the current learning implementation, not a production target.

## 1. Split infrastructure from server configuration

**Status:** Accepted  
**Context:** The previous portfolio project built the environment with manual AWS CLI commands and startup scripts.  
**Alternatives:** Put package installation in EC2 user data; let Terraform configure services; or use Terraform for AWS resources and Ansible after instance creation.  
**Decision:** Terraform owns the VPC, routing, security groups, IAM, EC2, endpoints, DHCP, and DNS. Ansible owns packages, service settings, application configuration, and startup. No service installation uses user data.  
**Trade-off:** Clear ownership and repeatable configuration require a separate Ansible run after Terraform and a maintained inventory.

## 2. Use flat Terraform files and local state for this project

**Status:** Accepted for this single-operator portfolio project  
**Context:** The learning focus is Terraform fundamentals for one environment.  
**Alternatives:** Modules plus shared remote state, or flat files plus local state.  
**Decision:** Keep flat `.tf` files and local state, excluded from Git.  
**Trade-off:** Less setup for one operator; no team locking or shared recovery. Modules and remote state remain production follow-up work.

## 3. Use SSM instead of SSH

**Status:** Accepted and verified  
**Context:** All service instances run in a private subnet without public IPs. Ansible still needs host access.  
**Alternatives:** Public IPs and SSH, a bastion, or Systems Manager with Ansible's `aws_ssm` plugin.  
**Decision:** Use SSM for interactive access and Ansible, with the SSM instance policy and `ssm`, `ssmmessages`, and `ec2messages` interface endpoints.  
**Trade-off:** No inbound SSH keys or port 22 are needed, but the SSM agent, IAM, endpoint path, and S3 relay bucket must all work.

## 4. Add an S3 Gateway endpoint

**Status:** Accepted and verified  
**Context:** The Ansible SSM plugin uses S3 for file transfer, while the private subnet has no general internet route.  
**Alternatives:** Permanent NAT or an S3 Gateway endpoint associated with the private route table.  
**Decision:** Use the S3 Gateway endpoint for S3 access.  
**Trade-off:** Private instances can reach S3 without a NAT Gateway, but the endpoint does not provide access to arbitrary internet repositories.

## 5. Install RabbitMQ with Ansible and use temporary NAT for bootstrap

**Status:** Accepted; temporary NAT removed from steady-state code  
**Context:** RabbitMQ is absent from the default AL2023 repositories. Upstream repository access is needed to resolve its package dependencies.  
**Alternatives:** Reuse Project 1's golden AMI, retain a permanent NAT Gateway, or install with Ansible using temporary outbound access.  
**Decision:** Install RabbitMQ from upstream RabbitMQ/Cloudsmith repositories using Ansible. Temporarily add NAT resources for a clean installation, then destroy them and remove the temporary code.  
**Trade-off:** All four services remain managed by Ansible and no NAT remains in the steady-state design. A fresh RabbitMQ instance requires a manual bootstrap and incurs temporary NAT cost.

## 6. Host the PyMySQL wheel in S3

**Status:** Accepted  
**Context:** The MariaDB role needs PyMySQL, unavailable in the configured AL2023 package repositories.  
**Alternatives:** General internet access through permanent NAT, or store the pure-Python wheel in S3 and retrieve it through the Gateway endpoint.  
**Decision:** Fetch the wheel from the artifacts bucket.  
**Trade-off:** Avoids general internet access for this dependency, but requires the artifact to exist at the expected S3 path.

## 7. Run the application on Tomcat 10

**Status:** Accepted and verified  
**Context:** The WAR returned 404 under Tomcat 9 and logs showed a missing Jakarta Servlet class. The WAR includes Spring Web 6.0.11.  
**Alternatives:** Keep Tomcat 9 based on the application's apparent age; use Tomcat 10.1 to match its Jakarta Servlet generation; or use Tomcat 11, whose Servlet generation is too new for this Spring 6.0.x application.  
**Decision:** Use the AL2023 `tomcat10` package after checking the WAR's actual dependencies and supported Servlet versions.  
**Trade-off:** The deployed app starts and returns HTTP 200. A future framework upgrade may require checking compatibility again.

## 8. Use Route 53 private DNS and a DHCP search domain

**Status:** Accepted and verified  
**Context:** The app uses short names `db01`, `mc01`, and `rmq01`; these did not resolve. A private hosted zone alone does not make the OS append its suffix.  
**Alternatives:** Hard-code IPs, edit `/etc/hosts`, or use private Route 53 plus VPC DHCP options.  
**Decision:** Create the `vprofile.internal` private zone and set the VPC DHCP search domain to `vprofile.internal` with AmazonProvidedDNS.  
**Trade-off:** Stable hostnames survive address changes, but DHCP settings apply across the VPC and must be correct along with DNS records.

## 9. Make DNS records depend on instance attributes

**Status:** Accepted and verified after rebuild  
**Context:** Literal IP records remained pointed at old addresses after instance recreation.  
**Alternatives:** Manually update IP strings or use each Terraform instance's `private_ip` attribute.  
**Decision:** Route 53 records reference `aws_instance.<tier>.private_ip`.  
**Trade-off:** Terraform updates records when instances change, avoiding manual edits and stale addresses.

## 10. Render application credentials at deployment time

**Status:** Accepted and verified  
**Context:** The WAR ships development defaults (`admin123` and `test`), while this environment uses Secrets Manager credentials.  
**Alternatives:** Edit the WAR, leave its defaults, or render a fresh properties file after Tomcat expands the archive.  
**Decision:** Use a Jinja2 template to write real credentials into the exploded `WEB-INF/classes/application.properties` directory, owned by `tomcat:tomcat` with mode `0640`.  
**Trade-off:** The WAR remains unchanged and the application receives runtime credentials. The rendered file contains secrets on the instance. Ansible lookups use the control node's AWS credentials, which must be authorized.

## 11. Guard non-idempotent tasks with state checks

**Status:** Accepted and verified  
**Context:** A real second run exposed MariaDB root-authentication changes, a destructive schema re-import, and an unnecessary RabbitMQ GPG-key fetch.  
**Alternatives:** Trust module state handling alone or query preconditions and gate risky work.  
**Decision:** Provide explicit MariaDB login parameters, check whether the schema exists before importing, and check whether the RabbitMQ key is already installed before fetching it.  
**Trade-off:** More tasks, but repeat runs avoid data loss and unnecessary network access. Verify idempotency with an actual second run.

## 12. Record the ALB security group without claiming an ALB is deployed

**Status:** Current code note  
**Context:** Terraform defines `vprofile-alb-sg` and the app security group allows port 8080 from it, but there is no ALB, listener, or target group resource.  
**Decision:** Describe the security group as declared and referenced by the app security group's ingress rule, but note it is not attached to a deployed ALB. Show SSM port forwarding as the verified application access path.  
**Trade-off:** The ingress rule names the ALB security group as its source, but no ALB resource currently exists, so this repository has no public application endpoint.


