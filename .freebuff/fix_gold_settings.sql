SET NOCOUNT ON;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT CompanyId FROM [central].[Companies] WHERE IsDeleted=0 AND IsActive=1 ORDER BY CompanyId;
DECLARE @Cid INT;
OPEN c;
FETCH NEXT FROM c INTO @Cid;
WHILE @@FETCH_STATUS=0
BEGIN
    DECLARE @Wh INT=(SELECT MIN(WarehouseId) FROM [inventory].[Warehouses] WHERE CompanyId=@Cid);
    DECLARE @Cg INT=(SELECT TOP 1 AccountGroupId FROM [accounting].[AccountGroups] WHERE CompanyId=@Cid AND GroupType=N'Detil' AND GroupCode=N'01');
    DECLARE @Sg INT=(SELECT TOP 1 AccountGroupId FROM [accounting].[AccountGroups] WHERE CompanyId=@Cid AND GroupType=N'Detil' AND GroupCode=N'02');
    DECLARE @Cash INT=(SELECT TOP 1 m.MoeinId FROM [accounting].[BaseMoein] m JOIN [accounting].[BaseCol] c ON c.ColId=m.ColId WHERE m.CompanyId=@Cid AND c.ColCode=N'10' AND m.MoeinCode=N'001');
    DECLARE @Sales INT=(SELECT TOP 1 m.MoeinId FROM [accounting].[BaseMoein] m JOIN [accounting].[BaseCol] c ON c.ColId=m.ColId WHERE m.CompanyId=@Cid AND c.ColCode=N'30' AND m.MoeinCode=N'001');
    DECLARE @Cost INT=(SELECT TOP 1 m.MoeinId FROM [accounting].[BaseMoein] m JOIN [accounting].[BaseCol] c ON c.ColId=m.ColId WHERE m.CompanyId=@Cid AND c.ColCode=N'40' AND m.MoeinCode=N'001');
    UPDATE [goldshop].[GoldShopSettings]
    SET InventoryWarehouseId=@Wh, CustomerAccountGroupId=@Cg, SupplierAccountGroupId=@Sg,
        SalesAccountId=@Sales, SalesAccountCode=N'30001', SalesAccountTitle=N'درآمد عملیاتی',
        InventoryAccountId=@Cash, InventoryAccountCode=N'10001', InventoryAccountTitle=N'دارایی جاری',
        TaxPayableAccountId=@Cost, TaxPayableAccountCode=N'40001', TaxPayableAccountTitle=N'هزینه‌های عملیاتی',
        CashAccountId=@Cash, CashAccountCode=N'10001', CashAccountTitle=N'دارایی جاری',
        DefaultTaxPercent=10, LaborTaxPercent=10, IsEnabled=1, UpdatedBy=N'seed'
    WHERE CompanyId=@Cid;
    FETCH NEXT FROM c INTO @Cid;
END
CLOSE c; DEALLOCATE c;
SELECT CompanyId, InventoryWarehouseId, CustomerAccountGroupId, SupplierAccountGroupId, SalesAccountId, SalesAccountCode FROM goldshop.GoldShopSettings;
