******************************************************************************
******************************************************************************
** This file creates Table 5
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
log using "$package/logs/table5.log", replace

******************************************************************************
use "$data\Final Data\main_facility_dataset.dta", clear

keep if year>=2000 

duplicates drop borrowercompanyid packageid facilityid, force 

//Year-month variable
gen  month = month(facilitystartdate) 
gen year_month =ym(year, month) 
gen ym = year_month 
format year_month %tm


* keep neccessary variables *
keep ym allindrawn facilityamt instTL year_month 



*Compute the monthly (a) average allindrawn-spread and the (b) sum of facility amounts for bank vs nonbank loans
//b) average allindrawn-spread
preserve 
	collapse (mean) allindrawn  [weight=facilityamt] , by(instTL year_month)
	tempfile allindrawn
	save	`allindrawn'
restore

//c) loan amounts
collapse (first) ym (sum) facilityamt , by(instTL year_month)

merge 1:1 instTL year_month using `allindrawn', nogen


//Credit cycle variables
merge m:1 ym using "$data\Final Data\monthly_credit_cycles_measures_standardized.dta", keep(3) nogen 

//Multiply the cycle variables with the TLB-indicator
foreach var of varlist  lag_* {
	gen `var'_termb = 	`var'* instTL
}

//Compute the log of the facility_amt
gen log_amt = log(facilityamt)

// label variables
label var instTL "Term B"
label var lag_eb_premium "Excess Bond Premium"
label var lag_eb_premium_termb "Excess Bond Premium x Term B"
label var instTL "Term B"

* Amount *
eststo p4: reghdfe log_amt lag_eb_premium instTL, noabsorb vce(robust)
estadd local ym "N"
eststo p5: reghdfe log_amt lag_eb_premium lag_eb_premium_termb instTL, noabsorb vce(robust)
estadd local ym "N"
eststo p6: reghdfe log_amt lag_eb_premium_termb instTL 	, abs(year_month) vce(robust)
estadd local ym "Y"

* Spread *
eststo p7: reghdfe allindrawn lag_eb_premium instTL, noabsorb vce(robust)
estadd local ym "N"
eststo p8: reghdfe allindrawn lag_eb_premium lag_eb_premium_termb instTL, noabsorb vce(robust)
estadd local ym "N"
eststo p9: reghdfe allindrawn lag_eb_premium_termb instTL , abs(year_month) vce(robust)
estadd local ym "Y"

esttab p4 p5 p6 using "$tables/table5a.tex", tex mgroup("Log(Facility Amount)" , pattern(1 0 0  ) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) nomtitle  varwidth(30) b(%8.3f) se(%8.3f) sfmt(%12.0fc %12.0fc %8.3f) drop(_cons) noobs scalars("ym Year-Month FE" "N Obs." "r2 \$R^2\$") msign($-$) replace nonotes  starlevels(* 0.10 ** 0.05 *** 0.01) wrap label  substitute(\hline \toprule)

esttab p7 p8 p9  using "$tables/table5b.tex", tex mgroup("All-in-drawn Spread" , pattern(1 0 0  ) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) nomtitle  varwidth(30) b(%8.3f) se(%8.3f) sfmt(%12.0fc %12.0fc %8.3f) drop(_cons) noobs scalars("ym Year-Month FE" "N Obs." "r2 \$R^2\$") msign($-$) replace nonotes  starlevels(* 0.10 ** 0.05 *** 0.01) wrap label  substitute(\hline \toprule)

log close  