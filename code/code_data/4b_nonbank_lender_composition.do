******************************************************************************
******************************************************************************
** This file creates the nonbank lender composition file: Bank vs. Nonbank Lending
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
log using "$package/logs/nonbank_lender_composition.log", replace


******************************************************************************

*SNC Data: Import size of the loan market and size of nonbanks
import excel "$data\Raw Data\snc\size of loanmarket.xlsx", clear firstrow

drop D G H I J K L M 
rename *, lower
rename nonbanksharefortotalcommitme nonbankshare

*SIFMA data: Size of CLO Market
preserve
	import excel "$data\Raw Data\sifma\US-Asset-Backed-Securities-Statistics-SIFMA.xlsx", sheet("USD CDO CLO Outstanding") clear cellrange(A10:C43) firstrow
	
	drop CDO 
	rename *, lower	
	rename date year
	rename clo clo_sifma
	
	tempfile clo_sifma
	save	`clo_sifma'
restore

merge 1:1 year using `clo_sifma', nogen

*Morningstar data: Size of Loan Mutual Funds
preserve
	//Load Morninstar flow data
	use "$data\Intermediate Data\AggregateAuM.dta", clear

	*Keep Q2 values
	generate month = month(date)
	keep if month == 12
	
	*Generate year
	generate year = year(date)
	drop month date
	
	rename aum_all aum_mutualfunds
	
	//Temporary file
	tempfile mutual_funds_morningstar
	save `mutual_funds_morningstar'
restore

merge 1:1 year using `mutual_funds_morningstar', nogen


* Compute the CLO share and CLO + MF share of nonbank loans *
generate clo_nonbank = clo_sifma / totalnonbankcommitments
generate mutualfunds_plus_clo = aum_mutualfunds + clo_sifma
generate clo_funds_nonbank = mutualfunds_plus_clo / totalnonbankcommitments

* save file *
save 	"$data\Final Data\nonbank_lender_composition.dta", replace