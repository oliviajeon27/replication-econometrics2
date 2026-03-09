******************************************************************************
******************************************************************************
** This file creates Table 7
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
log using "$package/logs/table7.log", replace

******************************************************************************
use "$data\Final Data\main_facility_dataset.dta", clear

* identify lead arranger *
merge m:1 bank packageid using "$data/Intermediate Data/deal_lead"
gen deal_lead = (_merge==3)

keep if year>=2000 
keep if top43==1

gen  month = month(facilitystartdate) 

* equal allocation across all lenders *
bys	facilityid: egen synd_size = count(bank)
gen	allocamt_ew = facilityamt/synd_size
gen	allocamt_nonlead = allocamt_ew if deal_lead==0

* date variables *
gen year_month =ym(year, month) 
gen ym = year_month 
format ym %tm

* weighted average spread *
gen spread_amt = allocamt_ew*allindrawn
bys bank ym instTL: egen tot_fac = sum(allocamt_ew) 
bys bank ym instTL: egen tot_spread_amt = sum(spread_amt)
gen weighted_spread = tot_spread_amt/ tot_fac 

gen	spread_amt_nonlead = allocamt_nonlead*allindrawn
bys bank ym instTL: egen tot_fac_nonlead = sum(allocamt_nonlead) 
bys bank ym instTL: egen tot_spread_amt_nonlead = sum(spread_amt_nonlead)
gen weighted_spread_nonlead = tot_spread_amt_nonlead/ tot_fac_nonlead

* collapse to bank x quarter x TL-type level *
collapse (sum) allocamt_ew allocamt_nonlead (mean) weighted_spread weighted_spread_nonlead, by(ym bank instTL) 

* merge in credit cycle measures
merge m:1 ym using "$data\Final Data\monthly_credit_cycles_measures_standardized.dta", keep(3) nogen

//Multiply the cycle variables with the TLB-indicator
foreach var of varlist  lag_* {
	egen `var'_std = std(`var')
	drop `var'
}

* additional variables *
gen log_amt = log(allocamt_ew)
gen	log_amt_nonlead = log(allocamt_nonlead)
egen bankid = group(bank) 
gen	   	tlb_ebp = instTL * lag_eb_premium

* label variables *
label  	variable tlb_ebp "Excess Bond Premium x Term B"
label  	variable instTL "Term B"
label	variable lag_eb_premium "Excess Bond Premium"

* Volumes *
eststo clear
eststo p1: reghdfe	log_amt lag_eb_premium instTL tlb_ebp, noabsorb cl(bankid ym)
estadd local bank "N"
estadd local banktime "N": p1
estadd local role "All": p1
estadd local matcontrols "N": p1
estadd local relcontrols "N": p1

eststo p2: reghdfe	log_amt lag_eb_premium instTL tlb_ebp, absorb(bankid) cl(bankid ym)
estadd local bank "Y"
estadd local banktime "N": p2
estadd local role "All": p2
estadd local matcontrols "N"
estadd local relcontrols "N"

eststo p4: reghdfe	log_amt lag_eb_premium instTL tlb_ebp, absorb(bankid#ym) cl(bankid ym)
estadd local bank "N"
estadd local banktime "Y": p4
estadd local role "All": p4
estadd local matcontrols "N"
estadd local relcontrols "N"


eststo p5: reghdfe	log_amt_nonlead lag_eb_premium instTL tlb_ebp, absorb(bankid#ym) cl(bankid ym)
estadd local bank "N"
estadd local banktime "Y": p5
estadd local role "Non-Lead": p5
estadd local matcontrols "N"
estadd local relcontrols "N"

esttab  p1 p2  p4 p5  using "$tables/table7a.tex", tex mgroup("Log(Amount)", pattern(1 0 0 0 0 0 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) nomtitle  varwidth(40) b(%8.3f) se(%8.3f) sfmt(%s %s %s  %12.0fc  %8.3f)  drop(_cons ) noomit noobs scalars("bank Bank FE" "banktime Bank x Month FE" "role Role" "N Obs." "r2 \$R^2\$") msign($-$) replace nonotes  starlevels(* 0.10 ** 0.05 *** 0.01) wrap label  noconstant  noomitted substitute(\hline \toprule)


* Spreads *
eststo clear
eststo p1: reghdfe	weighted_spread lag_eb_premium instTL tlb_ebp, noabsorb cl(bankid ym)
estadd local bank "N"
estadd local banktime "N": p1
estadd local role "All": p1
estadd local matcontrols "N"
estadd local relcontrols "N"

eststo p2: reghdfe	weighted_spread lag_eb_premium instTL tlb_ebp, absorb(bankid) cl(bankid ym )
estadd local bank "Y"
estadd local banktime "N": p2
estadd local role "All": p2
estadd local matcontrols "N"
estadd local relcontrols "N"

eststo p4: reghdfe	weighted_spread lag_eb_premium instTL tlb_ebp, absorb(bankid#ym) cl(bankid ym)
estadd local bank "N"
estadd local banktime "Y": p4
estadd local role "All": p4
estadd local matcontrols "N"
estadd local relcontrols "N"

eststo p5: reghdfe	weighted_spread_nonlead lag_eb_premium instTL tlb_ebp, absorb(bankid#ym) cl(bankid ym)
estadd local bank "N"
estadd local banktime "Y": p5
estadd local role "Non-Lead": p5
estadd local matcontrols "N"
estadd local relcontrols "N"

esttab  p1 p2 p4 p5  using "$tables/table7b.tex", tex mgroup("All-in-drawn-spread", pattern(1 0 0 0 0 0 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) nomtitle  varwidth(40) b(%8.3f) se(%8.3f) sfmt(%s %s %s  %12.0fc  %8.3f)  drop(_cons ) noomit noobs scalars("bank Bank FE" "banktime Bank x Month FE" "role Role" "N Obs." "r2 \$R^2\$") msign($-$) replace nonotes  starlevels(* 0.10 ** 0.05 *** 0.01) wrap label  noconstant  noomitted substitute(\hline \toprule)

log close  