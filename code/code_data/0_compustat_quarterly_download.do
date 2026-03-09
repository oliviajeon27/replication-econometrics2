******************************************************************************
******************************************************************************
** This file creates Compustat Quarterly Panel: Bank vs. Nonbank Lending
** in "Nonbank Lending and Credit Cyclicality" by Fleckenstein et. al. (2024)
******************************************************************************
******************************************************************************

set more off
clear all
set scheme s1color

global output `"$package\results"'
global data `"$package\data"'
global code `"$package\code"'
global figures `"$package\figures"'
global code `"$package\tables"'

capture log close
log using "$package/logs/prep_compustat_quarterly.log", replace

******************************************************************************

clear all 
odbc load, exec("select gvkey, CONM, datadate, CEQQ, ATQ, PRCCQ, CSHOQ from comp.fundq where consol='C' and popsrc='D' and indfmt='INDL' and datafmt='STD' and datadate >= '1999-01-01'") dsn("wrds-pgdata-64")
destring gvkey, replace

* drop duplicates *
duplicates drop 

* merge in Schwert Dealscan-Compustat link file for banks *
preserve
	import excel "$data\Raw Data\website_schwert\Dealscan_Lender_Link_Jefferiesupdated.xlsx", sheet("Compustat") clear firstrow
	keep gvkey lender
	bysort gvkey: keep if _n == 1
	count
	
	tempfile schwert_link
	save	`schwert_link'
restore

merge m:1 gvkey using `schwert_link', nogen keep(3)


*Generate market cap 
generate marketcap = (prccq * cshoq)

*Generate the market equity ratio according to Schwert
generate market_eq_ratio = marketcap / (atq - ceqq + marketcap)

* save data *
compress
save "$data\Intermediate Data\Combined_Compustat_Quarterly.dta", replace


log close


