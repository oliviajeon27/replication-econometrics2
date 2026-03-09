******************************************************************************
******************************************************************************
** This file creates Fig 5 - Cyclicality of Originations: Bank vs. Nonbank Lending
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
global code `"$package\tables"'
capture log close
log using "$package/logs/figures7.log", replace


******************************************************************************

** Panel A **
use		"$data\Final Data\clo_bank_spreads.dta", clear

keep	if inrange(pricingmonth,tm(2005,1),tm(2020,12))

label 	variable aaa_palmerclo  "AAA-LIBOR"
label 	variable wacd_palmerclo "WACD-LIBOR"

tsset pricingmonth
// secondary market spread relative to LIBOR + EBP 
twoway line aaa_palmerclo ebp_bps   wacd_palmerclo   pricingmonth , cmissing(n n n) xtitle("") ytitle("Spread in BPS")  lcolor(red black  blue)  lp(dash solid  solid)
graph export "$figures/figure7a.pdf", replace


** Panel B **
use 	"$data\Final Data\CLO_Bank_leverage.dta", clear

keep 	if inrange(qdate,tq(2005,1),tq(2020,4))

label 	variable market_eq_ratio_nonib_ma_pct "Bank Equity Ratio"
label	variable equity_ratio_org_w1_ma "CLO Equity Ratio"

twoway line market_eq_ratio_nonib_ma_pct equity_ratio_org_w1_ma  month , cmissing(n n) xtitle("") lcolor( black red)  lp(solid dash) ytitle("Equity Ratio (in Percent)") 
graph  export	"$figures\figure7b.pdf", replace

log close  