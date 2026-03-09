clear all

*************** DESCRIPTION ***************************************************
* Prepares dataset to analyze nonbank dependence pre-crisis vs. 
* changes in lending from before to during the crisis.
*
* We focus on top 43 banks and largely follow Chodorow-Reich (2014)
*******************************************************************************   

*********** Compute number and volume of loans per bank. 

use "$data/final data/oldDS_main_facility_dataset", clear

* Select banks
keep if top43 == 1 

*Set definition of nonbank loans (nonbank = facilities in a deal with 1+ institutional tranche)
replace instTL = deal_instTL 

*Keep the pre crisis (period == 1) and the crisis period (period == 3)
keep if period == 1 | period == 3

**

/* ------------------------------ */
/* 	COMPUTE VOLUME DECOMPOSITION  */
/* ------------------------------ */

*Compute the volume and number of loans for each bank
collapse (sum) no=finalalloc vol=allocamt, by(instTL bank period corp)
compress

*Reshape the data
reshape wide no vol, i(bank period instTL) j(corp)
rename *0 *_ncr
rename *1 *_cr

reshape wide no* vol*, i(bank period) j(instTL)
rename *0 *_b
rename *1 *_nb

reshape wide no* vol*, i(bank) j(period)
rename *1 *_pre
rename *3 *_gfc

*Replace missing values with zero
qui ds, has(type numeric)
local varlist `r(varlist)'
foreach var of local varlist {
replace `var' = 0 if missing(`var')
}

*Compute volumes and numbers across corporate and non-corporate loans
local fields "b_pre b_gfc nb_pre nb_gfc"
foreach field of local fields {
	generate no_`field' = no_ncr_`field' + no_cr_`field'
	generate vol_`field' = vol_ncr_`field' + vol_cr_`field'
}

*Drop all noncorporate entries
drop *ncr*

*Compute total lending
generate vol_tot_pre = vol_b_pre + vol_nb_pre
generate vol_tot_gfc = vol_b_gfc + vol_nb_gfc
gsort -vol_tot_pre

*Compute lending changes
generate lenchg_tot_vol = vol_tot_gfc / (vol_tot_pre/2) - 1
generate lenchg_b_vol = vol_b_gfc / (vol_b_pre/2) - 1
generate lenchg_nb_vol = vol_nb_gfc / (vol_nb_pre/2) - 1

*Compute nonb dependence prior to the gfc
generate nb_dep_vol = vol_nb_pre/vol_tot_pre
order nb_dep_vol, after(bank)

*Compute total lending
generate vol_cr_tot_pre = vol_cr_b_pre + vol_cr_nb_pre
generate vol_cr_tot_gfc = vol_cr_b_gfc + vol_cr_nb_gfc

*Compute lending changes
generate lenchg_tot_vol_cr = vol_cr_tot_gfc / (vol_cr_tot_pre/2) - 1
generate lenchg_b_vol_cr = vol_cr_b_gfc / (vol_cr_b_pre/2) - 1
generate lenchg_nb_vol_cr = vol_cr_nb_gfc / (vol_cr_nb_pre/2) - 1

**

/* ------------------------------ */
/* 	COMPUTE NUMBER DECOMPOSITION  */
/* ------------------------------ */

*Compute total lending
generate no_tot_pre = no_b_pre + no_nb_pre
generate no_tot_gfc = no_b_gfc + no_nb_gfc

*Compute lending changes
generate lenchg_tot_no = no_tot_gfc / (no_tot_pre/2) - 1
generate lenchg_b_no = no_b_gfc / (no_b_pre/2) - 1
generate lenchg_nb_no = no_nb_gfc / (no_nb_pre/2) - 1


*Compute nonb dependence prior to the gfc
generate nb_dep_no = no_nb_pre/no_tot_pre
order nb_dep_no, after(nb_dep_vol)

*Compute total lending
generate no_cr_tot_pre = no_cr_b_pre + no_cr_nb_pre
generate no_cr_tot_gfc = no_cr_b_gfc + no_cr_nb_gfc

*Compute nonbank dependence prior to the gfc
generate nb_dep_no_cr = no_cr_nb_pre/no_cr_tot_pre

*Compute lending changes
generate lenchg_tot_no_cr = no_cr_tot_gfc / (no_cr_tot_pre/2) - 1
generate lenchg_b_no_cr = no_cr_b_gfc / (no_cr_b_pre/2) - 1
generate lenchg_nb_no_cr = no_cr_nb_gfc / (no_cr_nb_pre/2) - 1

**

/* ---------------------- */
/* 	 ADD BANK VARIABLES   */
/* ---------------------- */
* From Chodorow-Reich website
preserve
	import excel "$data\Raw Data\website_chodorow_reich\final_bank_variables_adj.xls", firstrow clear
	drop id source 
	tempfile chodorow_reich
	save	`chodorow_reich'
restore
merge 1:1 bank using `chodorow_reich', nogen

foreach var in lehman_exp loading revat renco reco da{
	egen std_`var' = std(`var')
}
gen ibnb = type=="IB" | type=="Nonbank"

label var std_loading "ABX Exposure" 
label var std_lehman_exp "Lehman exposure"
label var std_revat "07-08 Trading Rev/AT" 
label var std_reco "RE CO flag" 
label var std_renco "07-08 RE NCO/AT"  
label var std_da "07 Deposits/Assets" 
label var ibnb "IB/FinCo indicator" 
label var nb_dep_no "Nonbank Dependence"
label var nb_dep_vol "Nonbank Dependence"
label var nb_dep_no_cr "Nonbank Dependence"

save "$data/final data/GFC_data.dta", replace
