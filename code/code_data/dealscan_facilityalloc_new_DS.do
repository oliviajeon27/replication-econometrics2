******************************************************************************
******************************************************************************

************ DESCRIPTION: Loan Share Allocation ************************
*
* Creates lender x facility-level dataset. Code must be run within the main_facility_new_DS code
* The loan share allocation follows the approach by Chodorow-Reich (2014)
* 
******************************************************************************* 
******************************************************************************
******************************************************************************
/* ---------------------------- */
/* 		FACILITY ALLOCATION  	*/
/* ---------------------------- */

* Compute and store list of facilities with near complete allocation data 
use "$data\Intermediate Data\facility_dataset_new_DS.dta", clear
replace lender_share = "" if lender_share=="N/A"
destring lender_share, replace
egen totallocation = sum(lender_share), by(lpc_tranche_id tranche_active_date)  // note: with new DS now defined by id + date
drop if totallocation < 98 | totallocation > 102
keep lpc_tranche_id tranche_active_date
bys lpc_tranche_id tranche_active_date : keep if _n == 1
save "$data\Intermediate Data\fac_temp.dta", replace

** I/ ALLOCATION BY EXACT MAPPING *** 
use "$data\Intermediate Data\facility_dataset_new_DS.dta", clear
keep lpc_tranche_id tranche_active_date lender_name primary_role lender_share 
sort lpc_tranche_id tranche_active_date

* Count lenders by role 
egen	facilityid_new_DS = group(lpc_tranche_id tranche_active_date)
egen nlen = count(facilityid_new_DS), by(facilityid_new_DS primary_role)
drop lender_name
replace lender_share = "" if lender_share=="N/A"
destring lender_share, replace
rename lender_share all

* Compute mean allocation by lender role and reshape across lenderroles 
collapse (mean) all*, by(facilityid_new_DS  lpc_tranche_id tranche_active_date primary_role nlen )
encode primary_role, gen(lcode)
drop primary_role 
reshape wide all nlen, i(facilityid_new_DS lpc_tranche_id tranche_active_date ) j(lcode)

* Define and store lookup keys (combination of # of lenders and roles) by facility
order lpc_tranche_id tranche_active_date facilityid_new_DS  all* nlen*
egen nkey = concat(nlen*), p(" ")
save "$data\Intermediate Data\exactmappingkeys.dta", replace

* Keep facilities with full allocations and compute average shares by key 
merge 1:1 lpc_tranche_id tranche_active_date using "$data\Intermediate Data\fac_temp.dta"
drop if _merge ~= 3
drop _merge
drop nlen* facilityid
collapse (mean) all*, by(nkey)

* NOTE: Amounts must be normalized in allocation to ensure all loans are allocated at 100
reshape long all, i(nkey) 
drop if all == .
rename all all_exact
decode _j, g(primary_role)
drop _j
save "$data\Intermediate Data\exact_alloc.dta", replace

** II/ ALLOCATION BY CREDIT *** 
use "$data\Intermediate Data\facility_dataset_new_DS.dta", clear
keep lpc_tranche_id tranche_active_date lender_name primary_role lender_share league_table_credit
sort lpc_tranche_id tranche_active_date

* Count lenders by role (see above)
g lendertype = "Other"
replace lendertype = "Arranger" if league_table_credit =="Yes"
egen	facilityid_new_DS = group(lpc_tranche_id tranche_active_date)
egen nlenders = count(facilityid_new_DS), by(facilityid_new_DS lendertype)
replace lender_share = "" if lender_share=="N/A"
destring lender_share, replace
rename lender_share all
drop lender_name league_table_credit


* Compute mean allocation by lender role and reshape across lenderroles 
collapse (mean) all, by(facilityid_new_DS lpc_tranche_id tranche_active_date primary_role nlenders)
encode primary_role, gen(lcode)
drop primary_role 
duplicates drop facilityid_new_DS lpc_tranche_id tranche_active_date lcode, force 
reshape wide all nlenders, i(facilityid_new_DS lpc_tranche_id tranche_active_date) j(lcode)

* Define and store lookup keys (combination of # of lenders and roles) by facility
order lpc_tranche_id tranche_active_date facilityid_new_DS all* nlen*
egen credkey = concat(nlen*), p(" ")
save "$data\Intermediate Data\creditmappingkeys.dta", replace

* Keep facilities with full allocations and compute average shares by key 
merge 1:1  lpc_tranche_id tranche_active_date using "$data\Intermediate Data\fac_temp.dta" 
drop if _merge ~= 3
drop nlen* facilityid
collapse (mean) all*, by(credkey )

reshape long all, i(credkey ) 
drop if all == .
rename all all_cred
decode _j, g(lendertype)
drop _j
save "$data\Intermediate Data\cred_alloc.dta", replace

erase "$data\Intermediate Data\fac_temp.dta"

***
/* -------------------------------*/
/* Map allocation to main dataset */
/* -------------------------------*/
use "$data\Intermediate Data\facility_dataset_new_DS.dta", clear
 
* Map to exact allocation 
merge m:1 lpc_tranche_id tranche_active_date using "$data\Intermediate Data\exactmappingkeys.dta", keepusing(nkey) nogen
joinby nkey primary_role using "$data\Intermediate Data\exact_alloc.dta", unm(master) 
drop _m

* Map to credit-based allocation 
merge m:1 lpc_tranche_id tranche_active_date using "$data\Intermediate Data\creditmappingkeys.dta", keepusing(credkey) nogen
g lendertype = "Other"
replace lendertype = "Arranger" if league_table_credit =="Yes"
joinby credkey lendertype using "$data\Intermediate Data\cred_alloc.dta", unm(master) 
drop _m

replace lender_share = "" if lender_share=="N/A"
destring lender_share, replace
g finalalloc = lender_share
replace finalalloc = all_exact if lender_share == .
replace finalalloc = all_cred if lender_share== . & all_exact == .
egen	facilityid_new_DS = group(lpc_tranche_id tranche_active_date)
egen nlenders = count(facilityid_new_DS) , by(facilityid_new_DS)
drop	 facilityid_new_DS
replace finalalloc = 100*(1/nlenders) if finalalloc == .

* Normalize to add to 100 if not direct bank allocation
egen totallocation =sum(finalalloc), by(lpc_tranche_id tranche_active_date)
replace finalalloc = finalalloc*(100/totallocation) if totallocation ~= 100
drop totallocation 
replace finalalloc = finalalloc/100

keep lpc_tranche_id tranche_active_date lender_name finalalloc
drop if finalalloc == .
compress
recast str300 lender_name //necessary for merge after!
duplicates drop lender_name lpc_tranche_id tranche_active_date, force 
save "$data\Intermediate Data\allocation_new_DS.dta", replace

erase "$data\Intermediate Data\exactmappingkeys.dta"
erase "$data\Intermediate Data\creditmappingkeys.dta"
erase "$data\Intermediate Data\exact_alloc.dta"
erase "$data\Intermediate Data\cred_alloc.dta"


