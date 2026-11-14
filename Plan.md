# OrderFlow implementation plan

## Primary goal

Build a reproducible OrderFlow platform where a GitHub change is automatically tested, packaged, security-scanned, deployed to an isolated Azure staging environment, and promoted as the same immutable image to an isolated production environment after approval, with health verification and automatic traffic rollback on failure.

The finished project must be demonstrable end to end, understandable in an interview, and kept below the USD 200 Azure spending ceiling for the current month.

## Confirmed decisions

- Repository: `https://github.com/Mouad852/OrderFlow.git` (currently empty).
- Delivery priority: finish the core platform in the least practical time, without hiding verification or security failures.
- Core scope: FastAPI, PostgreSQL, tests, Docker, Jenkins, Terraform, Azure Container Registry, Azure Container Apps, Key Vault, managed identities, Monitor/Application Insights, staging, production approval, and basic rollback.
- Deferred scope: Service Bus, background worker, transactional outbox, dead-letter handling, advanced canary analysis, and load testing.
- Jenkins path: validate the controller and pipeline locally in Docker with a disposable local agent, then host Jenkins on an Azure VM; add a separate Azure build-agent VM only after the end-to-end path works.
- Local workflow: WSL2 Ubuntu, Docker Desktop, Git, Azure CLI, Terraform, and `uv` with Python 3.12.
- Azure region: use `westeurope` by default; use `northeurope` only if the subscription lacks a required SKU, quota, or service in West Europe.
- Environment isolation: staging and production receive separate resource groups, Container Apps environments, PostgreSQL servers, Key Vaults, identities, and telemetry resources.
- Shared resources: one Basic ACR, one Terraform state storage account, and the Jenkins CI resource group.
- Cost posture: consumption/serverless hosting where possible, burstable single-zone databases, small VMs that are deallocated when idle, short log retention, no production HA, and no private endpoints in the core build.

## Fast-delivery strategy

The shortest safe path is one thin, working vertical slice at a time. Each phase ends with a stop gate. Do not start the next phase until the gate passes; otherwise defects compound across Python, Docker, Jenkins, Terraform, and Azure.

Target effort is **36–52 focused hours across 6–8 working days**. This is a planning range, not a guarantee; Azure quota, DNS/certificate issuance, and Jenkins plugin setup are the main external risks.

| Day | Critical-path outcome | Target effort |
| --- | --- | ---: |
| 1 | Tooling, repository, API contract, first tests | 6–8h |
| 2 | PostgreSQL, Alembic, full API, Docker Compose | 6–8h |
| 3 | Local Jenkins CI, image build, Trivy gate | 5–7h |
| 4 | Terraform backend and shared Azure foundation | 5–7h |
| 5 | Isolated staging and production infrastructure | 5–8h |
| 6 | Azure Jenkins, webhook, staging CD | 5–7h |
| 7 | Production approval, rollback, security, telemetry | 3–5h |
| 8 | Documentation, evidence, rehearsal, final audit | 1–2h |

## Cost envelope and hard gates

These are allocation limits, not Azure price quotes. Before the first `terraform apply`, use the subscription's Azure Pricing Calculator and Cost Analysis data to replace them with a region- and subscription-specific estimate.

| Cost area | Maximum monthly allocation |
| --- | ---: |
| Jenkins controller and temporary build agent | $45 |
| Staging and production PostgreSQL | $70 |
| Container Apps and ACR | $25 |
| Monitoring and log ingestion | $20 |
| Storage, Key Vault, public IP, and network traffic | $10 |
| Safety margin | $30 |
| **Absolute ceiling** | **$200** |

Cost controls:

1. Create a monthly Azure budget of **$180**, leaving a $20 emergency margin, with actual-cost alerts at 50%, 75%, 90%, and 100%, plus a forecast alert at 80%.
2. Treat budget alerts as notifications only; they do not stop resources automatically.
3. Require a reviewed cost estimate before each environment apply.
4. Set Container Apps minimum replicas to zero during the portfolio build.
5. Use burstable, single-zone PostgreSQL without HA for this month; production data isolation is retained, but production-grade HA is deferred.
6. Auto-shutdown/deallocate Jenkins VMs outside active work. The webhook will be unavailable while Jenkins is stopped, which is acceptable during development.
7. Limit Log Analytics retention and avoid verbose application logging.
8. Tag every Azure resource with `project=orderflow`, `environment`, `owner`, and `expires_on`.
9. Provide a reviewed teardown runbook. Never run `terraform destroy` without inspecting the plan and explicitly confirming the target environment.
10. Stop provisioning if the current spend plus the calculator forecast can exceed $180; redesign before continuing.

## Target architecture

