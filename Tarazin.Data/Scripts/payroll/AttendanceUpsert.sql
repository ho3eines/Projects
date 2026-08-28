-- =============================================
-- Tarazin.Data/Scripts/payroll/AttendanceUpsert.sql
-- Schema: payroll
-- Execute. ثبت/به‌روزرسانی حضورغیاب روزانه (ورود/خروج).
--
-- محاسبهٔ خودکار:
--   WorkMinutes     = اختلاف CheckOut - CheckIn (اگر هر دو موجود باشند)
--   OvertimeMinutes = مازاد بر ساعت استاندارد روزانه (8 ساعت = 480 دقیقه)
--                     اگر CheckOut بعد از 16:30 باشد و ورود قبل از 8:00،
--                     ساعت کاری عادی 8:30 در نظر گرفته می‌شود — ساده‌سازی:
--                     مازاد بر 480 دقیقه = اضافه‌کار.
-- =============================================
IF @EmployeeId IS NULL OR @EmployeeId <= 0
    THROW 51090, N'کارمند نامعتبر است.', 1;
IF @AttendanceDate IS NULL
    THROW 51091, N'تاریخ حضورغیاب الزامی است.', 1;

DECLARE @Work INT = 0;
DECLARE @Over INT = 0;
IF @CheckIn IS NOT NULL AND @CheckOut IS NOT NULL AND @CheckOut > @CheckIn
BEGIN
    SET @Work = DATEDIFF(MINUTE, @CheckIn, @CheckOut);
    -- ساعت استاندارد روزانه: 480 دقیقه (8 ساعت). مازاد = اضافه‌کار.
    IF @Work > 480
    BEGIN
        SET @Over = @Work - 480;
        SET @Work = 480;
    END
END

IF EXISTS (SELECT 1 FROM [payroll].[AttendanceLogs] WHERE EmployeeId = @EmployeeId AND AttendanceDate = @AttendanceDate)
BEGIN
    UPDATE [payroll].[AttendanceLogs]
    SET CheckIn = @CheckIn,
        CheckOut = @CheckOut,
        WorkMinutes = @Work,
        OvertimeMinutes = @Over,
        Notes = @Notes,
        UpdatedAt = SYSUTCDATETIME(),
        UpdatedBy = @CreatedBy
    WHERE EmployeeId = @EmployeeId AND AttendanceDate = @AttendanceDate;
END
ELSE
BEGIN
    INSERT INTO [payroll].[AttendanceLogs]
        (EmployeeId, CompanyId, AttendanceDate, CheckIn, CheckOut, WorkMinutes, OvertimeMinutes, Notes, CreatedAt, CreatedBy)
    VALUES
        (@EmployeeId, @CompanyId, @AttendanceDate, @CheckIn, @CheckOut, @Work, @Over, @Notes, SYSUTCDATETIME(), @CreatedBy);
END

SELECT AttendanceId FROM [payroll].[AttendanceLogs]
WHERE EmployeeId = @EmployeeId AND AttendanceDate = @AttendanceDate;
