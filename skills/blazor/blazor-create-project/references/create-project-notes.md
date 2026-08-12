# Create Project - Reference Notes

## Quick Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| 401 Unauthorized on POST | Missing or wrong `X-Api-Key` header | Read from config: `Config["RequestService:ApiKeys:0"]` |
| Database not created | `master` connection failed | Check SQL Server is running, trusted_connection=True |
| Form validation fail | Empty required fields | Ensure Name, LoginTokenHash, EncryptionKey, ApiKey, ConnectionString, DatabaseName are filled |
| CREATE DATABASE fails | Already exists, race condition | SQL will silently succeed inside `IF DB_ID IS NULL` block |

## API Endpoints Used

| Method | Endpoint | Body | Headers |
|--------|----------|------|---------|
| POST | `/api/projects` | `CreateProjectDto` | `X-Api-Key: <central_key>` |
| GET | `/create-project` | — | — |

## Expected Response

```json
// Success (200)
{
  "projectGuid": "aaaa...".
}

// Error (400/500)
{
  "error": "...."
}
```

## Database Schema

Insert column mapping for `dbo.Projects`:

| Json Property | DB Column |
|--------------|-----------|
| `ProjectGuid` | `ProjectGuid` (uniqueidentifier) |
| `Name` | `Name` (nvarchar) |
| `Schema` | `Schema` (nvarchar, default "dbo") |
| `LoginTokenHash` | `LoginTokenHash` (nvarchar) |
| `EncryptionKey` | `EncryptionKey` (nvarchar) |
| `ApiKey` | `ApiKey` (nvarchar) |
| `SessionTimeoutMinutes` | `SessionTimeoutMinutes` (int, default 10) |
| `IsActive` | `IsActive` (bit, default true) |
| `ConnectionString` | `ConnectionString` (nvarchar) |
| `DatabaseName` | `DatabaseName` (nvarchar) |
| `DatabaseProvider` | `DatabaseProvider` (nvarchar, default "SqlServer") |
| `AutoBackupEnabled` | `AutoBackupEnabled` (bit) |
| `AutoBackupIntervalMinutes` | `AutoBackupIntervalMinutes` (int, default 1440) |
| `AutoBackupTimeUtc` | `AutoBackupTimeUtc` (time) |
| `MaxBackupRetention` | `MaxBackupRetention` (int, default 7) |
| `Description` | `Description` (nvarchar, nullable) |
| `CreatedAtUtc` | `CreatedAtUtc` (datetime2, default GETUTCDATE()) |