```text
Developer -> GitHub -> Jenkins controller -> temporary Jenkins build agent
                              |                    |
                              |                    +-> test / build / Trivy
                              |                    +-> push immutable SHA image
                              v
                        Shared ACR + Terraform state
                              |
                 +------------+-------------+
                 |                          |
          Staging resource group     Production resource group
          - Container Apps env       - Container Apps env
          - API Container App        - API Container App
          - PostgreSQL server        - PostgreSQL server
          - Key Vault + identity     - Key Vault + identity
          - Logs + App Insights      - Logs + App Insights
                 |                          |
          automatic deployment       approved promotion
                                            |
                                  revision health check
                                  promote or restore traffic
```

The application image is built once, identified by Git commit SHA and registry digest, and promoted without rebuilding. Infrastructure changes use a separate Jenkins pipeline and approval boundary.

## Phase 0 — Documentation discovery and architecture freeze

**How this serves the primary goal:** It prevents the project from being built around invented or obsolete commands, resource arguments, and deployment behavior.

### What to implement

1. Record supported versions at implementation time in `docs/decisions/0001-supported-versions.md`:
   - Python 3.12 patch release managed by `uv`.
   - FastAPI/Pydantic versions resolved in `uv.lock`.
   - SQLAlchemy 2.x typed ORM API and compatible Alembic release.
   - Jenkins LTS Docker image and minimal plugin versions.
   - Terraform stable release and a pinned AzureRM v5 minor constraint, rechecked against the current provider release before implementation.
   - Azure CLI and Container Apps extension versions.
   - PostgreSQL 17 unless live region/subscription checks establish a better supported choice; do not begin a greenfield deployment on PostgreSQL 14 because its standard support ends in December 2026.
2. Verify subscription access, required resource providers, West Europe service availability, VM quota, PostgreSQL SKU availability, and Container Apps quota.
3. Write `docs/decisions/0002-architecture-and-scope.md` containing the confirmed scope, environment boundary, rollback model, and deferrals.
4. Freeze the minimal API contract:
   - `POST /orders` -> `201`.
   - `GET /orders?limit=&offset=` -> `200`.
   - `GET /orders/{id}` -> `200` or `404`.
   - `PATCH /orders/{id}/cancel` -> `200`, `404`, or `409`.
   - `GET /health` -> process liveness.
   - `GET /ready` -> database readiness, returning `503` when unavailable.
5. Freeze order states as `PENDING`, `PROCESSING`, `COMPLETED`, `CANCELLED`, and `FAILED`; the core build creates `PENDING` orders and permits cancellation only from `PENDING`.

### Allowed APIs and authoritative references

- FastAPI path operations and `TestClient`: <https://fastapi.tiangolo.com/tutorial/testing/>
- SQLAlchemy typed mappings: `DeclarativeBase`, `Mapped`, and `mapped_column` from <https://docs.sqlalchemy.org/en/20/orm/quickstart.html>
- `uv` project locking: `uv lock`, `uv sync`, `uv run --locked`, and `uv lock --check` from <https://docs.astral.sh/uv/concepts/projects/sync/>
- Docker Compose readiness: `depends_on.condition: service_healthy` and `healthcheck` from <https://docs.docker.com/compose/how-tos/startup-order/>
- Declarative Jenkins Pipeline: `pipeline`, `agent`, `stages`, `when`, `post`, and stage `input` from <https://www.jenkins.io/doc/book/pipeline/syntax/>
- Jenkins approval step: `input message: ..., ok: ...` from <https://www.jenkins.io/doc/pipeline/steps/pipeline-input-step/>
- Terraform Azure Blob backend: the `azurerm` backend from <https://developer.hashicorp.com/terraform/language/backend/azurerm>
- Container Apps revisions and traffic: <https://learn.microsoft.com/azure/container-apps/revisions> and <https://learn.microsoft.com/azure/container-apps/revisions-manage>
- Container Apps Key Vault references and managed identity: <https://learn.microsoft.com/azure/container-apps/manage-secrets>
- Application Insights OpenTelemetry for Python/FastAPI: <https://learn.microsoft.com/python/api/overview/azure/monitor-opentelemetry-readme>
- Azure budgets: <https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-acm-create-budgets>
- Trivy image scanning and exit codes: <https://trivy.dev/docs/latest/target/container_image/> and <https://trivy.dev/docs/latest/configuration/others/>
- AzureRM current releases and v5 changes: <https://github.com/hashicorp/terraform-provider-azurerm/releases>
- Container Apps logging migration to Azure Monitor diagnostic settings: <https://learn.microsoft.com/azure/container-apps/migrate-logs-azure-monitor>

### Verification checklist

- [ ] Every selected version and Azure resource type has an official documentation link.
- [ ] `westeurope` supports the selected PostgreSQL, Container Apps, ACR, Key Vault, Monitor, and VM configuration.
- [ ] A calculator estimate fits the cost envelope with at least $20 margin.
- [ ] API and state-transition decisions are written before code begins.
- [ ] Deferred features are clearly excluded from core acceptance criteria.

