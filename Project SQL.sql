-- Project SQL

-- příprava tabulek:

create or replace table t_lucie_swiatkova_project_SQL_primary
SELECT 
	cpib.name as industry_name, cp.payroll_year, round(avg(cp.value)) as avg_salary_current_year, round(avg(cp2.value)) as avg_salary_prev_year,
	round((avg(cp.value) - avg(cp2.value))/avg(cp2.value) *100, 2) as salary_change,
	CASE 
		when round((avg(cp.value) - avg(cp2.value))/avg(cp2.value) *100, 2) <0 then 'decrease'
		ELSE 'increase'
	END as yoy_salary_change
FROM czechia_payroll cp
JOIN czechia_payroll cp2
		ON cp.industry_branch_code = cp2.industry_branch_code 
		and cp.payroll_year = cp2.payroll_year + 1 
JOIN czechia_payroll_industry_branch cpib ON cpib.code = cp.industry_branch_code
WHERE cp.value_type_code = 5958 and cp2.value_type_code = 5958
group by cpib.name, cp.payroll_year 
ORDER by cp.payroll_year;



CREATE or replace view v_pomocny as
SELECT cpc.name ,round(avg(cp.value),2) as avg_price, YEAR (date_from) as year
FROM czechia_price cp
join czechia_price_category cpc on cp.category_code = cpc.code 
GROUP by cpc.name, year;

CREATE or REPLACE TABLE t_lucie_swiatkova_project_sql_primary_2
SELECT *
from v_pomocny vp
join t_lucie_swiatkova_project_sql_primary pf on vp.year= pf.payroll_year  ;

alter table t_lucie_swiatkova_project_sql_primary_2 drop column year ; 

DROP table t_lucie_swiatkova_project_sql_primary ;

CREATE or REPLACE table t_yoy_change_of_prices_2 as 
select t1.name as goods, t1.avg_price as avg_price_of_goods,t1.payroll_year as current_year, t2.avg_price as previous_year_price,  round((t1.avg_price- t2.avg_price) / t2.avg_price * 100, 2)  as yoy_price_change
from t_lucie_swiatkova_project_sql_primary_2 t1
join t_lucie_swiatkova_project_sql_primary_2 t2 
	on t1.name = t2.name 
	and t1.payroll_year = t2.payroll_year +1
GROUP by t1.name, t1.payroll_year
order by t1.name, t1.payroll_year ;


CREATE or REPLACE TABLE t_lucie_swiatkova_project_sql_primary_final
SELECT *
from t_yoy_change_of_prices_2 tch
join t_lucie_swiatkova_project_sql_primary_2  pf 
	on tch.goods = pf.name
	and tch.current_year = pf.payroll_year  ; 

drop table t_lucie_swiatkova_project_sql_primary_2 ;


CREATE or REPLACE table t_lucie_swiatkova_project_SQL_secondary_final
SELECT e.country, e.year, e.GDP, e.population , e.gini , e.taxes, e.fertility, e.mortaliy_under5,
	round((e.GDP - e2.GDP)/e2.GDP *100,2) as yoy_gdp_change
from economies e
join economies e2 on e.country = e2.country
				and e.year = e2.year + 1
left join countries c on e.country = c.country;



-- Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají? odpověď zde

SELECT industry_name , payroll_year, salary_change ,avg_salary_current_year, avg_salary_prev_year 
FROM t_lucie_swiatkova_project_sql_primary_final
WHERE yoy_salary_change = 'decrease'
GROUP by industry_name 
ORDER by industry_name , payroll_year ;



-- Kolik je možné si koupit litrů mléka a kilogramů chleba za první a poslední srovnatelné období v dostupných datech cen a mezd?

-- v případě, že chceme vidět kolik množství se může koupit každé jednotlivé odvětví
SELECT payroll_year,industry_name , name , round(avg_salary_current_year/avg_price,0) as amount_of_goods
from t_lucie_swiatkova_project_sql_primary_final
where name in ('Chléb konzumní kmínový','Mléko polotučné pasterované') 
	and payroll_year in ('2007', '2018') 
GROUP by name, payroll_year, industry_name
order by payroll_year, name, industry_name ; 


-- v případě průměrné mzdy za všechna odvětví --> kupní síla roste
SELECT payroll_year, name , round(avg_salary_current_year/avg_price,0) as amount_of_goods
from t_lucie_swiatkova_project_sql_primary_final
where name in ('Chléb konzumní kmínový','Mléko polotučné pasterované') 
	and payroll_year in ('2007', '2018') 
GROUP by name, payroll_year
order by payroll_year, name ; 


-- Která kategorie potravin zdražuje nejpomaleji (je u ní nejnižší percentuální meziroční nárůst)?
-- nedokážu z toho vytáhnout nejnižší nárůst v daném roce pro jednu potravinu

SELECT goods, current_year , yoy_price_change
from t_lucie_swiatkova_project_sql_primary_final 
group by goods, current_year
ORDER by current_year , yoy_price_change ;

SELECT current_year , min(yoy_price_change)
from t_lucie_swiatkova_project_sql_primary_final
group by current_year
ORDER by current_year , yoy_price_change ;


-- Existuje rok, ve kterém byl meziroční nárůst cen potravin výrazně vyšší než růst mezd (větší než 10 %)?

SELECT current_year, round(avg(yoy_price_change),2) as average_price_change, salary_change, 
CASE 
	when (avg(yoy_price_change) - salary_change) > 10 then 'increased_of_prices>10%'
	WHEN (avg(yoy_price_change) - salary_change) < 10 and (avg(yoy_price_change) - salary_change) > 0  then 'increased_of_prices<10%'
	else 'salary_increase>prices_increase'
END as prices_vs_salary
from t_lucie_swiatkova_project_sql_primary_final
group by current_year ;

-- Má výška HDP vliv na změny ve mzdách a cenách potravin? Neboli, pokud HDP vzroste výrazněji v jednom roce, projeví se to na cenách potravin či mzdách ve stejném nebo násdujícím roce výraznějším růstem?


SELECT t2.country, t1.current_year, t2.yoy_gdp_change, round(avg(t1.yoy_price_change),2) as avg_yoy_salary_change, t1.salary_change  
from t_lucie_swiatkova_project_SQL_secondary_final t2
join t_lucie_swiatkova_project_sql_primary_final t1 on t2.year = t1.current_year 
where t2.country = 'Czech Republic'
group by year
ORDER by year DESC ;
