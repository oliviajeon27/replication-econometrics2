******************************************************************************
******************************************************************************

************ DESCRIPTION: CONSTRUCT CYCLE MEASURES ************************

******************************************************************************* 
******************************************************************************
******************************************************************************
set more off
clear all
set scheme s1color

global package "C:\Users\Eunkyung\ASU Dropbox\Eunkyung Jeon\2026-1\econometrics\12. replicate\nonbank lending and credit cyclicality"

global output `"$package\results"'
global data `"$package\data"'
global code `"$package\code"'
global figures `"$package\figures"'
global tables `"$package\tables"'
capture log close
log using "$package/logs/credit_cycle_measures.log", replace

******************************************************************************
import delimited "$data\Raw Data\gilchrist_zakrajsek\ebp.csv", clear

* Create date *
rename date date1
generate date = date(date1, "YMD")
generate ym = mofd(date)
format ym %tm

* rename variables *
keep ym ebp
rename ebp eb_premium

* Lag the ebp *
tsset ym 
gen lag_eb_premium = l1.eb_premium
keep ym lag_eb_premium eb_premium 

*Keep the relevant time-series
keep if ym >= ym(2000,1) & ym <= ym(2021,12)

*Standardize
foreach var of varlist  lag_eb_premium eb_premium {
	egen `var'_std = std(`var')
	drop `var'
	rename `var'_std `var'
}

save "$data/Final Data/monthly_credit_cycles_measures_standardized", replace




