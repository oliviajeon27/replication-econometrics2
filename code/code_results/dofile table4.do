******************************************************************************
******************************************************************************
** This file creates Table 4
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
log using "$package/logs/table4.log", replace

******************************************************************************

use "$data/final data/oldDS_main_facility_dataset", clear

*************** DESCRIPTION ***************************************************
* Compute the loan shock measures on the borrower level
*******************************************************************************   

***************
* Choose percentile
***************

*Choose the percentile
//global percentile = 90
//global percentile = 95
global percentile = 98


***************
* Step 1) Keep the borrowers that likely have an active relationship
***************

keep countryofsyndication facilitystartdate facilityenddate corp borrowercompanyid top43 facilityid finalalloc facilityamt bank instTL deal_instTL company salesatclose publicprivate emp primarysiccode

keep if countryofsyndication == "USA"

*Keep only the borrower that likely had an active relationship with lenders
g loan_orig0408 = 0
replace loan_orig0408 = 1 if facilitystartdate >= td(01jan2004) & facilitystartdate <= td(31aug2008) & facilitystartdate~=.
g loan_post07 = 0
replace loan_post07 = 1 if facilitystartdate < td(01jan2004) & facilityenddate >= td(01nov2007) & facilityenddate~=.
g validloan = loan_orig0408 + loan_post07
keep if validloan == 1

*Keep only working capital or corporate purposes
//keep if inlist(primarypurpose,"Corp. purposes","Work. cap.")
keep if corp == 1
	
unique borrowercompanyid

*Keep the last loans (choose one facility if there is a deal with several facilities)
bysort borrowercompanyid (facilitystartdate): keep if facilitystartdate[_n] == facilitystartdate[_N]

*keep only loans where there is one top 43 lender included
bysort facilityid (top43): keep if top43[_N] == 1

***************
* Step 2) Compute the pre-crisis syndicate shares
***************

********Compute the shares
preserve	
	*Collapse across lender entities for same bank holding company
	collapse (sum) finalalloc, by(borrowercompanyid bank facilityid facilityamt)
	
	sort borrowercompanyid facilityid
	order borrowercompanyid facilityid

	*Collapse lender shares across all facility within a package
	collapse (mean) finalalloc [weight=facilityamt], by(borrowercompanyid bank)
	
	*Reshape
	rename finalalloc share
	//reshape wide share, i(borrowerparentid) j(bankid)
	
	*Save
	tempfile precrisis_syndicate
	save	`precrisis_syndicate'
restore

*Merge-in the pre-crisis syndicate shares 
	//Keep the variables from Compustat
keep borrowercompanyid company salesatclose publicprivate emp primarysiccode
bysort borrowercompanyid: keep if _n == 1

*Sample statistics
	*Sales
	replace salesatclose = salesatclose/ 10^6 //convert to millions
	summarize salesatclose, detail //Distribution looks similar to CR
	format salesatclose %9.1f
	
	*Employment
		//Note: emp is in thousands of employees
	replace emp = emp * 1000 //Convert to unscaled number of employees
	summarize emp, detail
	//Some of the firms state zero number of employees?	

*******Merge-in the pre-crisis syndicate shares
merge 1:m borrowercompanyid using `precrisis_syndicate'
drop _merge


***************
* Step 3) Compute the lending decline on the originating bank level
***************

***** Create the bank-level lending decline (excluding the borrower itself)

