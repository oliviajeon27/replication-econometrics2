******************************************************************************
******************************************************************************
** This file creates Fig 4 - Bank-Nonbank Matching: Bank vs. Nonbank Lending
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
global tables `"$package\tables"'
capture log close
log using "$package/logs/figures4.log", replace


******************************************************************************

*TO TBE DELETED
//cd "C:\Users\shillenbrand\Dropbox (Harvard University)\2_Nonbank lending and credit cyclicality\0_NEW FOLDER\0_Data\6.GFC"
//use "$data\Final Data\GFC_data.dta", clear

use "$data/final data/GFC_data.dta", clear

keep lenchg_tot_no nb_dep_no

*Scatter plot lending change vs. nonbank dependence
twoway (scatter lenchg_tot_no nb_dep_no, xlabel(0(0.2)1) ///
	ytitle("Lending change during GFC") xtitle("Nonbank dependence (pre-crisis)") ) || ///
	(lfit lenchg_tot_no nb_dep_no), ///
	legend(off)
graph export "$figures/figure4.pdf", replace

log close