### Anti-pattern guards

- Do not copy Terraform arguments from blogs or old examples without checking the pinned provider documentation.
- Do not use SQLAlchemy 1.x `Query` patterns in new code.
- Do not treat Azure budgets as spending cutoffs.
- Do not include Service Bus or the worker in the core critical path.

### Stop gate

Proceed only when the region, versions, architecture decision records, API contract, and cost estimate are accepted.

## Phase 1 — Workstation, Git, repository skeleton, and budget guardrails

**How this serves the primary goal:** It creates one reproducible development surface and establishes cost protection before any billable infrastructure exists.

### What to implement

1. In WSL2 Ubuntu, install `uv`, Terraform, Azure CLI, GitHub CLI, `jq`, and `make`; let `uv` install Python 3.12 so the existing Windows Python 3.14 does not affect the project.
2. Clone the empty remote into the existing workspace safely, or initialize the existing folder and add `origin` after confirming it contains only `Plan.md`.
3. Create the initial monorepo layout:
   - `app/api`, `app/core`, `app/database`, `app/models`, `app/schemas`, `app/services`.
   - `tests/unit`, `tests/integration`.
   - `alembic`, `docker`, `jenkins`, `terraform/bootstrap`, `terraform/modules`, `terraform/environments/staging`, `terraform/environments/production`.
   - `scripts`, `monitoring`, `docs/decisions`, and `docs/runbooks`.
4. Add `pyproject.toml`, `.python-version`, `uv.lock`, `.gitignore`, `.dockerignore`, `.editorconfig`, `.env.example`, `Makefile`, and a minimal `README.md`.
5. Configure Ruff and Pytest in `pyproject.toml`; set an initial 80% coverage gate for application code.
6. Authenticate Azure CLI, select the intended subscription explicitly, and record only the subscription name/ID—not tokens or secrets—in local notes.
7. Create the $180 subscription budget and alert recipients before provisioning application resources.
8. Push the first planning/bootstrap commit to `main`, then enable branch protection after CI exists.

### Documentation references

- Copy the managed Python 3.12 installation pattern from <https://docs.astral.sh/uv/concepts/python-versions/>.
- Copy the locked project workflow from <https://docs.astral.sh/uv/concepts/projects/sync/>.
- Copy budget threshold behavior from the Azure Cost Management budget tutorial in Phase 0.

### Verification checklist

- [ ] `uv run python --version` reports Python 3.12.x.
- [ ] `uv lock --check`, `docker version`, `terraform version`, `az version`, and `gh --version` succeed in WSL2.
- [ ] `git remote -v` points to the OrderFlow GitHub repository.
- [ ] No secret is returned by `git grep -nEi '(password|secret|token|connection_string)='` except safe examples/placeholders.
- [ ] Azure budget and alerts are visible at the subscription scope.

### Anti-pattern guards

- Do not install project dependencies into the Windows Python 3.14 environment.
- Do not commit `.env`, Azure credentials, SSH private keys, Terraform state, or Jenkins secrets.
- Do not provision Azure application resources in this phase.

### Stop gate

Proceed only after a clean clone on WSL can reproduce the environment and the budget alert exists.

## Phase 2 — Order API vertical slice, database model, and tests

**How this serves the primary goal:** It produces the smallest useful application artifact that every later CI/CD and Azure phase can validate and deploy.

### What to implement

1. Create configuration with `pydantic-settings`; require `DATABASE_URL`, environment name, logging level, and optional Application Insights connection string.
2. Use synchronous SQLAlchemy 2.x sessions with Psycopg 3 for the core build; avoid unnecessary async database complexity.
3. Model `Order` and `OrderItem` with UUID identifiers, UTC timestamps, constrained quantities, and PostgreSQL `NUMERIC` values for prices and totals.
4. Use Pydantic request/response models and `Decimal`; never use binary floating point for money.
5. Implement calculation and state-transition logic in services, not route handlers.
6. Implement the frozen endpoints, consistent error responses, pagination bounds, and database dependency injection.
7. Initialize Alembic and create the first explicit migration. Do not create tables with `Base.metadata.create_all()` in application startup.
8. Add unit tests for validation, total calculation, and cancellation rules.
9. Add PostgreSQL integration tests for persistence, API responses, duplicate/not-found behavior, readiness, and migration upgrade from an empty database.
10. Produce JUnit XML and coverage XML for Jenkins publication later.

### Documentation references

- Copy the multi-file application and testing patterns from the FastAPI documentation linked in Phase 0.
- Copy SQLAlchemy 2.x typed declarative mappings from the ORM quick start linked in Phase 0.
- Copy migration initialization and upgrade patterns from <https://alembic.sqlalchemy.org/en/latest/tutorial.html>.
- Copy Pydantic settings behavior from <https://docs.pydantic.dev/latest/concepts/pydantic_settings/>.

