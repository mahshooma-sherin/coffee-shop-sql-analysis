
--------------------------Monday cofee data analysis-------------

CREATE TABLE city (
    city_id INT PRIMARY KEY,
    city_name VARCHAR(100) NOT NULL,
    population INT NOT NULL,
    estimated_rent INT NOT NULL,
    city_rank INT NOT NULL
);
===============================================================
CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    city_id INT NOT NULL,

    CONSTRAINT fk_customer_city
        FOREIGN KEY (city_id)
        REFERENCES city(city_id)
);
=================================================
CREATE TABLE products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(150) NOT NULL,
    price INT NOT NULL
);
====================================================
CREATE TABLE sales (
    sale_id INT PRIMARY KEY,
    sale_date DATE NOT NULL,
    product_id INT NOT NULL,
    customer_id INT NOT NULL,
    total INT NOT NULL,
    rating INT CHECK (rating BETWEEN 1 AND 5),

    CONSTRAINT fk_sales_product
        FOREIGN KEY (product_id)
        REFERENCES products(product_id),

    CONSTRAINT fk_sales_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
);
====================================================
----------1. Coffee Consumers Count----------
Question: How many people in each city are estimated to consume coffee, given that 25% of the population does?
SELECT
    city_name,
    round((population * 0.25)/1000000,2)AS estimated_coffee_consumers,
	city_rank
FROM city
order by 2 desc;
===================================================
-----------2. Total Revenue from Coffee Sales----------
Question: What is the total revenue generated from coffee sales across all cities in the last quarter of 2023?
SELECT city_name,
    SUM(s.total) AS total_revenue
FROM city c
JOIN customers cu
ON c.city_id = cu.city_id
JOIN sales s
ON cu.customer_id = s.customer_id
WHERE EXTRACT(YEAR FROM sale_date)=2023
AND EXTRACT(QUARTER FROM sale_date)=4
group by 1
order by 2 desc;


=====================================================
----------3. Sales Count for Each Product-------
--Question: How many units of each coffee product have been sold?--
SELECT
    p.product_name,
    COUNT(s.sale_id) AS units_sold
FROM products p
JOIN sales s
ON p.product_id = s.product_id
GROUP BY p.product_name
ORDER BY units_sold DESC;
---------4. Average Sales Amount per City----------
--Question: What is the average sales amount per customer in each city?--
SELECT
    c.city_name,
    ROUND(sum(s.total)) AS total_revanue,
	count(distinct cu.customer_id) as total_customers,
	 round(sum(s.total)/ count(distinct cu.customer_id)::numeric) as average_sales_per_customer
FROM city c
JOIN customers cu
ON c.city_id = cu.city_id
JOIN sales s
ON cu.customer_id = s.customer_id
GROUP BY c.city_name
ORDER BY average_sales_per_customer DESC; 
--------------------5. City Population and Coffee Consumers----------
SELECT
    city_name,
    round((population * 0.25)/1000000,2)AS coffee_consumers,
	count (distinct cu.customer_id)as unique_customers
FROM city c
JOIN customers cu
ON c.city_id = cu.city_id
JOIN sales s
ON cu.customer_id = s.customer_id
group by city_name ,2;

---------6. Top 3 Selling Products by City-----------
SELECT *
FROM
(       SELECT
        ci.city_name,
        p.product_name,
        COUNT(s.sale_id) AS total_sales,
        RANK() OVER(
            PARTITION BY ci.city_name
            ORDER BY COUNT(s.sale_id) DESC
        ) AS rank
    FROM sales s
    JOIN customers c
        ON s.customer_id = c.customer_id
    JOIN city ci
        ON c.city_id = ci.city_id
    JOIN products p
        ON s.product_id = p.product_id
    GROUP BY
        ci.city_name,
        p.product_name
) AS ranked_products
WHERE rank <= 3
ORDER BY city_name, rank;
-------------7.Customer Segmentation by City------------
select c.city_name,
       count(distinct cu.customer_id) as unique_customers
FROM city c
JOIN customers cu
ON c.city_id = cu.city_id
JOIN sales s
ON cu.customer_id = s.customer_id
group by city_name
order by 2 desc;
------------8.Impact of Estimated Rent on Sales---------
SELECT
    c.city_name,
	round(avg(s.total)::numeric,2) as average_sales_per_customer,
	round((c.estimated_rent)/ count(distinct cu.customer_id)::numeric,2) as average_rent_per_customer
FROM city c
JOIN customers cu
ON c.city_id = cu.city_id
JOIN sales s
ON cu.customer_id = s.customer_id
GROUP BY c.city_name,c.estimated_rent
ORDER BY average_sales_per_customer DESC; 

--------------9.monthly sales growth---------

WITH monthly_sales AS
(SELECT ci.city_name,
        EXTRACT(YEAR FROM s.sale_date)  AS sale_year,
        EXTRACT(MONTH FROM s.sale_date) AS sale_month,
        SUM(s.total) AS total_sale
    FROM sales s
    JOIN customers c ON s.customer_id = c.customer_id
    JOIN city ci ON c.city_id = ci.city_id
    GROUP BY ci.city_name, sale_year, sale_month),
growth AS (SELECT city_name, sale_year, sale_month, total_sale,
            LAG(total_sale) OVER (PARTITION BY city_name
            ORDER BY sale_year, sale_month) AS prev_month_sale
            FROM monthly_sales)
SELECT city_name, sale_year, sale_month, total_sale, prev_month_sale,
ROUND((total_sale - prev_month_sale)::numeric/ NULLIF(prev_month_sale, 0) * 100, 2) AS growth_pct
FROM growth
ORDER BY city_name, sale_year, sale_month;


------10. Market Potential Analysis --------
WITH city_metrics AS
        (SELECT ci.city_name,
        SUM(s.total) AS total_sale,
        ci.estimated_rent AS total_rent,
        COUNT(DISTINCT s.customer_id) AS total_customers,
        ROUND((ci.population * 0.25)/1000000.0,2) || 'M' AS estimated_coffee_consumers
        FROM sales s
   JOIN customers c ON s.customer_id = c.customer_id
   JOIN city ci ON c.city_id = ci.city_id
        GROUP BY ci.city_name, ci.estimated_rent, ci.population)
SELECT city_name,
    ROUND(total_sale/1000000.0, 2) || 'M' AS total_sale,
    ROUND(total_rent/1000.0, 2) || 'K' AS total_rent,
total_customers, estimated_coffee_consumers
FROM city_metrics
ORDER BY total_sale DESC
LIMIT 3;