# ADR 0002: Architecture and scope

- Status: Accepted
- Date: 2026-11-14

## Goal

Build a reproducible OrderFlow platform where a GitHub change is tested, packaged,
security-scanned, deployed to isolated Azure staging, and promoted as the same
immutable image to isolated production after approval.

## Decisions

- The application is a FastAPI API backed by PostgreSQL.
- The core data layer uses synchronous SQLAlchemy 2.x and Psycopg 3.
- Staging and production are isolated: separate resource groups, Container Apps
  environments, PostgreSQL servers, Key Vaults, managed identities, and telemetry.
- Azure Container Registry is shared and stores Docker images tagged with the full
  Git commit SHA and identified by their immutable registry digest.
- Jenkins validates the pipeline locally first, then runs on an Azure VM.
- A successful main-branch build deploys to staging automatically.
- Production promotion requires manual approval and uses the exact staging image digest.
- Production uses Container Apps revisions: validate a zero-traffic candidate, then
  switch traffic; restore traffic to the previous healthy revision on failure.
- Secrets stay in Key Vault and workloads use managed identities rather than stored
  Azure credentials.
- The monthly Azure budget target is USD 180, with a hard ceiling of USD 200.

## Deferred from the core build

- Service Bus, workers, transactional outbox, retries, and dead-letter handling.
- Business authentication/authorization and a frontend.
- Advanced canary analysis, load testing, PostgreSQL HA, private endpoints,
  Kubernetes, multi-region recovery, and custom product domains.

## Consequences

The first milestone is a small but fully tested order API. Cloud infrastructure and
deployment automation are added only after the local API, database migrations,
container image, and CI checks are proven.

## Region decision

The preferred region was West Europe. This subscription is restricted from provisioning
Azure Database for PostgreSQL Flexible Server there, so OrderFlow uses North Europe.

North Europe was verified to support Container Apps, Container Registry, PostgreSQL
Flexible Server, Key Vault, Log Analytics, Application Insights, Storage, networking,
and virtual machines. PostgreSQL 17 and the Burstable `Standard_B1ms` SKU are available.

This is the only approved regional fallback unless a later documented quota or
availability constraint requires another decision.
