--  Creation of Schema
CREATE SCHEMA tech_electro;
USE tech_electro;

--- DATA EXPLORATION
SELECT * FROM tech_electro.external_factors LIMIT 5;
SELECT * FROM tech_electro.`sales data` LIMIT 5;
SELECT * FROM tech_electro.product_information LIMIT 5;
-- Understanding the structure of our dataset
SHOW COLUMNS FROM tech_electro.external_factors ;
DESCRIBE tech_electro.`sales data`;
DESC tech_electro.product_information;
-- Data cleaning :
-- change to the right data type for all colmns
-- starting from the external factor table: SalesDate DATE , GDP DECIMAL(15,2) , InflationRate DECIMAL(5,2), SeasonalFactor DECIMAL(5,2)
ALTER TABLE tech_electro.external_factors 
ADD COLUMN New_Sales_Date DATE;
SET SQL_SAFE_UPDATES = 0; -- Turning off safe updates
UPDATE tech_electro.external_factors
SET New_Sales_Date = STR_TO_DATE(`Sales Date`, '%d/%m/%Y');
ALTER TABLE tech_electro.external_factors
DROP COLUMN `Sales Date`;
ALTER TABLE tech_electro.external_factors
CHANGE COLUMN New_Sales_Date Sales_Date DATE;

ALTER TABLE tech_electro.external_factors 
MODIFY COLUMN GDP DECIMAL(15,2);

ALTER TABLE tech_electro.external_factors 
MODIFY COLUMN `Inflation Rate` DECIMAL(5,2);

ALTER TABLE tech_electro.external_factors 
MODIFY COLUMN `Seasonal Factor` DECIMAL(5,2);

SHOW COLUMNS FROM tech_electro.external_factors ;
-- changing the right data type for the product columns
-- Product ID should be Int NOT NULL, Product Category Text, Promotions ENUM('yes', 'no')
ALTER TABLE tech_electro.product_information
ADD COLUMN NewPromotions ENUM('yes', 'no');
UPDATE tech_electro.product_information
SET Newpromotions = CASE
WHEN Promotions = 'yes' THEN 'yes'
WHEN Promotions = 'no' THEN 'no'
ELSE NULL
END;
ALTER TABLE tech_electro.product_information
DROP COLUMN Promotions;
ALTER TABLE tech_electro.product_information
CHANGE COLUMN NewPromotions Promotions ENUM('yes', 'no');

SHOW COLUMNS FROM tech_electro.product_information;
-- changing the right data type for the sales data  columns
-- product should be int,sales date should DATE,inventory quality int, product cost DECIMAL(10,2)
ALTER TABLE tech_electro.`sales data`
ADD COLUMN New_Sales_Date DATE;
UPDATE tech_electro.`sales data`
SET New_Sales_Date = STR_TO_DATE(`Sales Date`, '%d/%m/%Y');
ALTER TABLE tech_electro.`sales data`
DROP COLUMN `Sales Date`;
ALTER TABLE tech_electro.`sales data`
CHANGE COLUMN New_Sales_Date Sales_Date DATE;
DESC tech_electro.`sales data`;
-- Checking for missing values
-- starting from our external_factors tabel
SELECT
SUM(CASE WHEN Sales_Date IS NULL THEN 1 ELSE 0 END) AS missing_sales_date,
SUM(CASE WHEN GDP IS NULL THEN 1 ELSE 0 END) AS missing_gdp,
SUM(CASE WHEN `Inflation Rate` IS NULL THEN 1 ELSE 0 END) AS missing_inflation_rate,
SUM(CASE WHEN `Seasonal Factor` IS NULL THEN 1 ELSE 0 END) AS missing_seasonal_factor
FROM tech_electro.external_factors;

-- product information data
SELECT
SUM(CASE WHEN `Product ID` IS NULL THEN 1 ELSE 0 END) AS missing_product_id,
SUM(CASE WHEN `Product Category` IS NULL THEN 1 ELSE 0 END) AS product_category,
SUM(CASE WHEN `Promotions` IS NULL THEN 1 ELSE 0 END) AS missing_promotions
FROM tech_electro.product_information;

-- sales data tabel
SELECT
SUM(CASE WHEN `Product ID` IS NULL THEN 1 ELSE 0 END) AS missing_product_id,
SUM(CASE WHEN `Inventory Quantity` IS NULL THEN 1 ELSE 0 END) AS missing_inventory_quantity,
SUM(CASE WHEN `Product Cost` IS NULL THEN 1 ELSE 0 END) AS missing_product_cost,
SUM(CASE WHEN Sales_Date IS NULL THEN 1 ELSE 0 END) AS missing_sales_date
FROM tech_electro.`sales data`;
-- No missing values was found in all the dataset table