*a) For the pre-crisis period
preserve
	use "$data/final data/oldDS_main_facility_dataset", clear

	drop if missing(bank)
	
	*Keep the pre crisis (period == 1) and the crisis period (period == 3)
	keep if period == 1 | period == 3
	keep if corp == 1	
		
	keep instTL deal_instTL borrowercompanyid bank finalalloc period
	
	*Define institutional on the deal-level
	replace instTL = deal_instTL //If use this line, then all loans in a deal with an institutional tranche get classified as institutional
	
	*Generate pre-crisis indicator
	generate pre_gfc = (period == 1)
	
	***** For the pre-crisis period
		*Sum all loans (here: do not look at loan volumes but at quantities)
		egen no_pre_instTL_plusown 	= sum(finalalloc*instTL*pre_gfc), by(bank) 
		egen no_pre_bank_plusown  	= sum(finalalloc*(1-instTL)*pre_gfc), by(bank)
		egen no_pre_total_plusown 	= sum(finalalloc*pre_gfc), by(bank)
		
		*Subtract the number of loans made to the borrower itself
		egen no_pre_instTL_own 	= sum(finalalloc*instTL*pre_gfc), by(borrowercompanyid bank) 
		egen no_pre_bank_own 	= sum(finalalloc*(1-instTL)*pre_gfc), by(borrowercompanyid bank)
		egen no_pre_total_own 	= sum(finalalloc*pre_gfc), by(borrowercompanyid bank)	
		generate no_pre_instTL	= no_pre_instTL_plusown  - no_pre_instTL_own
		generate no_pre_bank 	= no_pre_bank_plusown  - no_pre_bank_own
		generate no_pre_total	= no_pre_total_plusown  - no_pre_total_own

		
	***** For the crisis period
		*Sum all loans (here: do not look at loan volumes but at quantities)
		egen no_gfc_instTL_plusown 	= sum(finalalloc*instTL*(1-pre_gfc)), by(bank) 
		egen no_gfc_bank_plusown 	= sum(finalalloc*(1-instTL)*(1-pre_gfc)), by(bank)
		egen no_gfc_total_plusown 	= sum(finalalloc*(1-pre_gfc)), by(bank)
		
		*Subtract the number of loans made to the borrower itself
		egen no_gfc_instTL_own = sum(finalalloc*instTL*(1-pre_gfc)), by(borrowercompanyid bank) 
		egen no_gfc_bank_own = sum(finalalloc*(1-instTL)*(1-pre_gfc)), by(borrowercompanyid bank)	
		egen no_gfc_total_own = sum(finalalloc*(1-pre_gfc)), by(borrowercompanyid bank)	
		generate no_gfc_instTL 	= no_gfc_instTL_plusown - no_gfc_instTL_own
		generate no_gfc_bank 	= no_gfc_bank_plusown - no_gfc_bank_own
		generate no_gfc_total	= no_gfc_total_plusown - no_gfc_total_own
	
	drop *_own
	
	keep  borrowercompanyid bank no_pre_instTL* no_pre_bank* no_pre_total* no_gfc_instTL* no_gfc_bank* no_gfc_total*
	order borrowercompanyid bank no_pre_instTL* no_pre_bank* no_pre_total* no_gfc_instTL* no_gfc_bank* no_gfc_total*
	
	*Drop duplicates (because borrowers obtain several loans)
	duplicates drop
				
	*Save
	tempfile loanshock_borrower_bank
	save	`loanshock_borrower_bank'
restore


merge m:1 borrowercompanyid bank using `loanshock_borrower_bank'
drop if _merge == 2
drop _merge

*Replace the observations where we do not have the lender in the sample
bysort bank (no_pre_instTL_plusown): 	replace no_pre_instTL = no_pre_instTL_plusown[1] if missing(no_pre_instTL)
bysort bank (no_pre_bank_plusown): 		replace no_pre_bank = no_pre_bank_plusown[1] if missing(no_pre_bank)
bysort bank (no_pre_total_plusown): 	replace no_pre_total = no_pre_total_plusown[1] if missing(no_pre_total)

bysort bank (no_gfc_instTL_plusown): 	replace no_gfc_instTL = no_gfc_instTL_plusown[1] if missing(no_gfc_instTL)
bysort bank (no_gfc_bank_plusown): 		replace no_gfc_bank = no_gfc_bank_plusown[1] if missing(no_gfc_bank)
bysort bank (no_gfc_total_plusown): 	replace no_gfc_total = no_gfc_total_plusown[1] if missing(no_gfc_total)

drop *plusown

drop if missing(no_pre_instTL) | missing(no_pre_bank) | missing(no_pre_total) | missing(no_gfc_instTL) | missing(no_gfc_bank) | missing(no_gfc_total)


*Compute lending changes
generate chg_b = no_gfc_bank / (no_pre_bank/2) - 1
generate chg_nb = no_gfc_instTL / (no_pre_instTL/2) - 1
generate chg_tot = no_gfc_total / (no_pre_total/2) - 1

*Compute nonb dependence prior to the gfc
generate nb_dep = no_pre_instTL/(no_pre_bank+no_pre_instTL)

*Some missings	
mdesc
drop if missing(chg_tot)

*Insert 0% if lending both before and during crisis was 0
replace chg_b = 0 if 	no_gfc_bank == 0 	& no_pre_bank == 0
replace chg_nb = 0 if 	no_gfc_instTL == 0 	& no_pre_instTL == 0

drop if missing(chg_b) | missing(chg_nb)
	

*Adjust the syndicate shares such that they sum to 1
bysort borrowercompanyid: egen sum_shares = sum(share)
replace share = share/sum_shares
drop sum_shares
bysort borrowercompanyid: egen sum_shares = sum(share)
	
	
***************
* Sample of firms
***************

sort borrowercompanyid

*Generate variables: 
generate log_sales = log(salesatclose)
generate log_emp = log(emp)
generate public = (publicprivate == "Public")