### Verification checklist

- [ ] Ruff format and lint checks pass.
- [ ] Unit and integration tests pass against PostgreSQL, not SQLite.
- [ ] Coverage is at least 80% for application code.
- [ ] `alembic upgrade head` succeeds on an empty database and a second run is idempotent.
- [ ] OpenAPI lists exactly the required endpoints.
- [ ] Cancellation returns `409` for non-pending states.

### Anti-pattern guards

- Do not embed database calls, price calculations, or state transitions directly in routes.
- Do not use SQLite as a substitute for PostgreSQL integration testing.
- Do not auto-generate a migration and commit it without reviewing the SQL/schema diff.
- Do not log complete request bodies or database credentials.

### Stop gate

Proceed only when tests prove the complete create/list/get/cancel path and migrations work from zero.

## Phase 3 — Reproducible containers and local runtime

**How this serves the primary goal:** It creates the immutable artifact and dependency topology that Jenkins will build once and Azure will run unchanged.

### What to implement

1. Create a multi-stage `docker/Dockerfile.api` from a pinned Python 3.12 slim base digest.
2. Copy the locked dependencies in a cache-friendly layer, install with `uv`, then copy the application.
3. Run as a dedicated non-root user, set a read-only-friendly working directory, and expose only the API port.
4. Add container health checking against `/health`; use `/ready` for deployment verification.
5. Create `compose.yaml` with API, PostgreSQL, a persistent named volume, a private network, database health check, and `service_healthy` dependency.
6. Add a one-shot migration service or explicit `make migrate` command so schema ownership is visible.
7. Add `scripts/smoke-test.sh` that checks health, readiness, order creation, retrieval, listing, and cancellation.

### Documentation references

- Copy the dependency-first Docker layer pattern from <https://docs.astral.sh/uv/guides/integration/docker/>.
- Copy Compose `service_healthy` startup behavior from the Docker documentation linked in Phase 0.
- Copy Dockerfile `USER`, `HEALTHCHECK`, and build guidance from <https://docs.docker.com/build/building/best-practices/>.

### Verification checklist

- [ ] `docker compose config` succeeds.
- [ ] `docker compose up --build -d` reaches healthy status from a clean volume.
- [ ] The migration and smoke-test commands succeed twice.
- [ ] `docker inspect` confirms the API process is not root.
- [ ] Image history contains no `.env` file or credential.
- [ ] The image works when configuration changes but the image digest does not.

### Anti-pattern guards

- Do not use `latest` for base images or release images.
- Do not bake environment-specific configuration or secrets into an image.
- Do not rely on Compose startup order without a database health check.
- Do not run Alembic independently in every API replica.

### Stop gate

Proceed only when a new clone can build and smoke-test the local stack with one documented command sequence.

## Phase 4 — Local Jenkins CI and DevSecOps gate

**How this serves the primary goal:** It proves every change can be validated, packaged, and rejected when unsafe before Azure deployment is introduced.

### What to implement

1. Run Jenkins LTS in Docker with persistent `JENKINS_HOME`; pin the image version, set controller executors to zero, and attach a disposable Docker-capable local agent for builds.
2. Install only required plugins: Pipeline, Git, GitHub Branch Source, Credentials Binding, JUnit, and Pipeline Utility Steps.
3. Create a multibranch pipeline for the GitHub repository and keep pipeline logic in `jenkins/Jenkinsfile`.
4. Implement stages: checkout, environment/lock verification, Ruff, unit tests, PostgreSQL integration tests, JUnit/coverage publication, Docker build, Trivy scan, and artifact metadata publication.
5. Tag the image with the full Git commit SHA; record the image digest after build.
6. Configure Trivy to fail on fixed `HIGH` and `CRITICAL` vulnerabilities using a nonzero exit code and `--ignore-unfixed`; scan the filesystem/IaC as a report before it becomes a hard gate.
7. Use `post { always { ... } }` for reports and cleanup.
8. Prove branch behavior: pull requests validate but do not push/deploy; `main` is eligible for publish/deploy stages.

### Documentation references

- Copy Declarative Pipeline and `post` patterns from the Jenkins syntax reference in Phase 0.
- Copy JUnit publication from <https://www.jenkins.io/doc/pipeline/steps/junit/>.
- Copy credential binding from <https://www.jenkins.io/doc/pipeline/steps/credentials-binding/>.
- Copy Trivy image and exit-code options from the official Trivy references in Phase 0.

### Verification checklist

- [ ] A deliberately failing Ruff check stops before tests/build.
- [ ] A deliberately failing test publishes JUnit output and stops the image stage.
- [ ] A known vulnerable test image causes the Trivy gate to fail.
- [ ] A healthy feature branch completes CI without deployment.
- [ ] A healthy `main` build produces exactly one SHA-tagged image and records its digest.
- [ ] Jenkins logs do not expose credentials.

