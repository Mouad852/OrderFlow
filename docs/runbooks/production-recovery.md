# Production Recovery Runbook

## Purpose

This runbook explains how to verify and recover the OrderFlow production PostgreSQL database and Jenkins VM without overwriting the live services.

## Production resources

| Component | Value |
|---|---|
| Production resource group | `rg-orderflow-production-swe` |
| PostgreSQL server | `psqlorderflowprodswellet6w` |
| PostgreSQL database | `orderflow` |
| PostgreSQL backup retention | 14 days |
| Jenkins resource group | `rg-orderflow-jenkins-swe` |
| Recovery Services vault | `rsv-orderflow-jenkins-swe` |
| Jenkins VM | `vm-orderflow-jenkins-swe` |

## Safety rules

- Confirm the incident before beginning recovery.
- Never overwrite or delete the production PostgreSQL server.
- Restore PostgreSQL to a uniquely named temporary server.
- Restore Jenkins disks only to an isolated temporary resource group.
- Use UTC timestamps for point-in-time recovery.
- Do not expose restored databases publicly.
- Delete all temporary recovery resources immediately after verification.
- Do not place administrator passwords, connection strings, or access tokens in terminal history, source control, or this document.

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
```

Expected result: the server is `Ready`, backup retention is at least 14 days, and public network access is disabled.

## PostgreSQL point-in-time restore

Read the current source and networking values. Do not hard-code these IDs because infrastructure can change.

```bash
SOURCE_RG="rg-orderflow-production-swe"
SOURCE_SERVER="psqlorderflowprodswellet6w"

az postgres flexible-server show \
  --resource-group "$SOURCE_RG" \
  --name "$SOURCE_SERVER" \
  --query '{
    SourceId:id,
    SubnetId:network.delegatedSubnetResourceId,
    PrivateDnsZoneId:network.privateDnsZoneArmResourceId
  }' \
  --output json
```

Export the returned values, then choose a point at least ten minutes in the past to allow backup logs to become available.

```bash
SOURCE_ID="<SourceId>"
RESTORE_SUBNET_ID="<SubnetId>"
RESTORE_DNS_ZONE_ID="<PrivateDnsZoneId>"
RESTORE_SERVER="psql-orderflow-dr-$(date -u +%Y%m%d%H%M%S)"
RESTORE_TIME="$(date -u -d '10 minutes ago' +'%Y-%m-%dT%H:%M:%SZ')"
```

Restore into an isolated private server:

```bash
az postgres flexible-server restore \
  --resource-group "$SOURCE_RG" \
  --name "$RESTORE_SERVER" \
  --source-server "$SOURCE_ID" \
  --restore-time "$RESTORE_TIME" \
  --subnet "$RESTORE_SUBNET_ID" \
  --private-dns-zone "$RESTORE_DNS_ZONE_ID" \
  --sku-name "Standard_D2ds_v5" \
  --tier "GeneralPurpose" \
  --zone "1" \
  --yes \
  --output json
```

`Standard_D2ds_v5` was used during the November 2026 drill because Azure did not have capacity for a new `Standard_D2s_v3` server.

## PostgreSQL restore verification and cleanup

```bash
az postgres flexible-server show \
  --resource-group "$SOURCE_RG" \
  --name "$RESTORE_SERVER" \
  --query '{Name:name,State:state,Fqdn:fullyQualifiedDomainName}' \
  --output json

az postgres flexible-server db list \
  --resource-group "$SOURCE_RG" \
  --server-name "$RESTORE_SERVER" \
  --query '[].{Name:name,Charset:charset,Collation:collation}' \
  --output table
```

The server must be `Ready` and the table must contain the `orderflow` database with `UTF8` and `en_US.utf8`.

Delete only the temporary server after verification:

```bash
az postgres flexible-server delete \
  --resource-group "$SOURCE_RG" \
  --name "$RESTORE_SERVER" \
  --yes
```

## Jenkins backup verification

```bash
az backup item list \
  --resource-group rg-orderflow-jenkins-swe \
  --vault-name rsv-orderflow-jenkins-swe \
  --backup-management-type AzureIaasVM \
  --output table

az backup recoverypoint list \
  --resource-group rg-orderflow-jenkins-swe \
  --vault-name rsv-orderflow-jenkins-swe \
  --backup-management-type AzureIaasVM \
  --container-name vm-orderflow-jenkins-swe \
  --item-name vm-orderflow-jenkins-swe \
  --output table
```

Expected result: protection is `Healthy`, the last backup is `Completed`, and at least one recovery point exists.

## Jenkins disk recovery drill

This restores the VM backup as separate managed disks. It does not restart, replace, or change the live Jenkins VM.

Create isolated temporary resources:

```bash
RESTORE_RG="rg-orderflow-jenkins-restore-drill-swe"
RESTORE_LOCATION="swedencentral"
RESTORE_STORAGE="stofjenkinsdr$(date -u +%s)"

az group create \
  --name "$RESTORE_RG" \
  --location "$RESTORE_LOCATION"

az storage account create \
  --resource-group "$RESTORE_RG" \
  --name "$RESTORE_STORAGE" \
  --location "$RESTORE_LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false
```

Restore the latest recovery point into the temporary resource group:

```bash
VAULT_RG="rg-orderflow-jenkins-swe"
VAULT_NAME="rsv-orderflow-jenkins-swe"
JENKINS_VM="vm-orderflow-jenkins-swe"

RECOVERY_POINT="$(
  az backup recoverypoint list \
    --resource-group "$VAULT_RG" \
    --vault-name "$VAULT_NAME" \
    --backup-management-type AzureIaasVM \
    --container-name "$JENKINS_VM" \
    --item-name "$JENKINS_VM" \
    --query '[0].name' \
    --output tsv
)"

az backup restore restore-disks \
  --resource-group "$VAULT_RG" \
  --vault-name "$VAULT_NAME" \
  --container-name "$JENKINS_VM" \
  --item-name "$JENKINS_VM" \
  --rp-name "$RECOVERY_POINT" \
  --restore-mode AlternateLocation \
  --storage-account "$RESTORE_STORAGE" \
  --storage-account-resource-group "$RESTORE_RG" \
  --target-resource-group "$RESTORE_RG" \
  --output json
```

Wait for the returned Azure Backup job to report `Completed`, then verify an unattached disk exists in the temporary resource group:

```bash
az disk list \
  --resource-group "$RESTORE_RG" \
  --query '[].{Name:name,State:diskState,SizeGB:diskSizeGb,Source:creationData.sourceResourceId}' \
  --output table
```

Delete all temporary drill resources:

```bash
az group delete --name "$RESTORE_RG" --yes --no-wait
```

## Known resilience limitations

- PostgreSQL high availability is disabled.
- PostgreSQL geo-redundant backup is disabled, so regional recovery is not currently available.
- Azure SKU capacity can delay or block a same-region PostgreSQL restore.
- Jenkins disk recovery has been tested successfully, but a fully booted replacement Jenkins VM has not yet been tested.

## Recovery rehearsal record

| Date | Component | Result |
|---|---|---|
| 2026-11-16 | Production PostgreSQL | Passed: a point-in-time restore created a private isolated server containing the `orderflow` database. The temporary server was deleted afterward. |
| 2026-11-16 | Jenkins VM | Passed: Azure Backup restored the Jenkins OS disk as an unattached managed disk in an isolated temporary resource group. All temporary resources were deleted afterward. |