*Industry identifier
tostring primarysiccode, replace
generate sic = substr(primarysiccode,1,1)
destring sic, replace //Otherwise cannot use in regression as fixed effect or dummies
tab sic

*Number of firms
count //4,804
count if !missing(emp) //2,691
count if !missing(emp) & emp < 1000 //617
count if !missing(emp) & emp >= 1000 //2,074

*Predict the employment with sales
	//Fitting with logs (works worse than level-levels)
	//binscatter log_emp log_sales if emp < 3000, n(100)
	//Only use each firm once
	bysort borrowercompanyid: generate first_obs = (_n==1)
	regress log_emp c.log_sales#i.sic if first_obs == 1, robust
	predict pred_emp
	replace pred_emp = exp(pred_emp) 
	order pred_emp, after(emp)
	
	*Test the regression 
	//generate below_1000 = emp < 1000
	//generate below_1000_pred = pred_emp < 1000
	//regress below_1000 below_1000_pred
	

*Classify firms
	*Use actual employment
	generate firm_type = "large" if emp > 1000 & !missing(emp)
	order firm_type, after(pred_emp)
	replace firm_type = "medium" if emp >= 250 & emp < 1000 & !missing(emp)
	replace firm_type = "small" if emp < 250 & !missing(emp)
	
	*Use sales
	replace pred_emp = . if !missing(emp)
	replace firm_type = "large" if pred_emp > 1000 & !missing(pred_emp)
	replace firm_type = "medium" if pred_emp >= 250 & pred_emp < 1000 & !missing(pred_emp)	
	replace firm_type = "small" if pred_emp < 250 & !missing(pred_emp)	
	
	*Use publicprivate
	replace firm_type = "large" if publicprivate == "Public" & missing(firm_type)
	
	*Assume the remaining firms are small
	replace firm_type = "small" if missing(firm_type)
	tab firm_type
	

*Use mean employment for small firms if still missing(employment shares)
replace pred_emp = emp if missing(pred_emp)
summarize pred_emp if firm_type == "small"
replace pred_emp = `r(mean)'  if firm_type == "small" & missing(pred_emp)

*Matching?
	//egen firm_type_group = group(firm_type) // 1 -> large, 2 -> medium, 3 -> small
	//regress nb_dep i.firm_type_group, robust
	//Little evidence
	
	*Also: stronger decline for larger firms (because substitute to the bond market?)
	//regress chg_tot i.firm_type_group, robust
	//Evidence for this --> stronger decline for larger firms

*Weight of each firms in terms of employment share
egen total_emp = total(pred_emp*(firm_type!="large")*first_obs) //Compute total employment for medium & small firms
generate weight_firm = pred_emp/total_emp if firm_type!="large"
drop total_emp


***************
* Compute the percentile
***************

preserve
*Step a) Compute the loan shock on the borrower level
	*Weighted sum across past syndicate members
	collapse (sum) chg_tot_firm=chg_tot (last) salesatclose  publicprivate emp company primarysiccode firm_type weight_firm [pweight=share], by(borrowercompanyid)


	*Summary statistics for the loan shock
	summarize chg_tot_firm, detail //sd = 19%. q90 - q10 = -74% - (-30%) = 44%

	*Winsorize the measures
	//winsor2 chg_tot_firm, cuts(0 99) replace

	**** Histograms with the bank and nonbank lending decline
		/*
		twoway (histogram chg_nb, width(0.05) color(red%30)) ///        
			   (histogram chg_b, width(0.05) color(green%30)), ///   
			   legend(order(1 "Loan supply - nonbank" 2 "Loan supply - bank" ))

		hist nb_dep
		*/

	gsort -chg_tot_firm

	*Compute the percentile
	_pctile chg_tot_firm, p($percentile)
	return list
	global quantile_chg_tot = `r(r1)'
	display($quantile_chg_tot)	
restore


***************
* Main Chodorow-Reich counterfactual
***************

