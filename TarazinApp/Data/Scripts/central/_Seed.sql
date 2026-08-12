-- =============================================
-- TarazinApp/Data/Scripts/central/_Seed.sql
-- Schema: central
-- Endpoint: execute (startup)
-- =============================================
IF NOT EXISTS (SELECT 1 FROM [central].[Parties])
BEGIN
    INSERT INTO [central].[Parties] (PartyCode, PartyType, FullName, NationalId, Phone, Email, IsActive, CreatedBy)
    VALUES
        (N'CUS-001', N'Customer', N'شرکت بازرگانی آمل', N'10100456789', N'011-32123456', N'info@amol-trade.ir', 1, N'seed'),
        (N'VEN-001', N'Vendor',   N'تأمین‌کننده طلا و جواهر تهران', N'10200765432', N'021-88776655', NULL, 1, N'seed'),
        (N'EMP-001', N'Employee', N'علی محمدی', N'10300987654', N'09121112233', N'ali@tarazin.local', 1, N'seed');
END

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
