-- =============================================
-- Tarazin.Data/Scripts/inventory/StockCardReport.sql
-- Schema: inventory
-- Query. کارتکس کالا با ماندهٔ جاری (تعداد و ارزش + قیمت تمام‌شده) — به تفکیک انبار/انبارک اختیاری.
-- بهبود فاز ۲: افزودن CostPrice و BalanceValue در هر سطر + CreatedBy.
-- بهبود LotSerial: ستون‌های Lot/Serial/Expiry در هر سطر (از inventory.LotSerials)
-- + EarliestExpiry برای هشدار انقضای نزدیک در UI.
-- بهبود مبدأ: SourceType/SourceId از SourceReference + فیلتر @SourceType
-- (StoreOrder/PINV/SINV/RET/Transfer/Stocktake/Manual — NULL/خالی = همه).
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
    sw.Title AS SubWarehouseName,
    ls.LotNo,
    ls.SerialNo,
    ls.ExpiryDate,
    ls.EarliestExpiry,
    m.SourceReference,
    src.SourceType,
    src.SourceId
INTO #Card
FROM [inventory].[Movements] m
CROSS APPLY (
    SELECT CASE WHEN CHARINDEX(N':', m.SourceReference) > 0
                THEN LEFT(m.SourceReference, CHARINDEX(N':', m.SourceReference) - 1)
                ELSE m.SourceReference END AS SourceType,
           CASE WHEN CHARINDEX(N':', m.SourceReference) > 0
                THEN TRY_CONVERT(BIGINT, SUBSTRING(m.SourceReference, CHARINDEX(N':', m.SourceReference) + 1, 400))
                ELSE NULL END AS SourceId
) src
LEFT JOIN [inventory].[Warehouses] w ON w.WarehouseId = m.WarehouseId AND w.IsDeleted = 0
LEFT JOIN [inventory].[SubWarehouses] sw ON sw.SubWarehouseId = m.SubWarehouseId AND sw.IsDeleted = 0
LEFT JOIN (
    -- هر حرکت (دریافت/صدور) ممکن است چند سریال/بچ داشته باشد → یک رشتهٔ ادغام‌شده
    SELECT
        COALESCE(ReceiptMovementId, IssueMovementId) AS MovementId,
        STRING_AGG(ISNULL(NULLIF(LotNo, N''), N''), N', ') WITHIN GROUP (ORDER BY LotSerialId) AS LotNo,
        STRING_AGG(ISNULL(NULLIF(SerialNo, N''), N''), N', ') WITHIN GROUP (ORDER BY LotSerialId) AS SerialNo,
        STRING_AGG(CONVERT(NVARCHAR(10), ExpiryDate, 111), N', ') WITHIN GROUP (ORDER BY LotSerialId) AS ExpiryDate,
        MIN(ExpiryDate) AS EarliestExpiry
    FROM [inventory].[LotSerials]
    WHERE ItemId = @ItemId AND CompanyId = @CompanyId
      AND (ReceiptMovementId IS NOT NULL OR IssueMovementId IS NOT NULL)
    GROUP BY COALESCE(ReceiptMovementId, IssueMovementId)
) ls ON ls.MovementId = m.MovementId
WHERE m.ItemId = @ItemId
  AND m.IsDeleted = 0
  AND m.MovementDate BETWEEN @FromDate AND @ToDate
  AND m.CompanyId = @CompanyId
  AND (@WarehouseId IS NULL OR m.WarehouseId = @WarehouseId)
  AND (@SubWarehouseId IS NULL OR m.SubWarehouseId = @SubWarehouseId)
  AND (@SourceType IS NULL OR @SourceType = N'' OR src.SourceType = @SourceType)
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
    c.LotNo,
    c.SerialNo,
    c.ExpiryDate,
    c.EarliestExpiry,
    c.SourceReference,
    c.SourceType,
    c.SourceId,
    @InQty AS OpeningQty,
    @InValue AS OpeningValue,
    SUM(c.InQty - c.OutQty) OVER (ORDER BY c.MovementDate, c.MovementId ROWS UNBOUNDED PRECEDING) + @InQty - @OutQty AS BalanceQty,
    SUM(c.InValue - c.OutValue) OVER (ORDER BY c.MovementDate, c.MovementId ROWS UNBOUNDED PRECEDING) + @InValue - @OutValue AS BalanceValue
FROM #Card c
ORDER BY c.MovementDate, c.MovementId;

DROP TABLE #Card;