### Anti-pattern guards

- Do not put secrets in Groovy interpolation or echo environment variables.
- Do not treat `/var/run/docker.sock` as an ordinary file mount; it gives the trusted build agent effectively privileged host access and must never be exposed to untrusted pull-request code.
- Do not build production images with an unpinned `latest` tag.
- Do not allow deployment stages on pull requests.
- Do not disable the vulnerability gate merely to obtain a green build; document and time-limit any justified exception.

### Stop gate

Proceed only after both a successful build and intentional failure demonstrations are captured as evidence.

## Phase 5 — Terraform backend and shared Azure foundation

**How this serves the primary goal:** It makes shared cloud resources reproducible and gives later environment deployments locked, remote infrastructure state.

### What to implement

1. Create a small, reviewed `terraform/bootstrap` configuration or Azure CLI script for the unavoidable one-time backend bootstrap: resource group, storage account, private container, soft delete, versioning, and access controls.
2. Configure the Terraform `azurerm` backend using Microsoft Entra authentication; do not place storage keys in code.
3. Pin Terraform and AzureRM provider constraints; commit `.terraform.lock.hcl`. For AzureRM v5, explicitly register every namespace the plan uses because automatic provider registration defaults to none.
4. Create shared modules/resources for:
   - Basic ACR with admin access disabled.
   - Terraform state storage.
   - Jenkins resource group/network/security foundation.
   - Common tags and naming.
5. Add `jenkins/Jenkinsfile.infrastructure` with fmt, validate, lock check, Trivy configuration scan, plan artifact, approval, and apply stages.
6. Make the first shared `terraform plan` locally, inspect it, apply it, and immediately compare actual cost estimates with the envelope.

### Documentation references

- Copy the `azurerm` backend configuration from HashiCorp documentation in Phase 0.
- Copy AzureRM resource schemas only from the version-matched provider registry.
- Copy ACR managed-identity guidance from <https://learn.microsoft.com/azure/container-registry/container-registry-authentication-managed-identity>.

### Verification checklist

- [ ] `terraform fmt -check -recursive`, `terraform init`, `terraform validate`, and `terraform plan` pass.
- [ ] State is in Azure Blob Storage and local state files are absent from Git.
- [ ] Blob state locking works when a second operation is attempted.
- [ ] Required namespaces are registered explicitly, including `Microsoft.App`, `Microsoft.ContainerRegistry`, `Microsoft.DBforPostgreSQL`, `Microsoft.KeyVault`, `Microsoft.OperationalInsights`, `Microsoft.Insights`, `Microsoft.ManagedIdentity`, `Microsoft.Authorization`, `Microsoft.Storage`, `Microsoft.Network`, and later `Microsoft.ServiceBus` only if the deferred phase is started.
- [ ] ACR admin access is disabled.
- [ ] A second plan after apply reports no changes.
- [ ] Actual/forecast cost remains inside the allocated envelope.

### Anti-pattern guards

- Do not try to create the backend with the same state that depends on it.
- Do not use storage access keys, client secrets, or `Owner` at subscription scope when narrower RBAC works.
- Do not apply an unreviewed or stale plan.
- Do not mix application image deployment with the infrastructure pipeline.

### Stop gate

Proceed only after remote state, locking, no-drift planning, ACR, and the cost check all pass.

## Phase 6 — Isolated staging and production Azure environments

**How this serves the primary goal:** It creates two independently secured deployment targets so staging validation cannot accidentally mutate production.

### What to implement

1. Build reusable Terraform modules for Container Apps environment/app, PostgreSQL Flexible Server/database, Key Vault, managed identities/RBAC, Log Analytics, and Application Insights.
2. Instantiate separate `staging` and `production` roots with separate backend keys and resource groups.
3. Give each environment its own PostgreSQL 17 server, database administrator secret, Key Vault, Container Apps environment, API identity, Log Analytics workspace, and Application Insights resource.
4. Use burstable single-zone PostgreSQL, minimum supported storage, short backup retention, and no HA for the budget-limited build.
5. Generate secrets through Terraform-sensitive values or a controlled bootstrap process and write them to Key Vault; never output their plaintext.
6. Keep ACR in legacy RBAC mode for the core timebox, then grant each API identity only `AcrPull` on shared ACR and `Key Vault Secrets User` on its own vault. If ABAC repository permissions are enabled instead, use `Container Registry Repository Reader/Writer`; `AcrPull`/`AcrPush` do not apply in that mode.
7. Configure Key Vault with the AzureRM v5 `rbac_authorization_enabled` field and versioned secret references in Container Apps; set minimum replicas to zero and conservative CPU/memory limits.
8. Restrict each PostgreSQL public firewall to the relevant Container Apps environment outbound addresses and a temporary administrator address, connect by server FQDN, and require TLS verification. Never use the broad “Allow public access from any Azure service” option.
9. Deploy a temporary bootstrap image so infrastructure can be verified before the application CD stage.
10. Apply staging first, verify it, review cost, then apply production.

