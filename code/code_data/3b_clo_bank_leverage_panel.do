******************************************************************************
******************************************************************************
** This file creates CLO_Bank_leverage file: Bank vs. Nonbank Lending
** in "Nonbank Lending and Credit Cyclicality" by Fleckenstein et. al. (2024)
******************************************************************************
******************************************************************************

set more off
clear all
set scheme s1color


global output `"$package\results"' //change from output to result
global data `"$package\data"'
global code `"$package\code"'
global figures `"$package\figures"'
global tables `"$package\tables"'  //typo

capture log close
log using "$package/logs/prep_clo_bank_leverage.log", replace

******************************************************************************

* Start with loan-level data set
use "$data\Final Data\main_facility_dataset_deallead.dta", clear //need to link with schwert linking table

* keep only neccessary variables *
keep   allocamt lender_id qdate lead_deal type year 

* restrict sample *
drop if missing(allocamt)
keep if qdate >= yq(2000,1)

* add linke between new DS lender id and old DS lender id *
rename 	lender_id lender_id_new_DS
destring 	lender_id_new_DS, replace
preserve
	import excel "$data\Raw Data\dealscan_new\LPC_Loanconnector_Company_ID_Mappings.xlsx", sheet("in") firstrow clear
	rename	LoanConnectorCompanyID lender_id_new_DS
	rename 	LPC_COMPANY_ID lender_id_old_DS
	keep	lender_id_*
	tempfile link
	save `link', replace
restore
merge m:1 lender_id_new_DS using `link', keep(1 3) nogen //because schwert file use old dealscan lender id - compustat gvkey

*Load the Schwert link file and create a annual panel with valid links
preserve
	import excel "$data\Raw Data\website_schwert\Dealscan_Lender_Link_Jefferiesupdated.xlsx", sheet("Compustat") clear firstrow allstring
	
	// rename variable 
	rename lcoid lender_id_old_DS
	
	// Create variables
	destring lender_id_old_DS, replace
	destring gvkey, replace
	drop note
	
	// Reformat the dates
	local var_list "ds_start ds_end comp_start comp_end"	
	foreach var of local var_list {
		rename `var' `var'_help
		generate  `var' = date(`var'_help, "YMD")
		format `var' %td
	}
	drop *help
	
	// Convert to panel data
	generate year = 2000 if _n == 1
	replace year = year[_n-1] + 1 if _n > 1 & year[_n-1] < 2020
	bysort lender_id_old_DS: replace year = 2000 + _n if missing(year)
	xtset lender_id_old_DS year
	tsfill, full
	
	// Fill in all missing observations
	bysort lender_id_old_DS (gvkey): replace ds_start = ds_start[_n-1] 		if missing(ds_start)
	bysort lender_id_old_DS (gvkey): replace ds_end = ds_end[_n-1] 			if missing(ds_end)
	bysort lender_id_old_DS (gvkey): replace comp_start = comp_start[_n-1] 	if missing(comp_start)
	bysort lender_id_old_DS (gvkey): replace comp_end = comp_end[_n-1] 		if missing(comp_end)
	bysort lender_id_old_DS (gvkey): replace lender = lender[_n-1] 			if missing(lender)
	bysort lender_id_old_DS (gvkey): replace gvkey = gvkey[_n-1] 			if missing(gvkey)
	sort lender_id_old_DS year
	
	// Determine the (entire) years for which the link is valid
	replace comp_end = td(31dec2020) if comp_end == td(31dec2019) // assumes link is valid also for 2020
	keep if year < year(comp_end+1) | comp_end == td(31dec2020)
	keep if year > year(comp_start-1)
	
	keep lender_id_old_DS gvkey year
	
	tempfile schwert_lender_link
	save	`schwert_lender_link'
restore
merge m:1 lender_id_old_DS year using `schwert_lender_link', keep(3) nogen
//keep(3): only matched observation

*Merge in the Compustat firm names
preserve 
	use "$data\Intermediate Data\Combined_Compustat_Quarterly.dta", clear
	
	* generate quarter *
	gen		qdate = qofd(datadate)

	bysort gvkey qdate (datadate): keep if _n==_N // If two entries in one quarter. keep later one
	drop if missing(gvkey)
	
	*Keep last observation per year
	keep conm qdate gvkey
	
	tempfile compustat_names
	save	`compustat_names'
