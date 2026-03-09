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
log using "$package/logs/prep_compustat_annual_firm.log", replace

******************************************************************************

clear all
odbc load, exec("select gvkey, fyear, datadate, indfmt, consol, popsrc, datafmt, at, emp from comp.funda where consol='C' and popsrc='D' and indfmt='INDL' and datafmt='STD' ") dsn("wrds-pgdata-64")


compress
save "$data/Raw Data/compustat/funda.dta", replace

log close
