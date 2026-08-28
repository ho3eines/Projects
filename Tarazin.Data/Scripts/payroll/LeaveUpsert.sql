-- =============================================
-- Tarazin.Data/Scripts/payroll/LeaveUpsert.sql
-- Schema: payroll
-- Execute. ثبت/به‌روزرسانی مرخصی کارمند.
-- LeaveId=0 → جدید. LeaveType: Annual | Sick | Unpaid | Hourly
-- IsPaid=1 → استحقاقی (با حقوق) | IsPaid=0 → بدون حقوق (از فیش کسر می‌شود)
-- =============================================
IF @EmployeeId IS NULL OR @EmployeeId <= 0
    THROW 51092, N'کارمند نامعتبر است.', 1;
IF @StartDate IS NULL OR @EndDate IS NULL
    THROW 51093, N'بازه مرخصی الزامی است.', 1;
IF @EndDate < @StartDate
    THROW 51094, N'تاریخ پایان مرخصی قبل از شروع است.', 1;

IF @LeaveId = 0
BEGIN
    INSERT INTO [payroll].[LeaveRecords]
        (EmployeeId, CompanyId, StartDate, EndDate, Days, LeaveType, IsPaid, Description, ApprovedBy, CreatedAt, CreatedBy)
    VALUES
        (@EmployeeId, @CompanyId, @StartDate, @EndDate,
         ISNULL(@Days, DATEDIFF(DAY, @StartDate, @EndDate) + 1),
         @LeaveType, ISNULL(@IsPaid, 1), @Description, @ApprovedBy, SYSUTCDATETIME(), @CreatedBy);
    SELECT CAST(SCOPE_IDENTITY() AS INT) AS LeaveId;
END
ELSE
BEGIN
    UPDATE [payroll].[LeaveRecords]
    SET StartDate = @StartDate,
        EndDate = @EndDate,
        Days = ISNULL(@Days, DATEDIFF(DAY, @StartDate, @EndDate) + 1),
        LeaveType = @LeaveType,
        IsPaid = ISNULL(@IsPaid, IsPaid),
        Description = @Description,
        ApprovedBy = @ApprovedBy,
        UpdatedAt = SYSUTCDATETIME(),
        UpdatedBy = @CreatedBy
    WHERE LeaveId = @LeaveId AND CompanyId = @CompanyId;
    SELECT @LeaveId AS LeaveId;
END
