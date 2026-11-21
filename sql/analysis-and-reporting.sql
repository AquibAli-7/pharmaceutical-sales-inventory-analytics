-- Import the nine cleaned CSVs into dbo before running this script.
USE PharmaAnalytics;
GO

-- Question 1: Overall sales performance
SELECT
    COUNT(*) AS SalesLines,
    SUM(quantity_packs) AS PacksSold,
    SUM(
        quantity_packs * unit_price_inr
        - ROUND(
            quantity_packs * unit_price_inr
            * discount_pct / 100,
            2
        )
    ) AS NetRevenueINR
FROM dbo.sales;

-- Question 2: Yearly sales performance
SELECT
    YEAR(sale_date) AS SalesYear,
    COUNT(*) AS SalesLines,
    SUM(quantity_packs) AS PacksSold,
    SUM(
        quantity_packs * unit_price_inr
        - ROUND(
            quantity_packs * unit_price_inr
            * discount_pct / 100,
            2
        )
    ) AS NetRevenueINR
FROM dbo.sales
GROUP BY YEAR(sale_date)
ORDER BY SalesYear;


-- Question 3: Monthly sales performance
SELECT
    YEAR(sale_date) AS SalesYear,
    MONTH(sale_date) AS SalesMonth,
    SUM(quantity_packs) AS PacksSold,
    SUM(
        quantity_packs * unit_price_inr
        - ROUND(
            quantity_packs * unit_price_inr
            * discount_pct / 100,
            2
        )
    ) AS NetRevenueINR
FROM dbo.sales
GROUP BY
    YEAR(sale_date),
    MONTH(sale_date)
ORDER BY
    SalesYear,
    SalesMonth;


    -- Question 4: Revenue by category
SELECT
    c.category_name AS Category,
    SUM(s.quantity_packs) AS PacksSold,
    SUM(
        s.quantity_packs * s.unit_price_inr
        - ROUND(
            s.quantity_packs * s.unit_price_inr
            * s.discount_pct / 100,
            2
        )
    ) AS NetRevenueINR
FROM dbo.sales AS s
JOIN dbo.products AS p
    ON s.product_id = p.product_id
JOIN dbo.categories AS c
    ON p.category_id = c.category_id
GROUP BY c.category_name
ORDER BY NetRevenueINR DESC;


-- Question 5: Top 10 products by revenue
SELECT TOP (10)
    p.product_id AS ProductID,
    p.product_name AS ProductName,
    SUM(s.quantity_packs) AS PacksSold,
    SUM(
        s.quantity_packs * s.unit_price_inr
        - ROUND(
            s.quantity_packs * s.unit_price_inr
            * s.discount_pct / 100,
            2
        )
    ) AS NetRevenueINR
FROM dbo.sales AS s
JOIN dbo.products AS p
    ON s.product_id = p.product_id
GROUP BY
    p.product_id,
    p.product_name
ORDER BY
    NetRevenueINR DESC,
    p.product_id;



-- Question 6: Sales by customer type
SELECT
    c.customer_type AS CustomerType,
    COUNT(*) AS SalesLines,
    SUM(s.quantity_packs) AS PacksSold,
    SUM(
        s.quantity_packs * s.unit_price_inr
        - ROUND(
            s.quantity_packs * s.unit_price_inr
            * s.discount_pct / 100,
            2
        )
    ) AS NetRevenueINR
FROM dbo.sales AS s
JOIN dbo.customers AS c
    ON s.customer_id = c.customer_id
GROUP BY c.customer_type
ORDER BY NetRevenueINR DESC;


-- Question 7: Revenue per active customer
SELECT
    c.customer_type AS CustomerType,
    COUNT(DISTINCT s.customer_id) AS ActiveCustomers,
    CAST(
        SUM(
            s.quantity_packs * s.unit_price_inr
            - ROUND(
                s.quantity_packs * s.unit_price_inr
                * s.discount_pct / 100,
                2
            )
        ) / COUNT(DISTINCT s.customer_id)
        AS decimal(14,2)
    ) AS RevenuePerActiveCustomerINR
FROM dbo.sales AS s
JOIN dbo.customers AS c
    ON s.customer_id = c.customer_id
WHERE s.customer_id <> N'C_UNKNOWN'
GROUP BY c.customer_type
ORDER BY RevenuePerActiveCustomerINR DESC;


-- Question 8: Revenue by customer location
SELECT
    c.city AS City,
    c.state AS State,
    COUNT(DISTINCT s.customer_id) AS ActiveCustomers,
    SUM(s.quantity_packs) AS PacksSold,
    SUM(
        s.quantity_packs * s.unit_price_inr
        - ROUND(
            s.quantity_packs * s.unit_price_inr
            * s.discount_pct / 100,
            2
        )
    ) AS NetRevenueINR
FROM dbo.sales AS s
JOIN dbo.customers AS c
    ON s.customer_id = c.customer_id
GROUP BY
    c.city,
    c.state
ORDER BY NetRevenueINR DESC;


-- Question 9: Stock on the reporting date
SELECT
    snapshot_date AS ReportDate,
    COUNT(*) AS Products,
    SUM(closing_stock_packs) AS AvailablePacks
FROM dbo.inventory_month_end
WHERE snapshot_date = '20251231'
GROUP BY snapshot_date;


-- Question 10: Products needing stock review
SELECT
    p.product_id AS ProductID,
    p.product_name AS ProductName,
    i.closing_stock_packs AS AvailablePacks,
    p.reorder_point_packs AS ReorderPoint
FROM dbo.inventory_month_end AS i
JOIN dbo.products AS p
    ON i.product_id = p.product_id
WHERE i.snapshot_date = '20251231'
  AND i.closing_stock_packs <= p.reorder_point_packs
