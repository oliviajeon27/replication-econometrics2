clear all

************ DESCRIPTION: ****************************************************
* Allocates facility balances to lenders following Chodorow-Reich (2013)
* 
* We use a three-stage strategy: 
*   - first, we allocate based on the reported allocation in the data
* 	- next, we allocate based on the number of participating banks and their role
*	  to match the allocation in similar deals
* 	- last, we allocate by number of banks and their role in deal

*******************************************************************************   


use "$data/final data/oldDS_main_facility_dataset", clear


* identify facilities with reported allocation
egen totallocation = sum(bankallocation), by(facilityid)
drop if totallocation < 98 | totallocation > 102
keep facilityid
bys facilityid : keep if _n == 1
save "$data/temp/fac_temp", replace

*

/* ------------------------------------------------ */
/*  I/ COMPUTE ALLOCATION BY # OF LENDERS AND ROLES */
/* ------------------------------------------------ */

use "$data/final data/oldDS_main_facility_dataset", clear
keep facilityid lender lenderrole bankallocation 
sort facilityid

* Count lenders by role 
egen nlen = count(facilityid), by(facilityid lenderrole)
drop lender
rename bankallocation alloc

* Compute mean allocation by lender role and reshape across lenderroles 
collapse (mean) alloc*, by(facilityid lenderrole nlen )
encode lenderrole, gen(lcode)
drop lenderrole 
reshape wide alloc nlen, i(facilityid ) j(lcode)

* Define and store lookup keys (combination of # of lenders and roles) by facility
order facilityid alloc* nlen*
egen nkey = concat(nlen*), p(" ")
save "$data/temp/exactmappingkeys", replace

* Keep facilities with full allocations and compute average shares by key 
merge 1:1 facilityid using "$data/temp/fac_temp"
drop if _merge ~= 3
drop _merge
drop nlen* facilityid
collapse (mean) alloc*, by(nkey)

* NOTE: Amounts must be normalized in allocation to ensure all loans are allocated at 100
reshape long alloc, i(nkey) 
drop if alloc == .
rename alloc alloc_exact
decode _j, g(lenderrole)
drop _j
save "$data/temp/exact_alloc", replace

*

/* ----------------------------------------------- */
/*  II/ COMPUTE ALLOCATION BY # OF BANKS AND ROLES */
/* ----------------------------------------------- */

use "$data/final data/oldDS_main_facility_dataset", clear
keep facilityid lender bankallocation agentcredit leadarrangercredit
sort facilityid

* Count lenders by role (see above)
g lendertype = "Other"
replace lendertype = "Arranger" if leadarrangercredit =="Yes"
replace lendertype = "Agent" if agentcredit =="Yes" & leadarrangercredit == "No"
egen nlenders = count(facilityid), by(facilityid lendertype)
rename bankallocation alloc
drop lender agentcredit leadarrangercredit

* Compute mean allocation by lender role and reshape across lenderroles 
collapse (mean) alloc, by(facilityid lendertype nlenders)
encode lendertype, gen(lcode)
drop lendertype 
reshape wide alloc nlenders, i(facilityid) j(lcode)

* Define and store lookup keys (combination of # of lenders and roles) by facility
order facilityid alloc* nlen*
egen credkey = concat(nlen*), p(" ")
save "$data/temp/creditmappingkeys", replace

* Keep facilities with full allocations and compute average shares by key 
merge 1:1 facilityid using "$data/temp/fac_temp"
drop if _merge ~= 3
drop nlen* facilityid
collapse (mean) all*, by(credkey )

reshape long alloc, i(credkey ) 
drop if alloc == .
rename alloc alloc_cred
decode _j, g(lendertype)
drop _j
save "$data/temp/cred_alloc", replace

***

/* -------------------------------*/
/* 		IMPLEMENT ALLOCATION	  */
/* -------------------------------*/
use "$data/final data/oldDS_main_facility_dataset", clear
 
* Map to exact allocation 
merge m:1 facilityid using "$data/temp/exactmappingkeys", keepusing(nkey) nogen
joinby nkey lenderrole using "$data/temp/exact_alloc", unm(master) 
drop _m

* Map to credit-based allocation 
merge m:1 facilityid using "$data/temp/creditmappingkeys", keepusing(credkey) nogen
g lendertype = "Other"
replace lendertype = "Arranger" if leadarrangercredit == "Yes"
replace lendertype = "Agent" if agentcredit =="Yes" & leadarrangercredit == "No"
joinby credkey lendertype using "$data/temp/cred_alloc", unm(master) 
drop _m

g finalalloc = bankallocation
replace finalalloc = alloc_exact if bankallocation == .
replace finalalloc = alloc_cred if bankallocation== . & alloc_exact == .
egen nlenders = count(facilityid) , by(facilityid) 
replace finalalloc = 100*(1/nlenders) if finalalloc == . // 829 facilities mapped this way 

* Generate lead based allocation
g lead = leadarrangercredit == "Yes"
egen nleads = sum(lead), by(facilityid)
g leadalloc = 1/nleads if lead == 1

* Normalize to add to 100 if not direct bank allocation
egen totallocation =sum(finalalloc), by(facilityid)
replace finalalloc = finalalloc*(100/totallocation) if totallocation ~= 100
drop totallocation 
replace finalalloc = finalalloc/100

keep facilityid lender finalalloc
drop if finalalloc == .
compress
save "$data/Intermediate Data/oldDS_allocation", replace

erase "$data/temp/fac_temp.dta"
erase "$data/temp/exactmappingkeys.dta"
erase "$data/temp/creditmappingkeys.dta"
erase "$data/temp/exact_alloc.dta"
erase "$data/temp/cred_alloc.dta"


