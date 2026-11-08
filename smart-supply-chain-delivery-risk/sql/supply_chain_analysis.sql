-- =====================================================================
-- Project : Smart Supply Chain Performance & Delivery Risk Analytics
-- Tools   : Google BigQuery (SQL)
-- Project ID : supply-chain-513612
-- Dataset    : SupplyChain
-- Tabel mentah: SupplyChain (hasil upload DataCoSupplyChainDataset.csv)
-- =====================================================================

### 1. Melihat Semua Nama Kolom / Variabel
-- Jumlah baris tabel mentah
SELECT COUNT(*)
FROM `supply-chain-513612.SupplyChain.SupplyChain`;

-- Daftar nama kolom dan tipe data 
SELECT column_name, data_type
FROM `supply-chain-513612.SupplyChain.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'SupplyChain'
ORDER BY ordinal_position;

### 2. Membuat View Yang Berisi 18 Variabel Yang Akan Digunakan
CREATE OR REPLACE VIEW `supply-chain-513612.SupplyChain.vw_supply_chain` AS
SELECT
  `Order Id`                      AS order_id,
  `Order Item Id`                 AS order_item_id,
  `order date _DateOrders_`       AS order_date,
  `shipping date _DateOrders_`    AS shipping_date,
  `Days for shipping _real_`      AS days_for_shipping_real,
  `Days for shipment _scheduled_` AS days_for_shipment_scheduled,
  `Delivery Status`               AS delivery_status,
  `Late_delivery_risk`            AS late_delivery_risk,
  `Shipping Mode`                 AS shipping_mode,
  `Market`                        AS market,
  `Order Region`                  AS order_region,
  `Order Country`                 AS order_country,
  `Order State`                   AS order_state,
  `Sales`                         AS sales,
  `Benefit per order`             AS benefit_per_order,
  `Order Item Quantity`           AS order_item_quantity,
  `Category Name`                 AS category_name,
  `Department Name`               AS department_name
FROM `supply-chain-513612.SupplyChain.SupplyChain`;

SELECT *
FROM `supply-chain-513612.SupplyChain.vw_supply_chain`
LIMIT 10;

### 3. Cek Kualitas Data
## 3a. Distribusi Status Pengiriman
SELECT delivery_status, COUNT(*) AS jumlah
FROM `supply-chain-513612.SupplyChain.vw_supply_chain`
GROUP BY delivery_status
ORDER BY jumlah DESC;

## 3b. Cek Missing Value
SELECT
  COUNTIF(order_id IS NULL)      AS null_order_id,
  COUNTIF(order_date IS NULL)    AS null_order_date,
  COUNTIF(shipping_date IS NULL) AS null_shipping_date,
  COUNTIF(sales IS NULL)         AS null_sales,
  COUNTIF(order_state IS NULL)   AS null_state
FROM `supply-chain-513612.SupplyChain.vw_supply_chain`;

## 3c. Cek Data Duplicate Pada Kolom Order Id
SELECT COUNT(*) AS total_baris,
       COUNT(DISTINCT order_item_id) AS item_unik
FROM `supply-chain-513612.SupplyChain.vw_supply_chain`; 

### LATE RATE PER SHIPPING MODE (DATA FULL)
SELECT
  shipping_mode,
  COUNT(*) AS total_items,
  COUNTIF(delivery_status = 'Late delivery') AS late_items,
  ROUND(100 * COUNTIF(delivery_status = 'Late delivery') / COUNT(*), 2) AS late_rate_pct,
  ROUND(AVG(days_for_shipping_real - days_for_shipment_scheduled), 2) AS avg_delay_gap
FROM `supply-chain-513612.SupplyChain.vw_supply_chain`
GROUP BY shipping_mode
ORDER BY late_rate_pct DESC;

### ------ Menentukan Periode Data 3 Tahun (2015-2017) ------ ###

### 1. Periode Data
## 1a. Rentang Tanggal
SELECT
  MIN(order_date) AS tanggal_awal,
  MAX(order_date) AS tanggal_akhir
FROM `supply-chain-513612.SupplyChain.vw_supply_chain`;

## 1b. Cek Order Per Tahun dan Bulan
SELECT
  EXTRACT(YEAR FROM order_date) AS tahun,
  COUNT(DISTINCT EXTRACT(MONTH FROM order_date)) AS jumlah_bulan,
  COUNT(DISTINCT order_id) AS total_orders,
  COUNT(*) AS total_items
FROM `supply-chain-513612.SupplyChain.vw_supply_chain`
GROUP BY tahun
ORDER BY tahun;

### 2. View Data Yang Sudah Difilter (2015-01-01 sampai 2017-12-31)
CREATE OR REPLACE VIEW `supply-chain-513612.SupplyChain.vw_supply_chain_filtered` AS
SELECT *
FROM `supply-chain-513612.SupplyChain.vw_supply_chain`
WHERE DATE(order_date) BETWEEN '2015-01-01' AND '2017-12-31';

SELECT
  COUNT(*) AS jumlah_baris,
  COUNT(DISTINCT order_id) AS jumlah_order,
  MIN(order_date) AS tanggal_awal,
  MAX(order_date) AS tanggal_akhir
FROM `supply-chain-513612.SupplyChain.vw_supply_chain_filtered`;

### 3. Cek Kualitas Data (Filter)
## 3a. Distribusi Status Pengiriman
SELECT
  delivery_status,
  COUNT(*) AS jumlah,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS persen
FROM `supply-chain-513612.SupplyChain.vw_supply_chain_filtered`
GROUP BY delivery_status
ORDER BY jumlah DESC;

## 3b. Missing Value
SELECT
  COUNTIF(order_id IS NULL)      AS null_order_id,
  COUNTIF(order_date IS NULL)    AS null_order_date,
  COUNTIF(shipping_date IS NULL) AS null_shipping_date,
  COUNTIF(sales IS NULL)         AS null_sales,
  COUNTIF(order_state IS NULL)   AS null_state
FROM `supply-chain-513612.SupplyChain.vw_supply_chain_filtered`;

## 3c. Data Duplikat
SELECT
  COUNT(*) AS total_baris,
  COUNT(DISTINCT order_item_id) AS item_unik
FROM `supply-chain-513612.SupplyChain.vw_supply_chain_filtered`;

## 3d. Cek Nilai tidak Wajar
SELECT
  COUNTIF(sales <= 0) AS sales_nol_atau_negatif,
  COUNTIF(order_item_quantity <= 0) AS qty_nol_atau_negatif,
  COUNTIF(days_for_shipping_real < 0) AS hari_kirim_negatif,
  COUNTIF(shipping_date < order_date) AS kirim_sebelum_order
FROM `supply-chain-513612.SupplyChain.vw_supply_chain_filtered`;

### 4. Analisis (tanpa pesanan batal)
## 4a. KPI Utama
SELECT
  COUNT(DISTINCT order_id) AS total_orders,
  SUM(order_item_quantity) AS total_units,
  ROUND(SUM(sales), 2) AS total_sales,
  ROUND(SUM(benefit_per_order), 2) AS total_profit,
  ROUND(100 * SUM(benefit_per_order) / SUM(sales), 2) AS profit_margin_pct,
  ROUND(100 * COUNTIF(delivery_status = 'Late delivery') / COUNT(*), 2) AS late_rate_pct,
  ROUND(AVG(days_for_shipping_real), 2) AS avg_shipping_days,
  ROUND(AVG(days_for_shipping_real - days_for_shipment_scheduled), 2) AS avg_delay_gap
FROM `supply-chain-513612.SupplyChain.vw_supply_chain_filtered`
WHERE delivery_status != 'Shipping canceled';

## 4b. Late Rate Per Shipping Mode
SELECT
  shipping_mode,
  COUNT(*) AS total_items,
  COUNTIF(delivery_status = 'Late delivery') AS late_items,
  ROUND(100 * COUNTIF(delivery_status = 'Late delivery') / COUNT(*), 2) AS late_rate_pct,
  ROUND(AVG(days_for_shipment_scheduled), 2) AS avg_scheduled_days,
  ROUND(AVG(days_for_shipping_real), 2) AS avg_real_days,
  ROUND(AVG(days_for_shipping_real - days_for_shipment_scheduled), 2) AS avg_delay_gap
FROM `supply-chain-513612.SupplyChain.vw_supply_chain_filtered`
WHERE delivery_status != 'Shipping canceled'
GROUP BY shipping_mode
ORDER BY late_rate_pct DESC;


### ------ Menyimpan Hasil Filter ------ ###
CREATE OR REPLACE TABLE `supply-chain-513612.SupplyChain.supply_chain_final` AS
SELECT
  *,
  days_for_shipping_real - days_for_shipment_scheduled AS delay_gap,
  IF(delivery_status = 'Late delivery', 1, 0) AS is_late,
  EXTRACT(YEAR FROM order_date) AS order_year,
  EXTRACT(MONTH FROM order_date) AS order_month,
  SAFE_DIVIDE(benefit_per_order, sales) AS profit_margin
FROM `supply-chain-513612.SupplyChain.vw_supply_chain_filtered`;