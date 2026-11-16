# Production Recovery Runbook

## Purpose

This runbook describes how to verify and recover the OrderFlow production PostgreSQL database and Jenkins server.

It is designed to restore into new, isolated resources. Never overwrite production during a recovery drill.

## Production resources

| Component | Value |
|---|---|
| Production resource group | `rg-orderflow-production-swe` |
| PostgreSQL server | `psqlorderflowprodswellet6w` |
| PostgreSQL database | `orderflow` |
| PostgreSQL backup retention | 14 days |
| PostgreSQL public access | Disabled |
| PostgreSQL high availability | Disabled |
| PostgreSQL geo-redundant backup | Disabled |
| Jenkins resource group | `rg-orderflow-jenkins-swe` |
| Recovery Services vault | `rsv-orderflow-jenkins-swe` |
| Jenkins VM | `vm-orderflow-jenkins-swe` |

## Safety rules

- Confirm the production incident before beginning recovery.
- Never delete, overwrite, or modify the production PostgreSQL server.
- Restore to a new server with a unique `psql-orderflow-dr-<timestamp>` name.
- Use UTC timestamps for point-in-time recovery.
- Delete temporary recovery resources immediately after verification.
- Do not expose the restored database publicly.

## PostgreSQL backup verification

```bash
az postgres flexible-server show \
  --resource-group rg-orderflow-production-swe \
  --name psqlorderflowprodswellet6w \
  --query '{
    Server:name,
    State:state,
    BackupRetentionDays:backup.backupRetentionDays,
    GeoRedundantBackup:backup.geoRedundantBackup,
    HighAvailability:highAvailability.mode,
    PublicNetworkAccess:network.publicNetworkAccess
  }' \
  --output json