-- Checking for dulicate in our dataset
-- starting with the external fuction table
SELECT sales_date, COUNT(*) AS count
FROM tech_electro.external_factors
GROUP BY sales_date
HAVING count > 1;
-- this is to check the total count number of the duplicate
SELECT COUNT(*) FROM (SELECT sales_date, COUNT(*) AS count
FROM tech_electro.external_factors
GROUP BY sales_date
HAVING count > 1) AS dup;
---  352 duplicate was found in the external_factor table
-- product information table
-- this is to check the total count number of the duplicate
SELECT COUNT(*) FROM (SELECT `Product ID`, COUNT(*) AS count
FROM tech_electro.product_information
GROUP BY `Product ID`
HAVING count > 1) AS dup;
-- 117 duplicates was found in the product_information table.
-- sales data duplicate check
SELECT `Product ID`, Sales_Date, COUNT(*) AS count
FROM tech_electro.`sales data`
GROUP BY `Product ID`, Sales_Date
HAVING count > 1;

--- Dealing with dulicates for external_factors and product_information tables
-- External_factors
USE tech_electro;
DELETE el FROM tech_electro.external_factors el
INNER JOIN (
SELECT Sales_Date,
ROW_NUMBER() OVER (PARTITION BY Sales_Date ORDER BY Sales_Date) AS rn
FROM tech_electro.external_factors
) e2 ON el.Sales_Date = e2.Sales_Date
WHERE e2.rn > 1;
-- product_information tables
USE tech_electro;
DELETE pl FROM tech_electro.product_information pl
INNER JOIN (
SELECT `Product ID`,
ROW_NUMBER() OVER (PARTITION BY `Product ID` ORDER BY `Product ID`) AS rn
FROM tech_electro.product_information
) p2 ON pl.`Product ID` = p2.`Product ID`
WHERE p2.rn > 1;

-- DATA iNTERGATION
-- Joining the sales and product information table data together and name it sales_product_data with their unique key product id to create  a view 
CREATE VIEW sales_product_data AS 
SELECT
s.`Product ID`,
s.Sales_Date,
s.`Inventory Quantity`,
s.`Product Cost`,
p.`Product Category`,
p.`Promotions`
FROM tech_electro.`sales data` s
JOIN tech_electro.product_information p ON s.`Product ID` = p.`Product ID`;

-- combining the sales_product_data and external factor dataset with their uniques key sales_date to create a view
CREATE VIEW Inventory_data AS 
SELECT
sp.`Product ID`,
sp.Sales_Date,
sp.`Inventory Quantity`,
sp.`Product Cost`,
sp.`Product Category`,
sp.`Promotions`,
e.GDP,
e.`Inflation Rate`,
e.`Seasonal Factor`
FROM tech_electro.sales_product_data sp
LEFT JOIN tech_electro.external_factors e 
ON sp.Sales_Date = e.Sales_Date;

-- Descriptive Analysis
-- Basic Statistics
-- calculating the average sales of(product iventory quantity and product cost)
SELECT `Product ID`,
AVG(`Inventory Quantity` * `Product Cost`)as avg_sales
FROM Inventory_data
GROUP BY `Product ID`
ORDER BY avg_sales DESC;
-- calculating the median stock level (i.e inventory quantity)
SELECT `Product ID`, AVG(`Inventory Quantity`) as median_stock
FROM(
SELECT `Product ID`,
       `Inventory Quantity`,
ROW_NUMBER() OVER(PARTITION BY `Product ID` ORDER BY `Inventory Quantity`) as row_num_dsc,
ROW_NUMBER() OVER(PARTITION BY `Product ID` ORDER BY `Inventory Quantity` DESC) as row_num_desc
FROM Inventory_data
)AS subquary
WHERE row_num_dsc IN (row_num_desc, row_num_desc = 1, row_num_desc = 1)
GROUP BY `Product ID`;
--  Product performance metrics(total sales per product)
SELECT `Product ID`,
ROUND(SUM(`Inventory Quantity` * `Product Cost`)) as total_sales
FROM Inventory_data
GROUP BY `Product ID`
ORDER BY total_sales DESC;
-- Note that 

