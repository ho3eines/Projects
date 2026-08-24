SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
-- تفصیلی مشتری CUS-001 در گروه 3 (مشتریان) زیر معین 10 (دارایی جاری)
DECLARE @CustDetilId INT, @CustCode NVARCHAR(7);
EXEC accounting.BaseDetilCreateAuto
    @Title = N'شرکت بازرگانی آمل', @Description = N'مشتری طلافروشی', @MoeinId = 10,
    @AccountGroupId = 3, @AccountNature = N'Debit', @IsActive = 1, @CreatedBy = N'seed', @CompanyId = 3,
    @NewId = @CustDetilId OUTPUT, @DetilCode = @CustCode OUTPUT;
PRINT 'Cust detil: ' + CAST(@CustDetilId AS VARCHAR(10)) + ' code=' + @CustCode;
-- تفصیلی تأمین‌کننده VEN-001 در گروه 4 (تأمین‌کنندگان) زیر معین 12 (بدهی‌های جاری)
DECLARE @VenDetilId INT, @VenCode NVARCHAR(7);
EXEC accounting.BaseDetilCreateAuto
    @Title = N'تأمین‌کننده طلا و جواهر تهران', @Description = N'تأمین‌کننده طلافروشی', @MoeinId = 12,
    @AccountGroupId = 4, @AccountNature = N'Credit', @IsActive = 1, @CreatedBy = N'seed', @CompanyId = 3,
    @NewId = @VenDetilId OUTPUT, @DetilCode = @VenCode OUTPUT;
PRINT 'Ven detil: ' + CAST(@VenDetilId AS VARCHAR(10)) + ' code=' + @VenCode;
-- لینک به GoldPartyLinks (DetailLinkId = LinkId مسیر تفصیلی)
UPDATE l SET l.DetailLinkId = dl.LinkId, l.DetailAccountCode = d.DetilCode
FROM goldshop.GoldPartyLinks l
JOIN central.Parties p ON p.PartyId = l.PartyId AND p.CompanyId = l.CompanyId
JOIN accounting.BaseDetil d ON d.Title = CASE WHEN p.PartyType = N'Customer' THEN N'شرکت بازرگانی آمل' ELSE N'تأمین‌کننده طلا و جواهر تهران' END AND d.CompanyId = 3
LEFT JOIN accounting.BaseDetilLink dl ON dl.DetilId = d.DetilId AND dl.CompanyId = 3 AND dl.ParentLinkId IS NULL
WHERE l.CompanyId = 3 AND p.PartyType IN (N'Customer', N'Vendor');
SELECT l.PartyId, p.PartyCode, l.PartyType, l.DetailLinkId, l.DetailAccountCode FROM goldshop.GoldPartyLinks l JOIN central.Parties p ON p.PartyId=l.PartyId WHERE l.CompanyId=3;
