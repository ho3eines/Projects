-- =============================================
-- پیش‌نمایش اولین شمارهٔ آزاد در بازهٔ یک گروه تفصیلی.
-- تخصیص نهایی و همزمانی در BaseDetilCreateAuto کنترل می‌شود.
-- قانون چندشرکتی: گروه باید متعلق به همین شرکت (یا سراسری) باشد.
-- =============================================
DECLARE @From NVARCHAR(7);
DECLARE @To NVARCHAR(7);
DECLARE @Next NVARCHAR(7) = NULL;

SELECT @From = FromCode, @To = ToCode
FROM [accounting].[AccountGroups]
WHERE AccountGroupId = @AccountGroupId
  AND GroupType = N'Detil'
  AND IsDeleted = 0
  AND IsActive = 1
  AND (CompanyId = @CompanyId OR CompanyId IS NULL);

IF @From IS NULL
    THROW 50130, N'گروه تفصیلی فعال و معتبر نیست یا متعلق به این شرکت نیست.', 1;

IF NOT EXISTS (SELECT 1 FROM [accounting].[BaseDetil] WHERE DetilCode = @From AND CompanyId = @CompanyId)
    SET @Next = @From;
ELSE
BEGIN
    SELECT TOP (1)
        @Next = RIGHT(N'0000000' + CONVERT(NVARCHAR(7), code.NumericCode + 1), 7)
    FROM [accounting].[BaseDetil] d
    CROSS APPLY (VALUES (TRY_CONVERT(INT, d.DetilCode))) code(NumericCode)
    WHERE d.CompanyId = @CompanyId
      AND code.NumericCode >= CONVERT(INT, @From)
      AND code.NumericCode < CONVERT(INT, @To)
      AND NOT EXISTS (
          SELECT 1 FROM [accounting].[BaseDetil] nextCode
          WHERE nextCode.CompanyId = @CompanyId
            AND nextCode.DetilCode = RIGHT(N'0000000' + CONVERT(NVARCHAR(7), code.NumericCode + 1), 7)
      )
    ORDER BY code.NumericCode;
END

SELECT
    @AccountGroupId AS AccountGroupId,
    g.Title AS GroupTitle,
    g.FromCode,
    g.ToCode,
    @Next AS NextCode,
    CAST(CASE WHEN @Next IS NULL THEN 0 ELSE 1 END AS BIT) AS HasCapacity
FROM [accounting].[AccountGroups] g
WHERE g.AccountGroupId = @AccountGroupId AND g.IsDeleted = 0
  AND (g.CompanyId = @CompanyId OR g.CompanyId IS NULL);
