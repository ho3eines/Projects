-- Database-enforced isolation for short-lived tz_m_* SQL users.
-- Web/bootstrap identities remain trusted. Mobile identity is derived only from
-- the immutable generated database user -> active broker session mapping; caller
-- supplied CustomerGuid and SESSION_CONTEXT never select a mobile tenant.
-- All function, ownership, and policy upgrades are one transaction: a failed
-- migration cannot leave only part of the RLS boundary installed.
SET XACT_ABORT ON;
SET QUOTED_IDENTIFIER ON;
BEGIN TRY
    BEGIN TRANSACTION;

-- Authoritative v4 tenant-default function. Generated mobile principals can
-- resolve only their live broker-bound company. Trusted Web/bootstrap identities
-- retain the existing active-context/fallback behavior used by business-table
-- defaults. The object version makes upgrades explicit and avoids ALTERing a
-- schema-bound function on every startup.
DECLARE @MobileCompanyFunctionVersion INT =
(
    SELECT TRY_CONVERT(INT, ep.[value])
    FROM sys.extended_properties AS ep
    WHERE ep.class = 1
      AND ep.major_id = OBJECT_ID(N'[central].[fn_MobileCompanyId]')
      AND ep.minor_id = 0
      AND ep.name = N'Tarazin.SecurityDefinitionVersion'
);

IF OBJECT_ID(N'[central].[fn_MobileCompanyId]', N'FN') IS NULL
   OR COALESCE(@MobileCompanyFunctionVersion, 0) < 4
BEGIN
    DECLARE @MobileCompanyFunctionSql NVARCHAR(MAX) =
        CASE WHEN OBJECT_ID(N'[central].[fn_MobileCompanyId]', N'FN') IS NULL
             THEN N'CREATE' ELSE N'ALTER' END + N'
        FUNCTION [central].[fn_MobileCompanyId]()
        RETURNS INT
        WITH SCHEMABINDING
        AS
        BEGIN
            DECLARE @CompanyId INT;
            IF LEFT(USER_NAME(), 5) = N''tz_m_''
                SELECT @CompanyId = s.CompanyId
                FROM [central].[MobileCredentialSessions] AS s
                JOIN [central].[CredentialCustomers] AS cc
                  ON cc.CredentialCustomerId = s.CustomerId
                 AND cc.CustomerGuid = s.CustomerGuid
                 AND cc.CompanyId = s.CompanyId
                JOIN [central].[Companies] AS c ON c.CompanyId = s.CompanyId
                WHERE s.SqlLoginName = USER_NAME()
                  AND s.ActivatedAt IS NOT NULL
                  AND s.RevokedAt IS NULL
                  AND s.CredentialExpiresAt > SYSUTCDATETIME()
                  AND s.SessionExpiresAt > SYSUTCDATETIME()
                  AND cc.IsActive = 1
                  AND cc.CredentialAccessEnabled = 1
                  AND c.IsActive = 1
                  AND c.IsDeleted = 0;
            ELSE
            BEGIN
                SET @CompanyId = TRY_CONVERT(INT, SESSION_CONTEXT(N''TarazinCompanyId''));
                IF @CompanyId IS NULL
                    SELECT TOP (1) @CompanyId = c.CompanyId
                    FROM [central].[Companies] AS c
                    WHERE c.IsDeleted = 0
                    ORDER BY c.CompanyId;
            END;
            RETURN @CompanyId;
        END';
    EXEC sys.sp_executesql @MobileCompanyFunctionSql;

    IF EXISTS
       (SELECT 1 FROM sys.extended_properties
        WHERE class = 1 AND major_id = OBJECT_ID(N'[central].[fn_MobileCompanyId]')
          AND minor_id = 0 AND name = N'Tarazin.SecurityDefinitionVersion')
        EXEC sys.sp_updateextendedproperty
            @name = N'Tarazin.SecurityDefinitionVersion', @value = 4,
            @level0type = N'SCHEMA', @level0name = N'central',
            @level1type = N'FUNCTION', @level1name = N'fn_MobileCompanyId';
    ELSE
        EXEC sys.sp_addextendedproperty
            @name = N'Tarazin.SecurityDefinitionVersion', @value = 4,
            @level0type = N'SCHEMA', @level0name = N'central',
            @level1type = N'FUNCTION', @level1name = N'fn_MobileCompanyId';
END

