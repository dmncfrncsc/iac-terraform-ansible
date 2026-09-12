# NOTES.md — iac-terraform-ansible (Project 2)

Study notes, chronological by session. Short definitions + real examples from this project.

## Session 1 — 2026-09-09 — Repo Setup

**MinTTY has no PTY support** — Git Bash's terminal (MinTTY) can't run tools that need
an interactive pseudo-terminal (arrow-key menus, live prompts). Same root cause as the
`winpty python` requirement.

*This project:* `gh auth login` failed with "You appear to be running in MinTTY without
pseudo terminal support" — fixed with `winpty gh auth login`.

**Cross-device `mv`** — `mv` between different drives (e.g. C: → G:) can't do an atomic
rename; it copies then deletes. If the destination already has a same-named non-empty
folder, it fails with "unable to remove target: Directory not empty" instead of merging.

*This project:* had a stray `iac-terraform-ansible/PROGRESS.md` already sitting on G:
from before the repo existed — had to move that file into the cloned repo first, then
`rmdir` the empty leftover folder, then `mv` the real repo into place.

**Git line-ending conversion (CRLF/LF)** — On Windows, Git's `core.autocrlf` setting
converts LF → CRLF in your working directory and back on commit. The "LF will be
replaced by CRLF" warning on `git add` is expected behavior, not an error.

*This project:* saw this on `git add .gitignore PROGRESS.md` — no action needed.

**`gh repo create --clone`** — clones into your *current* working directory at the time
the command runs, not a directory you `cd` into afterward. Always `cd` to the target
location first.

