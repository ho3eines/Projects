-- =============================================
-- Tarazin.Data/Scripts/central/_Seed.sql
-- Schema: central
-- Endpoint: execute (startup)
-- =============================================
-- Seed the demo parties for EVERY active company (multi-company).
DECLARE party_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT CompanyId FROM [central].[Companies] WHERE IsDeleted=0 AND IsActive=1 ORDER BY CompanyId;
DECLARE @PartySeedCompanyId INT;
OPEN party_cursor;
FETCH NEXT FROM party_cursor INTO @PartySeedCompanyId;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [central].[Parties] WHERE CompanyId = @PartySeedCompanyId)
    BEGIN
        INSERT INTO [central].[Parties] (CompanyId, PartyCode, PartyType, FullName, NationalId, Phone, Email, IsActive, CreatedBy)
        VALUES
            (@PartySeedCompanyId, N'CUS-001', N'Customer', N'شرکت بازرگانی آمل', N'10100456789', N'011-32123456', N'info@amol-trade.ir', 1, N'seed'),
            (@PartySeedCompanyId, N'VEN-001', N'Vendor',   N'تأمین‌کننده طلا و جواهر تهران', N'10200765432', N'021-88776655', NULL, 1, N'seed'),
            (@PartySeedCompanyId, N'EMP-001', N'Employee', N'علی محمدی', N'10300987654', N'09121112233', N'ali@tarazin.local', 1, N'seed');
    END
    FETCH NEXT FROM party_cursor INTO @PartySeedCompanyId;
END
CLOSE party_cursor;
DEALLOCATE party_cursor;
GO

IF NOT EXISTS (SELECT 1 FROM [central].[News])
BEGIN
    INSERT INTO [central].[News] (Title, Summary, Body, PublishedAt, IsActive, CreatedBy)
    VALUES
        (N'افتتاح پلتفرم ترازین', N'هفت محصول روی یک پلتفرم یکپارچه در دسترس قرار گرفت.', N'پلتفرم یکپارچهٔ ترازین شامل حسابداری، انبار، خزانه‌داری، حقوق، طلافروشی و فروشگاه اینترنتی راه‌اندازی شد.', CAST('2026-08-12' AS DATE), 1, N'seed'),
        (N'بروزرسانی پاییز ۱۴۰۵', N'نسخهٔ جدید با بهبود سرعت و امنیت منتشر شد.', N'توکن‌های کوتاه‌مدت، audit با زنجیرهٔ هش و رزولوشن امن اسکریپت‌ها در این نسخه گنجانده شد.', CAST('2026-08-12' AS DATE), 1, N'seed');
END

IF NOT EXISTS (SELECT 1 FROM [central].[BlogPosts])
BEGIN
    INSERT INTO [central].[BlogPosts] (Title, Slug, Body, Author, Tags, PublishedAt, IsActive, CreatedBy)
    VALUES
        (N'معماری پلتفرم ترازین', N'tarazin-architecture', N'معماری تک‌وب‌سرویسی با اسکیمهٔ جدا برای هر محصول و بک‌بون رویدادها با Outbox.', N'تیم معماری', N'معماری, Outbox, امنیت', CAST('2026-08-12' AS DATE), 1, N'seed'),
        (N'گزارش‌محوری در طراحی', N'report-first', N'در هر محصول ابتدا گزارش‌های مصوب، سپس مدل‌ها و صفحات طراحی می‌شوند.', N'تیم محصول', N'گزارش', CAST('2026-08-12' AS DATE), 1, N'seed');
END

IF NOT EXISTS (SELECT 1 FROM [central].[GalleryItems])
BEGIN
    INSERT INTO [central].[GalleryItems] (Title, Caption, SortOrder, IsActive, CreatedBy)
    VALUES
        (N'داشبورد حسابداری', N'نمای کلی سندهای روز', 1, 1, N'seed'),
        (N'گزارشات انبار', N'کارتکس و موجودی', 2, 1, N'seed'),
        (N'فروشگاه اینترنتی', N'سبد خرید و سفارش', 3, 1, N'seed');
END
GO

IF NOT EXISTS (SELECT 1 FROM [central].[Companies])
BEGIN
    -- Seed default company (id 1)
    SET IDENTITY_INSERT [central].[Companies] ON;
    INSERT INTO [central].[Companies] (CompanyId, CompanyName, IsActive, CreatedBy)
    VALUES (1, N'شرکت نمونه ترازین', 1, N'seed');
    SET IDENTITY_INSERT [central].[Companies] OFF;
END
GO

-- Seed fiscal year 1405 for EVERY active company (multi-company).
DECLARE fy_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT CompanyId FROM [central].[Companies] WHERE IsDeleted=0 AND IsActive=1 ORDER BY CompanyId;
DECLARE @FySeedCompanyId INT;
OPEN fy_cursor;
FETCH NEXT FROM fy_cursor INTO @FySeedCompanyId;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [central].[FiscalYears] WHERE CompanyId = @FySeedCompanyId AND YearName = N'1405')
        INSERT INTO [central].[FiscalYears] (CompanyId, YearName, StartDate, EndDate, IsActive, CreatedBy)
        VALUES (@FySeedCompanyId, N'1405', '2026-03-21', '2027-03-20', 1, N'seed');
    FETCH NEXT FROM fy_cursor INTO @FySeedCompanyId;
END
CLOSE fy_cursor;
DEALLOCATE fy_cursor;
GO
UPDATE [central].[Parties] SET CompanyId=1 WHERE CompanyId IS NULL;
GO