-- identify high - demand product based on average sales
WITH HighDemandProducts AS (
    SELECT `Product ID`, AVG(`Inventory Quantity`) as average_sales
    FROM Inventory_data
    GROUP BY `Product ID`
    HAVING average_sales > (
        SELECT AVG(`Inventory Quantity`) * 0.95
        FROM tech_electro.`sales data`
    )
)



-- calculate stock out frequency for high demand products
SELECT s.`Product ID`,
COUNT(*) as stockout_freguency
FROM Inventory_data s
WHERE s.`Product ID` IN (SELECT `Product ID` FROM HighDemandProducts)
AND s.`Inventory Quantity` = 0
GROUP BY s.`Product ID`;
-- observation is that none of our high demand product has exprience any stockout.

 -- calculating how External Influnce factors like GdP AND iNFLATION Affect the inventor sales
 -- i.e influence of external factors starting from Gdp
 SELECT `Product ID`,
       AVG(CASE WHEN GDP > 0 THEN `Inventory Quantity` END) AS avg_sales_positive_gdp,
       AVG(CASE WHEN GDP <= 0 THEN `Inventory Quantity` END) AS avg_sales_non_positive_gdp
FROM Inventory_data
GROUP BY `Product ID`
HAVING avg_sales_positive_gdp IS NOT NULL;

-- influence of iNFLATION HAS external factor Calculation
SELECT `Product ID`,
       AVG(CASE WHEN `Inflation Rate` > 0 THEN `Inventory Quantity` ELSE NULL END) AS avg_sales_positive_inflation,
       AVG(CASE WHEN `Inflation Rate` <= 0 THEN `Inventory Quantity` ELSE NULL END) AS avg_sales_non_positive_inflation
FROM Inventory_data
GROUP BY `Product ID`
HAVING avg_sales_positive_inflation IS NOT NULL;
-- observation 


