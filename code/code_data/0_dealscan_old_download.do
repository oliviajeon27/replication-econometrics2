

******************************************************************************
******************************************************************************
** This file creates Compustat Annual Panel: Bank vs. Nonbank Lending
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
log using "$package/logs/prep_dealscan_old.log", replace

******************************************************************************

* Company
clear all
odbc load, exec("select * from tr_dealscan.company") dsn("wrds-pgdata-64")
rename *, lower
compress
save "$data/Raw Data/dealscan_old/company.dta", replace

* Facility
clear all
odbc load, exec("select * from tr_dealscan.facility") dsn("wrds-pgdata-64")
rename *, lower
compress
save "$data/Raw Data/dealscan_old/facility.dta", replace

* Pricing
clear all
odbc load, exec("select * from tr_dealscan.currfacpricing") dsn("wrds-pgdata-64")
rename *, lower
compress
save "$data/Raw Data/dealscan_old/pricing.dta", replace

* Lender shares
clear all
odbc load, exec("select * from tr_dealscan.LenderShares") dsn("wrds-pgdata-64")
rename *, lower
compress
save "$data/Raw Data/dealscan_old/lenders.dta", replace

* Package
clear all
odbc load, exec("select * from tr_dealscan.package") dsn("wrds-pgdata-64")
rename *, lower
compress
save "$data/Raw Data/dealscan_old/package.dta", replace

