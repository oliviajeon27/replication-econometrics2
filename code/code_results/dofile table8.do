******************************************************************************
******************************************************************************
** This file creates Table 8 - Cyclicality of Lead Banks, Non-lead Banks, and Nonbanks
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
log using "$package/logs/table8.log", replace


*******************************************************************************
*** Lead vs. non-lead banks
*******************************************************************************

use "$data\Final Data\main_facility_dataset_deallead.dta", clear

keep if year>=2000 

gen leadamt = allocamt * lead_deal  * (1-instTL)
gen participantamt = allocamt * (1-lead_deal) * (1-instTL)
gen nonbankamt = allocamt * instTL

gen  month = month(facilitystartdate) 
gen n=1

// calculate weighted spread 
gen spread_amt = facilityamt* allindrawn
bys borrowercompanyid packageid instTL: egen tot_fac = sum(facilityamt) 
bys borrowercompanyid packageid instTL: egen tot_spread_amt = sum(spread_amt)
gen weighted_spread = tot_spread_amt/ tot_fac 

gen year_month =ym(year, month) 
bys packageid: egen min= min(year_month)

replace year_month = min 

collapse (sum) leadamt participantamt nonbankamt (first) year_month, by(borrowercompanyid packageid) 

gen ym = year_month 
format year_month %tm

merge m:1 ym using "$data\Final Data\monthly_credit_cycles_measures_standardized.dta", keep(3) nogen 

label var lag_eb_premium "Excess Bond Premium"

rename leadamt amt1
rename participantamt amt2
rename nonbankamt amt3 

reshape long amt, i(borrowercompanyid packageid) j(type, string)
replace type ="Lead Bank" if type =="1"
replace type ="Participant Bank" if type =="2"
replace type = "Nonbank" if type =="3" 

encode type, gen(type_code) 

gen log_amt = log(amt)


eststo clear
eststo s1: reghdfe log_amt lag_eb_premium c.lag_eb_premium#ib3.type_code, abs(borrowercompanyid type_code) cluster(borrowercompanyid year_month) 
estadd local borrower "Y"
estadd local time "N": s1
estadd local borrower_time "N": s1
estadd local lender_type "Y": s1
sum		year_month if e(sample)

eststo s2: reghdfe log_amt lag_eb_premium c.lag_eb_premium#ib3.type_code, abs(year_month borrowercompanyid type_code) cluster(borrowercompanyid year_month) 
estadd local borrower "Y"
estadd local time "Y": s2
estadd local borrower_time "N": s2
estadd local lender_type "Y": s2
sum		year_month if e(sample)

eststo s3: reghdfe log_amt lag_eb_premium c.lag_eb_premium#ib3.type_code, abs(packageid type_code) cluster(borrowercompanyid year_month) 
estadd local borrower "N"
estadd local time "N": s3
estadd local borrower_time "Y": s3
estadd local lender_type "Y": s3
sum		year_month if e(sample)



esttab  s1 s2 s3  using "$tables/table8.tex", tex  mgroup("Log(Facility Amount)", pattern(1 0 0 ) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) nomtitle varwidth(40) b(%8.3f) se(%8.3f) sfmt(%s %s %s %s %12.0fc  %8.3f) noomitted   noomitted noobs scalars("borrower Borrower FE" "time Year-Month FE" "borrower_time Deal FE" "lender_type Lender-Role FE" "N Obs." "r2 \$R^2\$") msign($-$) replace nonotes  starlevels(* 0.10 ** 0.05 *** 0.01) wrap label  substitute(\hline \toprule)  keep(lag_eb_premium *type_code*#c.lag_eb_premium) 


log close 