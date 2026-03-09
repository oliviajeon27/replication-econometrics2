******************************************************************************
******************************************************************************
** This file creates Fig 2 - Composition of Nonbank Lenders: Bank vs. Nonbank Lending
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
log using "$package/logs/figures2.log", replace


******************************************************************************
use 	"$data\Final Data\nonbank_lender_composition.dta", clear


drop if missing(aum_mutualfunds)
generate other = 1 
replace other = clo_funds_nonbank if clo_funds_nonbank>1
keep	if year>=2000

twoway ///
(area clo_nonbank year) || ///
(rarea clo_nonbank clo_funds_nonbank year) || ///
(rarea clo_funds_nonbank other year), ///
ylabel(0(0.2)1) graphregion(color(white)) ///
ytitle("Share of nonbanks") ///
xtitle("") ///
legend(order(1 "CLOs" 2 "Mutual funds sector" 3 "Other"))
graph export "$figures/figure2.pdf", replace

log close  