### Documentation references

- Copy Container Apps, managed identity, and Key Vault reference patterns from Microsoft Learn links in Phase 0.
- Copy PostgreSQL Flexible Server sizing and stop/start guidance from <https://learn.microsoft.com/azure/postgresql/flexible-server/overview>.
- Copy role definitions and use exact role IDs from <https://learn.microsoft.com/azure/role-based-access-control/built-in-roles>.

### Verification checklist

- [ ] Staging and production have different resource groups, state keys, databases, vaults, identities, and telemetry resources.
- [ ] Neither environment identity can read the other environment's Key Vault.
- [ ] Both Container Apps can pull from ACR without registry admin credentials.
- [ ] PostgreSQL rejects non-allowlisted sources and application connections use FQDN plus verified TLS.
- [ ] Secrets are referenced, not stored as plaintext Terraform outputs or Container App values.
- [ ] Both roots have a no-change plan after apply.
- [ ] Updated actual/forecast cost remains below the $180 operating gate.

### Anti-pattern guards

- Do not share a PostgreSQL server, Key Vault, or workload identity between staging and production.
- Do not enable expensive HA, private endpoints, NAT Gateway, or dedicated Container Apps workloads without a new budget decision.
- Do not grant cross-environment wildcard RBAC.
- Do not expose PostgreSQL broadly to `0.0.0.0/0`.

### Stop gate

Proceed only after access-boundary tests and a cost review prove both environments are isolated and affordable.

## Phase 7 — Azure-hosted Jenkins and GitHub webhook

**How this serves the primary goal:** It moves automation to an always-reproducible cloud control plane that GitHub can trigger without depending on the developer laptop.

### What to implement

1. Provision a small Ubuntu Jenkins controller VM through Terraform with a managed OS disk, managed identity, restricted NSG, Azure Monitor agent, backup plan, and auto-shutdown schedule.
2. Bootstrap Docker and pinned Jenkins LTS through cloud-init; store Jenkins configuration and plugin list in version control without secrets.
3. Restrict SSH to the current administrator IP and expose Jenkins only through HTTPS.
4. Assign a DNS label/FQDN and use Caddy or Nginx with a valid automated certificate; if certificate issuance fails, stop and solve HTTPS before adding the webhook.
5. Restore/recreate the local multibranch job and credentials on the Azure controller.
6. Grant the Jenkins VM identity scoped permissions: push to ACR, update only the target Container Apps, read required deployment metadata, and execute approved Terraform at specific resource-group scopes.
7. Configure a GitHub webhook to `/github-webhook/` with a strong webhook secret and verify its delivery signature/status.
8. After the cloud controller works, add a small Docker-capable build agent so routine builds do not execute on the controller. Deallocate the agent when inactive.

### Documentation references

- Copy Linux VM creation and managed identity patterns from Microsoft Learn Azure VM documentation.
- Copy Jenkins controller/agent guidance from <https://www.jenkins.io/doc/book/scaling/architecting-for-scale/>.
- Copy GitHub webhook configuration from <https://docs.github.com/webhooks/using-webhooks/creating-webhooks>.
- Copy Jenkins security guidance from <https://www.jenkins.io/doc/book/security/>.

### Verification checklist

- [ ] Only ports 22 from the current admin IP and 443 publicly are permitted.
- [ ] Jenkins serves a valid HTTPS certificate and anonymous users cannot administer or run jobs.
- [ ] A GitHub push creates one webhook delivery and one Jenkins build.
- [ ] `az login --identity` works without a stored Azure client secret.
- [ ] A normal build runs on the agent, not the controller.
- [ ] VM shutdown/deallocation behavior and webhook downtime are documented.

### Anti-pattern guards

- Do not expose Jenkins on public port 8080.
- Do not use the Jenkins controller as the permanent Docker build node.
- Do not grant the Jenkins identity subscription-level `Owner`.
- Do not accept a self-signed certificate for the GitHub webhook.

### Stop gate

Proceed only after a real GitHub push securely triggers CI on the Azure Jenkins installation.

## Phase 8 — Staging CD, approved production promotion, and rollback

**How this serves the primary goal:** It completes the user-visible source-to-production delivery path while ensuring a bad release cannot keep production traffic.

### What to implement