restore
merge m:1 gvkey qdate using `compustat_names', keep(3) nogen

*Entire loan amount - Only loans where bank is lead arranger	
preserve
	keep if lead_deal == 1
	collapse  (sum) suml_leads =allocamt , by(gvkey qdate)
	tempfile lead_loans
	save	`lead_loans'
restore

* Sum up entire loan amount per Bank x Quarter *
collapse (lastnm)  type conm ///
(sum) sum_loans=allocamt  , by(gvkey qdate)

* merge in amounts as lead arranger *
merge 1:1 gvkey qdate using `lead_loans' //263 bank x year observation are dropped because bank never functioned as lead arranger
drop _merge


* Merge-in Bank's Market Equity Ratio *
preserve 
	use "$data\Intermediate Data\Combined_Compustat_Quarterly.dta", clear
	
	drop if missing(gvkey)
	
	*Keep last observation per year
	gen		qdate = qofd(datadate)
	bysort gvkey qdate (datadate): keep if _n == _N 
	drop datadate

	keep	gvkey qdate market_eq_ratio
	tempfile compustat_information
	save	`compustat_information'
restore

merge m:1 gvkey qdate using `compustat_information', keep(1 3) nogen

* Further classify banks based on type *
	// Some manual revision because "gvkeys" might get mappend to different "banks"
replace type = "Bank"		if conm == "ABN-AMRO HOLDINGS NV"
replace type = "Bank" 		if conm == "BANCO SANTANDER SA"
replace type = "Nonbank"	if conm == "ALLIANZ SE"
replace type = "Universal" 	if conm == "BANK OF AMERICA CORP"
replace type = "Regional"	if conm == "FIRST NIAGARA FINANCIAL GRP"
replace type = "IB" 		if conm == "MORGAN STANLEY"
replace type = "Universal" 	if conm == "NATWEST GROUP PLC"
replace type = "Nonbank"	if conm == "GENERAL ELECTRIC CAP CORP"
replace type = "Universal"	if conm == "MITSUBISHI UFJ FINANCIAL GRP"

	// Define the types that were previously undefined
replace type = "IB" if conm == "JEFFERIES GROUP LLC"
replace type = "Universal" if conm == "ABN-AMRO HOLDINGS NV"
replace type = "Nonbank" if conm == "ALLY FINANCIAL INC"
replace type = "Regional" if conm == "AMEGY BANCORPORATION INC"
replace type = "Regional" if conm == "ASSOCIATED BANC-CORP"
replace type = "Universal" if conm == "BANCO SANTANDER SA"
replace type = "Regional" if conm == "BANK OF HAWAII CORP"
replace type = "Universal" if conm == "BBVA"
replace type = "Universal" if conm == "BBVA COMPASS BANCSHARES INC"
replace type = "Regional" if conm == "CAPITAL ONE FINANCIAL CORP"
replace type = "Regional" if conm == "CITIZENS FINANCIAL GROUP INC"
replace type = "Universal" if conm == "DBS GROUP HOLDINGS LTD"
replace type = "Universal" if conm == "DRESDNER BANK AG"
replace type = "Regional" if conm == "FIRSTMERIT CORP"
replace type = "Regional" if conm == "HIBERNIA CORP  -CL A"
replace type = "Regional" if conm == "HUNTINGTON BANCSHARES"
replace type = "Universal" if conm == "ING GROEP NV"
replace type = "Universal" if conm == "LLOYDS BANKING GROUP PLC"
replace type = "Regional" if conm == "MARSHALL & ILSLEY CORP"
replace type = "Universal" if conm == "MIZUHO FINANCIAL GROUP INC"
replace type = "Regional" if conm == "NATIONAL AUSTRALIA BK"
replace type = "Universal" if conm == "NORTHERN TRUST CORP"
replace type = "Regional" if conm == "PEOPLE'S UNITED FINL INC"
replace type = "Nonbank" if conm == "PROVIDENT FINANCIAL GRP INC"
replace type = "Regional" if conm == "SOUTHTRUST CORP"
replace type = "Nonbank" if conm == "STATE STREET CORP"
replace type = "IB" if conm == "STIFEL FINANCIAL CORP"
replace type = "Universal" if conm == "SUMITOMO MITSUI FINANCIAL GR"
replace type = "Regional" if conm == "SYNOVUS FINANCIAL CORP"
replace type = "Regional" if conm == "TRUSTMARK CORP"
replace type = "Universal" if conm == "UNITED OVERSEAS BANK LTD"
replace type = "Regional" if conm == "WEBSTER FINANCIAL CORP"
replace type = "Universal" if conm == "WESTPAC BANKING"
replace type = "Universal" if conm == "ZIONS BANCORPORATION NA"

* Adjust Bank types *
generate inv_bank = (type == "IB")
generate nonbank = (type == "Nonbank")

* Focus on the largest lead arrangers *
	// Compute total volume of loans where bank was lead arranger
bysort gvkey: egen total20yr_volumelead = total(suml_leads)
replace total20yr_volumelead = total20yr_volumelead / 10^6

	// Generate ranking in terms of volume for lead arranger over entire sample
preserve
	keep gvkey total20yr_volumelead
	duplicates drop 
	gsort -total20yr_volumelead
	generate rk_vol = _n
	tempfile rank_in_volume
	save	`rank_in_volume'
