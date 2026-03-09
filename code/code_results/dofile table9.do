******************************************************************************
******************************************************************************
** This file creates Table 9 - Cyclicality of Lead Banks, Non-lead Banks, and Nonbanks by Borrower Characteristics
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
log using "$package/logs/table9.log", replace


*******************************************************************************
*** Interactions with assymetric info 
*******************************************************************************

use "$data\Final Data\main_facility_dataset_deallead.dta", clear

keep if year>=2000 

gen leadamt = allocamt * lead_deal  * (1-instTL)
gen participantamt = allocamt * (1-lead_deal) * (1-instTL)
gen nonbankamt = allocamt * instTL

gen  month = month(facilitystartdate) 
gen n=1

// calcualte weighted spread 
gen spread_amt = facilityamt* allindrawn
bys borrowercompanyid packageid instTL: egen tot_fac = sum(facilityamt) 
bys borrowercompanyid packageid instTL: egen tot_spread_amt = sum(spread_amt)
gen weighted_spread = tot_spread_amt/ tot_fac 

gen year_month =ym(year, month) 
bys packageid: egen min= min(year_month)

replace year_month = min 

collapse (sum) leadamt participantamt nonbankamt (first) year_month year (mean) at (firstnm) gvkey, by(borrowercompanyid packageid) 

gen ym = year_month 
format year_month %tm


merge m:1 ym using "$data\Final Data\monthly_credit_cycles_measures_standardized.dta", keep(3) nogen 
label var lag_eb_premium "EBP"

rename leadamt amt1
rename participantamt amt2
rename nonbankamt amt3 

reshape long amt, i(borrowercompanyid packageid) j(type, string)
replace type ="Lead Bank" if type =="1"
replace type ="Participant Bank" if type =="2"
replace type = "Nonbank" if type =="3" 

encode type, gen(type_code) 

gen log_amt = log(amt)


//////////////////////////////
//size 
xtile size_median = at
gen size_median_text = "Large" if size_median==2 
replace size_median_text = "Small" if size_median==1 
encode size_median_text, gen(size_median_code) 


///////////////////////////////////////////
// age - compustat 

preserve
	use "$data/Raw Data/compustat/funda.dta", clear
	*Keep the first filing date for each firm (gvkey)
	bysort gvkey (datadate): keep if _n == 1
	rename datadate first_filing
	drop if missing(gvkey)
	destring gvkey, replace	
	tempfile compustat_age
	save	`compustat_age'
restore
******************

merge m:1 gvkey using `compustat_age'
drop if _merge == 2
drop _merge

gen compu_age = (dofm(year_month) - first_filing) / 365
summarize compu_age, detail

generate age_median = (compu_age >= `r(p50)') if !missing(compu_age)

gen age_median_text = "Old" if age_median==1 
replace age_median_text = "Young" if age_median==0
encode age_median_text, gen(age_median_code) 


///////////////////////////////////////////////
// age - dealscan 

preserve
	use "$data\Intermediate Data\facility_dataset_new_DS.dta", clear

	*Filtering critertion
	drop if facilitystartdate == . 

	*Keep variables needed
	keep facilityid packageid borrowercompanyid facilitystartdate

	*Keep only one facility by packageid (the first one according to the facilitystartdate)
	bysort packageid (facilitystartdate): keep if _n == 1
	drop facilityid
	rename facilitystartdate packagestartdate

	*Sort the loan deals for each borrower and numerate
	bysort borrowercompanyid (packagestartdate): generate count_loan = _n

	*Generate the count of prior loans
	generate prior_loans = count_loan - 1

	*Save
	keep packageid prior_loans
	tempfile prior_loans
	save	`prior_loans'
restore
******************

merge m:1 packageid using `prior_loans'
drop if _merge == 2
drop _merge

summarize prior_loans, detail
generate age_median_DS = (prior_loans >= `r(p50)') if !missing(prior_loans)


gen age_median_text_ds = "Old-DS" if age_median_DS==1 
replace age_median_text_ds = "Young-DS" if age_median_DS==0
encode age_median_text_ds, gen(age_median_code_ds) 


///////////////////////////////////////////
// public vs private 
gen public = "Public" if gvkey!=. & year_month<=tm(2017,7)
replace public = "Private" if gvkey==. & year_month<=tm(2017,7) // need to restrict to March 2017 bc DS-CS link file ends there
encode public, gen(public_code) 



*******************************************************************************
*** Interactions with asymmetric information
*******************************************************************************


eststo p3: reghdfe log_amt lag_eb_premium c.lag_eb_premium##ib3.type_code##i.size_median_code, abs(packageid type_code) cluster(borrowercompanyid year_month) 
estadd local borrower "N"
estadd local time "N": p3
estadd local borrower_time "Y": p3
estadd local lender_type "Y": p3
sum		year_month if e(sample)

eststo p6: reghdfe log_amt lag_eb_premium c.lag_eb_premium##ib3.type_code##i.age_median_code, abs(packageid type_code) cluster(borrowercompanyid year_month) 
estadd local borrower "N"
estadd local time "N": p6
estadd local borrower_time "Y": p6
estadd local lender_type "Y": p6
sum		year_month if e(sample)

eststo p9: reghdfe log_amt lag_eb_premium c.lag_eb_premium##ib3.type_code##i.age_median_code_ds, abs(packageid type_code) cluster(borrowercompanyid year_month) 
estadd local borrower "N"
estadd local time "N": p9
estadd local borrower_time "Y": p9
estadd local lender_type "Y": p9
sum		year_month if e(sample)

eststo p12: reghdfe log_amt lag_eb_premium c.lag_eb_premium##ib3.type_code##i.public_code, abs(packageid type_code) cluster(borrowercompanyid year_month) 
estadd local borrower "N"
estadd local time "N": p12
estadd local borrower_time "Y": p12
estadd local lender_type "Y": p12
sum		year_month if e(sample)


esttab  p3 p6 p9 p12  using "$tables/table9.tex", tex  mgroup("Log(Facility Amount)", pattern(1 0 0 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) nomtitle varwidth(40) b(%8.3f) se(%8.3f) sfmt(%s %s %s %s %12.0fc  %8.3f) noomitted   noomitted noobs scalars("borrower Borrower FE" "time Year-Month FE" "borrower_time Deal FE" "lender_type Lender-Role FE" "N Obs." "r2 \$R^2\$") msign($-$) replace nonotes  starlevels(* 0.10 ** 0.05 *** 0.01) wrap label  substitute(\hline \toprule)  keep( *type_code*#c.lag_eb_premium) 

log close 