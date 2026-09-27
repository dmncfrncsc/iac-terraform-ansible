# Engineering Incidents and Resolutions

This log records actual failures and operational gaps documented in `NOTES.md` and `PROGRESS.md`. Resolutions below reflect the evidence recorded for this project.

## 1. SSM targets were not connected because Terraform selected a minimal AMI

**Date / checkpoint:** Session 9 — 2026-09-19  
**Symptoms and impact:** `aws ssm start-session` returned `TargetNotConnected`; Ansible could not manage the new instances.  
**Diagnostic evidence:** The broad AMI filter matched the newer `al2023-ami-minimal-...` variant, which omitted the SSM agent. IAM, security groups, and VPC endpoints were checked.  
**Root cause:** `most_recent = true` with `al2023-ami-*-x86_64` allowed the minimal image to match.  
**Fix and verification:** Narrowed the filter to `al2023-ami-2023.*-x86_64`, replaced the instances, and verified SSM registration and Ansible connectivity. Session 19's rebuild confirmed the filter selected the standard image.  
**Prevention:** Keep the AMI name filter specific and confirm SSM managed-instance registration before running Ansible.

## 2. Ansible SSM file transfers hung because the private subnet had no S3 route

**Date / checkpoint:** Session 11 — 2026-09-22  
**Symptoms and impact:** Interactive SSM shell access worked, but Ansible's `aws_ssm` connection could not complete the file-transfer path.  
**Diagnostic evidence:** Verbose Ansible output showed a request to a presigned S3 URL hanging. The VPC had SSM interface endpoints but no S3 Gateway endpoint or NAT route.  
**Root cause:** An interactive SSM shell does not exercise Ansible's S3 relay path. The instances could reach SSM but had no route to S3.  
**Fix and verification:** Added an S3 Gateway endpoint associated with the private route table. `ansible -m ping` then succeeded on all four hosts.  
**Prevention:** Verify the S3 relay bucket and private S3 route in addition to basic SSM shell access.

## 3. VProfile returned 404 under Tomcat 9 because the WAR required Jakarta Servlet

**Date / checkpoint:** Session 15 — 2026-09-27  
**Symptoms and impact:** Tomcat was active and the WAR was present, but `/vprofile/` returned 404. Tomcat logged an application listener startup failure.  
**Diagnostic evidence:** The application-level log contained `jakarta.servlet.ServletContextListener` class-loading errors. The WAR included `spring-web-6.0.11.jar`; the relevant trace was in Tomcat's `localhost` log, not the assumed container log.  
**Root cause:** Tomcat 9 provides the older `javax.servlet` API, while the WAR requires Jakarta Servlet classes.  
**Fix and verification:** Switched to Tomcat 10 and reconciled the Ansible role to install `tomcat10`. The service became active and the application returned HTTP 200 at `/vprofile/`.  
**Prevention:** Inspect the WAR's actual dependencies before choosing a container. Verify an application request, not only the service state or WAR file presence.

## 4. Private DNS records existed, but backend short names did not resolve

**Date / checkpoint:** Sessions 15–16 — 2026-09-27  
**Symptoms and impact:** The application used `db01`, `mc01`, and `rmq01`, but those names did not resolve, so the app could not reach its backends.  
**Diagnostic evidence:** A private hosted zone alone did not make instances append its suffix. The VPC still supplied `us-east-1.compute.internal` as the DHCP search domain.  
**Root cause:** Both Route 53 records and a matching VPC DHCP search domain were required.  
**Fix and verification:** Created the `vprofile.internal` private zone and associated DHCP options setting `domain_name = vprofile.internal` and AmazonProvidedDNS. Host resolution and TCP reachability on 3306, 11211, and 5672 were verified from Tomcat.  
**Prevention:** Check the record, VPC association, DHCP search domain, and resolution from the application instance. Test the actual service port; ICMP is not allowed by these security groups.

## 5. RabbitMQ installation needed temporary outbound access