ORDER BY
    i.closing_stock_packs,
    p.product_id;


-- Question 11: Stock coverage for low-stock products
;WITH RecentSales AS (
    SELECT
        product_id,
        SUM(quantity_packs) AS PacksSold90Days
    FROM dbo.sales
    WHERE sale_date BETWEEN '20251003' AND '20251231'
    GROUP BY product_id
)
SELECT
    p.product_id AS ProductID,
    p.product_name AS ProductName,
    i.closing_stock_packs AS AvailablePacks,
    p.reorder_point_packs AS ReorderPoint,
    COALESCE(r.PacksSold90Days, 0) AS PacksSold90Days,
    CAST(
        i.closing_stock_packs * 90.0
        / NULLIF(r.PacksSold90Days, 0)
        AS decimal(10,2)
    ) AS EstimatedDaysOfStock
FROM dbo.inventory_month_end AS i
JOIN dbo.products AS p
    ON i.product_id = p.product_id
LEFT JOIN RecentSales AS r
    ON i.product_id = r.product_id
WHERE i.snapshot_date = '20251231'
  AND i.closing_stock_packs <= p.reorder_point_packs
ORDER BY
    CASE WHEN r.PacksSold90Days > 0 THEN 0 ELSE 1 END,
    EstimatedDaysOfStock;


USE PharmaAnalytics;
GO

-- Question 12A: Combine stock movements
CREATE OR ALTER VIEW dbo.vw_StockMovements AS

SELECT
    batch_id,
    product_id,
    receipt_date AS MovementDate,
    quantity_received_packs AS QuantityChange
FROM dbo.stock_receipts

UNION ALL

SELECT
    batch_id,
    product_id,
    sale_date,
    -quantity_packs
FROM dbo.sales

UNION ALL

SELECT
    batch_id,
    product_id,
    adjustment_date,
    quantity_change_packs
FROM dbo.stock_adjustments;
GO

-- Check the combined stock balance
SELECT SUM(QuantityChange) AS RemainingStockPacks
FROM dbo.vw_StockMovements
WHERE MovementDate <= '20251231';


-- Question 12B: Remaining stock by batch
GO

CREATE OR ALTER VIEW dbo.vw_BatchStock_20251231 AS
SELECT
    batch_id,
    SUM(QuantityChange) AS RemainingPacks
FROM dbo.vw_StockMovements
WHERE MovementDate <= '20251231'
GROUP BY batch_id
HAVING SUM(QuantityChange) > 0;
GO

SELECT
    COUNT(*) AS BatchesWithStock,
    SUM(RemainingPacks) AS RemainingStockPacks
FROM dbo.vw_BatchStock_20251231;


-- Question 12C: Stock value by expiry window
;WITH ExpiryDetails AS (
    SELECT
        s.batch_id,
        s.RemainingPacks,
        s.RemainingPacks * b.unit_cost_inr AS StockValueINR,
        CASE
            WHEN b.expiry_date <= '20251231' THEN 0
            WHEN b.expiry_date <= '20260130' THEN 1
            WHEN b.expiry_date <= '20260301' THEN 2
            WHEN b.expiry_date <= '20260331' THEN 3
            ELSE 4
        END AS ExpiryGroup
    FROM dbo.vw_BatchStock_20251231 AS s
    JOIN dbo.batches AS b
        ON s.batch_id = b.batch_id
)
SELECT
    CASE ExpiryGroup
        WHEN 0 THEN 'Already expired'
        WHEN 1 THEN '1–30 days'
        WHEN 2 THEN '31–60 days'
        WHEN 3 THEN '61–90 days'
        ELSE 'Over 90 days'
    END AS ExpiryWindow,
    COUNT(*) AS Batches,
    SUM(RemainingPacks) AS RemainingPacks,
    SUM(StockValueINR) AS StockValueINR
FROM ExpiryDetails
GROUP BY ExpiryGroup
ORDER BY ExpiryGroup;


-- Reporting view for Power BI
GO

CREATE OR ALTER VIEW dbo.vw_SalesAnalysis AS
SELECT
    sales_line_id,
    sale_date,
    customer_id,
    product_id,
    batch_id,
    quantity_packs,
    unit_price_inr,
    discount_pct,
    CAST(
        quantity_packs * unit_price_inr
        - ROUND(
            quantity_packs * unit_price_inr
            * discount_pct / 100,
            2
        )
        AS decimal(18,2)
    ) AS NetRevenueINR
FROM dbo.sales;
GO

-- Verify the reporting view
SELECT
    COUNT(*) AS SalesLines,
    SUM(quantity_packs) AS PacksSold,
    SUM(NetRevenueINR) AS NetRevenueINR
FROM dbo.vw_SalesAnalysis;


-- Inventory reporting view for Power BI
GO

CREATE OR ALTER VIEW dbo.vw_InventoryAnalysis_20251231 AS
SELECT
    CAST('20251231' AS date) AS ReportDate,
    s.batch_id,
    b.product_id,
    b.supplier_id,
    b.expiry_date,
    s.RemainingPacks,
    b.unit_cost_inr,
    s.RemainingPacks * b.unit_cost_inr AS StockValueINR,
    DATEDIFF(
        DAY,
        CAST('20251231' AS date),
        b.expiry_date
    ) AS DaysToExpiry
FROM dbo.vw_BatchStock_20251231 AS s
JOIN dbo.batches AS b
    ON s.batch_id = b.batch_id;
GO

-- Verify the inventory view
SELECT
    COUNT(*) AS BatchesWithStock,
    SUM(RemainingPacks) AS AvailablePacks,
    SUM(StockValueINR) AS StockValueINR
FROM dbo.vw_InventoryAnalysis_20251231;