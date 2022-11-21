-- Project SQL

-- příprava tabulek:

CREATE OR REPLACE TABLE t_lucie_swiatkova_project_SQL_primary
SELECT 
	cpib.name as industry_name, cp.payroll_year, round(avg(cp.value)) as avg_salary_current_year, round(avg(cp2.value)) as avg_salary_prev_year,
	round((avg(cp.value) - avg(cp2.value))/avg(cp2.value) *100, 2) as salary_change,
	CASE 
		WHEN round((avg(cp.value) - avg(cp2.value))/avg(cp2.value) *100, 2) <0 THEN 'decrease'
		ELSE 'increase'
	END as yoy_salary_change
FROM czechia_payroll cp
JOIN czechia_payroll cp2
		ON cp.industry_branch_code = cp2.industry_branch_code 
		AND cp.payroll_year = cp2.payroll_year + 1 
JOIN czechia_payroll_industry_branch cpib ON cpib.code = cp.industry_branch_code
WHERE cp.value_type_code = 5958 AND cp2.value_type_code = 5958
GROUP BY cpib.name, cp.payroll_year 
ORDER BY cp.payroll_year;



CREATE OR REPLACE VIEW v_pomocny as
SELECT cpc.name ,round(avg(cp.value),2) as avg_price, YEAR (date_from) as year
FROM czechia_price cp
JOIN czechia_price_category cpc on cp.category_code = cpc.code 
GROUP by cpc.name, year;

CREATE or REPLACE TABLE t_lucie_swiatkova_project_sql_primary_2
SELECT *
FROM v_pomocny vp
JOIN t_lucie_swiatkova_project_sql_primary pf on vp.year= pf.payroll_year  ;

ALTER TABLE t_lucie_swiatkova_project_sql_primary_2 DROP COLUMN year ; 

DROP TABLE t_lucie_swiatkova_project_sql_primary ;

CREATE OR REPLACE TABLE  t_yoy_change_of_prices_2 as 
SELECT t1.name as goods, t1.avg_price as avg_price_of_goods,t1.payroll_year as current_year, t2.avg_price as previous_year_price,  round((t1.avg_price- t2.avg_price) / t2.avg_price * 100, 2)  as yoy_price_change
FROM t_lucie_swiatkova_project_sql_primary_2 t1
JOIN t_lucie_swiatkova_project_sql_primary_2 t2 
	ON t1.name = t2.name 
	AND t1.payroll_year = t2.payroll_year +1
GROUP BY t1.name, t1.payroll_year
ORDER BY t1.name, t1.payroll_year ;


CREATE OR REPLACE TABLE t_lucie_swiatkova_project_sql_primary_final
SELECT *
FROM t_yoy_change_of_prices_2 tch
JOIN t_lucie_swiatkova_project_sql_primary_2  pf 
	ON tch.goods = pf.name
	AND tch.current_year = pf.payroll_year  ; 

DROP TABLE t_lucie_swiatkova_project_sql_primary_2 ;

DROP TABLE t_yoy_change_of_prices_2; 

DROP VIEW v_pomocny ;

ALTER TABLE t_lucie_swiatkova_project_sql_primary_final DROP COLUMN IF EXISTS name ;

ALTER TABLE t_lucie_swiatkova_project_sql_primary_final DROP COLUMN IF EXISTS avg_price ;

ALTER TABLE t_lucie_swiatkova_project_sql_primary_final DROP COLUMN IF EXISTS payroll_year  ;

CREATE OR REPLACE TABLE t_lucie_swiatkova_project_SQL_secondary_final
SELECT e.country, e.year, e.GDP, e.population , e.gini , e.taxes, e.fertility, e.mortaliy_under5,
	round((e.GDP - e2.GDP)/e2.GDP *100,2) as yoy_gdp_change
FROM economies e
JOIN economies e2 ON e.country = e2.country
				AND e.year = e2.year + 1
LEFT JOIN countries c on e.country = c.country;



-- Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají? odpověď zde

SELECT industry_name , current_year, salary_change ,avg_salary_current_year, avg_salary_prev_year 
FROM t_lucie_swiatkova_project_sql_primary_final
WHERE yoy_salary_change = 'decrease'
GROUP by industry_name 
ORDER by industry_name , current_year;



-- Kolik je možné si koupit litrů mléka a kilogramů chleba za první a poslední srovnatelné období v dostupných datech cen a mezd?

-- Množství za každé jednotlivé odvětví
SELECT current_year, industry_name , goods, round(avg_salary_current_year/avg_price_of_goods,0) as amount_of_goods
FROM t_lucie_swiatkova_project_sql_primary_final
WHERE goods IN ('Chléb konzumní kmínový','Mléko polotučné pasterované') 
	AND current_year IN ('2007', '2018') 
GROUP by goods, current_year, industry_name
ORDER BY current_year, goods, industry_name ; 


-- Průměr mzdy za všechna odvětví
SELECT current_year, goods, round(avg_salary_current_year/avg_price_of_goods ,0) as amount_of_goods
FROM t_lucie_swiatkova_project_sql_primary_final
WHERE goods IN ('Chléb konzumní kmínový','Mléko polotučné pasterované') 
	AND current_year IN ('2007', '2018') 
GROUP BY goods, current_year
ORDER BY current_year, goods; 


-- Která kategorie potravin zdražuje nejpomaleji (je u ní nejnižší percentuální meziroční nárůst)?

SELECT goods, current_year , yoy_price_change
FROM t_lucie_swiatkova_project_sql_primary_final 
GROUP BY goods, current_year
ORDER BY current_year , yoy_price_change ;


SELECT current_year , min(yoy_price_change)
FROM t_lucie_swiatkova_project_sql_primary_final
GROUP BY current_year
ORDER BY current_year , yoy_price_change ;



-- Existuje rok, ve kterém byl meziroční nárůst cen potravin výrazně vyšší než růst mezd (větší než 10 %)?

SELECT current_year, round(avg(yoy_price_change),2) as average_price_change, salary_change, 
CASE 
	WHEN (avg(yoy_price_change) - salary_change) > 10 THEN 'increased_of_prices>10%'
	WHEN (avg(yoy_price_change) - salary_change) < 10 AND (avg(yoy_price_change) - salary_change) > 0  THEN 'increased_of_prices<10%'
	ELSE 'salary_increase>prices_increase'
END as prices_vs_salary
FROM t_lucie_swiatkova_project_sql_primary_final
GROUP BY current_year ;

-- Má výška HDP vliv na změny ve mzdách a cenách potravin? Neboli, pokud HDP vzroste výrazněji v jednom roce, projeví se to na cenách potravin či mzdách ve stejném nebo násdujícím roce výraznějším růstem?


SELECT t2.country, t1.current_year, t2.yoy_gdp_change, round(avg(t1.yoy_price_change),2) as avg_yoy_salary_change, t1.salary_change  
FROM t_lucie_swiatkova_project_SQL_secondary_final t2
JOIN t_lucie_swiatkova_project_sql_primary_final t1 ON t2.year = t1.current_year 
WHERE t2.country = 'Czech Republic'
GROUP BY year
ORDER BY year DESC ;
