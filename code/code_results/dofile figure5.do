******************************************************************************
******************************************************************************
** This file creates Fig 5 - Cyclicality of Originations: Bank vs. Nonbank Lending
** in "Nonbank Lending and Credit Cyclicality" by Fleckenstein et. al. (2024)
******************************************************************************
******************************************************************************

set more off
clear all
set scheme s1color

global data `"$package\data"'
global code `"$package\code"'
global figures `"$package\figures"'
global tables `"$package\tables"'
capture log close
log using "$package/logs/figure5.log", replace


******************************************************************************

********************************************
*** Panel A: All loans
********************************************

use "$data\Final Data\main_facility_dataset", clear
bys facilityid: keep if _n == 1

* define
g nbamt = facilityamt*(instTL) 
collapse (sum) nbamt facilityamt , by(mdate)

drop if mdate==. 
tset mdate
tsfill, full
g bamt = facilityamt-nbamt

foreach X in facilityamt bamt nbamt   {
g log`X' = log(1 + `X')
tssmooth ma log`X'_ma = log`X', w(0 1 5)
}

drop if facilityamt == . 
sort mdate

*Figure 1, Panel A: Originations. Panel A: All loans
keep if mdate >= ym(2000,1)
line logbamt_ma lognbamt_ma mdate, lcolor(black red) lp(s dash) yti("Log(Amount of Originations) (M)") leg(order(1 "Bank" 2 "Nonbank"))  xti("") graphregion(color(white)) //ylabel(0(4)12)
graph export "$figures/figure5a.pdf", replace


 
********************************************
*** Panel B: Real investment loans
********************************************

use "$data\Final Data\main_facility_dataset", clear
bys facilityid: keep if _n == 1
keep if inv 

* define
g nbamt = facilityamt*instTL
collapse (sum) nbamt facilityamt , by(mdate)
tset mdate
tsfill, full
g bamt = facilityamt-nbamt

foreach X in facilityamt bamt nbamt {
replace `X' = . if `X' == 0
egen min`X' = min(`X')
replace `X' = min`X' if `X' == .
g log`X' = log(1 + `X')
tssmooth ma log`X'_ma = log`X', w(0 1 5)
}

drop if facilityamt == . 
sort mdate

*Figure 1, Panel B: Originations
keep if mdate >= ym(2000,1)
line logbamt_ma lognbamt_ma mdate, lcolor(black red) lp(s dash) yti("Log(Amount of Originations) (M)") leg(order(1 "Bank" 2 "Nonbank"))  xti("") graphregion(color(white))
graph export "$figures/figure5b.pdf", replace

log close 