1. Extend the application Jenkinsfile so a successful `main` build logs into Azure with managed identity, pushes the SHA image to ACR, records its digest, and deploys that digest to staging.
2. Run the migration once as an explicit pipeline step before application promotion; only backward-compatible expand/contract migrations are allowed.
3. Wait for the staging revision to become ready, then run the complete smoke test against staging.
4. Add a production `input` approval that displays commit SHA, image digest, staging evidence, and Terraform environment version.
5. Promote the exact staging digest to a zero-traffic candidate production revision in multiple-revision mode.
6. Test the candidate through its revision-specific URL or label.
7. Capture the previous stable revision, switch 100% traffic to the candidate, and run post-switch smoke checks.
8. On any failed readiness or smoke check, restore 100% traffic to the recorded stable revision, fail the Jenkins build, and preserve logs/evidence.
9. Prove rollback with an intentionally unhealthy image, then restore the healthy code.

### Documentation references

- Copy `input` usage from the Jenkins approval references in Phase 0.
- Copy revision naming, activation, labels, and traffic weights from the Container Apps revision references in Phase 0.
- Use documented `az containerapp update`, `az containerapp revision list/show`, and `az containerapp ingress traffic set` commands only after checking the installed CLI extension help.

### Verification checklist

- [ ] Pull requests never push or deploy an image.
- [ ] `main` automatically deploys the SHA/digest to staging.
- [ ] Production cannot begin without manual approval.
- [ ] Staging and production report the same registry digest.
- [ ] Candidate validation happens before normal production traffic changes.
- [ ] The unhealthy-release exercise restores the previous stable revision automatically.
- [ ] Database remains compatible after application traffic rollback.

### Anti-pattern guards

- Do not rebuild the image for production.
- Do not deploy mutable tags such as `latest`.
- Do not reverse an Alembic migration automatically as part of application rollback.
- Do not call traffic reversal “automatic rollback” unless the intentional failure test proves it.

### Stop gate

Proceed only after both the healthy promotion and unhealthy rollback scenarios pass from a GitHub commit.

## Phase 9 — Security hardening and operational visibility

**How this serves the primary goal:** It makes the deployed system defensible and observable instead of merely reachable.

### What to implement

1. Integrate the current `microsoft-opentelemetry` distribution before FastAPI imports are initialized; obtain `APPLICATIONINSIGHTS_CONNECTION_STRING` through each environment's Key Vault reference. Do not initialize the older Azure Monitor distribution alongside it.
2. Emit structured logs with environment, service, revision, request/correlation ID, route, status code, and duration; redact secrets and customer data.
3. Configure each Container Apps environment with `logs_destination = "azure-monitor"` and version-matched `azurerm_monitor_diagnostic_setting` resources for console logs, system logs, and metrics. Do not use the retired direct `log-analytics`/HTTP Data Collector path or removed inline retention examples.
4. Create saved queries/workbooks for request volume, p95 latency, 5xx rate, readiness failures, PostgreSQL connectivity, CPU, memory, and revision changes.
5. Add alert rules for sustained 5xx errors, readiness failures, and high latency with conservative thresholds that avoid noisy demo traffic.
6. Harden Jenkins authorization, disable unused plugins, back up `JENKINS_HOME`, and document plugin/controller update procedures.
7. Enable GitHub branch protection on `main`: pull request required, Jenkins checks required, stale approvals dismissed, direct pushes blocked.
8. Add ACR retention/cleanup policy for old unreferenced images while retaining demo and rollback digests.
9. Run a least-privilege review of all Azure role assignments and a final secret scan.

### Documentation references

- Copy the supported FastAPI OpenTelemetry initialization from the Application Insights Python documentation in Phase 0.
- Copy Container Apps logging behavior from <https://learn.microsoft.com/azure/container-apps/log-monitoring>.
- Copy Jenkins security and backup guidance from official Jenkins documentation.
- Copy GitHub protected-branch settings from <https://docs.github.com/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches>.

### Verification checklist

- [ ] A test request appears in Application Insights with its correlated trace and sanitized log.
- [ ] Workbook queries return data for both environments without cross-environment access.
- [ ] A controlled error triggers the expected alert path.
- [ ] Branch protection rejects a direct unreviewed main-branch change.
- [ ] Secret scanning finds no real credentials in Git history or image layers.
- [ ] RBAC review shows environment-scoped access and no accidental subscription Owner assignment.

### Anti-pattern guards

- Do not initialize two OpenTelemetry distributions/providers for the same signal.
- Do not log request bodies, authorization headers, connection strings, or Key Vault values.
- Do not create alerts without testing and documenting their query/threshold.
- Do not retain unlimited logs or images under the $200 budget.

### Stop gate

Proceed only when a request can be traced, a controlled error can be observed, and the security checklist is clean.

## Phase 10 — Documentation, evidence, and interview demonstration

**How this serves the primary goal:** It turns the working platform into a reproducible portfolio artifact that another engineer can understand, operate, and verify.

### What to implement

