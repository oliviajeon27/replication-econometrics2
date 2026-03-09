******************************************************************************
******************************************************************************
** This file creates AuM of different funds: Bank vs. Nonbank Lending
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
global code `"$package\tables"'


capture log close
log using "$package/logs/prep_aggregate_AuM.log", replace


******************************************************************************
* load Open End fund data *
import 		excel "$data\Raw Data\morningstar\Morningstar_OpenEnd_AuM_PerShareClass_Loans_March2022.xlsx", sheet("AuM_2") cellrange(A2) firstrow clear

* rename variables *
rename	Fund date

* restrict sample period *
drop 	if date >= mdy(1,1,2022)

* Convert into AuM into millions *
foreach x of varlist FOUSA05DIS-FOUSA00JDW {
replace `x' = `x' / 10^6
}

* Convert into a long data set *
foreach x of varlist FOUSA05DIS-FOUSA00JDW {
rename `x' aum_`x'
}
reshape long aum_, i(date) j(secid) string
rename aum_ aum

* Compute aggregate assets under management *
collapse (sum) aum, by(date)
replace aum = aum / 10^3  //Convert AuM to billions

* Save the aum of open-end mutual funds in a temporary file
rename aum aum_open
label var aum_open "Open-end mutual funds AuM"
tempfile 	aum_open
save	 	`aum_open', replace
	
******************************************************************************
* load Closed End fund data *
import 		excel "$data\Raw Data\morningstar\Morningstar_ClosedEnd_AuM_Loans_March2022.xlsx", sheet("AuM_2") cellrange(A2) firstrow clear

* rename variables *
rename	Fund date

* restrict sample period *
drop 	if date >= mdy(1,1,2022)

* Create date-identifier *
sort date
generate id = _n
order date id
	
* Convert into AuM into millions *
foreach x of varlist FCUSA04ACI-F00000VCT2 {
replace `x' = `x' / 10^6
}	

* Convert into a long data set *
foreach x of varlist FCUSA04ACI-F00000VCT2 {
rename `x' aum_`x'
}
reshape long aum_, i(date) j(secid) string
rename aum_ aum
sort secid date

* Drop funds where too many values are missings *
drop if secid == "FCUSA04AG2"
drop if secid == "F00000Z3DJ"
drop if secid == "F00000ZBSX"
drop if secid == "F00000ZBSY"
drop if secid == "F000013VY4"
drop if secid == "F000011SON"

* Interpolate missing values *
bysort secid (date): ipolate aum id, g(aum_ipolated) 

* If one of the last two values is missing, replace it with the previous value *
replace aum_ipolated = aum_ipolated[_n-1] if missing(aum_ipolated) & date == mdy(1,31,2020)
replace aum_ipolated = aum_ipolated[_n-1] if missing(aum_ipolated) & date == mdy(2,29,2020)
replace aum_ipolated = aum_ipolated[_n-1] if missing(aum_ipolated) & date == mdy(3,31,2020)	

* Use only the interpolated assets under management values *
drop aum
rename aum_ipolated aum_closed
	
* Compute aggregate assets under management * 
collapse (sum) aum_closed, by(date)
replace aum_closed = aum_closed / 10^3 //Convert AuM to billions

* Save the aum of closed-end mutual funds in a temporary file *
label var aum_closed "Closed-end mutual funds AuM"
tempfile 	aum_closed
save	 	`aum_closed', replace	

	
******************************************************************************
* load Loan ETF data *
import 		excel "$data\Raw Data\morningstar\Morningstar_ETF_AuM_Loans_March2022.xlsx", sheet("AuM_2") cellrange(A2) firstrow clear

* rename variables *
rename	Fund date

* restrict sample period *
drop 	if date >= mdy(1,1,2022)

* Convert into AuM into millions
foreach x of varlist F00000M1JE-F00000XAYE {
replace `x' = `x' / 10^6
}

* Convert into a long data set
foreach x of varlist F00000M1JE-F00000XAYE {
rename `x' aum_`x'
}
reshape long aum_, i(date) j(secid) string
rename aum_ aum
sort secid date 

* Compute aggregate assets under management
collapse (sum) aum, by(date)
replace aum = aum / 10^3 //Convert AuM to billions
	
* Save the aum of ETFs in a temporary file
rename aum aum_etf
label var aum_etf "ETFs, AuM"
tempfile 	aum_etf
save	 	`aum_etf', replace	

	
	
******************************************************************************
* load Separata Accounts data *
import 		excel "$data\Raw Data\morningstar\Morningstar_SeparateAccounts_AuM_Loans_March2022.xlsx", sheet("AuM_2") cellrange(A2) firstrow clear

* rename variables *
rename	Fund date

* restrict sample period *
drop 	if date >= mdy(1,1,2022)

* Create date-identifier *
sort date
generate id = _n
order date id

* Convert into AuM into millions *
foreach x of varlist F00000V2QH-F00000WP41 {
replace `x' = `x' / 10^6
}

* Convert into a long data set *
foreach x of varlist F00000V2QH-F00000WP41 {
rename `x' aum_`x'
}
reshape long aum_, i(date id) j(secid) string
rename aum_ aum
sort secid date
	
* Interpolate missing values *
bysort secid (date): ipolate aum id, g(aum_ipolated) 

* If one of the last two values is missing, replace it with the previous value *
replace aum_ipolated = aum_ipolated[_n-1] if missing(aum_ipolated) & date == mdy(1,31,2020)
replace aum_ipolated = aum_ipolated[_n-1] if missing(aum_ipolated) & date == mdy(2,29,2020)
replace aum_ipolated = aum_ipolated[_n-1] if missing(aum_ipolated) & date == mdy(3,31,2020)	

* Use only the interpolated assets under management values *
drop aum
rename aum_ipolated aum_sp
	
* Compute aggregate assets under management * 
collapse (sum) aum_sp, by(date)
replace aum_sp = aum_sp / 10^3 //Convert AuM to billions
		
* Save the aum of separate accounts in a temporary file * 
keep date aum_sp
label var aum_sp "Separate Accounts, AuM"
tempfile 	aum_sp
save	 	`aum_sp', replace
	
	
******************************************************************************
* Combine all information *

* load and add AuMs by fund type *
clear all
use `aum_open'
merge 1:1 date using `aum_closed', nogen
merge 1:1 date using `aum_etf', nogen
merge 1:1 date using `aum_sp', nogen

* generate total Fund AuM *
generate aum_all = aum_open + aum_etf + aum_sp + aum_closed
label var aum_all "All vehicles, AuM"

* save file *
compress
save "$data\Intermediate Data\AggregateAuM", replace	

	

	
	
	
	
	

