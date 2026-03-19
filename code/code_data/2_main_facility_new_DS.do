******************************************************************************
******************************************************************************

************ DESCRIPTION: CONSTRUCT MAIN ANALYSIS FILE ************************
*
* Creates facility-level dataset including a variety of loan type indicators. 
* Merges Dealscan with Compustat and top 43 lender characteristics.
* 
******************************************************************************* 
******************************************************************************
******************************************************************************
set more off
clear all
set scheme s1color


global package "C:\Users\Eunkyung\ASU Dropbox\Eunkyung Jeon\2026-1\econometrics\12. replicate\nonbank lending and credit cyclicality"
global project "$package"

global output `"$package\results"'
global data `"$package\data"'
global code `"$package\code"'
global figures `"$package\figures"'
global tables `"$package\tables"'
capture log close
log using "$package/logs/main_facility_dataset.log", replace

******************************************************************************
  
* open new Dealscan *
use "$data\Raw Data\dealscan_new\Dealscan_data_full_compress.dta", clear

/* drop certain variables
drop 
law_firm_borrower_other law_firm_borrower_primary law_firm_lender_other law_firm_lender_primary law_firm_name foreign_exchange bankers_acceptance bid_option multi_currency swingline letter_of_credit eligible_property_value marketable_securities property_plant_equipment cash_cash_equivalents inv_work_in_progress inv_finished_goods inv_raw_material inventory acc_rec_foreign acc_rec_domestic oil_gas_reserves accounts_receivable capex_final_usd capex_initial_usd ebitda_final_amount_usd ebitda_initial_amount_usd terms_changes percentage_of_net_income insurance_proceeds_sweep
*/

/* ------------------------- */
/* 		SAMPLE SELECTION	 */
/* ------------------------- */
rename *, lower
* keep US, USD, syndicated loans
keep if country == "United States" & country_of_syndication=="United States"
keep if tranche_currency == "U.S. Dollar" 	| tranche_currency == "US Dollar (Same Day) (pre Mar 2014)"
keep if deal_currency == "U.S. Dollar" 		| deal_currency == "US Dollar (Same Day) (pre Mar 2014)"
drop if ~strmatch(distribution_method,"Syndication")
keep if tranche_active_date > td(01jan1986) & tranche_active_date~=.
keep if tranche_active_date < mdy(1,1,2021)

* define data variables *
g year = year(tranche_active_date)
gen mdate = mofd(tranche_active_date)
format mdate %tm
gen qdate = qofd(tranche_active_date)
format qdate %tq

* drop FIRE: SIC codes 6000-6799
gen	sic_code_num = substr(sic_code,1,4)
replace sic_code_num = subinstr(sic_code_num,":","",.)
destring sic_code_num, replace
drop if sic_code_num >= 6000 & sic_code_num <= 6799

* Drop borrowers with missing data *
drop if tranche_active_date == . 
drop if sic_code_num == . 

* periods
g period = 0
replace period = 1 if  tranche_active_date >= td(01oct2005) & tranche_active_date <= td(30june2006) & tranche_active_date~=.
replace period = 1 if  tranche_active_date >= td(01oct2006) & tranche_active_date <= td(30june2007) & tranche_active_date~=.
replace period = 2 if  tranche_active_date >= td(01oct2007) & tranche_active_date <= td(30june2008) & tranche_active_date~=.
replace period = 3 if  tranche_active_date >= td(01oct2008) & tranche_active_date <= td(30june2009) & tranche_active_date~=.
save "$data\Intermediate Data\facility_dataset_new_DS.dta", replace

/* ---------------------------- */
/* 		ESTIMATE ALLOCATION	    */
/* ---------------------------- */
* Complicated algorithm follows CR
do "$code\code_data\dealscan_facilityalloc_new_DS.do"


use "$data\Intermediate Data\facility_dataset_new_DS.dta",clear
recast str300 lender_name //necessary for merge after!
duplicates drop lender_name lpc_tranche_id tranche_active_date, force 
merge 1:1 lender_name lpc_tranche_id tranche_active_date using  "$data\Intermediate Data\allocation_new_DS.dta", keepusing(finalalloc) nogen
g allocamt = tranche_amount * finalalloc
save "$data\Intermediate Data\facility_dataset_new_DS.dta", replace

/* ------------------ */
/*     MAP LENDERS	  */
/* ------------------ */

* M&A adjustments for top banks
import excel "$data\Raw Data\mapping\Bank mapping_final.xlsx", sheet("Output") firstrow clear
rename lender lender_name
merge 1:m lender_name using "$data\Intermediate Data\facility_dataset_new_DS.dta",nogen  keep(matched using) // all should match -> if there is differnt name for same bank, make it same
rename mappedname mappedlender //mappedlender: standardized bank name

* use ultimate parent, not lender if missing
replace mappedlender = lender_parent_name if mappedlender == ""
recast strL lender_name 
save "$data\Intermediate Data\facility_dataset_new_DS.dta", replace

	
/* ------------------------ */
/* 	   MAP LENDER TYPES	 	*/
/* ------------------------ */

* Lender institution type
g lentype = "Bank" if strpos(lender_institution_type,"Bank")
replace lentype = "IB" if lender_institution_type == "Investment Bank"
replace lentype = "Nonbank" if lentype == "" //distinguish bank vs nonbank for GFC analysis

save "$data\Intermediate Data\facility_dataset_new_DS.dta", replace

*  DETAILED TYPE FOR TOP 43 Banks  * 
import excel "$data\Raw Data\website_chodorow_reich\final_bank_variables_adj.xls", firstrow clear
rename bank mappedlender
rename type type43
keep mappedlender type43
merge 1:m mappedlender using "$data\Intermediate Data\facility_dataset_new_DS.dta", nogen

//  use detailed type for top 43 banks, otherwise lendertype in Dealscan
g mappedtype = lentype    
replace mappedtype = type43 if type43 ~= "" 
recast str300 lender_name //necessary for merge after! 
save "$data\Intermediate Data\facility_dataset_new_DS.dta", replace

* MANUAL REVIEW FOR LENDERS WITH DIVERGING TYPES  *
import excel "$data\Raw Data\mapping\type_mapping.xlsx", sheet("mapped") firstrow clear
keep lender mappedtype
rename mappedtype manualtype
rename lender lender_name
merge 1:m lender_name using "$data\Intermediate Data\facility_dataset_new_DS.dta", nogen
replace mappedtype = manualtype if manualtype ~= "" 
drop type43 manualtype

* resolve different lenders with same patern but different types 
foreach X in Bank IB Nonbank Regional Universal {
	egen ct`X' = sum(mappedtype=="`X'"), by(mappedlender )
}
egen maxct = rowmax(ct*)
foreach X in Bank IB Nonbank Regional Universal {
	replace mappedtype = "`X'" if ct`X' == maxct
}
drop ct* maxct


/* ---------------------------- */
/* 		LOAN TYPE INDICATORS 	*/
/* ---------------------------- */

* Define real investment loans *
g inv  = inlist(primary_purpose,"General Purpose","Working capital","General Purpose/Refinance"," Capital expenditure")

* Define real investment deals *
g deal_inv  = inlist(deal_purpose,"General Purpose","Working capital","General Purpose/Refinance"," Capital expenditure")

* Define credit lines *
g creditline = inlist(tranche_type,"Limited Line","Revolver/Line < 1 Yr.","Revolver/Line >= 1 Yr.")

* Define Institutional Loans and Deals *
g instTL = 0
replace instTL = 1 if inlist(tranche_type,"Term Loan B", "Term Loan C", ///
						 "Term Loan D",  "Term Loan E", "Term Loan F")
replace instTL = 1 if inlist(tranche_type,"Term Loan G", "Term Loan H", ///
						 "Term Loan I",  "Term Loan J", "Term Loan K")
g noninstTL = instTL ~= 1
egen deal_instTL = max(instTL),by(lpc_deal_id tranche_active_date)
g deal_noninstTL = deal_instTL ~= 1


save  "$data\Intermediate Data\facility_dataset_new_DS.dta", replace


/* ----------------- */
/* 		COMPUSTAT  	 */
/* ----------------- */
* Compustat data *
use 	"$data\Raw Data\compustat\funda.dta", clear
keep gvkey datadate at   
keep if year(datadate) >= 1986
destring gvkey, replace
save "$data\Intermediate Data\tfile.dta", replace

* Map to dealscan facilities
import excel "$data\Raw Data\dealscan_new\Dealscan-Compustat Linking Database_2018.xlsx", sheet("link_data") firstrow clear // UPDATE

// add mapping from facilityid to new tranche-id!
preserve
	import excel "$data\Raw Data\dealscan_new\WRDS_to_LoanConnector_IDs.xlsx",  firstrow clear
	keep LoanConnectorTrancheID WRDSfacility_id
	rename WRDSfacility_id facid
	rename LoanConnectorTrancheID lpc_tranche_id
	tempfile ids
	save	`ids', replace
restore
merge 1:1 facid using `ids', keep(1 3)  nogen
keep gvkey bcoid facstartdate facid lpc_tranche_id 
rename bcoid borrowercompanyid
rename facid facilityid

// Merge with the file that contains COMPUSTAT fundamentals *
rename facilityid facid 
drop borrowercompanyid 
destring gvkey, replace
mmerge gvkey using "$data\Intermediate Data\tfile.dta"
keep	if _merge==3
drop	_merge
erase 	"$data\Intermediate Data\tfile.dta"
* select last fiscal year prior to origination
g  ddate = datadate - facstartdate
drop if ddate > 0 
gsort facid -ddate 
bys facid: keep if _n == 1
drop ddate 
rename  facstartdate tranche_active_date

* merge by facilityid *
rename facid facilityid
drop	if lpc_tranche_id==.
tostring lpc_tranche_id, replace
merge 1:m lpc_tranche_id tranche_active_date  using "$data\Intermediate Data\facility_dataset_new_DS.dta", nogen keep(matched using)
save "$data\Intermediate Data\facility_dataset_new_DS.dta", replace


/* -------------------------- */
/* 	ADD BANK VARS FOR TOP 43  */
/* -------------------------- */

import excel "$data\Raw Data\website_chodorow_reich\final_bank_variables_adj.xls", firstrow clear
drop id source type
rename bank mappedlender
merge 1:m mappedlender using "$data\Intermediate Data\facility_dataset_new_DS.dta"
g top43 = _merge == 3
drop _merge
rename mappedlender bank 
rename mappedtype type



/* ------------------------------------ */
/* 				Clean Maturity  		*/
/* ------------------------------------ */
replace	tenor_maturity = . if tenor_maturity==0 //=missing end date


/* ------------------------------------ 
/* 	drop variables we don't need!		*/
/* ------------------------------------ */

drop	lender_name lender_parent_name lender_parent_id  additional_roles lender_commit lender_operating_country lender_parent_operating_country additional_borrowers ticker perm_id legal_entity_id_lei city state_province zip country region sales_size broad_industry_group major_industry_group parent parent_ticker sponsor guarantor target organization_type senior_debt_to_ebitda total_debt_to_ebitda company_url lead_arranger number_of_lead_arrangers bookrunner number_of_bookrunners top_tier_arranger number_of_top_tier_arrangers lead_left number_of_lead_left arranger number_of_arrangers co_arranger number_of_co_arrangers agent number_of_agents lead_manager number_of_lead_managers all_lenders number_of_lenders lender_region lender_parent_region lender_institution_type deal_permid deal_amount_converted deal_input_date  project_finance phase deal_active deal_refinancing purpose_remark deal_remark deal_amended sales_size_at_close tranche_permid league_table_amount league_table_amount_converted _100_percent_vote tranche_amount_converted market_segment market_of_syndication country_of_syndication league_table_tranche_date   repayment_type repayment_schedule collateral_security_type distribution_method primary_purpose secondary_purpose tertiary_purpose tranche_refinancing sponsored project_finance_sponsor tranche_active closed_date completion_date mandated_date launch_date average_life multi_currency_tranche borrower_consent agent_consent assignment_minimum assignment_fee new_money new_money_converted amend_extend_flag tranche_amended currency_onshore_offshore base_reference_rate margin_bps all_base_rate_spread_margin base_rate_margin_bps floor_bps call_protection call_protection_text all_in_spread_undrawn_bps annual_fee_bps commitment_fee_bps letter_of_credit_fee_bps upfront_fee_bps all_in_fee_asia_only base_rate_comment repayment_comment performance_pricing performance_pricing_grid performance_pricing_remark cancellation_fee_bps documentary_issuing_fee_bps documentary_lc_fee_bps tiered_upfront_fee utilization_fee_bps all_fees covenants max_leverage_ratio max_debt_to_cash_flow max_sr_debt_to_cash_flow tangible_net_worth net_worth min_fixed_charge_coverage_ratio min_debt_service_coverage_ratio min_interest_coverage_ratio min_cash_interest_coverage_ratio max_debt_to_tangible_net_worth max_debt_to_equity_ratio min_current_ratio max_loan_to_value_ratio all_covenants_financial covenant_comment excess_cf_sweep asset_sales_sweep material_restriction debt_issue_sweep equity_issue_sweep collateral_release required_lenders all_covenants_general
*/
compress



/* ------------------------------------ */
/* 	identify observations to retain		*/
/* ------------------------------------ */

* retain only new originations and refinancings with  change in major loan terms
preserve 

	* keep one observation per tranche, date (dropping duplicates relative to lenders) *
	bys lpc_tranche_id tranche_active_date : keep if _n==1

	* indicate refinancings/amendements *
	gen amend = strpos(tranche_o_a , "Amendment")

	* original amount, spread, and maturity *
	gen orig_amt = tranche_amount if amend ==0
	bys lpc_tranche_id (orig_amt ): replace orig_amt = orig_amt[_n-1] if orig_amt ==.

	gen orig_spread = all_in_spread_drawn_bps if amend ==0
	bys lpc_tranche_id (orig_spread ): replace orig_spread = orig_spread[_n-1] if orig_spread ==.

	gen orig_maturity = tranche_maturity_date if amend ==0
	bys lpc_tranche_id (orig_maturity ): replace orig_maturity = orig_maturity[_n-1] if orig_maturity ==.
	format orig_maturity %td 

	* indicate refinancings as opposed to amendments without major contractual changes *
	gen refinancing = amend ==1  & (orig_maturity!=tranche_maturity_date) & (orig_spread!=all_in_spread_drawn_bps)

	* retaining originations and refinancings with major contractual changes * 
	keep if refinancing ==1 | amend ==0

	*There are two outliers with a 200 billion loan and a 1000 billion loan 
		drop if lpc_tranche_id == "199393"
		drop if lpc_tranche_id == "302857"	
		
	* drop if tranche amount is negative 
	keep if tranche_amount>0 

	keep lpc_tranche_id lpc_deal_id tranche_active_date amend

	tempfile observations_to_retain_new_DS
	save 	`observations_to_retain_new_DS', replace

restore
merge m:1 lpc_deal_id lpc_tranche_id tranche_active_date using `observations_to_retain_new_DS', keep(3) nogen 

* generate identifying variables and rename variables *
drop	facilityid
egen facilityid = group(lpc_tranche_id tranche_active_date)
egen packageid = group(lpc_deal_id tranche_active_date)
egen borrowercompanyid = group(borrower_name)
rename tranche_active_date facilitystartdate
rename tranche_amount facilityamt 
rename tranche_maturity_date facilityenddate
rename all_in_spread_drawn_bps allindrawn 
rename tenor_maturity maturity 
rename deal_purpose dealpurpose

* winsorize spread variable *
winsor2 allindrawn, cuts(1 99) replace 

* save intermdiate file *
save 	"$data\Intermediate Data\facility_dataset_new_DS.dta", replace

* keep only neccessary variables *
keep allindrawn allocamt at	bank	borrowercompanyid	creditline	deal_instTL	deal_inv	///
dealpurpose	 facilityamt	facilityenddate	facilityid	facilitystartdate	finalalloc	gvkey instTL	inv	 	lender_id 	maturity	///
mdate	packageid	period	qdate 	seniority	sic_code_num top43	tranche_type type	year	primary_role 

* save final file *
save "$data\Final Data\main_facility_dataset.dta", replace 


*******************************************************************************
/* ------------------------------------ */
/* 	identify lead arrangers				*/
/* ------------------------------------ */
*******************************************************************************

use "$data/Final Data/main_facility_dataset", clear 

// for each deal retaining all banks and their different roles 
collapse (sum) allocamt, by(bank primary_role packageid)

// assigning admin agent of deal as lead 
gen lead_deal = (inlist(primary_role,"Admin agent"))
bys packageid: egen found_lead_deal = max(lead_deal)

// if no admin agent
replace lead_deal =1 if found_lead_deal ==0 & inlist(primary_role,"Agent", "Arranger", "Bookrunner", "Joint arranger", "Lead bank", "Lead manager", "Lead arranger", "Mandated Lead arranger")

drop found_lead_deal
bys packageid: egen found_lead_deal = max(lead_deal)

// if none of above types are also found 
replace lead_deal =1 if found_lead_deal ==0 & inlist(primary_role, "Co-agent", "Co-arranger", "Collateral agent", "Coordinating arranger", "Documentation agent", "Managing agent", "Syndications agent")

// reain lead arrangers of the deal
keep if lead_deal ==1 
contract  bank packageid
drop _freq 

save "$data/Intermediate Data/deal_lead", replace 

  
/* --------------------------------------------------- */
/* 	merging lead assignment to main faiclity dataset   */
/* --------------------------------------------------- */
use "$data/Final Data/main_facility_dataset", clear 

// some banks have multiple roles - consolidating that into one observation 
drop primary_role //duplicates because of role difference
duplicates drop
quietly ds  allocamt finalalloc bank facilityid packageid, not
local varlist `r(varlist)'
di "`varlist'"
collapse (sum) allocamt finalalloc (lastnm) `varlist' , by(bank facilityid packageid )

merge m:1 bank packageid using "$data/Intermediate Data/deal_lead"
gen lead_deal =  _merge ==3
drop _merge 

save "$data/Final Data/main_facility_dataset_deallead", replace 


