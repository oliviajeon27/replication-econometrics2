
******************************************************************************
******************************************************************************
** This file creates Table 3
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
log using "$package/logs/table3.log", replace

******************************************************************************	
use "$data/final data/GFC_data.dta", clear

keep bank lenchg_tot_no lenchg_b_no lenchg_nb_no lenshare nb_dep_no std_lehman_exp std_loading std_revat std_reco std_renco std_da

*Compute interaction terms
generate std_lehman_exp_int_no = std_lehman_exp * nb_dep_no 
generate std_loading_int_no = std_loading * nb_dep_no
generate std_revat_int_no = std_revat * nb_dep_no
generate std_reco_int_no = std_reco * nb_dep_no
generate std_renco_int_no = std_renco * nb_dep_no
generate std_da_int_no = std_da * nb_dep_no

label var std_lehman_exp_int_no 	"Lehman exposure x NB Dep."
label var std_loading_int_no 		"ABX Exposure x NB Dep." 
label var std_revat_int_no 			"07-08 Trading Rev/AT x NB Dep." 
label var std_reco_int_no 			"RE CO flag x NB Dep."
label var std_renco_int_no 			"07-08 RE NCO/AT x NB Dep."
label var std_da_int_no 			"07 Deposits/Assets x NB Dep." 

regress lenchg_tot_no nb_dep_no [aw=lenshare]
corr lenchg_tot_no nb_dep_no [aw=lenshare]

**** Horse race: Bank health vs. nonbank dependence 
eststo clear
*Old regression: Bank health measures
eststo: reg lenchg_tot_no std_lehman_exp [aw=lenshare], robust
eststo: reg lenchg_tot_no std_loading [aw=lenshare], robust
eststo: reg lenchg_tot_no std_revat std_reco std_renco std_da [aw=lenshare], robust
*Horse race: Bank health measures vs. nonbank dependence
eststo: reg lenchg_tot_no nb_dep_no std_lehman_exp [aw=lenshare], robust
eststo: reg lenchg_tot_no nb_dep_no std_loading [aw=lenshare], robust
eststo: reg lenchg_tot_no nb_dep_no std_revat std_reco std_renco std_da [aw=lenshare], robust
*Split: Bank loans vs. nonbank loans
eststo: reg lenchg_b_no 	std_lehman_exp std_loading std_revat std_reco std_renco std_da [aw=lenshare], robust
eststo: reg lenchg_nb_no 	std_lehman_exp std_loading std_revat std_reco std_renco std_da [aw=lenshare], robust

esttab, r2 starlevels(* 0.10 ** 0.05 *** 0.01) noconstant b(%8.3f)

esttab  using "$tables/table3.tex", tex se ///
mgroup("$\Delta$ All Loans" "$\Delta$ Bank" "$\Delta$ Nonbank", pattern(1 0 0 0 0 0 1 1) ///
prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) nomtitle  ///
varwidth(20) b(%8.3f) t(%8.3f) sfmt(%12.0fc  %8.3f)  ///
noobs scalars("N Obs." "r2 \$R^2\$") msign($-$) ///
replace nonotes wrap label  noconstant ///
substitute(\hline \toprule) starlevels(* 0.10 ** 0.05 *** 0.01)

log close
