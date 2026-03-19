******************************************************************************
******************************************************************************
** This file creates Compustat Annual Panel: Bank vs. Nonbank Lending
** in "Nonbank Lending and Credit Cyclicality" by Fleckenstein et. al. (2024)
******************************************************************************
******************************************************************************

set more off
clear all
set scheme s1color

global package "C:\Users\Eunkyung\ASU Dropbox\Eunkyung Jeon\2026-1\econometrics\12. replicate\nonbank lending and credit cyclicality"
global project "$package"

global output `"$package\results"' //change from output to result
global data `"$package\data"'
global code `"$package\code"'
global figures `"$package\figures"'
global tables `"$package\tables"'  //typo

capture log close
log using "$package/logs/prep_compustat_annual.log", replace

******************************************************************************

clear all 
odbc load, exec("select gvkey, CONM, datadate, fyear, CEQ, AT, PRCC_C, csho, CURNCD from comp.funda where consol='C' and popsrc='D' and indfmt='INDL' and datafmt='STD' and datadate >= '1999-01-01'") dsn("wrds-pgdata-64")
destring gvkey, replace

*List of all gvkeys
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
generate marketcap = (prcc_c * csho)

*Generate the market equity ratio according to Schwert
generate market_eq_ratio = marketcap / (at - ceq + marketcap)

compress
save "$data\Intermediate Data\Combined_Compustat_Annual.dta", replace






