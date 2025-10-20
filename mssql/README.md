### Custom MSSQL chart
This chart is inspired by https://gitlab.com/xrow-public/helm-mssql with the main modification being able to run multiple MSSQL servers under one chart.

The image that we are using(`gcr.io/cloudkite-public/mssql:2022`) is a from `registry.gitlab.com/xrow-public/helm-mssql/mssql:1.2.0` that has been pulled without any modification.

## Backup Configuration

This chart supports a sophisticated multi-tier backup strategy for MSSQL databases, combining Full, Differential, and Transaction Log backups. All backups are stored directly to AWS S3 using SQL Server's native S3 backup functionality.

### Understanding MSSQL Backup Types

#### 1. Full Backup
A **Full Backup** creates a complete copy of the entire database, including all data files and objects (tables, procedures, functions, views, indexes, etc.).

**Characteristics:**
- Captures everything in the database at a point in time
- Establishes a "base" for differential backups
- Largest backup size, takes the longest time
- Essential for any restore operation
- Uses T-SQL command: `BACKUP DATABASE [db] WITH FORMAT, COMPRESSION`

**When to use:**
- As the foundation of any backup strategy (required)
- Weekly or daily, depending on database size and criticality
- After major schema changes or data migrations

#### 2. Differential Backup
A **Differential Backup** captures only the data that has changed since the last FULL backup.

**Characteristics:**
- Much faster and smaller than full backups
- Each differential backup grows larger as more changes accumulate
- Relies on the most recent full backup as its "base"
- Uses T-SQL command: `BACKUP DATABASE [db] WITH DIFFERENTIAL, COMPRESSION`

**How it works:**
- SQL Server tracks changed extents (groups of 8 pages) using a differential bitmap
- When you run a full backup, the bitmap resets
- Each differential backup captures all changes since that full backup
- Each subsequent differential is cumulative (includes all changes since the last full)

**When to use:**
- Between full backups for more frequent protection
- Daily or every few hours for production databases
- When you want faster backups than full but still need database-level recovery

**Important:** Once you take a new full backup, the differential "chain" resets. All previous differential backups become obsolete because they reference the old full backup.

#### 3. Transaction Log Backup
A **Transaction Log Backup** captures all database transactions since the last log backup.

**Characteristics:**
- Enables point-in-time recovery (restore to a specific moment)
- Only works with databases in FULL or BULK_LOGGED recovery model
- Very small and fast (only captures transaction log records)
- Sequential - must be applied in order during restore
- Uses T-SQL command: `BACKUP LOG [db] WITH COMPRESSION`

**When to use:**
- For critical databases requiring minimal data loss (low RPO)
- Every 15-30 minutes for high-availability scenarios
- When you need the ability to restore to a specific point in time
- To keep the transaction log size manageable

**Note:** Not included in default configuration. Enable only if your database is in FULL recovery model and you need point-in-time recovery.

### Backup Strategy Patterns

The chart supports three common backup patterns:

#### Pattern 1: Basic (Small/Medium databases, Dev/Staging)
```yaml
backup:
  strategy:
    full:
      enabled: true
      schedule: "0 2 * * 0"  # Weekly on Sunday at 2 AM
      retentionDays: 90
    differential:
      enabled: true
      schedule: "0 2 * * 1-6"  # Daily Mon-Sat at 2 AM
      retentionDays: 30
    log:
      enabled: false
```
- **RPO (Recovery Point Objective):** ~24 hours
- **RTO (Recovery Time Objective):** Fast (restore 1 full + 1 differential)
- **Storage usage:** Low
- **Best for:** Non-critical databases, development, staging environments

#### Pattern 2: Standard (Production databases)
```yaml
backup:
  strategy:
    full:
      enabled: true
      schedule: "0 2 * * *"  # Daily at 2 AM
      retentionDays: 90
    differential:
      enabled: true
      schedule: "0 */6 * * *"  # Every 6 hours
      retentionDays: 30
    log:
      enabled: false
```
- **RPO:** ~6 hours
- **RTO:** Fast
- **Storage usage:** Medium
- **Best for:** Most production databases with standard availability requirements

#### Pattern 3: High Availability (Critical databases)
```yaml
backup:
  strategy:
    full:
      enabled: true
      schedule: "0 2 * * *"  # Daily at 2 AM
      retentionDays: 90
    differential:
      enabled: true
      schedule: "0 */3 * * *"  # Every 3 hours
      retentionDays: 30
    log:
      enabled: true
      schedule: "*/15 * * * *"  # Every 15 minutes
      retentionDays: 7
```
- **RPO:** ~15 minutes (can restore to any point in time)
- **RTO:** Moderate (requires replaying transaction logs)
- **Storage usage:** Higher
- **Best for:** Critical databases with strict availability SLAs

### S3 Organization

Backups are organized in S3 with the following structure:

```
s3://your-backup-bucket/
  └── backups/
      └── {database_name}/
          ├── full/
          │   ├── db_a-full-2025-01-20-02-00-00.bak
          │   ├── db_a-full-2025-01-27-02-00-00.bak
          │   └── db_a-full-2025-02-03-02-00-00.bak
          ├── differential/
          │   ├── db_a-diff-2025-01-21-02-00-00.bak
          │   ├── db_a-diff-2025-01-22-02-00-00.bak
          │   └── db_a-diff-2025-01-26-02-00-00.bak
          └── log/
              ├── db_a-log-2025-01-26-12-00-00.trn
              ├── db_a-log-2025-01-26-12-15-00.trn
              └── db_a-log-2025-01-26-12-30-00.trn
```

### Restore Process

#### Restore from Full + Differential Backup

1. **Identify the backups needed:**
   - Most recent FULL backup before the desired restore point
   - Most recent DIFFERENTIAL backup before the desired restore point

2. **Restore the full backup:**
   ```sql
   RESTORE DATABASE [db_a]
   FROM URL = 's3://your-bucket/backups/db_a/full/db_a-full-2025-01-20-02-00-00.bak'
   WITH NORECOVERY,
   CREDENTIAL = 's3://your-bucket.s3.us-east-1.amazonaws.com';
   ```

3. **Restore the differential backup:**
   ```sql
   RESTORE DATABASE [db_a]
   FROM URL = 's3://your-bucket/backups/db_a/differential/db_a-diff-2025-01-26-02-00-00.bak'
   WITH RECOVERY,
   CREDENTIAL = 's3://your-bucket.s3.us-east-1.amazonaws.com';
   ```

**Note:** You only need the latest differential backup. All previous differential backups can be ignored as each differential is cumulative.

#### Restore from Full + Differential + Transaction Logs

1. **Restore the full backup with NORECOVERY:**
   ```sql
   RESTORE DATABASE [db_a]
   FROM URL = 's3://your-bucket/backups/db_a/full/db_a-full-2025-01-20-02-00-00.bak'
   WITH NORECOVERY,
   CREDENTIAL = 's3://your-bucket.s3.us-east-1.amazonaws.com';
   ```

2. **Restore the differential backup with NORECOVERY:**
   ```sql
   RESTORE DATABASE [db_a]
   FROM URL = 's3://your-bucket/backups/db_a/differential/db_a-diff-2025-01-26-02-00-00.bak'
   WITH NORECOVERY,
   CREDENTIAL = 's3://your-bucket.s3.us-east-1.amazonaws.com';
   ```

3. **Restore transaction log backups in sequence:**
   ```sql
   -- Restore each log backup in chronological order
   RESTORE LOG [db_a]
   FROM URL = 's3://your-bucket/backups/db_a/log/db_a-log-2025-01-26-12-00-00.trn'
   WITH NORECOVERY,
   CREDENTIAL = 's3://your-bucket.s3.us-east-1.amazonaws.com';

   RESTORE LOG [db_a]
   FROM URL = 's3://your-bucket/backups/db_a/log/db_a-log-2025-01-26-12-15-00.trn'
   WITH NORECOVERY,
   CREDENTIAL = 's3://your-bucket.s3.us-east-1.amazonaws.com';

   -- Last log restore with RECOVERY to bring database online
   RESTORE LOG [db_a]
   FROM URL = 's3://your-bucket/backups/db_a/log/db_a-log-2025-01-26-12-30-00.trn'
   WITH RECOVERY,
   CREDENTIAL = 's3://your-bucket.s3.us-east-1.amazonaws.com';
   ```

4. **Or restore to a specific point in time:**
   ```sql
   RESTORE LOG [db_a]
   FROM URL = 's3://your-bucket/backups/db_a/log/db_a-log-2025-01-26-12-30-00.trn'
   WITH RECOVERY, STOPAT = '2025-01-26 12:25:00',
   CREDENTIAL = 's3://your-bucket.s3.us-east-1.amazonaws.com';
   ```

### Configuration Example

```yaml
databases:
  - name: db-a
    database: db_a
    backup:
      enabled: true
      s3Bucket: "your-primary-backup-bucket"
      s3Region: "us-east-1"

      # Backup strategy configuration
      strategy:
        # Full backup schedule (required as base for differential)
        full:
          enabled: true
          schedule: "0 2 * * 0"  # Weekly on Sunday at 2:00 AM UTC
          retentionDays: 90       # Keep for 3 months

        # Differential backup schedule (requires full backups)
        differential:
          enabled: true
          schedule: "0 2 * * 1-6"  # Daily Mon-Sat at 2:00 AM UTC
          retentionDays: 30        # Keep for 1 month

        # Transaction log backup (optional, for point-in-time recovery)
        log:
          enabled: false
          schedule: "*/30 * * * *"  # Every 30 minutes
          retentionDays: 7          # Keep for 1 week

      image:
        repository: gcr.io/cloudkite-public/mssql
        tag: "2022"
        pullPolicy: IfNotPresent

      serviceAccount:
        create: true
        name: "db-a-backup-sa"
        annotations:
          eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/mssql-backup-role-for-db-a"
```

### IAM Permissions Required

The service account's IAM role needs the following S3 permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-backup-bucket",
        "arn:aws:s3:::your-backup-bucket/*"
      ]
    }
  ]
}
```