restore 
merge m:1 gvkey using `rank_in_volume', keep(1 3) nogen
keep if rk_vol <= 43

* drop nonbanks *
drop if conm == "BANK OF NEW YORK MELLON CORP" //following Schwert
drop if type == "Nonbank"

* generate lagged quarterly lending per bank *
xtset gvkey qdate
gen  lag_sum_loans = l1.sum_loans

* generate banks' market equity ratio *
gen		market_eq_ratio_nonib = market_eq_ratio if inv_bank==0

* collapse to weighted time-series *
collapse (mean)  market_eq_ratio_nonib   [aweight=lag_sum_loans] , by(qdate)

* merge in weighted average CLO equity_ratio *
gen month = mofd(dofq(qdate))
format month %tm
preserve
	use "$data\Intermediate Data\CLO_capitalstructure_spreads_primarymarket.dta",clear
	
	// trim equity ratio
	winsor2 equity_ratio_org, cut(2.5 97.5) suffix(_w1) trim

	// generate origination month
	gen month = mofd(origination_date)
	format month %tm
	collapse (mean)  equity_ratio_org_w1_mth=equity_ratio_org_w1  (count) num_obs_per_month = equity_ratio_org [aweight=clo_value_org], by(month)
	tempfile clo
	save 	`clo'
restore
merge 	1:1 month using `clo', nogen

* change unit of CLO equity ratio to percent *
gen		equity_ratio_org_w1_mth_pct = equity_ratio_org_w1_mth*100 

* drop CLO equity ratio observations if less than 2 observations per quarter *	
replace equity_ratio_org_w1_mth_pct =. if num_obs_per_month<2

* fill in missing months and use quarterly bank equity ratio in each month of a quarter *
tsset month
tsfill
format month %tm
replace  qdate = qofd(dofm(month)) if qdate==.
bys	qdate (market_eq_ratio_nonib): replace  market_eq_ratio_nonib = market_eq_ratio_nonib[1] if market_eq_ratio_nonib==. 

* take moving average of CLO equity ratio *
tssmooth ma equity_ratio_org_w1_ma = equity_ratio_org_w1_mth_pct, w(0 1 1)

* take moving average of bank equity ratio *
preserve
	keep	qdate  market_eq_ratio_nonib
	duplicates drop
	tsset qdate
	tssmooth ma market_eq_ratio_nonib_ma = market_eq_ratio_nonib, w(0 1 1)
	keep	qdate  market_eq_ratio_nonib_ma
	tempfile  bankequity
	save 		`bankequity'
restore
merge m:1 qdate using `bankequity'

* keep last observation per quarter *
bys	qdate (month): keep if _n==_N

* in Percent *
gen		market_eq_ratio_nonib_ma_pct = market_eq_ratio_nonib_ma*100

* keep neccessary variables *
keep 	qdate market_eq_ratio_nonib_ma_pct equity_ratio_org_w1_ma  month

* save file *
save 	"$data\Final Data\CLO_Bank_leverage.dta", replace
