******************************************************************************
******************************************************************************
** This file creates Fig 5 - Cyclicality of Originations: Bank vs. Nonbank Lending
** in "Nonbank Lending and Credit Cyclicality" by Fleckenstein et. al. (2024)
******************************************************************************
******************************************************************************

set more off
clear all
set scheme s1color

global package "C:\Users\Eunkyung\ASU Dropbox\Eunkyung Jeon\2026-1\econometrics\12. replicate\nonbank lending and credit cyclicality"
global project "$package"

global output `"$package\results"' //change from output to result
global data `"$package\data"'
global code `"$package\code"'
global figures `"$package\figures"'
global tables `"$package\tables"'  //typo

capture log close
log using "$package/logs/prep_clo_bank_spreads.log", replace

******************************************************************************


* CLO tranche file *
use "$data\Raw Data\creditflux\tranches.dta", clear

*Select deal type US CLOs *
keep if dealtype=="US CLO"

*Keep first observation (does not matter because will use "pricingdate" anyways)
bysort tranche_id (reportdate): keep if _n == 1

*Generate pricing month
replace pricingdate = closingdate if missing(pricingdate)
drop if missing(pricingdate)
generate pricingmonth = mofd(pricingdate)
format pricingmonth %tm

* Keep only the debt tranches *
replace	seniority = originalsp if seniority=="" & originalsp!=""
keep if inlist(seniority, "AAA", "AA", "A", "BBB", "BB", "B")

* keep if baserate = Libor
tab baserate
keep if strpos(baserate, "LIBOR") //Drop the fixed spreads

* share of each seniority in total issuance *
bys  pricingmonth: egen clo_issuance_vol = total(originalbalance*(coupon!=.))
bys  pricingmonth seniority: egen share_debt_structure = total(originalbalance/clo_issuance_vol)

* Collapse to month x seniority * 
collapse  (lastnm) share_debt_structure , by(pricingmonth seniority)
replace seniority = "_" + seniority
reshape wide  share_debt_structure , i(pricingmonth) j(seniority) string
rename *, lower

*Merge-in the Palmer Square Indices yields
preserve
	import excel "$data\Raw Data\palmer_square\Palmer_Square_Indices.xlsx", clear firstrow sheet("DiscountMargin") cellrange(A4)
	drop if _n <= 3
	destring *, replace
	generate date = date(A,"MDY")
	format date %td
	order date
	
	rename PCLOAAADIndex aaa_palmerclo
	rename PCLOAADMIndex aa_palmerclo
	rename PCLOADMIndex a_palmerclo
	rename PCLOBBBDIndex bbb_palmerclo
	rename PCLOBBDMIndex bb_palmerclo
	
	*Collapse by month
	generate pricingmonth = mofd(date)
	format pricingmonth %tm
	collapse (mean) *_palmerclo, by(pricingmonth)

	tempfile palmer_squared_indices
	save	`palmer_squared_indices'
restore

merge 1:1 pricingmonth using `palmer_squared_indices', nogen

* weighted secondary market spreads *
local	d "_a _aa _aaa _bbb _bb"
foreach var of local d {
	egen med_debt_share`var' =  median(share_debt_structure`var')
}
egen	rowtotal_med_debt_str = rowtotal(med_debt_share*)
local	d "_a _aa _aaa _bbb _bb"
foreach var of local d {
	replace med_debt_share`var' = med_debt_share`var'/rowtotal_med_debt_str
}

gen wacd_palmerclo = med_debt_share_aaa * aaa_palmerclo
local	d "a aa bbb bb"
foreach var of local d {
	replace wacd_palmerclo =  wacd_palmerclo + med_debt_share_`var' * `var'_palmerclo
}

* merge in EBP *
preserve
	import delimited "$data\Raw Data\gilchrist_zakrajsek\ebp.csv", clear
	gen		date_num = date(date,"YMD",.)
	gen		pricingmonth = mofd(date_num)
	format 	pricingmonth %tm
	egen	ebp_std = std(ebp)
	keep	ebp ebp_std pricingmonth
	tempfile ebp
	save	`ebp', replace
restore
merge 1:1 pricingmonth using `ebp', nogen 
gen	ebp_bps = ebp*100


* keep variables 
keep 	wacd_palmerclo pricingmonth aaa_palmerclo ebp_bps

* save file *a
save		"$data\Final Data\clo_bank_spreads.dta", replace
