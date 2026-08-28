IF NOT EXISTS (
    SELECT 1 FROM [payroll].[PayrollRuns]
    WHERE RunId = @RunId AND (@CompanyId IS NULL OR CompanyId = @CompanyId))
    THROW 51040, N'دوره حقوق پیدا نشد', 1;

IF EXISTS (SELECT 1 FROM [payroll].[PayrollRuns] WHERE RunId = @RunId AND Status NOT IN (N'Finalized', N'Closed'))
    THROW 51041, N'فقط دوره نهایی‌شده قابل ارسال است', 1;

IF NOT EXISTS (
    SELECT 1 FROM [payroll].[Outbox]
    WHERE EventType = N'PayrollPostRequested' AND EventKey = CONCAT(N'RunId=', @RunId))
BEGIN
    INSERT INTO [payroll].[Outbox] (EventType, EventKey, Payload, PayloadVersion)
    SELECT N'PayrollPostRequested', CONCAT(N'RunId=', r.RunId),
           (SELECT r.RunId, r.Period, r.NetTotal, r.EmployeeCount, r.CompanyId,
                   s.PayableAccountCode, s.InsuranceAccountCode, s.TaxAccountCode, s.BankAccountCode
            FROM [payroll].[PayrollRuns] r
            LEFT JOIN [payroll].[PayrollSettings] s ON s.CompanyId = r.CompanyId
            WHERE r.RunId = @RunId
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER), 1
    FROM [payroll].[PayrollRuns] r
    WHERE r.RunId = @RunId;
END