*Step a) Compute the loan shock on the borrower level

	*Compute the counterfactual changes
		*True lending
		bysort borrowercompanyid: egen chg_tot_firm = total(chg_tot*share)
		//bysort borrowercompanyid: egen chg_tot_firm_test = total(chg_b*(1-nb_dep)*share+chg_nb*nb_dep*share)
		
		*Identify the firms that had a lending decline more than the percentile
		generate cf_firm = (chg_tot_firm < $quantile_chg_tot)
		
		*Counterfactual: Change bank lending
		generate chg_b_q = $quantile_chg_tot if cf_firm == 1
		replace chg_b_q = chg_b if cf_firm == 0
		bysort borrowercompanyid: egen chg_tot_b = total(chg_b_q*(1-nb_dep)*share+chg_nb*nb_dep*share)

		*Counterfactual: Change nonbank lending
		generate chg_nb_q = $quantile_chg_tot if cf_firm == 1
		replace chg_nb_q = chg_nb if cf_firm == 0
		bysort borrowercompanyid: egen chg_tot_nb = total(chg_b*(1-nb_dep)*share+chg_nb_q*nb_dep*share)		
		
		*Counterfactual: Change both
		bysort borrowercompanyid: egen chg_tot_b_nb = total(chg_b_q*(1-nb_dep)*share+chg_nb_q*nb_dep*share)	
		
		*Matching counterfactual
			*Document whether there is matching with firm types
			//egen firm_type_group = group(firm_type)
			//order firm_type_group, after(firm_type) //1 large, 2 medium, 3 small
			//regress nb_dep i.firm_type_group
		*Compute the mean nonbank dependence across all syndicate members
		egen nb_dep_q = wtmean(nb_dep), weight(share)
		bysort borrowercompanyid: egen chg_tot_nb_dep = total(chg_b*(1-nb_dep_q)*share+chg_nb*nb_dep_q*share)		
		
keep borrowercompanyid chg_tot_firm chg_tot_b chg_tot_nb chg_tot_b_nb chg_tot_nb_dep salesatclose  publicprivate emp company primarysiccode firm_type weight_firm cf_firm
bysort borrowercompanyid: keep if _n == 1	

order borrowercompanyid chg* cf_firm
gsort -chg_tot_firm

*Predicted effect of lending decline on employment growth
	//Table IX column (2) and Table X column (1) in Chodorow-Reich
	//Standardized coefficient multiplied with standard deviation of explanatory variable
//generate coef_all = 1.67/19.1
//generate coef_large = 0   
generate coef_small = 2.16/19.1
generate coef_medium = 1.84/19.1


****** Predicted losses by the linear regression
	*Predicted employment growth by linear regression results
	generate empchg_pred = chg_tot_firm * coef_small if firm_type == "small"
	replace empchg_pred = chg_tot_firm * coef_medium if firm_type == "medium"
	
	*Average predicted losses by lending decline (could be credit demand as well as supply)
	egen avg_empchg_pred = wtmean(empchg_pred), weight(weight_firm)
	display(avg_empchg_pred)


*******Counterfactual 1: Replicate the Chodorow-Reich counterfactual analysis

	*Counterfactual employment growth (if there was no credit supply shock)
	generate empchg_cf1 = chg_tot_b_nb * coef_medium if firm_type == "medium"
	replace empchg_cf1 	= chg_tot_b_nb * coef_small if firm_type == "small"
	
	*Compute the credit supply contribution to overall employment decline for small & medium firms
	egen avg_contr_cf1 = wtmean(empchg_pred-empchg_cf1), weight(weight_firm)
	display(avg_contr_cf1[1]) //-2.6% of employment growth comes from credit supply
		//Overall employment decline for small and medium firms was 7% (Table XIII)
	display(avg_contr_cf1[1]/-0.07) //Find 36.8%. Chodorow-Reich finds 34.4%


*******Counterfactual 2: Leave bank unchanged, change nonbank credit supply
capture drop chg_tot_cf2 empchg_cf2	avg_contr_cf2  chg_tot_cf2 empchg_cf2 avg_contr_cf2
					
	*Counterfactual employment growth (if there was no credit supply shock)
	generate empchg_cf2 = chg_tot_nb * coef_medium if firm_type == "medium"
	replace empchg_cf2 	= chg_tot_nb * coef_small if firm_type == "small"
	
	*Compute the credit supply contribution to overall employment decline for small & medium firms
	egen avg_contr_cf2 = wtmean(empchg_pred-empchg_cf2), weight(weight_firm)
	display(avg_contr_cf2[1]) //-xx% of employment growth comes from credit supply
	display(avg_contr_cf2[1]/avg_contr_cf1[1]) //Percentage of credit supply loses


*******Counterfactual 3: Leave bank unchanged, change nonbank credit supply
capture drop chg_tot_cf3 empchg_cf3	avg_contr_cf3  chg_tot_cf3 empchg_cf3 avg_contr_cf3
					
	*Counterfactual employment growth (if there was no credit supply shock)
	generate empchg_cf3 = chg_tot_b * coef_medium if firm_type == "medium"
	replace empchg_cf3 	= chg_tot_b * coef_small if firm_type == "small"
	
	*Compute the credit supply contribution to overall employment decline for small & medium firms
	egen avg_contr_cf3 = wtmean(empchg_pred-empchg_cf3), weight(weight_firm)
	display(avg_contr_cf3[1]) //-xx% of employment growth comes from credit supply
	display(avg_contr_cf3[1]/avg_contr_cf1[1]) //Percentage of credit supply loses
	
log close