*This project:* ran `gh repo create ... --clone` from `~`, so it cloned into
`~/iac-terraform-ansible` instead of the intended `G:\...\DevOps Project\`, requiring
a manual move afterward.

## Session 2 — 2026-09-10 — Terraform Version Verification

**Chocolatey installs/upgrades need an elevated shell** — Chocolatey installs packages
under `C:\ProgramData\...`, a system-owned folder. A non-admin terminal can run `choco`
but can't write there, so upgrades fail with `UnauthorizedAccessException: Access ... is
denied` after retrying each file 2-3 times, even after confirming "Y" to proceed.

*This project:* `choco upgrade terraform -y` from a normal Git Bash window failed on
every file under `chocolatey\lib\terraform\`. Re-running the identical command from
Git Bash opened via "Run as administrator" succeeded — Terraform went from v1.15.7 to
v1.16.1. Same root cause as `winpty` and package-manager admin requirements: Windows
permission boundaries, not a tool bug.

## Session 3 — 2026-09-10 — Requirements-to-Architecture Reasoning

**Architecture isn't invented from taste — it's derived by matching plain-English
requirements to a small set of trigger words**, then asking two follow-up questions
per component: *who needs to reach it, from where* (→ public vs. private placement),
and *on what specific ports/protocols even among things allowed to talk* (→ security
group rules).

**Trigger-word lookup table** (the actual mechanism, not intuition):

| Phrase in requirements | Component it implies |
|---|---|
| store / save / permanent / record / history | database |
| real-time / instantly / live update | push/messaging system |
| email / SMS / notification / receipt | separate notification service |
| browse / search / view a list of | read-facing API/backend |
| upload a photo / file / video | file/object storage |
| pay / checkout / charge a card | payment component |
| log in / sign up / account | authentication/user management |
| any device/app talking to "the system" | an API/backend it connects to |

*This project:* not yet applied to a real in-project decision — practiced so far only
on hypothetical apps (blog, food-delivery). Next real application should be an actual
Project 2 decision (e.g., Ansible connectivity method) reasoned out *before* being
told the answer, not after.

**Working agreement going forward:** for real architecture/design decisions in this
project (not hypotheticals), the requirement/constraint gets presented first and I
attempt to name the matching trigger word + component before the answer is confirmed,
instead of always receiving the fully-reasoned answer directly.



## Session 4 — 2026-09-11 — Terraform Fundamentals + Tooling Setup

**Declarative vs. imperative** — Project 1's AWS CLI commands were imperative (run this
step, then this step, then this step). Terraform is declarative: you describe the end
state you want, and Terraform figures out what needs to happen to reach it.

*This project:* a `resource "aws_vpc" "main" { cidr_block = "172.20.0.0/16" }` block
reads as a statement ("a VPC with this CIDR should exist"), not a command — there's no
verb like "create." That's what makes re-running the same files safe.

**Idempotency** — running the same operation multiple times produces the same end
result, with no duplicate side effects. This is *why* a Terraform resource block being
a description (not an instruction) matters: running `apply` twice with nothing changed
does nothing the second time, instead of creating a second copy of everything.

**Terraform state file (`terraform.tfstate`)** — Terraform's memory of what it already
created (resource IDs, properties). On every run it compares three things: what the
`.tf` files say should exist, what the state file says was already created, and what's
actually true in AWS right now.

*This project:* not yet generated — no resources exist yet, so no state file exists
yet either. Will appear the first time something is actually applied.

**`terraform plan`** — a read-only dry run. Shows what would be created (`+`), changed
(`~`), or destroyed (`-`) without touching AWS. Safe to run anytime; doesn't require
approval under this project's approval-gate rules, unlike `apply`.

**Configuration drift** — when real infrastructure no longer matches what the state
file believes exists (e.g., someone manually deletes a resource in the AWS console).
`terraform plan` catches this automatically by checking real AWS state, not just the
state file.

*This project:* reasoned through the example — if the VPC were deleted manually outside
Terraform, `plan` would report `1 to add`, because the state file still believes it
exists but AWS confirms it doesn't, and the `.tf` file still says it should.

**Terraform pessimistic constraint operator (`~>`) segment count changes its meaning**
— `~> 5.31` (two segments) only locks the *first* number, allowing anything from 5.31
up to (not including) 6.0. `~> 5.31.0` (three segments) locks the first *two* numbers,
only allowing patch releases within 5.31.x.

*This project:* `~> 5.31` in `versions.tf` installed v5.100.0 on `terraform init` — far
more drift than intended. Corrected to `~> 5.31.0`, re-ran `terraform init -upgrade`,
confirmed it now installs exactly v5.31.0.

**Editor vs. terminal — different jobs** — an editor (VS Code) is for writing/viewing
files; a terminal (Git Bash) is for running commands (`terraform init`, `git commit`,
etc.). VS Code's integrated terminal just puts both in one window; it doesn't change
what either one does. The editor choice has zero effect on what "runs in production" —
it never touches AWS itself, it only produces the files that a terminal/pipeline later
acts on.

*This project:* switched from heredoc (`cat > file << 'EOF'`) file creation to editing
directly in VS Code with the HashiCorp Terraform extension (syntax highlighting, inline
validation) installed and Git Bash set as the integrated terminal.

**Who decides architecture: architect/senior engineer vs. implementer** — in many
companies a Solutions/Cloud Architect or senior engineer decides the shape of the
infrastructure (how many subnets, what talks to what) from requirements; DevOps
engineers implement that decision in Terraform/Ansible/etc. Implementers are still
expected to catch mistakes and push back, not blindly execute. At smaller companies,
or in a portfolio project with no one else to decide it, the implementer *is* the one
doing the requirements-to-architecture reasoning (see Session 3).

*This project:* Project 2 is the "spec already decided" case — the architecture was
fixed in Project 1, so Phase 1 work here is translation into Terraform syntax, not new
architecture reasoning. Later projects (3+) hand over more undecided territory.
## Session 5 — 2026-09-11 — Security Groups, IAM, and Terraform File-Writing Patterns

**Resource block syntax: `resource "<type>" "<local name>"`** — the first string is fixed
by the AWS provider (can't be invented); the second is a name you choose purely for
referencing the resource elsewhere in the same project. AWS never sees the local name.

*This project:* `aws_subnet` used three times (`public_1a`, `public_1b`, `private_1a`) —
same type, distinct local names since there are three. `aws_vpc.main.id` reads as
type → local name → attribute.

**Nested blocks** — some resources group related settings into their own `{ }` block
inside the resource, instead of flat `key = value` pairs.

*This project:* `route { cidr_block = "0.0.0.0/0" gateway_id = ... }` inside
`aws_route_table.public` — a destination → target pair. This exact rule (`0.0.0.0/0` →
Internet Gateway) is what makes a route table, and any subnet associated with it, "public." No separate route table entry needed for the private subnet — it silently
falls back to the VPC's implicit main route table, which has no internet route.

**Variables/outputs extraction heuristic** — not everything needs to become a variable
or output; extracting one adds indirection that should buy something real.

*This project:* CIDR blocks and AZs → variables (would differ in a hypothetical second
environment). Ports (`3306`, `8080`, `11211`) and `0.0.0.0/0` → left hardcoded (protocol
constants, not configuration — same value in every environment). For outputs: extract
only if a *separate tool* (Ansible) or a human debugging needs the value directly — not
just because another Terraform resource in the same project references it (same-project
resources can already see each other without an output).

**Security group egress is NOT automatic in Terraform** — the AWS Console defaults a new
SG to allow all outbound traffic. Terraform doesn't inherit that default: no `egress`
block means zero outbound traffic allowed, since Terraform manages the complete rule set
for the resource. Common gotcha.

*This project:* every one of the five SGs (`alb`, `app`, `db`, `mc`, `ssm_ep`) has an
explicit `egress { protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }` block to match
Project 1's actual (Console-default) behavior.

**Security group as a source, not just an IP range** — an ingress rule's source can be
`security_groups = [aws_security_group.x.id]` instead of `cidr_blocks`. Scopes access to
"anything with this SG attached," which survives IP changes and is far more precise than
a subnet-wide CIDR allow.

*This project (hub-and-spoke pattern):* the app tier is the hub — `db-sg` and `mc-sg`
both allow inbound only from `app-sg` (not from each other; MariaDB and Memcached never
talk to each other directly). `app-sg` allows inbound only from `alb-sg`. `alb-sg` is the
one deliberate exception, open to `0.0.0.0/0` on 80/443, since it's the public entry point.

**IAM role vs. policy vs. instance profile — three distinct pieces** — a *role* is an
identity assumable by a service; a *policy* is the permissions document attached to a
role; an *instance profile* is the wrapper that actually attaches a role to an EC2
instance (EC2 can't hold a role directly). The Console auto-creates the profile when you
create an EC2 role, which hides this distinction — Terraform requires writing both.

*This project:* `aws_iam_role.ec2_role` (trust policy: only `ec2.amazonaws.com` can
assume it) → `aws_iam_role_policy.secrets_access` (least-privilege: `GetSecretValue` scoped
to exactly `vprofile/db/admin-password` and `vprofile/rmq/test-password`, not all
secrets) + `aws_iam_role_policy_attachment` for the AWS-managed
`AmazonSSMManagedInstanceCore` policy → `aws_iam_instance_profile.ec2_profile` wraps the
role for actual EC2 attachment.

**`jsonencode({...})`** — writes IAM policy documents (which AWS requires as JSON) using
HCL syntax instead of a raw JSON string; Terraform converts it. Less error-prone than
hand-written JSON strings embedded in `.tf` files.

**Secrets Manager ARN wildcard suffix (`-*`)** — every secret's real ARN has a random
6-character suffix AWS appends automatically. The policy resource ARN needs a trailing
`-*` to match it without hardcoding the random part, while still scoping to exactly the
named secret (not a broader wildcard like `vprofile/*`).

*This project:* `arn:aws:secretsmanager:us-east-1:747336059892:secret:vprofile/db/admin-password-*`

