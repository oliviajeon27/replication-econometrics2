clear all
tempfile tfile

************ DESCRIPTION: CONSTRUCT MAIN ANALYSIS FILE ************************
* Consolidates Dealscan datasets into a facility-level containing 
* all relevant information: 
* - borrowing company information 
* - facility characteristics
* - facility pricing
* - package details
* - lenders 
*******************************************************************************   

global project "C:\Users\ejeon8.ASURITE\ASU Dropbox\Eunkyung Jeon\2026-1\econometrics\12. replicate\nonbank lending and credit cyclicality"
global data "$project\data"
global code "$project\code"
global result "$project\result"

/* ------------------------ */
/* 		DATA CONSOLIDATION 	*/
/* ------------------------ */

****** FACILITIES ***** 

* COMPANY 
use "$data/Raw data/dealscan_old/company", clear
rename companyid borrowercompanyid
save tfile, replace

* FACILITY
use "$data/Raw data/dealscan_old/facility", clear
merge m:1 borrowercompanyid using tfile, keep(matched master) nogen
rename ultimateparentid borrowerparentid
save tfile, replace

* PRICING
use "$data/Raw data/dealscan_old/pricing",clear
bys facilityid: keep if _n ==1
keep facilityid allindrawn
merge 1:1 facilityid using tfile, nogen // Not all facilities in pricing dataset
save tfile, replace

* PACKAGES 
use "$data/Raw data/dealscan_old/package", clear
keep packageid salesatclose	dealamount dealpurpose
merge 1:m packageid using tfile, nogen keep(matched using)
save tfile, replace


**


****** LENDERS *****

* LENDER

* lender information
use "$data/Raw data/dealscan_old\lenders", clear
rename *, lower
merge m:1 companyid using "$data/Raw data/dealscan_old/company", keepusing(parentid ultimateparentid institutiontype primarysiccode) keep(master matched) nogen
rename primarysiccode lendersiccode

**

* LENDER ULTIMATE PARENT
rename companyid lenderid
rename institutiontype tempinstitutiontype
rename ultimateparentid companyid
merge m:1 companyid using "$data/Raw data/dealscan_old/company", keepusing(institutiontype company) keep(master matched) nogen
rename institutiontype upinstitutiontype
rename company uparent
rename companyid uparentid
rename tempinstitutiontype institutiontype 


* LENDER PARENT
rename parentid companyid
merge m:1 companyid using "$data/Raw data/dealscan_old/company", keepusing(company) keep(master matched) nogen
rename company parent
rename companyid parentid

**

****** COMBINE FACILITIES AND LENDERS *****

* Some facilities missing in lender dataset. Checked some directly on WRDS and are not available
merge m:1 facilityid using tfile, keep(matched) nogen 
erase tfile.dta
				 				
save "$data/Intermediate data/oldDS_raw_facility_dataset", replace


