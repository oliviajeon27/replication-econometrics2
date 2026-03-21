******************************************************************************
******************************************************************************
** This file creates CLO Capital Structure File: Bank vs. Nonbank Lending
** in "Nonbank Lending and Credit Cyclicality" by Fleckenstein et. al. (2024)
******************************************************************************
******************************************************************************

set more off
clear all
set scheme s1color


global output `"$package\results"' //change from output to result
global data `"$package\data"'
global code `"$package\code"'
global figures `"$package\figures"'
global tables `"$package\tables"'  //typo

capture log close
log using "$package/logs/prep_clo_capital_structure.log", replace

******************************************************************************


use		"$data\Raw Data\creditflux\tranches.dta", clear

* restrict sample and variables *
keep	if dealtype=="US CLO"
keep	clo_id reportmonth reportdate  closingdate pricingdate clo_value_org equity_ratio_org 

* keep only last report per month *
bys		clo_id reportmonth (reportdate): keep if reportdate==reportdate[_N]

* keep first report month *
bys		clo_id (reportmonth): keep if reportmonth==reportmonth[1]

* adjust origination date *
gen 	origination_date = pricingdate
replace	origination_date = closingdate if pricingdate==.

keep	clo_id origination_date clo_value_org equity_ratio_org 
duplicates drop


save	"$data\Intermediate Data\CLO_capitalstructure_spreads_primarymarket.dta", replace