**Date / checkpoint:** Sessions 14 and 19 — 2026-09-27  
**Symptoms and impact:** A clean RabbitMQ host could not fetch the upstream signing key or resolve packages from the RabbitMQ and Erlang repositories.  
**Diagnostic evidence:** The key request timed out against GitHub, and package installation could not reach upstream repositories. The same issue recurred after a full rebuild.  
**Root cause:** The private subnet has no general internet route. RabbitMQ requires live repository and dependency resolution, unlike the single PyMySQL wheel that can be hosted in S3.  
**Fix and verification:** Temporarily added NAT resources, installed RabbitMQ with Ansible, then destroyed the NAT resources and removed their Terraform code. A subsequent normal plan reported no changes. The clean rebuild confirmed the bootstrap is repeatable.  
**Prevention:** Treat temporary outbound access as a documented bootstrap requirement; the current repository does not automate it.

## 6. The WAR's development credentials did not match runtime secrets

**Date / checkpoint:** Session 17 — 2026-09-27  
**Symptoms and impact:** The WAR contained `jdbc.password=admin123` and `rabbitmq.password=test`, while the environment used real Secrets Manager credentials. Leaving the defaults would prevent authentication to the configured services.  
**Diagnostic evidence:** The defaults were confirmed in the WAR. Tomcat reads the exploded application's properties file, so editing the archive after deployment would not change the active configuration.  
**Root cause:** The reference WAR ships development defaults; this deployment needs environment-specific runtime credentials.  
**Fix and verification:** Added a Jinja2 template to the Tomcat role. It writes the rendered properties into the exploded `WEB-INF/classes` directory after waiting for it to exist. The scoped Ansible run succeeded, Tomcat was active, and the app returned HTTP 200. The file was verified as `tomcat:tomcat`, mode `0640`; an unprivileged SSM user could not read it.  
**Prevention:** Keep secret values out of Git and logs, render configuration at deployment time, and verify file permissions. The rendered file contains credentials on the instance.

## 7. Three Ansible tasks were unsafe on repeat runs

**Date / checkpoint:** Session 18 — 2026-09-27  
**Symptoms and impact:** Tasks that passed on first deployment failed, repeated network access, or risked resetting MariaDB data on later runs.  
**Diagnostic evidence and root causes:**

- **MariaDB root authentication:** Setting the root password changed the authentication path. The task only attempted Unix socket authentication on later runs.
- **Schema import:** The schema contains drop/create/insert statements, so an unconditional second import could destroy data.
- **RabbitMQ GPG key:** The URL-backed key task fetched the key on every run, timing out after NAT removal even when the key was already installed.

**Fix and verification:** Added password and user login parameters to the MariaDB root task; added a read-only schema check to gate imports; and checked whether the RabbitMQ key was installed before fetching it. A full second playbook run later returned `changed=0, failed=0` on all four hosts, with the expected guarded-task skips.  
**Prevention:** Verify idempotency with a real second run. Where a module cannot safely check its precondition, query current state and gate the state-changing task.

## 8. Backend connections failed after rebuild because DNS records kept old IPs

**Date / checkpoint:** Sessions 19–20 — 2026-09-27  
**Symptoms and impact:** After destroy/recreate, Tomcat could not connect to MariaDB, Memcached, or RabbitMQ on TCP 3306, 11211, or 5672.  
**Diagnostic evidence:** Backend services were active and listening; DNS resolved; and the expected security-group rules were present. The DNS addresses were from the previous deployment. An early direct-IP diagnostic used an old IP copied from the progress notes, so it did not test the new instances.  
**Root cause:** The three Route 53 records used literal IP strings and had no Terraform dependency on the EC2 instances.  
**Fix and verification:** Changed each record to reference `aws_instance.<tier>.private_ip`. Terraform planned three record updates and no resource additions or destructions. After apply, TCP checks from Tomcat succeeded on all three ports; the full second Ansible run remained idempotent.  
**Prevention:** Reference Terraform resource attributes instead of copying ephemeral addresses. Verify recorded IDs and IPs against current AWS state before using them in diagnostics.

