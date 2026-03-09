******************************************************************************
******************************************************************************
** This file creates Fig 3 - Composition of Nonbank Lenders: Bank vs. Nonbank Lending
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
log using "$package/logs/figures3.log", replace

******************************************************************************

use "$data/final data/oldDS_main_facility_dataset", clear

****************
*Start with loan-level data set
****************

drop if missing(qdate)
drop if missing(allocamt)

//g lead = leadarrangercredit == "Yes"

keep facilitystartdate allocamt deal_instTL lenderid bank qdate leadarrangercredit allindrawn year allocamt finalalloc

keep if qdate >= yq(2000,1)
keep if qdate < yq(2020,1) //Schwert link file ends here


****************
*Merge-in the Dealscan link
****************

*Load the Schwert link file and create a annual panel with valid links
preserve
	import excel "$data\Raw Data\website_schwert\Dealscan_Lender_Link_Jefferiesupdated.xlsx", sheet("Compustat") clear firstrow allstring
	duplicates report lcoid
	duplicates report gvkey
	duplicates report lcoid gvkey
	rename lcoid lenderid
	
	*Examine duplicates
	//bysort lenderid: generate dup = _N
	
	*Create variables
	destring lenderid, replace
	destring gvkey, replace
	drop note
	
	*Reformat the dates
	local var_list "ds_start ds_end comp_start comp_end"	
	foreach var of local var_list {
		rename `var' `var'_help
		generate  `var' = date(`var'_help, "YMD")
		format `var' %td
	}
	drop *help
	
	*Convert to panel data
	generate year = 2000 if _n == 1
	replace year = year[_n-1] + 1 if _n > 1 & year[_n-1] < 2019
	bysort lenderid: replace year = 2000 + _n if missing(year)
	xtset lenderid year
	tsfill, full
	
	*Fill in all missing observations
	mdesc
	bysort lenderid (gvkey): replace ds_start = ds_start[_n-1] 		if missing(ds_start)
	bysort lenderid (gvkey): replace ds_end = ds_end[_n-1] 			if missing(ds_end)
	bysort lenderid (gvkey): replace comp_start = comp_start[_n-1] 	if missing(comp_start)
	bysort lenderid (gvkey): replace comp_end = comp_end[_n-1] 		if missing(comp_end)
	bysort lenderid (gvkey): replace lender = lender[_n-1] 			if missing(lender)
	bysort lenderid (gvkey): replace gvkey = gvkey[_n-1] 			if missing(gvkey)
	sort lenderid year
	
	*Determine the (entire) years for which the link is valid
	keep if year < year(comp_end+1) | comp_end == td(31dec2019)
	keep if year > year(comp_start-1)
	
	keep lenderid gvkey year
	
	tempfile schwert_lender_link
	save	`schwert_lender_link'
restore

merge m:1 lenderid year using `schwert_lender_link'
keep if _merge == 3 //Key line: Only keep the lender id observation that could be matched to Compustat
drop _merge

*Merge in the Compustat firm names
preserve 
	use "$data\Intermediate Data\Combined_Compustat_Annual.dta", clear
	
	keep gvkey conm fyear
	
	drop if missing(gvkey)
	
	*Keep last observation per year
	rename fyear year
	keep conm year gvkey

	tempfile compustat_names
	save	`compustat_names'
restore

merge m:1 gvkey year using `compustat_names'
keep if _merge == 3
	//4 bank x year observation are missing because have no annual report:
	// 2001 GE Capital, 2007 KKR, 2003 Mitsubishi, 2008 Wachovia
drop _merge
order conm, after(bank)

unique conm //92 companies
unique gvkey //92 

****************
*Compute the decline in lending during the GFC (needed for binscatter)
****************

preserve
	keep if leadarrangercredit == "Yes"

	****Compute the lending decline between Oct2004 to June2007	and Oct2008 and June2009 (as in Schwert jmp)
	*Remove the third quarter
	drop if quarter(facilitystartdate) == 3
	
	*Compute aggregate loan orginiation volumes prior to financial crisis and during financial crisis
	generate period = 1 if qdate >= yq(2004,4) & qdate <= yq(2007,2)
	replace period = 0 if qdate >= yq(2008,4) & qdate <= yq(2009,2)
	keep if !missing(period) 
	collapse (sum) allocamt, by(gvkey conm period)
	
	*Compute the change
	reshape wide allocamt, i(gvkey conm) j(period)
	replace allocamt0 = 0 if missing(allocamt0)
	generate chg_lending_gfc = allocamt0/(allocamt1/3)-1
	
	*Saves as temporary file --> gets merged-in later
	keep gvkey chg_lending_gfc
	tempfile lending_decline
	save `lending_decline'
restore

****************
*Compute non-bank dependence (collapse to bank level)
****************

*Entire loan amount - Only loans where bank is lead arranger	
preserve
	keep if leadarrangercredit == "Yes"
	collapse (count) countl_leads =allocamt (sum) suml_leads = allocamt  (mean) means_lead = allindrawn, by(gvkey year)
	tempfile lead_loans
	save	`lead_loans'
restore

*Entire amount - Compute weighted average
preserve
	keep if leadarrangercredit == "Yes"
	collapse (mean) nonbankd_lead_no =deal_instTL [aweight=finalalloc], by(gvkey year)
	tempfile lead_loans2
	save	`lead_loans2'
restore

*Entire loan amount - All loans
collapse (firstnm) bank_first = bank (lastnm)  bank_last = bank conm ///
(count) count_loans=allocamt (sum) sum_loans=allocamt  (mean) mean_spread = allindrawn, by(gvkey year)

merge 1:1 gvkey year using `lead_loans' //263 bank x year observation are dropped because bank never functioned as lead arranger
drop _merge
merge 1:1 gvkey year using `lead_loans2'
drop _merge

sort gvkey year
order gvkey conm bank_first bank_last year
replace bank_last = "" if bank_first == bank_last
drop bank_last bank_first

*Merge-in the lending decline during the financial crisis
merge m:1 gvkey using `lending_decline'
drop _merge

****************
*Merge-in the Compustat variables
****************

preserve 
	use "$data\Intermediate Data\Combined_Compustat_Annual.dta", clear
	
	keep gvkey conm fyear datadate market_eq_ratio curncd
	
	drop if missing(gvkey)
	
	*Keep last observation per year
	rename fyear year
				//generate year = year(datadate)
	bysort gvkey year (datadate): keep if _n == _N //No observations deleted
	drop datadate

	tempfile compustat_information
	save	`compustat_information'
restore

merge m:1 gvkey year using `compustat_information'
drop if _merge == 2
drop _merge


****************
*Filters
**************** 

*	1) focus on top banks
*	2) us banks
*	3) year 2006

*Compute total volume of loans where bank was lead arranger
bysort gvkey: egen total20yr_volumelead = total(suml_leads)
replace total20yr_volumelead = total20yr_volumelead / 10^6

*Generate ranking in terms of volume for lead arranger over entire sample
preserve
	keep gvkey total20yr_volumelead
	duplicates drop 
	gsort -total20yr_volumelead
	generate rk_vol = _n
	tempfile rank_in_volume
	save	`rank_in_volume'
restore 
merge m:1 gvkey using `rank_in_volume'
drop if _merge == 2
drop _merge

*Focus on the largest lead arrangers
keep if rk_vol <= 43

*Focus on US banks
keep if curncd == "USD"
drop if conm == "HSBC HLDGS PLC"
drop if conm == "BANK OF NEW YORK MELLON CORP" //following Schwert

*Focus on year 2006
keep if year == 2006

****************
*Banking indicator: investment, regional or universal bank
****************

generate type = ""
replace type = "IB" 		if conm == "GOLDMAN SACHS GROUP INC"
replace type = "IB" 		if conm == "MERRILL LYNCH & CO INC"
replace type = "IB" 		if conm == "BEAR STEARNS COMPANIES INC"
replace type = "IB" 		if conm == "MORGAN STANLEY"
replace type = "IB" 		if conm == "JEFFERIES GROUP LLC"
replace type = "IB" 		if conm == "BANK OF AMERICA CORP"
replace type = "IB" 		if conm == "LEHMAN BROTHERS HOLDINGS INC"
replace type = "IB" 		if conm == "NOMURA HOLDINGS INC"

replace type = "Universal" 	if conm == "JPMORGAN CHASE & CO"
replace type = "Universal"	if conm == "CITIGROUP INC"
replace type = "Universal" 	if conm == "WACHOVIA CORP"
replace type = "Universal" 	if conm == "BANK OF AMERICA CORP"
replace type = "Universal" 	if conm == "WELLS FARGO & CO"

replace type = "Regional" 	if conm == "CAPITAL ONE FINANCIAL CORP"
replace type = "Regional" 	if conm == "FIFTH THIRD BANCORP"
replace type = "Regional" 	if conm == "REGIONS FINANCIAL CORP"
replace type = "Regional" 	if conm == "US BANCORP"
replace type = "Regional" 	if conm == "PNC FINANCIAL SVCS GROUP INC"
replace type = "Regional" 	if conm == "KEYCORP"
replace type = "Regional" 	if conm == "SUNTRUST BANKS INC"

replace type = "Nonbank" if conm == "GENERAL ELECTRIC CAP CORP"
replace type = "Nonbank" if conm == "CIT GROUP INC"

*Bank type
generate inv_bank = 		(type == "IB")
generate regional_bank = 	(type == "Regional")
generate nonbank = 			(type == "Nonbank")

*Labelling of banks
generate label_name = conm
replace label_name = proper(label_name)
replace label_name = subinstr(label_name, " Corp ", "", .) 	
replace label_name = subinstr(label_name, " & Co", "", .) 
replace label_name = subinstr(label_name, " Inc", "", .) 
replace label_name = subinstr(label_name, " Corp", "", .) 	
replace label_name = subinstr(label_name, "Inc", "", .) 
replace label_name = subinstr(label_name, " Llc", "", .)
replace label_name = subinstr(label_name, "Jpmorgan", "JPMorgan", .)
replace label_name = subinstr(label_name, " Group", "", .)
replace label_name = subinstr(label_name, " Holdings", "", .)
replace label_name = subinstr(label_name, " Financial", "", .)
replace label_name = subinstr(label_name, " Companies", "", .)
replace label_name = subinstr(label_name, "Keycorp", "KeyBank", .)
replace label_name = subinstr(label_name, "Us", "US", .)
replace label_name = subinstr(label_name, "Pnc", "PNC", .)
replace label_name = subinstr(label_name, "Of", "of", .)
replace label_name = subinstr(label_name, "Svcs", "", .)
replace label_name = subinstr(label_name, "Suntrust", "SunTrust", .)
replace label_name = subinstr(label_name, "Bancorp", "Bank", .)

*Figure
twoway /// *
(scatter nonbankd_lead_no market_eq_ratio  	if type == "IB" & label_name != "Goldman Sachs" & label_name != "Lehman Brothers", mlabel(label_name)) || ///
(scatter nonbankd_lead_no market_eq_ratio  	if type == "Universal" & label_name != "Citigroup", mlabel(label_name)) || ///	
(scatter nonbankd_lead_no market_eq_ratio  	if type == "Regional" & label_name != "Regions", mlabel(label_name)) || ///
(scatter nonbankd_lead_no market_eq_ratio  	if label_name == "Goldman Sachs", mlabel(label_name) mlabposition(2) mcolor(dkgreen) mlabcolor(dkgreen)) || ///
(scatter nonbankd_lead_no market_eq_ratio  	if label_name == "Lehman Brothers", mlabel(label_name) mlabposition(4) mcolor(dkgreen) mlabcolor(dkgreen)) || ///
(scatter nonbankd_lead_no market_eq_ratio  	if label_name == "Citigroup", mlabel(label_name) mlabposition(6) mlabcolor(orange_red) mcolor(orange_red)) || ///
(scatter nonbankd_lead_no market_eq_ratio  	if label_name == "Regions", mlabel(label_name) mlabposition(12) mlabcolor(navy) mcolor(navy)) || ///
(lfit  nonbankd_lead_no market_eq_ratio, lcolor(black)), ///
ytitle("Nonbank dependence in 2006") xtitle("Bank Capital in 2006") xlabel(0.05(0.05)0.27) ///
legend(order(1 "Investment banks" 2 "Universal banks" 3 "Regional banks") col(1) ring(0) pos(2) size(*0.8))
graph export "$figures/figure3.pdf", replace

log close  