1. Complete `README.md` with architecture, prerequisites, quick start, API examples, CI/CD flow, Azure cost warning, and cleanup.
2. Create `docs/architecture.md` with Mermaid diagrams for application, Azure, CI/CD, identity/RBAC, and rollback flow.
3. Create `docs/deployment.md` and runbooks for provisioning, release, rollback, database migration, Jenkins recovery, cost review, and teardown.
4. Save sanitized evidence: test report, coverage summary, Trivy result, Terraform plan summary, successful webhook, staging deploy, production approval, telemetry trace, and failed-release rollback.
5. Rehearse a 10–15 minute demo:
   - Show the API in production.
   - Change behavior and push a branch/PR.
   - Show Jenkins tests, image build, scan, ACR digest, and staging deployment.
   - Approve the same digest for production.
   - Deploy an unhealthy revision and show automatic traffic restoration.
6. Record current cost and the exact teardown/stop state after the demo.

### Documentation references

- Use the actual repository commands and outputs generated by prior phases; do not invent screenshots or results.
- Use Mermaid syntax from <https://mermaid.js.org/syntax/flowchart.html>.

### Verification checklist

- [ ] A new reader can reproduce local development from the README.
- [ ] A reviewer can map each diagram component to Terraform and pipeline code.
- [ ] Every evidence item is sanitized and tied to a commit SHA/image digest.
- [ ] The demo completes inside 15 minutes without manual Azure Portal deployment.
- [ ] Cost and cleanup state are documented at the end.

### Anti-pattern guards

- Do not use screenshots as the only proof when machine-readable reports are available.
- Do not document commands that were not rerun successfully from a clean context.
- Do not expose subscription IDs, public admin IPs, secrets, or customer-like data unnecessarily.

### Stop gate

Proceed to final verification only after a complete rehearsal succeeds without undocumented fixes.

## Phase 11 — Final verification and acceptance

**How this serves the primary goal:** It proves the repository meets its stated outcome from a clean checkout rather than only on the original machine.

### Verification procedure

1. Clone the repository into a clean temporary directory and follow the README exactly.
2. Verify dependency/API use against every Phase 0 official reference and the committed version constraints.
3. Run:
   - lockfile check;
   - Ruff format/lint;
   - unit and PostgreSQL integration tests;
   - coverage gate;
   - Docker build and local smoke test;
   - Trivy filesystem, configuration, and image scans;
   - Terraform format, validate, and plans for shared, staging, and production roots.
4. Grep for anti-patterns: mutable image tags, plaintext secrets, local Terraform state, broad CIDRs, subscription Owner grants, SQLite test shortcuts, `Base.metadata.create_all`, and automatic migration downgrade.
5. Trigger a GitHub PR build and confirm no deployment.
6. Merge to `main`, confirm automatic staging, approve production, verify identical digest, and execute the unhealthy-release rollback test.
7. Confirm dashboards/alerts, environment isolation, no Terraform drift, branch protection, and current Azure cost.
8. Create a release tag only after all checks pass.

### Acceptance checklist

- [ ] Functional order API and PostgreSQL migrations.
- [ ] Reproducible non-root container and local Compose stack.
- [ ] Jenkins CI with lint, tests, reports, immutable build, and Trivy gate.
- [ ] Terraform-managed shared, staging, production, and CI infrastructure with remote locked state.
- [ ] Separate staging/production data, secrets, identity, runtime, and telemetry boundaries.
- [ ] GitHub webhook to HTTPS Azure Jenkins.
- [ ] Automatic staging and approved same-digest production promotion.
- [ ] Proven candidate check and automatic traffic rollback.
- [ ] Key Vault references, managed identities, least-privilege RBAC, and clean secret scans.
- [ ] Application Insights traces, logs, dashboards, and tested alerts.
- [ ] Reproducible documentation, evidence, demo, and teardown runbook.
- [ ] Month-to-date actual plus forecast remains below $200.

### Anti-pattern guards

- Do not mark the project complete with skipped checks or an unproven rollback.
- Do not accept undocumented manual Portal changes; either codify them or remove them.
- Do not keep costly demo resources running after the final evidence is captured.

## Explicitly not now

- Azure Service Bus and background worker.
- Transactional outbox, idempotent consumer, retry/dead-letter processing.
- Percentage-based canary analysis and automated metric-based promotion.
- Load/performance testing.
- Business API authentication/authorization and frontend UI.
- Custom domain and public product branding beyond what Jenkins HTTPS requires.
- Zone-redundant PostgreSQL HA, private endpoints, NAT Gateway, Azure Firewall, Application Gateway, and multi-region disaster recovery.
- Kubernetes/AKS.

These can become a second roadmap only after the core acceptance checklist passes and a new cost envelope is approved.

## Step-by-step collaboration contract

For each phase, the guide should provide one small action at a time with:

1. The exact command or file change.
2. A short explanation of why it is needed.
3. The expected output or observable result.
4. A verification command.
5. A request for the user's result before moving to the next risky or billable action.

No Azure apply, production promotion, role grant, secret operation, or destroy action should be treated as an invisible background step. The user applies and verifies those checkpoints explicitly.
