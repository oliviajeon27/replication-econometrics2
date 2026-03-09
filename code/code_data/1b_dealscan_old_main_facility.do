clear all

************ DESCRIPTION: CONSTRUCT MAIN ANALYSIS FILE ************************
*
* Prepares facility-level dataset for analysis. 
*	- selects sample
*	- allocates facilities to lenders following CR
* 	- maps banks to account for mergers following CR
*	- identifies top 43 banks
*	- defines loan indicators
*	- merges Compsutat fields
* 
*******************************************************************************   

/* ------------------------- */
/* 		SAMPLE SELECTION	 */
/* ------------------------- */

use "$data/Intermediate Data/oldDS_raw_facility_dataset.dta", clear

* Apply filters
drop if country ~= "USA"
drop if ~strmatch(distributionmethod,"Syndication")

* clean and filter dates
g year = year(facilitystartdate)
gen qdate = qofd(facilitystartdate)
format qdate %tq
keep if facilitystartdate > td(01jan1995) & facilitystartdate~=.
keep if year <= 2019

* format amounts
replace facilityamt = facilityamt/1E6
format facilityamt %9.2g
replace dealamount = dealamount /1E6
format dealamount %9.2g

* drop FIRE: SIC codes 6011-6799
drop if inrange(primarysiccode,6000,6799)

* Drop borrowers with missing data
drop if facilitystartdate == . 
drop if primarysiccode == . 
drop if state == "" 
drop if publicprivate == ""

* winsorize sales
winsor2 sales, cuts(0 99) replace

save "$data/final data/oldDS_main_facility_dataset", replace

**

/* ------------------------ */
/* 	  ESTIMATE ALLOCATIONS	*/
/* ------------------------ */

* Run algorithm following CR
do "$code\code_data\dealscan_facilityalloc_old_DS".do

* Merge allocation
use "$data/final data/oldDS_main_facility_dataset",clear
merge 1:1 lender facilityid using "$data/Intermediate Data/oldDS_allocation", keepusing(finalalloc) nogen
g allocamt = facilityamt * finalalloc
save "$data/final data/oldDS_main_facility_dataset", replace

***

/* -------------------------- */
/*     MAP LENDERS FOR M&A	  */
/* -------------------------- */

***** IMPLEMENT M&A MAPPING *****
* Combines and/or separates lenders to account for M&A activity before and during the crisis
* We follow Chodorow-Reich (2013) in implementing this mapping
* See excel file below for additional details on the creation of the logic 
* for creating the mapping
import excel "$data/raw data/Mapping/Bank mapping_final.xlsx", sheet("Output") firstrow clear
merge 1:m lender using "$data/final data/oldDS_main_facility_dataset",nogen  keep(matched using) // all should match
rename mappedname mappedlender
replace mappedlender = uparent if mappedlender == ""
sleep 100
save "$data/final data/oldDS_main_facility_dataset", replace
	
**	

***** IDENTIFY LOANS MADE BY TOP 43 BANKS 
import excel "$data/Raw Data/website_chodorow_reich/final_bank_variables_adj.xls", firstrow clear
rename bank mappedlender
keep mappedlender 
merge 1:m mappedlender using "$data/final data/oldDS_main_facility_dataset"
g top43 = _merge == 3
drop _merge
save "$data/final data/oldDS_main_facility_dataset", replace

***		

/* ------------------------ */
/* 		ANALYSIS PERIODS 	*/
/* ------------------------ */
* Follow CR (pre crisis == 1, crisis == 3)
g period = 0
replace period = 1 if  facilitystartdate >= td(01oct2005) & facilitystartdate <= td(30june2006) & facilitystartdate~=.
replace period = 1 if  facilitystartdate >= td(01oct2006) & facilitystartdate <= td(30june2007) & facilitystartdate~=.
replace period = 2 if  facilitystartdate >= td(01oct2007) & facilitystartdate <= td(30june2008) & facilitystartdate~=.
replace period = 3 if  facilitystartdate >= td(01oct2008) & facilitystartdate <= td(30june2009) & facilitystartdate~=.

**

/* ------------------------ */
/* 		LOAN INDICATORS 	*/
/* ------------------------ */

* LOAN PURPOSE
g all = 1 
g corp = inlist(primarypurpose,"Corp. purposes","Work. cap.")
g rest = inlist(primarypurpose,"LBO","Merger","Acquis. line","Restructuring","Stock buyback")
g inv  = inlist(primarypurpose,"Corp. purposes" ,"Work. cap.","Capital expend.")

* DEAL PURPOSE
g deal_all = 1 
g deal_corp = inlist(dealpurpose,"Corp. purposes","Work. cap.")
g deal_rest = inlist(dealpurpose,"LBO","Merger","Acquis. line","Restructuring","Stock buyback")
g deal_inv  = inlist(dealpurpose,"Corp. purposes" ,"Work. cap.","Capital expend.")

* FACILITY TYPE
g term = inlist(loantype,"Term Loan", "Term Loan A", "Term Loan B", "Term Loan C", ///
						 "Term Loan D",  "Term Loan E", "Term Loan F", "Term Loan G")

g creditline = inlist(loantype,"Limited Line","Revolver/Line < 1 Yr.","Revolver/Line >= 1 Yr.")
g noncreditline = creditline == 0 

egen inc_creditline = max(creditline),by(package)
egen inc_term= max(term),by(package)
egen inc_noncreditline = max(noncreditline),by(package)

* NONBANK FACILITIES (nonbank = TLB-TLF)
g instTL = 0
replace instTL = 1 if inlist(loantype,"Term Loan B", "Term Loan C", ///
						 "Term Loan D",  "Term Loan E", "Term Loan F")
g noninstTL = instTL ~= 1

* DEAL TYPE (institutional = contains institutional facility)
egen deal_instTL = max(instTL),by(packageid)
g deal_noninstTL = deal_instTL ~= 1

save  "$data/final data/oldDS_main_facility_dataset", replace

***

/* ---------------------------- */
/* 	  ADD COMPUSTAT EMPLOYMENT  */
/* ---------------------------- */

* Load and prepare compustat
use "$data/Raw data/compustat/funda.dta", clear
keep gvkey datadate emp
destring gvkey,replace
keep if year(datadate) >= 1986
save "$data/temp/tfile", replace

* Load GVKEY-Dealscan map
import excel "$data/Raw Data/mapping/Dealscan-Compustat Linking Database_2018.xlsx", sheet("link_data") firstrow clear
keep gvkey bcoid facstartdate facid
destring gvkey, replace
sort gvkey

* Merge with compustat
joinby gvkey using "$data/temp/tfile"

* select last fiscal year prior to origination
g  ddate = datadate - facstartdate
drop if ddate > 0 
gsort facid -ddate 
bys facid: keep if _n == 1
drop ddate 

rename bcoid borrowercompanyid
rename facid facilityid

* Merge onto main dataset
merge 1:m borrowercompanyid facilityid using  "$data/final data/oldDS_main_facility_dataset"
drop if _m == 1
save "$data/final data/oldDS_main_facility_dataset", replace
***

/* ------------------------------------ */
/* 		CLEAN AND SAVE FILE				*/
/* ------------------------------------ */

* rename vars
rename mappedlender bank

* format dates
g qtr = quarter(dofq(qdate))
tostring year qtr, replace
g datestr =  year + "Q" + qtr
encode(datestr),g(qdateid)
destring year qtr, replace

* Save
compress
save "$data/final data/oldDS_main_facility_dataset", replace
erase "$data/temp\tfile.dta"