EXEC(N'
    CREATE OR ALTER FUNCTION [central].[fn_MobileSessionAccessInt](@Anchor INT)
    RETURNS TABLE
    WITH SCHEMABINDING
    AS
    RETURN
    (
        SELECT 1 AS IsAllowed
        WHERE LEFT(USER_NAME(), 5) <> N''tz_m_''
           OR EXISTS
              (
                  SELECT 1
                  FROM [central].[MobileCredentialSessions] AS s
                  JOIN [central].[CredentialCustomers] AS c
                    ON c.CredentialCustomerId = s.CustomerId
                   AND c.CustomerGuid = s.CustomerGuid
                   AND c.CompanyId = s.CompanyId
                  JOIN [central].[Companies] AS company ON company.CompanyId = s.CompanyId
                  WHERE s.SqlLoginName = USER_NAME()
                    AND s.ActivatedAt IS NOT NULL
                    AND s.RevokedAt IS NULL
                    AND s.CredentialExpiresAt > SYSUTCDATETIME()
                    AND s.SessionExpiresAt > SYSUTCDATETIME()
                    AND c.IsActive = 1
                    AND c.CredentialAccessEnabled = 1
                    AND company.IsActive = 1
                    AND company.IsDeleted = 0
              )
    )');

EXEC(N'
    CREATE OR ALTER FUNCTION [central].[fn_MobileSessionAccessBigInt](@Anchor BIGINT)
    RETURNS TABLE
    WITH SCHEMABINDING
    AS
    RETURN
    (
        SELECT 1 AS IsAllowed
        WHERE LEFT(USER_NAME(), 5) <> N''tz_m_''
           OR EXISTS
              (
                  SELECT 1
                  FROM [central].[MobileCredentialSessions] AS s
                  JOIN [central].[CredentialCustomers] AS c
                    ON c.CredentialCustomerId = s.CustomerId
                   AND c.CustomerGuid = s.CustomerGuid
                   AND c.CompanyId = s.CompanyId
                  JOIN [central].[Companies] AS company ON company.CompanyId = s.CompanyId
                  WHERE s.SqlLoginName = USER_NAME()
                    AND s.ActivatedAt IS NOT NULL
                    AND s.RevokedAt IS NULL
                    AND s.CredentialExpiresAt > SYSUTCDATETIME()
                    AND s.SessionExpiresAt > SYSUTCDATETIME()
                    AND c.IsActive = 1
                    AND c.CredentialAccessEnabled = 1
                    AND company.IsActive = 1
                    AND company.IsDeleted = 0
              )
    )');

EXEC(N'
    CREATE OR ALTER FUNCTION [central].[fn_MobileSessionAccessString](@Anchor NVARCHAR(50))
    RETURNS TABLE
    WITH SCHEMABINDING
    AS
    RETURN
    (
        SELECT 1 AS IsAllowed
        WHERE LEFT(USER_NAME(), 5) <> N''tz_m_''
           OR EXISTS
              (
                  SELECT 1
                  FROM [central].[MobileCredentialSessions] AS s
                  JOIN [central].[CredentialCustomers] AS c
                    ON c.CredentialCustomerId = s.CustomerId
                   AND c.CustomerGuid = s.CustomerGuid
                   AND c.CompanyId = s.CompanyId
                  JOIN [central].[Companies] AS company ON company.CompanyId = s.CompanyId
                  WHERE s.SqlLoginName = USER_NAME()
                    AND s.ActivatedAt IS NOT NULL
                    AND s.RevokedAt IS NULL
                    AND s.CredentialExpiresAt > SYSUTCDATETIME()
                    AND s.SessionExpiresAt > SYSUTCDATETIME()
                    AND c.IsActive = 1
                    AND c.CredentialAccessEnabled = 1
                    AND company.IsActive = 1
                    AND company.IsDeleted = 0
              )
    )');

-- Global/shared rows are readable to every live generated session, but writes
-- are safe only when exactly one enabled credential customer exists. This
-- preserves single-customer behavior without allowing one MAUI customer to
-- alter shared role/content/rate rows observed by another customer.
EXEC(N'
    CREATE OR ALTER FUNCTION [central].[fn_MobileGlobalWriteInt](@Anchor INT)
    RETURNS TABLE
    WITH SCHEMABINDING
    AS
    RETURN
    (
        SELECT 1 AS IsAllowed
        WHERE LEFT(USER_NAME(), 5) <> N''tz_m_''
           OR EXISTS
              (
                  SELECT 1
                  FROM [central].[MobileCredentialSessions] AS s
                  JOIN [central].[CredentialCustomers] AS c
                    ON c.CredentialCustomerId = s.CustomerId
                   AND c.CustomerGuid = s.CustomerGuid
                   AND c.CompanyId = s.CompanyId
                  JOIN [central].[Companies] AS company ON company.CompanyId = s.CompanyId
                  WHERE s.SqlLoginName = USER_NAME()
                    AND s.ActivatedAt IS NOT NULL
                    AND s.RevokedAt IS NULL
                    AND s.CredentialExpiresAt > SYSUTCDATETIME()
                    AND s.SessionExpiresAt > SYSUTCDATETIME()
                    AND c.IsActive = 1
                    AND c.CredentialAccessEnabled = 1
                    AND company.IsActive = 1
                    AND company.IsDeleted = 0
                    AND NOT EXISTS
                        (SELECT 1
                         FROM [central].[CredentialCustomers] AS other
                         WHERE other.IsActive = 1
                           AND other.CredentialAccessEnabled = 1
                           AND other.CredentialCustomerId <> c.CredentialCustomerId)
              )
    )');

EXEC(N'
    CREATE OR ALTER FUNCTION [central].[fn_MobileGlobalWriteBigInt](@Anchor BIGINT)
    RETURNS TABLE
    WITH SCHEMABINDING
    AS
    RETURN
    (
        SELECT 1 AS IsAllowed
        WHERE LEFT(USER_NAME(), 5) <> N''tz_m_''
           OR EXISTS
              (
                  SELECT 1
                  FROM [central].[MobileCredentialSessions] AS s
                  JOIN [central].[CredentialCustomers] AS c
                    ON c.CredentialCustomerId = s.CustomerId
                   AND c.CustomerGuid = s.CustomerGuid
                   AND c.CompanyId = s.CompanyId
                  JOIN [central].[Companies] AS company ON company.CompanyId = s.CompanyId
                  WHERE s.SqlLoginName = USER_NAME()
                    AND s.ActivatedAt IS NOT NULL
                    AND s.RevokedAt IS NULL
                    AND s.CredentialExpiresAt > SYSUTCDATETIME()
                    AND s.SessionExpiresAt > SYSUTCDATETIME()
                    AND c.IsActive = 1
                    AND c.CredentialAccessEnabled = 1
                    AND company.IsActive = 1
                    AND company.IsDeleted = 0
                    AND NOT EXISTS
                        (SELECT 1
                         FROM [central].[CredentialCustomers] AS other
                         WHERE other.IsActive = 1
                           AND other.CredentialAccessEnabled = 1
                           AND other.CredentialCustomerId <> c.CredentialCustomerId)
              )
    )');

EXEC(N'
    CREATE OR ALTER FUNCTION [central].[fn_MobileGlobalWriteString](@Anchor NVARCHAR(50))
    RETURNS TABLE
    WITH SCHEMABINDING
    AS
    RETURN
    (
        SELECT 1 AS IsAllowed
        WHERE LEFT(USER_NAME(), 5) <> N''tz_m_''
           OR EXISTS
              (
                  SELECT 1
                  FROM [central].[MobileCredentialSessions] AS s
                  JOIN [central].[CredentialCustomers] AS c
                    ON c.CredentialCustomerId = s.CustomerId
                   AND c.CustomerGuid = s.CustomerGuid
                   AND c.CompanyId = s.CompanyId
                  JOIN [central].[Companies] AS company ON company.CompanyId = s.CompanyId
                  WHERE s.SqlLoginName = USER_NAME()
                    AND s.ActivatedAt IS NOT NULL
                    AND s.RevokedAt IS NULL
                    AND s.CredentialExpiresAt > SYSUTCDATETIME()
                    AND s.SessionExpiresAt > SYSUTCDATETIME()
                    AND c.IsActive = 1
                    AND c.CredentialAccessEnabled = 1
                    AND company.IsActive = 1
                    AND company.IsDeleted = 0
                    AND NOT EXISTS
                        (SELECT 1
                         FROM [central].[CredentialCustomers] AS other
                         WHERE other.IsActive = 1
                           AND other.CredentialAccessEnabled = 1
                           AND other.CredentialCustomerId <> c.CredentialCustomerId)
              )
    )');

EXEC(N'
    CREATE OR ALTER FUNCTION [central].[fn_MobileCompanyAccess](@CompanyId INT)
    RETURNS TABLE
    WITH SCHEMABINDING
    AS
    RETURN
    (
        SELECT 1 AS IsAllowed
        WHERE LEFT(USER_NAME(), 5) <> N''tz_m_''
           OR EXISTS
              (
                  SELECT 1
                  FROM [central].[MobileCredentialSessions] AS s
                  JOIN [central].[CredentialCustomers] AS c
                    ON c.CredentialCustomerId = s.CustomerId
                   AND c.CustomerGuid = s.CustomerGuid
                   AND c.CompanyId = s.CompanyId
                  JOIN [central].[Companies] AS company ON company.CompanyId = s.CompanyId
                  WHERE s.SqlLoginName = USER_NAME()
                    AND s.ActivatedAt IS NOT NULL
                    AND s.CompanyId = @CompanyId
                    AND s.RevokedAt IS NULL
                    AND s.CredentialExpiresAt > SYSUTCDATETIME()
                    AND s.SessionExpiresAt > SYSUTCDATETIME()
                    AND c.IsActive = 1
                    AND c.CredentialAccessEnabled = 1
                    AND company.IsActive = 1
                    AND company.IsDeleted = 0
              )
    )');

-- Companies is itself protected by RLS, so its predicate must not query
-- [central].[Companies] (which would recursively invoke the same policy).
-- Active/deleted state is passed from the protected row instead.
EXEC(N'
    CREATE OR ALTER FUNCTION [central].[fn_MobileCompanyRowAccess]
        (@CompanyId INT, @IsActive BIT, @IsDeleted BIT)
    RETURNS TABLE
    WITH SCHEMABINDING
    AS
    RETURN
    (
        SELECT 1 AS IsAllowed
        WHERE LEFT(USER_NAME(), 5) <> N''tz_m_''
           OR
              (
                  @IsActive = 1
                  AND @IsDeleted = 0
                  AND EXISTS
                     (
                         SELECT 1
                         FROM [central].[MobileCredentialSessions] AS s
                         JOIN [central].[CredentialCustomers] AS c
                           ON c.CredentialCustomerId = s.CustomerId
                          AND c.CustomerGuid = s.CustomerGuid
                          AND c.CompanyId = s.CompanyId
                         WHERE s.SqlLoginName = USER_NAME()
                           AND s.ActivatedAt IS NOT NULL
                           AND s.CompanyId = @CompanyId
                           AND s.RevokedAt IS NULL
                           AND s.CredentialExpiresAt > SYSUTCDATETIME()
                           AND s.SessionExpiresAt > SYSUTCDATETIME()
                           AND c.IsActive = 1
                           AND c.CredentialAccessEnabled = 1
                     )
              )
    )');

EXEC(N'
    CREATE OR ALTER FUNCTION [central].[fn_MobileUserAccess](@UserId INT)
    RETURNS TABLE
    WITH SCHEMABINDING
    AS
    RETURN
    (
        SELECT 1 AS IsAllowed
        WHERE LEFT(USER_NAME(), 5) <> N''tz_m_''
           OR EXISTS
              (
                  SELECT 1
                  FROM [central].[MobileCredentialSessions] AS s
                  JOIN [central].[CredentialCustomers] AS c
                    ON c.CredentialCustomerId = s.CustomerId
                   AND c.CustomerGuid = s.CustomerGuid
                   AND c.CompanyId = s.CompanyId
                  JOIN [central].[Companies] AS company ON company.CompanyId = s.CompanyId
                  WHERE s.SqlLoginName = USER_NAME()
                    AND s.ActivatedAt IS NOT NULL
                    AND s.RevokedAt IS NULL
                    AND s.CredentialExpiresAt > SYSUTCDATETIME()
                    AND s.SessionExpiresAt > SYSUTCDATETIME()
                    AND c.IsActive = 1
                    AND c.CredentialAccessEnabled = 1
                    AND company.IsActive = 1
                    AND company.IsDeleted = 0
                    AND
                    (
                        s.UserId = @UserId
                        OR EXISTS
                           (
                               SELECT 1
                               FROM [central].[UserCompanies] AS uc
                               WHERE uc.UserId = @UserId
                                 AND uc.CompanyId = s.CompanyId
                           )
                    )
              )
    )');

EXEC(N'
    CREATE OR ALTER FUNCTION [central].[fn_MobileFiscalYearAccess](@FiscalYearId INT)
    RETURNS TABLE
    WITH SCHEMABINDING
    AS
    RETURN
    (
        SELECT 1 AS IsAllowed
        WHERE LEFT(USER_NAME(), 5) <> N''tz_m_''
           OR EXISTS
              (
                  SELECT 1
                  FROM [central].[FiscalYears] AS fy
                  JOIN [central].[MobileCredentialSessions] AS s
                    ON s.CompanyId = fy.CompanyId
                  JOIN [central].[CredentialCustomers] AS c
                    ON c.CredentialCustomerId = s.CustomerId
                   AND c.CustomerGuid = s.CustomerGuid
                   AND c.CompanyId = s.CompanyId
                  JOIN [central].[Companies] AS company ON company.CompanyId = s.CompanyId
                  WHERE fy.FiscalYearId = @FiscalYearId
                    AND s.SqlLoginName = USER_NAME()
                    AND s.ActivatedAt IS NOT NULL
                    AND s.RevokedAt IS NULL
                    AND s.CredentialExpiresAt > SYSUTCDATETIME()
                    AND s.SessionExpiresAt > SYSUTCDATETIME()
                    AND c.IsActive = 1
                    AND c.CredentialAccessEnabled = 1
                    AND company.IsActive = 1
                    AND company.IsDeleted = 0
              )
    )');

-- Generated principals receive direct DML grants so the existing MAUI scripts
-- continue to work. These owner-executed triggers are the database authorization
-- boundary for security-sensitive global RBAC rows: ad-hoc SQL cannot promote a
-- company user to Admin or compose a role with privileges the actor does not
-- already hold. Trusted Web/bootstrap logins retain their existing behavior.
EXEC(N'
    CREATE OR ALTER TRIGGER [central].[trg_MobileUsersAuthorization]
    ON [central].[Users]
    WITH EXECUTE AS OWNER
    AFTER INSERT, UPDATE
    AS
    BEGIN
        SET NOCOUNT ON;
        DECLARE @LoginName SYSNAME = ORIGINAL_LOGIN();
        IF LEFT(@LoginName, 5) <> N''tz_m_'' RETURN;

        DECLARE @ActorUserId INT, @ActorRoleId INT, @ActorRole NVARCHAR(40);
        SELECT TOP (1)
            @ActorUserId = actor.UserId,
            @ActorRoleId = CASE WHEN previousActor.UserId IS NOT NULL
                                THEN previousActor.RoleId ELSE actor.RoleId END,
            @ActorRole = CASE WHEN previousActor.UserId IS NOT NULL
                              THEN previousActor.Role ELSE actor.Role END
        FROM [central].[MobileCredentialSessions] AS s
        JOIN [central].[CredentialCustomers] AS customer
          ON customer.CredentialCustomerId = s.CustomerId
         AND customer.CustomerGuid = s.CustomerGuid
         AND customer.CompanyId = s.CompanyId
        JOIN [central].[Companies] AS company ON company.CompanyId = s.CompanyId
        JOIN [central].[Users] AS actor ON actor.UserId = s.UserId
        LEFT JOIN deleted AS previousActor ON previousActor.UserId = actor.UserId
        WHERE s.SqlLoginName = @LoginName
          AND s.ActivatedAt IS NOT NULL
          AND s.RevokedAt IS NULL
          AND s.CredentialExpiresAt > SYSUTCDATETIME()
          AND s.SessionExpiresAt > SYSUTCDATETIME()
          AND customer.IsActive = 1
          AND customer.CredentialAccessEnabled = 1
          AND company.IsActive = 1
          AND company.IsDeleted = 0
          AND (CASE WHEN previousActor.UserId IS NOT NULL
                    THEN previousActor.IsActive ELSE actor.IsActive END) = 1
          AND (CASE WHEN previousActor.UserId IS NOT NULL
                    THEN previousActor.IsDeleted ELSE actor.IsDeleted END) = 0
          AND
              ((CASE WHEN previousActor.UserId IS NOT NULL
                      THEN previousActor.Role ELSE actor.Role END) = N''Admin''
               OR EXISTS
                  (SELECT 1 FROM [central].[UserCompanies] AS actorCompany
                   WHERE actorCompany.UserId = actor.UserId
                     AND actorCompany.CompanyId = s.CompanyId));

        IF @ActorUserId IS NULL
            THROW 51094, N''Mobile authorization is no longer active.'', 1;

        IF @ActorRole <> N''Admin'' AND EXISTS
        (
            SELECT 1
            FROM inserted AS changedUser
            LEFT JOIN [central].[Roles] AS targetRole
              ON targetRole.RoleId = changedUser.RoleId
             AND targetRole.IsDeleted = 0
            WHERE targetRole.RoleId IS NULL
               OR targetRole.RoleKey <> changedUser.Role
               OR targetRole.RoleKey = N''Admin''
               OR EXISTS
                  (
                      SELECT 1
                      FROM [central].[RolePermissions] AS targetPermission
                      WHERE targetPermission.RoleId = targetRole.RoleId
                        AND NOT EXISTS
                           (
                               SELECT 1
                               FROM [central].[RolePermissions] AS actorPermission
                               WHERE actorPermission.RoleId = @ActorRoleId
                                 AND actorPermission.PermissionId = targetPermission.PermissionId
                           )
                  )
        )
            THROW 51094, N''Mobile user role assignment exceeds the acting user permissions.'', 1;
    END');

EXEC(N'
    CREATE OR ALTER TRIGGER [central].[trg_MobileRolesAuthorization]
    ON [central].[Roles]
    WITH EXECUTE AS OWNER
    AFTER INSERT, UPDATE
    AS
    BEGIN
        SET NOCOUNT ON;
        DECLARE @LoginName SYSNAME = ORIGINAL_LOGIN();
        IF LEFT(@LoginName, 5) <> N''tz_m_'' RETURN;

        DECLARE @ActorUserId INT, @ActorRoleId INT, @ActorRole NVARCHAR(40);
        SELECT TOP (1)
            @ActorUserId = actor.UserId,
            @ActorRoleId = actor.RoleId,
            @ActorRole = actor.Role
        FROM [central].[MobileCredentialSessions] AS s
        JOIN [central].[CredentialCustomers] AS customer
          ON customer.CredentialCustomerId = s.CustomerId
         AND customer.CustomerGuid = s.CustomerGuid
         AND customer.CompanyId = s.CompanyId
        JOIN [central].[Companies] AS company ON company.CompanyId = s.CompanyId
        JOIN [central].[Users] AS actor ON actor.UserId = s.UserId
        WHERE s.SqlLoginName = @LoginName
          AND s.ActivatedAt IS NOT NULL
          AND s.RevokedAt IS NULL
          AND s.CredentialExpiresAt > SYSUTCDATETIME()
          AND s.SessionExpiresAt > SYSUTCDATETIME()
          AND customer.IsActive = 1
          AND customer.CredentialAccessEnabled = 1
          AND company.IsActive = 1
          AND company.IsDeleted = 0
          AND actor.IsActive = 1
          AND actor.IsDeleted = 0
          AND
              (actor.Role = N''Admin'' OR EXISTS
                  (SELECT 1 FROM [central].[UserCompanies] AS actorCompany
                   WHERE actorCompany.UserId = actor.UserId
                     AND actorCompany.CompanyId = s.CompanyId));

        IF @ActorUserId IS NULL
            THROW 51094, N''Mobile authorization is no longer active.'', 1;

        IF @ActorRole <> N''Admin'' AND EXISTS
        (
            SELECT 1
            FROM inserted AS changedRole
            WHERE changedRole.IsSystem = 1
               OR changedRole.RoleKey = N''Admin''
               OR changedRole.RoleId = @ActorRoleId
               OR EXISTS
                  (
                      SELECT 1
                      FROM [central].[RolePermissions] AS targetPermission
                      WHERE targetPermission.RoleId = changedRole.RoleId
                        AND NOT EXISTS
                           (
                               SELECT 1
                               FROM [central].[RolePermissions] AS actorPermission
                               WHERE actorPermission.RoleId = @ActorRoleId
                                 AND actorPermission.PermissionId = targetPermission.PermissionId
                           )
                  )
        )
            THROW 51094, N''Mobile role mutation exceeds the acting user permissions.'', 1;
    END');

EXEC(N'
    CREATE OR ALTER TRIGGER [central].[trg_MobileRolePermissionsAuthorization]
    ON [central].[RolePermissions]
    WITH EXECUTE AS OWNER
    AFTER INSERT, UPDATE, DELETE
    AS
    BEGIN
        SET NOCOUNT ON;
        DECLARE @LoginName SYSNAME = ORIGINAL_LOGIN();
        IF LEFT(@LoginName, 5) <> N''tz_m_'' RETURN;

        DECLARE @ActorUserId INT, @ActorRoleId INT, @ActorRole NVARCHAR(40);
        SELECT TOP (1)
            @ActorUserId = actor.UserId,
            @ActorRoleId = actor.RoleId,
            @ActorRole = actor.Role
        FROM [central].[MobileCredentialSessions] AS s
        JOIN [central].[CredentialCustomers] AS customer
          ON customer.CredentialCustomerId = s.CustomerId
         AND customer.CustomerGuid = s.CustomerGuid
         AND customer.CompanyId = s.CompanyId
        JOIN [central].[Companies] AS company ON company.CompanyId = s.CompanyId
        JOIN [central].[Users] AS actor ON actor.UserId = s.UserId
        WHERE s.SqlLoginName = @LoginName
          AND s.ActivatedAt IS NOT NULL
          AND s.RevokedAt IS NULL
          AND s.CredentialExpiresAt > SYSUTCDATETIME()
          AND s.SessionExpiresAt > SYSUTCDATETIME()
          AND customer.IsActive = 1
          AND customer.CredentialAccessEnabled = 1
          AND company.IsActive = 1
          AND company.IsDeleted = 0
          AND actor.IsActive = 1
          AND actor.IsDeleted = 0
          AND
              (actor.Role = N''Admin'' OR EXISTS
                  (SELECT 1 FROM [central].[UserCompanies] AS actorCompany
                   WHERE actorCompany.UserId = actor.UserId
                     AND actorCompany.CompanyId = s.CompanyId));

        IF @ActorUserId IS NULL
            THROW 51094, N''Mobile authorization is no longer active.'', 1;

        IF @ActorRole <> N''Admin''
        BEGIN
            DECLARE @ChangedRoles TABLE (RoleId INT NOT NULL PRIMARY KEY);
            INSERT INTO @ChangedRoles (RoleId)
            SELECT RoleId FROM inserted
            UNION
            SELECT RoleId FROM deleted;

            IF EXISTS
            (
                SELECT 1
                FROM @ChangedRoles AS changed
                LEFT JOIN [central].[Roles] AS targetRole ON targetRole.RoleId = changed.RoleId
                WHERE targetRole.RoleId IS NULL
                   OR targetRole.IsSystem = 1
                   OR targetRole.RoleKey = N''Admin''
                   OR targetRole.RoleId = @ActorRoleId
                   OR EXISTS
                      (
                          SELECT 1
                          FROM [central].[RolePermissions] AS targetPermission
                          WHERE targetPermission.RoleId = targetRole.RoleId
                            AND NOT EXISTS
                               (
                                   SELECT 1
                                   FROM [central].[RolePermissions] AS actorPermission
                                   WHERE actorPermission.RoleId = @ActorRoleId
                                     AND actorPermission.PermissionId = targetPermission.PermissionId
                               )
                      )
            )
                THROW 51094, N''Mobile role permissions exceed the acting user permissions.'', 1;
        END
    END');

DECLARE @DefaultCompanyId INT =
(
    SELECT TOP (1) CompanyId
    FROM [central].[Companies]
    WHERE IsDeleted = 0
    ORDER BY CompanyId
);
DECLARE @CompanyCount INT =
(
    SELECT COUNT(*) FROM [central].[Companies]
);

-- Intentionally shared data is not assigned to one customer. It still receives
-- an active-session RLS predicate below, so expiry/revocation closes access.
-- Shared central: CMS content and RBAC definitions.
-- Shared currency: market/reference feeds consumed by every company.
DECLARE @GlobalTables TABLE
(
    SchemaName SYSNAME NOT NULL,
    TableName SYSNAME NOT NULL,
    AnchorColumn SYSNAME NOT NULL,
    PredicateName SYSNAME NOT NULL,
    PRIMARY KEY (SchemaName, TableName)
);
INSERT INTO @GlobalTables (SchemaName, TableName, AnchorColumn, PredicateName)
VALUES
    (N'central', N'News', N'NewsId', N'fn_MobileSessionAccessInt'),
    (N'central', N'BlogPosts', N'PostId', N'fn_MobileSessionAccessInt'),
    (N'central', N'GalleryItems', N'GalleryItemId', N'fn_MobileSessionAccessInt'),
    (N'central', N'Permissions', N'PermissionId', N'fn_MobileSessionAccessInt'),
    (N'central', N'Roles', N'RoleId', N'fn_MobileSessionAccessInt'),
    (N'central', N'RolePermissions', N'RoleId', N'fn_MobileSessionAccessInt'),
    (N'currency', N'Currencies', N'CurrencyId', N'fn_MobileSessionAccessInt'),
    (N'currency', N'PriceItems', N'PriceItemId', N'fn_MobileSessionAccessInt'),
    (N'currency', N'PriceRates', N'RateId', N'fn_MobileSessionAccessInt'),
    (N'currency', N'PriceSources', N'SourceId', N'fn_MobileSessionAccessInt'),
    (N'currency', N'PriceSourceValues', N'SourceValueId', N'fn_MobileSessionAccessBigInt'),
    (N'currency', N'RateHistory', N'HistoryId', N'fn_MobileSessionAccessBigInt'),
    (N'currency', N'Settings', N'SettingKey', N'fn_MobileSessionAccessString');

-- Every tenant-owned business table, plus central Parties/AuditLog, receives a
-- direct CompanyId. This intentionally avoids relying on traversable parent
-- relationships that arbitrary direct SQL could bypass.
DECLARE business_tables CURSOR LOCAL FAST_FORWARD FOR
SELECT s.name, t.name, t.object_id
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE
    (
        s.name IN
            (N'accounting', N'assets', N'bi', N'branch', N'currency', N'goldshop',
             N'inventory', N'payroll', N'store', N'treasury')
        AND NOT EXISTS
            (SELECT 1 FROM @GlobalTables g WHERE g.SchemaName = s.name AND g.TableName = t.name)
    )
    OR (s.name = N'central' AND t.name IN (N'AuditLog', N'Parties'))
ORDER BY s.name, t.name;

DECLARE @Schema SYSNAME, @Table SYSNAME, @ObjectId INT;
OPEN business_tables;
FETCH NEXT FROM business_tables INTO @Schema, @Table, @ObjectId;
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @Qualified NVARCHAR(520) = QUOTENAME(@Schema) + N'.' + QUOTENAME(@Table);
    DECLARE @Sql NVARCHAR(MAX);

    -- Existing rows cannot be assigned safely by guessing when several tenant
    -- companies already exist. Stop instead of silently exposing them to the
    -- first company; deployment must backfill explicit ownership and retry.
    IF @CompanyCount > 1
    BEGIN
        IF COL_LENGTH(@Schema + N'.' + @Table, N'CompanyId') IS NULL
            SET @Sql = N'IF EXISTS (SELECT 1 FROM ' + @Qualified +
                       N') THROW 51091, N''Explicit CompanyId backfill is required before mobile security can be enabled.'', 1;';
        ELSE
            SET @Sql = N'IF EXISTS (SELECT 1 FROM ' + @Qualified +
                       N' WHERE [CompanyId] IS NULL) THROW 51091, N''Explicit CompanyId backfill is required before mobile security can be enabled.'', 1;';
        EXEC sys.sp_executesql @Sql;
    END

    IF COL_LENGTH(@Schema + N'.' + @Table, N'CompanyId') IS NULL
    BEGIN
        SET @Sql = N'ALTER TABLE ' + @Qualified + N' ADD [CompanyId] INT NULL;';
        EXEC sys.sp_executesql @Sql;
    END

    IF @CompanyCount = 1
    BEGIN
        SET @Sql = N'UPDATE ' + @Qualified + N' SET [CompanyId] = @CompanyId WHERE [CompanyId] IS NULL;';
        EXEC sys.sp_executesql @Sql, N'@CompanyId INT', @CompanyId = @DefaultCompanyId;
    END

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.default_constraints dc
        JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id
        WHERE dc.parent_object_id = @ObjectId AND c.name = N'CompanyId'
    )
    BEGIN
        DECLARE @DefaultName SYSNAME = N'DF_MobileCompany_' + CONVERT(NVARCHAR(20), @ObjectId);
        SET @Sql = N'ALTER TABLE ' + @Qualified + N' ADD CONSTRAINT ' + QUOTENAME(@DefaultName) +
                   N' DEFAULT ([central].[fn_MobileCompanyId]()) FOR [CompanyId];';
        EXEC sys.sp_executesql @Sql;
    END

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes i
        JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.key_ordinal = 1
        JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
        WHERE i.object_id = @ObjectId AND c.name = N'CompanyId' AND i.is_disabled = 0
    )
    BEGIN
        DECLARE @IndexName SYSNAME = N'IX_MobileCompany_' + CONVERT(NVARCHAR(20), @ObjectId);
        SET @Sql = N'CREATE INDEX ' + QUOTENAME(@IndexName) + N' ON ' + @Qualified + N'([CompanyId]);';
        EXEC sys.sp_executesql @Sql;
    END

    DECLARE @PolicyName SYSNAME = N'MobileCompanyPolicy_' + CONVERT(NVARCHAR(20), @ObjectId);
    IF NOT EXISTS (SELECT 1 FROM sys.security_policies WHERE name = @PolicyName AND schema_id = SCHEMA_ID(N'central'))
    BEGIN
        SET @Sql = N'CREATE SECURITY POLICY [central].' + QUOTENAME(@PolicyName) +
            N' ADD FILTER PREDICATE [central].[fn_MobileCompanyAccess]([CompanyId]) ON ' + @Qualified +
            N', ADD BLOCK PREDICATE [central].[fn_MobileCompanyAccess]([CompanyId]) ON ' + @Qualified + N' AFTER INSERT' +
            N', ADD BLOCK PREDICATE [central].[fn_MobileCompanyAccess]([CompanyId]) ON ' + @Qualified + N' AFTER UPDATE' +
            N' WITH (STATE = ON);';
        EXEC sys.sp_executesql @Sql;
    END

    FETCH NEXT FROM business_tables INTO @Schema, @Table, @ObjectId;
END
CLOSE business_tables;
DEALLOCATE business_tables;

-- Party codes are tenant-local. Replace the legacy global uniqueness rule
-- after ownership is established; the old rule could reveal another tenant's
-- code through duplicate-key behavior and unnecessarily coupled customers.
IF OBJECT_ID(N'[central].[Parties]', N'U') IS NOT NULL
   AND NOT EXISTS
       (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[central].[Parties]')
        AND name = N'UQ_Parties_Company_Code' AND is_unique = 1)
BEGIN
    DECLARE @LegacyPartyUnique SYSNAME, @LegacyPartyIsConstraint BIT;
    SELECT TOP (1)
        @LegacyPartyUnique = i.name,
        @LegacyPartyIsConstraint = i.is_unique_constraint
    FROM sys.indexes i
    JOIN sys.index_columns ic
      ON ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.key_ordinal = 1
    JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    WHERE i.object_id = OBJECT_ID(N'[central].[Parties]')
      AND i.is_unique = 1 AND i.is_primary_key = 0
      AND c.name = N'PartyCode'
      AND NOT EXISTS
          (SELECT 1 FROM sys.index_columns extra
           WHERE extra.object_id = i.object_id AND extra.index_id = i.index_id AND extra.key_ordinal > 1);

    IF @LegacyPartyUnique IS NOT NULL
    BEGIN
        DECLARE @DropConstraintSql NVARCHAR(MAX);
        DECLARE @DropIndexSql NVARCHAR(MAX);
        IF @LegacyPartyIsConstraint = 1
        BEGIN
            SET @DropConstraintSql = N'ALTER TABLE [central].[Parties] DROP CONSTRAINT ' + QUOTENAME(@LegacyPartyUnique) + N';';
            EXEC(@DropConstraintSql);
        END
        ELSE
        BEGIN
            SET @DropIndexSql = N'DROP INDEX ' + QUOTENAME(@LegacyPartyUnique) + N' ON [central].[Parties];';
            EXEC(@DropIndexSql);
        END
    END

    ALTER TABLE [central].[Parties]
        ADD CONSTRAINT [UQ_Parties_Company_Code] UNIQUE ([CompanyId], [PartyCode]);
END

-- Central tables with an existing direct company/fiscal-year/user key.
DECLARE @CentralPolicies TABLE
(
    TableName SYSNAME NOT NULL,
    ColumnName SYSNAME NOT NULL,
    PredicateName SYSNAME NOT NULL
);
INSERT INTO @CentralPolicies (TableName, ColumnName, PredicateName)
VALUES
    (N'FiscalYears', N'CompanyId', N'fn_MobileCompanyAccess'),
    (N'UserCompanies', N'CompanyId', N'fn_MobileCompanyAccess'),
    (N'UserActiveContext', N'UserId', N'fn_MobileUserAccess'),
    (N'UserFiscalYears', N'FiscalYearId', N'fn_MobileFiscalYearAccess'),
    (N'Users', N'UserId', N'fn_MobileUserAccess');

-- Protect Companies with the non-recursive row predicate above. Recreate
-- the deterministic policy so an upgrade from the earlier self-referential
-- predicate cannot leave a recursive RLS graph active.
SET @ObjectId = OBJECT_ID(N'[central].[Companies]');
IF @ObjectId IS NOT NULL
BEGIN
    SET @PolicyName = N'MobileCentralPolicy_' + CONVERT(NVARCHAR(20), @ObjectId);
    IF EXISTS
       (SELECT 1 FROM sys.security_policies
        WHERE name = @PolicyName AND schema_id = SCHEMA_ID(N'central'))
    BEGIN
        SET @Sql = N'DROP SECURITY POLICY [central].' + QUOTENAME(@PolicyName) + N';';
        EXEC sys.sp_executesql @Sql;
    END

    SET @Sql = N'CREATE SECURITY POLICY [central].' + QUOTENAME(@PolicyName) +
        N' ADD FILTER PREDICATE [central].[fn_MobileCompanyRowAccess]([CompanyId], [IsActive], [IsDeleted]) ON [central].[Companies]' +
        N', ADD BLOCK PREDICATE [central].[fn_MobileCompanyRowAccess]([CompanyId], [IsActive], [IsDeleted]) ON [central].[Companies] AFTER INSERT' +
        N', ADD BLOCK PREDICATE [central].[fn_MobileCompanyRowAccess]([CompanyId], [IsActive], [IsDeleted]) ON [central].[Companies] AFTER UPDATE' +
        N' WITH (STATE = ON);';
    EXEC sys.sp_executesql @Sql;
END

DECLARE central_tables CURSOR LOCAL FAST_FORWARD FOR
SELECT TableName, ColumnName, PredicateName FROM @CentralPolicies;
DECLARE @Column SYSNAME, @Predicate SYSNAME;
OPEN central_tables;
FETCH NEXT FROM central_tables INTO @Table, @Column, @Predicate;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @ObjectId = OBJECT_ID(QUOTENAME(N'central') + N'.' + QUOTENAME(@Table));
    SET @PolicyName = N'MobileCentralPolicy_' + CONVERT(NVARCHAR(20), @ObjectId);
    IF @ObjectId IS NOT NULL AND NOT EXISTS
       (SELECT 1 FROM sys.security_policies WHERE name = @PolicyName AND schema_id = SCHEMA_ID(N'central'))
    BEGIN
        SET @Qualified = QUOTENAME(N'central') + N'.' + QUOTENAME(@Table);
        SET @Sql = N'CREATE SECURITY POLICY [central].' + QUOTENAME(@PolicyName) +
            N' ADD FILTER PREDICATE [central].' + QUOTENAME(@Predicate) + N'(' + QUOTENAME(@Column) + N') ON ' + @Qualified;
        IF @Table = N'UserActiveContext'
            SET @Sql += N', ADD BLOCK PREDICATE [central].[fn_MobileCompanyAccess]([ActiveCompanyId]) ON ' + @Qualified + N' AFTER INSERT' +
                        N', ADD BLOCK PREDICATE [central].[fn_MobileCompanyAccess]([ActiveCompanyId]) ON ' + @Qualified + N' AFTER UPDATE';
        ELSE IF @Table <> N'Users'
            SET @Sql += N', ADD BLOCK PREDICATE [central].' + QUOTENAME(@Predicate) + N'(' + QUOTENAME(@Column) + N') ON ' + @Qualified + N' AFTER INSERT' +
                        N', ADD BLOCK PREDICATE [central].' + QUOTENAME(@Predicate) + N'(' + QUOTENAME(@Column) + N') ON ' + @Qualified + N' AFTER UPDATE';
        SET @Sql += N' WITH (STATE = ON);';
        EXEC sys.sp_executesql @Sql;
    END
    FETCH NEXT FROM central_tables INTO @Table, @Column, @Predicate;
END
CLOSE central_tables;
DEALLOCATE central_tables;

-- Intentionally global rows are shared only while the generated login has a
-- live, non-revoked broker session. The anchor is ignored by the predicate but
-- binds the policy to each row for both reads and writes.
DECLARE global_tables CURSOR LOCAL FAST_FORWARD FOR
SELECT g.SchemaName, g.TableName, g.AnchorColumn, g.PredicateName, t.object_id
FROM @GlobalTables g
JOIN sys.schemas s ON s.name = g.SchemaName
JOIN sys.tables t ON t.schema_id = s.schema_id AND t.name = g.TableName;
DECLARE @Anchor SYSNAME, @SessionPredicate SYSNAME;
OPEN global_tables;
FETCH NEXT FROM global_tables INTO @Schema, @Table, @Anchor, @SessionPredicate, @ObjectId;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @Qualified = QUOTENAME(@Schema) + N'.' + QUOTENAME(@Table);
    DECLARE @WritePredicate SYSNAME =
        CASE @SessionPredicate
            WHEN N'fn_MobileSessionAccessBigInt' THEN N'fn_MobileGlobalWriteBigInt'
            WHEN N'fn_MobileSessionAccessString' THEN N'fn_MobileGlobalWriteString'
            ELSE N'fn_MobileGlobalWriteInt'
        END;

    -- Recreate the deterministic policy so upgrades from the earlier
    -- session-only block predicates receive the cross-customer write guard.
    SET @PolicyName = N'MobileGlobalWritePolicy_' + CONVERT(NVARCHAR(20), @ObjectId);
    IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = @PolicyName AND schema_id = SCHEMA_ID(N'central'))
    BEGIN
        SET @Sql = N'DROP SECURITY POLICY [central].' + QUOTENAME(@PolicyName) + N';';
        EXEC sys.sp_executesql @Sql;
    END

    SET @PolicyName = N'MobileGlobalPolicy_' + CONVERT(NVARCHAR(20), @ObjectId);
    IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = @PolicyName AND schema_id = SCHEMA_ID(N'central'))
    BEGIN
        SET @Sql = N'DROP SECURITY POLICY [central].' + QUOTENAME(@PolicyName) + N';';
        EXEC sys.sp_executesql @Sql;
    END

    SET @Sql = N'CREATE SECURITY POLICY [central].' + QUOTENAME(@PolicyName) +
        N' ADD FILTER PREDICATE [central].' + QUOTENAME(@SessionPredicate) + N'(' + QUOTENAME(@Anchor) + N') ON ' + @Qualified +
        N', ADD BLOCK PREDICATE [central].' + QUOTENAME(@WritePredicate) + N'(' + QUOTENAME(@Anchor) + N') ON ' + @Qualified + N' AFTER INSERT' +
        N', ADD BLOCK PREDICATE [central].' + QUOTENAME(@WritePredicate) + N'(' + QUOTENAME(@Anchor) + N') ON ' + @Qualified + N' AFTER UPDATE' +
        N', ADD BLOCK PREDICATE [central].' + QUOTENAME(@WritePredicate) + N'(' + QUOTENAME(@Anchor) + N') ON ' + @Qualified + N' BEFORE DELETE' +
        N' WITH (STATE = ON);';
    EXEC sys.sp_executesql @Sql;

    FETCH NEXT FROM global_tables INTO @Schema, @Table, @Anchor, @SessionPredicate, @ObjectId;
END
CLOSE global_tables;
DEALLOCATE global_tables;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
