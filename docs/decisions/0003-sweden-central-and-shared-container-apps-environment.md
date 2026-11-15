# ADR 0003: Sweden Central and shared Container Apps environment

- Status: Accepted
- Date: 2026-11-15

## Context

The subscription rejected PostgreSQL Flexible Server SKUs in North Europe and
successfully provisioned the staging platform in Sweden Central. The same
subscription also returned `MaxNumberOfGlobalEnvironmentsInSubExceeded` when a
second Azure Container Apps environment was requested.

The project must support production promotion without requesting a quota increase
or replacing Azure Container Apps with another compute platform.

## Decision

- Sweden Central is the active region for staging and production.
- Azure Container Registry remains shared between environments.
- Staging and production temporarily share the existing Container Apps environment
  and its virtual network.
- Production keeps separate application and migration-job resources, PostgreSQL
  server and database, delegated database subnet, Key Vault, managed identity,
  Application Insights instance, Log Analytics workspace, resource group, and
  Terraform state.
- Production images are selected by immutable registry digest after staging
  verification.
- Jenkins requires manual approval before production promotion and receives RBAC
  only on the production app and migration job.

## Consequences

The application data, secrets, identities, telemetry, deployment resources, and
Terraform state remain isolated. The Container Apps environment and virtual network
are shared, so they are not a complete security boundary between staging and
production.

If the subscription later permits another Container Apps environment, production
should move to its own environment and virtual network to restore the isolation
target from ADR 0002.
