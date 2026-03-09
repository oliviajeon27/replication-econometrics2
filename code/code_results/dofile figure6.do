******************************************************************************
******************************************************************************
** This file creates Fig 6 - Relative sensitivity of Bank and Nonbank Lending to the Credit Cycle
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
log using "$package/logs/figure6.log", replace


******************************************************************************

********************************************
*** Panel A: EBP and Nonbank Lending Share
********************************************
* open facility dataset *
use "$data\Final Data\main_facility_dataset.dta", clear
bys facilityid: keep if _n == 1
g nbamt = facilityamt*instTL

* define
collapse (sum) nbamt  facilityamt , by(mdate)
tset mdate
gen pct_nonbank = nbamt / facilityamt
save "$data\Intermediate Data\temp_gg", replace

* eBP
use "$data\Final Data\monthly_credit_cycles_measures_standardized", clear
rename ym mdate
merge 1:1 mdate using "$data\Intermediate Data\temp_gg", nogen keep(matched using)


* SMOOTH
tset mdate
tssmooth ma eb_premium_ma = eb_premium, w(0 1 5)
tssmooth ma pct_nonbank_ma = pct_nonbank, w(0 1 5)


keep if mdate >= ym(2000,1)
format mdate %tm 
twoway line eb_premium_ma mdate, lcolor(black) || (connected pct_nonbank_ma  mdate,ylab(0(0.1)0.4, axis(2)) yaxis(2) ms(i i) lcolor(red green) lp(dash dash)),  graphregion(color(white)) legend(order(1 "Excess Bond Premium " 2 "Nonbank Share") c(3))  ytitle("Excess Bond Premium (%)") ytitle("Nonbank Share (%)",axis(2)) xtitle("")
graph export "$figures/figure6a.pdf", replace




********************************************
*** Panel B: EBP and Nonbank-Bank Loan Pricing
********************************************

use "$data\Final Data\main_facility_dataset.dta", clear

* define
bys facilityid: keep if _n == 1
keep if seniority == "Senior"

*Merge-in information on the second lien
preserve
	use "$data\Intermediate Data\facility_dataset_new_DS.dta", clear
	
	keep if year>=2000 //& qofd(facilitystartdate)<=tq(2020,1)

	
	generate lien = (strpos(tranche_remark, "second-lien")>0)
	replace lien = (strpos(tranche_remark, "second lien")>0) if lien==0
	replace lien = (strpos(tranche_remark, "2nd lien")>0) if lien==0
	tab lien 
	keep facilityid lien
	duplicates drop facilityid, force 
	tempfile lien
	save `lien'
restore

merge 1:1 facilityid using `lien', keep(1 3) nogen 

tab lien
drop if lien == 1

keep if mdate >= ym(2000,1)

* compute spread difference
g logmaturity = log(maturity)
generate covid_dummy = (facilitystartdate >= mdy(3,13,2020))

reghdfe allindrawn c.instTL#i.mdate logmaturity  [aw=facilityamt], abs(deal_inv  seniority dealpurpose sic_code_num )
parmest, norestore

* format results
rename estimate spdiff
replace spdiff = . if spdiff == 0 
split(parm),p("#")
keep if strpos(parm2,"instTL")
g mdate = substr(parm1,1,3)
destring mdate,replace
format mdate %tm
tset mdate
save "$data\Intermediate Data\temp_gg.dta", replace

* GZ
use "$data\Final Data\monthly_credit_cycles_measures_standardized", clear
rename ym mdate
keep mdate eb_premium
merge 1:1 mdate using "$data\Intermediate Data\temp_gg.dta", nogen keep(matched using)
sleep 100
save "$data\Intermediate Data\temp_gg.dta", replace

* Smooth
use "$data\Intermediate Data\temp_gg.dta",clear
tset mdate
tssmooth ma spdiff_ma = spdiff, w(0 1 5)
tssmooth ma eb_premium_ma = eb_premium, w(0 1 5)

* figure *
keep if mdate >= ym(2000,1)
format mdate %tm
twoway line eb_premium_ma mdate, lcolor(black) || (connected spdiff_ma mdate, yaxis(2) ms(i) lcolor(red) lp(dash)),  legend(order(1 "Excess Bond Premium" 2 "Nonbank - Bank spread") c(3))  ytitle("Excess Bond Premium (%)") ytitle( "Nonbank-Bank spread (bps)",axis(2)) graphregion(color(white)) xtitle("")
graph export "$figures/figure6b.pdf", replace

erase "$data\Intermediate Data\temp_gg.dta"
log close 