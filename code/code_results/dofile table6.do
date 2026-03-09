******************************************************************************
******************************************************************************
** This file creates Table 6
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
log using "$package/logs/table6.log", replace

******************************************************************************
use "$data\Final Data\main_facility_dataset.dta", clear

keep if year>=2000 

* bring to facility level *
duplicates drop borrowercompanyid packageid facilityid, force 

* adjust date *
gen  month = month(facilitystartdate) 
gen year_month =ym(year, month) 
bys packageid: egen min= min(year_month)
replace year_month = min 

* calculate weighted spread *
preserve
	collapse (mean) allindrawn  [aweight=facilityamt], by(borrowercompanyid packageid instTL) 
	tempfile allindrawn
	save	`allindrawn'
restore

* collapse to deal x loantype level *
collapse (sum) facilityamt (first) year_month, by(borrowercompanyid packageid instTL) 

* merge in weighted spread *
merge 1:1 borrowercompanyid packageid instTL using `allindrawn', nogen
rename allindrawn weighted_spread

* merge in cycle variables *
gen ym = year_month 
format year_month %tm
merge m:1 ym using "$data\Final Data\monthly_credit_cycles_measures_standardized.dta", keep(3) nogen 

* create additional variables *
foreach var of varlist  lag_* {
	gen `var'_termb = 	`var'* instTL
}
gen log_amt = log(facilityamt)

* label variables *
label var instTL "Term B"
label var lag_eb_premium "Excess Bond Premium"
label var lag_eb_premium_termb "Excess Bond Premium x Term B"

* Volume *
eststo clear
eststo volume1: reghdfe log_amt lag_eb_premium instTL  , abs(borrowercompanyid) cluster(borrowercompanyid year_month) 
estadd local borrower "Y"
estadd local time "N":volume1
estadd local borrower_time "N":volume1
estadd local borrower_tlb "N":volume1
estadd local matcontrols "N":volume1

eststo volume2: reghdfe log_amt lag_eb_premium lag_eb_premium_termb instTL  , abs(borrowercompanyid) cluster(borrowercompanyid year_month) 
estadd local borrower "Y"
estadd local time "N":volume2
estadd local borrower_time "N":volume2
estadd local borrower_tlb "N":volume2
estadd local matcontrols "N":volume2

eststo volume3: reghdfe log_amt lag_eb_premium_termb instTL , abs(borrowercompanyid year_month) cluster(borrowercompanyid year_month) 
estadd local borrower "Y"
estadd local time "Y":volume3
estadd local borrower_time "N":volume3
estadd local borrower_tlb "N":volume3
estadd local matcontrols "N":volume3

eststo volume4: reghdfe log_amt lag_eb_premium_termb instTL , abs(packageid) cluster(borrowercompanyid year_month) 
estadd local borrower "N"
estadd local time "N":volume4
estadd local borrower_time "Y":volume4
estadd local borrower_tlb "N":volume4
estadd local matcontrols "N":volume4

eststo volume5: reghdfe log_amt lag_eb_premium_termb, abs(borrowercompanyid#packageid  i.borrowercompanyid#i.instTL) cluster(borrowercompanyid year_month) 
estadd local borrower "N"
estadd local time "N":volume5
estadd local borrower_time "Y":volume5
estadd local borrower_tlb "Y":volume5
estadd local matcontrols "N":volume5

esttab volume* using "$tables/table6a.tex", tex mgroup("Log(Facility Amount)" , pattern(1 0 0 0 0 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) nomtitle varwidth(40) b(%8.3f) se(%8.3f) sfmt(%s %s %s %s  %12.0fc  %8.3f) noomitted  drop(_cons ) noomitted noobs scalars("borrower Borrower FE" "time Year-Month FE" "borrower_time Deal FE" "borrower_tlb Borrower x Facility-Type FE"  "N Obs." "r2 \$R^2\$") msign($-$) replace nonotes  starlevels(* 0.10 ** 0.05 *** 0.01) wrap label substitute(\hline \toprule)

* Spread *
eststo clear
eststo spread1: reghdfe weighted_spread lag_eb_premium instTL, abs(borrowercompanyid) cluster(borrowercompanyid year_month) 
estadd local borrower "Y"
estadd local time "N":spread1
estadd local borrower_time "N":spread1
estadd local borrower_tlb "N":spread1
estadd local matcontrols "N":spread1
estadd local relcontrols "N":spread1

eststo spread2: reghdfe weighted_spread lag_eb_premium lag_eb_premium_termb instTL, abs(borrowercompanyid) cluster(borrowercompanyid year_month) 
estadd local borrower "Y"
estadd local time "N":spread2
estadd local borrower_time "N":spread2
estadd local borrower_tlb "N":spread2
estadd local matcontrols "N":spread2
estadd local relcontrols "N":spread2

eststo spread3: reghdfe weighted_spread lag_eb_premium_termb instTL, abs(borrowercompanyid year_month) cluster(borrowercompanyid year_month) 
estadd local borrower "Y"
estadd local time "Y":spread3
estadd local borrower_time "N":spread3
estadd local borrower_tlb "N":spread3
estadd local matcontrols "N":spread3
estadd local relcontrols "N":spread3

eststo spread4: reghdfe weighted_spread lag_eb_premium_termb instTL, abs(borrowercompanyid#packageid) cluster(borrowercompanyid year_month) 
estadd local borrower "N"
estadd local time "N":spread4
estadd local borrower_time "Y":spread4
estadd local borrower_tlb "N":spread4
estadd local matcontrols "N":spread4
estadd local relcontrols "N":spread4

eststo spread5: reghdfe weighted_spread lag_eb_premium_termb , abs(borrowercompanyid#packageid i.borrowercompanyid#i.instTL) cluster(borrowercompanyid year_month) 
estadd local borrower "N"
estadd local time "N":spread5
estadd local borrower_time "Y":spread5
estadd local borrower_tlb "Y":spread5
estadd local matcontrols "Y":spread5
estadd local relcontrols "Y":spread5

esttab  spread* using "$tables/table6b.tex", tex  mgroup( "All-in-drawn Spread", pattern(1 0 0 0 0 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) nomtitle varwidth(40) b(%8.3f) se(%8.3f) sfmt(%s %s %s %s %12.0fc  %8.3f) noomitted  drop(_cons ) noomitted noobs scalars("borrower Borrower FE" "time Year-Month FE" "borrower_time Deal FE" "borrower_tlb Borrower x Facility-Type FE" "N Obs." "r2 \$R^2\$") msign($-$) replace nonotes  starlevels(* 0.10 ** 0.05 *** 0.01) wrap label  substitute(\hline \toprule) 

log close  