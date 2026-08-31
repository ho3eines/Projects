-- =============================================
-- Tarazin.Data/Scripts/inventory/StockCardReport.sql
-- Schema: inventory
-- Query. کارتکس کالا با ماندهٔ جاری (تعداد و ارزش + قیمت تمام‌شده) — به تفکیک انبار/انبارک اختیاری.
-- بهبود فاز ۲: افزودن CostPrice و BalanceValue در هر سطر + CreatedBy.
-- =============================================
DECLARE @InQty DECIMAL(18,3) = 0, @InValue DECIMAL(18,2) = 0, @OutQty DECIMAL(18,3) = 0, @OutValue DECIMAL(18,2) = 0;

SELECT
    m.MovementId,
    m.MovementDate,
    m.MovementNumber,
    m.MovementType,
    CASE WHEN m.MovementType = N'Issue' THEN m.Qty ELSE 0 END AS OutQty,
    CASE WHEN m.MovementType <> N'Issue' THEN m.Qty ELSE 0 END AS InQty,
    CASE WHEN m.MovementType = N'Issue' THEN (m.Qty * m.CostPrice) ELSE 0 END AS OutValue,
    CASE WHEN m.MovementType <> N'Issue' THEN (m.Qty * m.UnitPrice) ELSE 0 END AS InValue,
    m.CostPrice,
    m.Qty,
    m.UnitPrice,
    (m.Qty * m.CostPrice) AS TotalValue,
    m.Description,
    m.CreatedBy,
    w.Title AS WarehouseName,
    sw.Title AS SubWarehouseName
INTO #Card
FROM [inventory].[Movements] m
LEFT JOIN [inventory].[Warehouses] w ON w.WarehouseId = m.WarehouseId AND w.IsDeleted = 0
LEFT JOIN [inventory].[SubWarehouses] sw ON sw.SubWarehouseId = m.SubWarehouseId AND sw.IsDeleted = 0
WHERE m.ItemId = @ItemId
  AND m.IsDeleted = 0
  AND m.MovementDate BETWEEN @FromDate AND @ToDate
  AND m.CompanyId = @CompanyId
  AND (@WarehouseId IS NULL OR m.WarehouseId = @WarehouseId)
  AND (@SubWarehouseId IS NULL OR m.SubWarehouseId = @SubWarehouseId)
ORDER BY m.MovementDate, m.MovementId;

-- ماندهٔ ابتدای دوره
SELECT @InQty = ISNULL(SUM(CASE WHEN MovementType <> N'Issue' THEN Qty ELSE 0 END), 0),
       @InValue = ISNULL(SUM(CASE WHEN MovementType <> N'Issue' THEN Qty * UnitPrice ELSE 0 END), 0),
       @OutQty = ISNULL(SUM(CASE WHEN MovementType = N'Issue' THEN Qty ELSE 0 END), 0),
       @OutValue = ISNULL(SUM(CASE WHEN MovementType = N'Issue' THEN Qty * CostPrice ELSE 0 END), 0)
FROM [inventory].[Movements]
WHERE ItemId = @ItemId AND IsDeleted = 0 AND MovementDate < @FromDate
  AND CompanyId = @CompanyId
  AND (@WarehouseId IS NULL OR WarehouseId = @WarehouseId)
  AND (@SubWarehouseId IS NULL OR SubWarehouseId = @SubWarehouseId);

SELECT
    c.MovementId,
    c.MovementDate,
    c.MovementNumber,
    c.MovementType,
    c.Qty,
    c.UnitPrice,
    c.CostPrice,
    c.TotalValue,
    c.Description,
    c.CreatedBy,
    c.WarehouseName,
    c.SubWarehouseName,
    c.InQty,
    c.OutQty,
    c.InValue,
    c.OutValue,
    @InQty AS OpeningQty,
    @InValue AS OpeningValue,
    SUM(c.InQty - c.OutQty) OVER (ORDER BY c.MovementDate, c.MovementId ROWS UNBOUNDED PRECEDING) + @InQty - @OutQty AS BalanceQty,
    SUM(c.InValue - c.OutValue) OVER (ORDER BY c.MovementDate, c.MovementId ROWS UNBOUNDED PRECEDING) + @InValue - @OutValue AS BalanceValue
FROM #Card c
ORDER BY c.MovementDate, c.MovementId;

DROP TABLE #Card;
