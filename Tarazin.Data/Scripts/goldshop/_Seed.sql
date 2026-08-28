SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;

-- Goldshop is seeded per active company. It runs after inventory in DbService.SeedAsync.
DECLARE company_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT CompanyId FROM [central].[Companies] WHERE IsDeleted=0 AND IsActive=1 ORDER BY CompanyId;
DECLARE @SeedCompanyId INT;
OPEN company_cursor;
FETCH NEXT FROM company_cursor INTO @SeedCompanyId;
WHILE @@FETCH_STATUS=0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [goldshop].[GoldItems] WHERE CompanyId=@SeedCompanyId)
        INSERT INTO [goldshop].[GoldItems](ItemCode,Title,Purity,InventoryItemCode,IsActive,CreatedAt,CompanyId)
        VALUES (N'XAU-24',N'طلای ۲۴ عیار (گرم)',24,N'GOLD-24',1,SYSUTCDATETIME(),@SeedCompanyId),
               (N'XAU-18',N'طلای ۱۸ عیار (گرم)',18,N'GOLD-18',1,SYSUTCDATETIME(),@SeedCompanyId),
               (N'SIKKEH-EMAMI',N'سکه امامی',NULL,N'SIKKEH',1,SYSUTCDATETIME(),@SeedCompanyId),
               (N'CHAIN-GOLD',N'زنجیر طلا',18,N'CHAIN-01',1,SYSUTCDATETIME(),@SeedCompanyId);
    IF NOT EXISTS (SELECT 1 FROM [goldshop].[GoldPrices] WHERE CompanyId=@SeedCompanyId)
        INSERT INTO [goldshop].[GoldPrices](ItemCode,Title,PricePerGram,UpdatedAt,CompanyId)
        VALUES (N'XAU-24',N'طلای ۲۴ عیار (گرم)',38000000,SYSUTCDATETIME(),@SeedCompanyId),
               (N'XAU-18',N'طلای ۱۸ عیار (گرم)',28000000,SYSUTCDATETIME(),@SeedCompanyId),
               (N'SIKKEH-EMAMI',N'سکه امامی',62000000,SYSUTCDATETIME(),@SeedCompanyId);
    -- تنظیمات با اتصال واقعی به درخت حسابداری (که پیش از این در DbService.SeedAsync seed شد)
    IF NOT EXISTS (SELECT 1 FROM [goldshop].[GoldShopSettings] WHERE CompanyId=@SeedCompanyId)
    BEGIN
        DECLARE @WhId INT=(SELECT MIN(WarehouseId) FROM [inventory].[Warehouses] WHERE CompanyId=@SeedCompanyId);
        -- گروه‌های تفصیلی از تنظیمات سراسری شرکت (CompanyAccountSettings)؛ در صورت نبود، fallback به گروه‌های seed
        DECLARE @CustGrp INT=ISNULL((SELECT CustomerAccountGroupId FROM [accounting].[CompanyAccountSettings] WHERE CompanyId=@SeedCompanyId),
                                     (SELECT TOP 1 AccountGroupId FROM [accounting].[AccountGroups] WHERE CompanyId=@SeedCompanyId AND GroupType=N'Detil' AND GroupCode=N'01'));
        DECLARE @SuppGrp INT=ISNULL((SELECT SupplierAccountGroupId FROM [accounting].[CompanyAccountSettings] WHERE CompanyId=@SeedCompanyId),
                                     (SELECT TOP 1 AccountGroupId FROM [accounting].[AccountGroups] WHERE CompanyId=@SeedCompanyId AND GroupType=N'Detil' AND GroupCode=N'02'));
        DECLARE @InvGrp INT=ISNULL((SELECT InventoryAccountGroupId FROM [accounting].[CompanyAccountSettings] WHERE CompanyId=@SeedCompanyId),
                                    (SELECT TOP 1 AccountGroupId FROM [accounting].[AccountGroups] WHERE CompanyId=@SeedCompanyId AND GroupType=N'Detil' AND GroupCode=N'03'));
        DECLARE @CashMoeinId INT=(SELECT TOP 1 m.MoeinId FROM [accounting].[BaseMoein] m JOIN [accounting].[BaseCol] c ON c.ColId=m.ColId WHERE m.CompanyId=@SeedCompanyId AND c.ColCode=N'10' AND m.MoeinCode=N'001');
        DECLARE @SalesMoeinId INT=(SELECT TOP 1 m.MoeinId FROM [accounting].[BaseMoein] m JOIN [accounting].[BaseCol] c ON c.ColId=m.ColId WHERE m.CompanyId=@SeedCompanyId AND c.ColCode=N'30' AND m.MoeinCode=N'001');
        DECLARE @CostMoeinId INT=(SELECT TOP 1 m.MoeinId FROM [accounting].[BaseMoein] m JOIN [accounting].[BaseCol] c ON c.ColId=m.ColId WHERE m.CompanyId=@SeedCompanyId AND c.ColCode=N'40' AND m.MoeinCode=N'001');
        -- صندوق/بانک سند حسابداری ← تفصیلی‌های استاندارد seed حسابداری (صندوق اصلی / بانک‌ها)
        DECLARE @CashDetilId INT=(SELECT TOP 1 d.DetilId FROM [accounting].[BaseDetil] d WHERE d.CompanyId=@SeedCompanyId AND d.DetilCode=N'0000002' AND d.IsDeleted=0);
        DECLARE @BankDetilId INT=(SELECT TOP 1 d.DetilId FROM [accounting].[BaseDetil] d WHERE d.CompanyId=@SeedCompanyId AND d.DetilCode=N'0000001' AND d.IsDeleted=0);
        INSERT INTO [goldshop].[GoldShopSettings]
            (CompanyId,InventoryWarehouseId,CustomerAccountGroupId,SupplierAccountGroupId,InventoryAccountGroupId,
             SalesAccountId,SalesAccountCode,SalesAccountTitle,
             InventoryAccountId,InventoryAccountCode,InventoryAccountTitle,
             TaxPayableAccountId,TaxPayableAccountCode,TaxPayableAccountTitle,
             CashAccountId,CashAccountCode,CashAccountTitle,
             BankChartAccountId,BankChartAccountCode,BankChartAccountTitle,
             DefaultTaxPercent,LaborTaxPercent,IsEnabled,UpdatedBy)
        VALUES
            (@SeedCompanyId,@WhId,@CustGrp,@SuppGrp,@InvGrp,
             @SalesMoeinId,N'30001',N'درآمد عملیاتی',
             @CashMoeinId,N'10001',N'دارایی جاری',
             @CostMoeinId,N'40001',N'هزینه‌های عملیاتی',
             @CashDetilId,N'0000002',N'صندوق اصلی',
             @BankDetilId,N'0000001',N'بانک‌ها',
             10,10,1,N'seed');
    END
    -- لینک خودکار طرف‌حساب‌ها: تفصیلی با کد طرف‌حساب در گروه تنظیمات ساخته/لینک می‌شود
    IF NOT EXISTS (SELECT 1 FROM [treasury].[PartyLinks] WHERE CompanyId=@SeedCompanyId)
    BEGIN
        DECLARE party_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT PartyId, PartyCode, PartyType, FullName FROM [central].[Parties]
            WHERE CompanyId=@SeedCompanyId AND PartyType IN (N'Customer',N'Vendor') AND IsDeleted=0;
        DECLARE @PId INT, @PCode NVARCHAR(50), @PType NVARCHAR(30), @PName NVARCHAR(200);
        OPEN party_cursor;
        FETCH NEXT FROM party_cursor INTO @PId, @PCode, @PType, @PName;
        WHILE @@FETCH_STATUS=0
        BEGIN
            EXEC [goldshop].[GoldPartyUpsert]
                @PartyId=@PId, @PartyCode=@PCode, @PartyType=@PType, @FullName=@PName,
                @NationalId=NULL, @Phone=NULL, @Email=NULL, @DetailLinkId=NULL, @DetailAccountCode=NULL,
                @IsActive=1, @CompanyId=@SeedCompanyId, @CreatedBy=N'seed';
            FETCH NEXT FROM party_cursor INTO @PId, @PCode, @PType, @PName;
        END
        CLOSE party_cursor;
        DEALLOCATE party_cursor;
    END
    IF NOT EXISTS (SELECT 1 FROM [goldshop].[SaleInvoices] WHERE CompanyId=@SeedCompanyId)
        INSERT INTO [goldshop].[SaleInvoices](InvoiceNumber,InvoiceDate,CustomerName,ItemCode,WeightGram,Workmanship,Profit,Tax,TotalAmount,Status,CreatedBy,CompanyId)
        VALUES(N'GINV-00001',CAST(SYSDATETIME() AS DATE),N'مشتری نمونه',N'XAU-18',5,3500000,2500000,540000,180540000,N'Issued',N'seed',@SeedCompanyId);
    FETCH NEXT FROM company_cursor INTO @SeedCompanyId;
END
CLOSE company_cursor;
DEALLOCATE company_cursor;