-- INVENTORY OPTIMIZATION
-- We are trying to determine the reorder cost base on historic sales data and external factors
-- reorder point = leadtime demand + safety stock
-- lead time demand = rolling average sales * lead time
-- safety stock = Z* lead time *2 standard deviation of demand
-- a constant lead time of 7 days for all products
-- we aim for 95% service level
-- standard deviation of 1.645
WITH InventoryCalculations AS (
    SELECT `Product ID`,
           AVG(rolling_avg_sales) AS avg_rolling_sales,
           AVG(rolling_variance) AS avg_rolling_variance
    FROM (
        SELECT `Product ID`,
               AVG(daily_sales) OVER (PARTITION BY `Product ID` ORDER BY Sales_Date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rolling_avg_sales,
               AVG(squared_diff) OVER (PARTITION BY `Product ID` ORDER BY Sales_Date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rolling_variance
        FROM (
            SELECT `Product ID`,
                   Sales_Date,
                   `Inventory Quantity` * `Product Cost` AS daily_sales,
                   (`Inventory Quantity` * `Product Cost` - AVG(`Inventory Quantity` * `Product Cost`) OVER (PARTITION BY `Product ID` ORDER BY Sales_Date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)) *
                   (`Inventory Quantity` * `Product Cost` - AVG(`Inventory Quantity` * `Product Cost`) OVER (PARTITION BY `Product ID` ORDER BY Sales_Date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)) AS squared_diff
            FROM Inventory_data
        ) subquery
    ) subquery2
    GROUP BY `Product ID`
)
SELECT `Product ID`,
       avg_rolling_sales * 7 AS lead_time_demand,
       1.645 * (avg_rolling_variance * 7) AS safety_stock,
       (avg_rolling_sales * 7) + (1.645 * (avg_rolling_variance * 7)) AS reorder_point
FROM InventoryCalculations;
-- creating the inventory optimization table
CREATE TABLE Inventory_optimization (
Product_ID INT,
Reorder_Point DOUBLE
);

-- Step 2 create store procedure to recalculate reorder point
DELIMITER //

CREATE PROCEDURE Recalculatereorderpoint(Product_ID INT)
BEGIN
    DECLARE avgRollingSales DOUBLE;
    DECLARE avgRollingVariance DOUBLE;
    DECLARE leadTimeDemand DOUBLE;
    DECLARE safetyStock DOUBLE;
    DECLARE reorderPoint DOUBLE;
    
    SELECT AVG(rolling_avg_sales), AVG(rolling_variance)
    INTO avgRollingSales, avgRollingVariance
    FROM (
        SELECT `Product ID`,
               AVG(daily_sales) OVER (PARTITION BY `Product ID` ORDER BY Sales_Date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rolling_avg_sales,
               AVG(squared_diff) OVER (PARTITION BY `Product ID` ORDER BY Sales_Date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rolling_variance
        FROM (
            SELECT `Product ID`,
                   Sales_Date,
                   `Inventory Quantity` * `Product Cost` AS daily_sales,
                   (`Inventory Quantity` * `Product Cost` - AVG(`Inventory Quantity` * `Product Cost`) OVER (PARTITION BY `Product ID` ORDER BY Sales_Date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)) *
                   (`Inventory Quantity` * `Product Cost` - AVG(`Inventory Quantity` * `Product Cost`) OVER (PARTITION BY `Product ID` ORDER BY Sales_Date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)) AS squared_diff
            FROM Inventory_data
            WHERE `Product ID` = Product_ID
        ) InnerDerived
    ) OuterDerived;
    
    SET leadTimeDemand = avgRollingSales * 7;
    SET safetyStock = 1.645 * SQRT(avgRollingVariance * 7);
    SET reorderPoint = leadTimeDemand + safetyStock;
    
    INSERT INTO Inventory_optimization (Product_ID, Reorder_Point)
    VALUES (Product_ID, reorderPoint)
    ON DUPLICATE KEY UPDATE Reorder_Point = reorderPoint;
END //

DELIMITER ;
-- Step 3 make inventory data a permanent table 
CREATE TABLE Inventory_table AS SELECT * FROM Inventory_data;
-- step 4 create a trigger 
DELIMITER //

CREATE TRIGGER AfterInventoryfindtable
AFTER INSERT ON Inventory_table
FOR EACH ROW
BEGIN
    CALL Recalculatereorderpoint(NEW.`Product ID`);
END //

DELIMITER ;

-- overstocking AND UNDERSTOCKING ANALYSIS CALCULATION
WITH RollingSales AS (
    SELECT 
        `Product ID`,
        Sales_Date,
        AVG(`Inventory Quantity` * `Product Cost`) OVER (PARTITION BY `Product ID` ORDER BY Sales_Date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rolling_avg_sales
    FROM Inventory_table
),
StockoutDays AS (
    SELECT 
        `Product ID`,
        COUNT(*) AS stockout_days
    FROM Inventory_table
    WHERE `Inventory Quantity` = 0
    GROUP BY `Product ID`
)
-- join the above CTEs with the main table to get the result
SELECT 
    f.`Product ID`,
    AVG(f.`Inventory Quantity` * f.`Product Cost`) AS avg_inventory_value,
    AVG(rs.rolling_avg_sales) AS avg_rolling_sales,
    COALESCE(sd.stockout_days, 0) AS stockout_days
FROM Inventory_table f
JOIN RollingSales rs ON f.`Product ID` = rs.`Product ID` AND f.Sales_Date = rs.Sales_Date
LEFT JOIN StockoutDays sd ON f.`Product ID` = sd.`Product ID`
GROUP BY f.`Product ID`, sd.stockout_days;
-- they need to work in their inventory cost they have alot of overstock product.

-- MONITOR AND ADJUST
-- creating a procedure to monitor our Inventory levels product
DELIMITER //
CREATE PROCEDURE MonitorInventoryLevels()
BEGIN
SELECT `Product ID`, AVG(`Inventory Quantity`) as AvgInventory
FROM Inventory_table
GROUP BY `Product ID`
ORDER BY AvgInventory DESC;
END//
DELIMITER ;
-- monitor sales trends
DELIMITER //
CREATE PROCEDURE MonitorSalesTrends()
BEGIN
    SELECT 
        `Product ID`, 
        Sales_Date,
        AVG(`Inventory Quantity` * `Product Cost`) OVER (PARTITION BY `Product ID` ORDER BY Sales_Date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS RollingAvgSales
    FROM Inventory_table
    ORDER BY `Product ID`, Sales_Date;
END //
DELIMITER ;

-- mONITOR stockout frequencies
DELIMITER //
CREATE PROCEDURE MonitorStockouts()
BEGIN
SELECT `Product ID`, COUNT(*) as StockoutDays
FROM Inventory_table
WHERE `Inventory Quantity` = 0
GROUP BY `Product ID`
ORDER BY StockoutDays DESC;
END//
DELIMITER ;

-- FEEDBACK LOOP

-- feedback loop establishment:
-- 1. Feedback Portal:We'll create a user-friendly website where stockholders can log in and share their thoughts. They can report on how well the inventory is working, any issues they're facing, or suggestions for improvement. This makes it easy for everyone to contribute ideas without needing to schedule meetings or send emails.
-- 2. Review Meetings:We'll set up regular meetings, maybe monthly or quarterly, where key people involved with the inventory system can come together. In these meetings, we'll discuss how the system is performing, look at data, and listen to people's experiences. This face-to-face interaction can lead to valuable insights and collaborative problem-solving.
-- 3. System Monitoring:We'll use special computer programs (SQL procedures) to constantly check how the inventory system is working. These programs will track things like stock levels, order times, and delivery speeds. If anything unusual happens, like suddenly running low on a product or delays in shipping, the system will alert us so we can investigate quickly.
-- 4. Feedback Analysis: We'll collect all the feedback from the website and meetings, then carefully study it. We'll look for patterns, like if many people are mentioning the same problem. This helps us understand what the biggest issues are and where we should focus our efforts to improve.
-- 5. Action Implementation:Based on what we learn from the feedback and data, we'll make changes. This could mean adjusting how much of each product we keep in stock, changing when we order new supplies, or updating our processes. We'll prioritize the most important issues first.
-- 6. Change Communication:Whenever we make changes based on feedback, we'll let everyone know. We'll explain what changes we're making and why, giving credit to the feedback that led to the improvements. This shows people that we value their input and encourages them to keep sharing their thoughts.
-- By following these steps, we create a continuous improvement cycle. We gather information, analyze it, make changes, and then start the process over again. This helps keep our inventory system up-to-date and responsive to real-world needs.



-- GENERAL INSIGHT AND RECCOMENDATION

-- KEY INSIGHT
-- 1 Inventory Discription : The Initial stages of the analysis revealed significant discrepancies in inventory levels,with instances of both overstocking and understocking
-- these inconsistencies were contributing to capital inefficiencies and customer dissatifaction

-- 2 Sales Trends and External Influences: the analysis indicate that sales trend were notably influenced by various external factors.
-- Recognizing these pattern provides an opportunity to forecast demand more accurately

-- 3 Subotimal Inventory levels:Thright the inventory optimization analysis ,it was envidnt that the exisiting inventory levels were not optimize for current sales trends.
-- products was identify that had eiter close excess inventory

-- 4 Inventory Not at the Right Levels:When we looked closely at our inventory, we saw it wasn't matching up with how much we were actually selling. Some products had way too much stock sitting around, while others were always running out.

-- RECCOMENDATIONS
-- 1 Implement Dynamic Inventory Management: the company should transition for a static to a dynamic inventory management system
-- adjusting inventory levels based on real_time sales trends ,seasonality and external factors
-- Use a Smart Inventory System:Change from a fixed system to one that changes with sales. Adjust how much stuff we keep based on what's selling now, what time of year it is, and other outside things that affect sales.  

-- 2 Optimize REORDER: Points AND SAFETY stocks: untilize the reorder pont and saftey stocks calculated during analysis to minimize stockouts and reduce excess inventory
-- regulary review these metrics to ensure they align with current market conditions
-- Order at the Right Time:Use the numbers we figured out to know when to order more stuff and how much extra to keep. This helps us not run out or have too much. Keep checking these numbers to make sure they still work for us.

-- 3 Ehance Pricing Strategies:conduct a through review of product pricing strategies,especially for products identified as unprofitable.
-- consider factors such as competitors pricing,marketdemand and product acquisition costs

-- 4 Reduce Overstock: identify products that are consistently overstocked and take steps to reduce their inventory levels
-- this could include promotion sales ,discounts or discontinuing product with low sales performance
-- Get Rid of Extra Stuff:Find out what we always have too much of. Try to have less of these things. We could have sales, lower prices, or stop selling things that don't sell well.

-- 5 Establish a feedback Loop: developa systematic approach to collect and analyze feedbacks from various stakeholders
-- use yjis feedback for  continuous improvemnet and alignment with business objectives

-- 6 Regular Montoring and Adjustment: adopt a proactive approach to inventory management by regularly monitoring key metrics 
-- and making neccessaru adjustment to inventory levels,order quantities and safety stocks
-- Keep Watching and Changing:Always look at how we're doing. Check important numbers often. Change how much stuff we have, how much we order, and how much extra we keep when we need to.






