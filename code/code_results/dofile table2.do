******************************************************************************
******************************************************************************
** This file creates Table 2
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
log using "$package/logs/table2.log", replace

******************************************************************************	
use "$data/final data/GFC_data.dta", clear
keep bank lenchg_tot_no lenchg_nb_no nb_dep_no lenchg_b_no no_tot_pre no_nb_pre no_b_pre no_tot_gfc no_nb_gfc no_b_gfc
					
*** Extensive margin (number of loans)
*Compute the numbers for the entire loan market
preserve 
	collapse (sum) no_tot_pre no_nb_pre no_b_pre no_tot_gfc no_nb_gfc no_b_gfc
	generate bank = "Aggregate Market"
	
	*Compute nonbank dependence and the lending declines
		*Compute lending changes
		generate lenchg_tot_no = no_tot_gfc / (no_tot_pre/2) - 1
		generate lenchg_b_no = no_b_gfc / (no_b_pre/2) - 1
		generate lenchg_nb_no = no_nb_gfc / (no_nb_pre/2) - 1

		*Compute nonb dependence prior to the gfc
		generate nb_dep_no = no_nb_pre/no_tot_pre	
	
	*Save as temporary file
	tempfile entire_market
	save	`entire_market'
restore
			
*Generate market share
egen tot_no_allbanks = total(no_tot_pre)
generate market_share = no_tot_pre / tot_no_allbanks
gsort -market_share
generate ranking = _n

*Keep only the top 20 banks for the table
keep if ranking <= 20

*Merge-in the entire loan market
append using `entire_market'
replace ranking = 0 if bank == "Aggregate Market"
replace market_share = 1 if bank == "Aggregate Market"

*Bank dependence
generate b_dep_no = 1 - nb_dep_no

*Compute the contributions to the declines in lending for banks and nonbanks
generate contribution_nb_no = (nb_dep_no * lenchg_nb_no)/lenchg_tot_no
generate contribution_b_no = ((1-nb_dep_no) * lenchg_b_no)/lenchg_tot_no

order 	ranking bank lenchg_tot_no lenchg_nb_no nb_dep_no lenchg_b_no b_dep_no contribution_nb_no contribution_b_no market_share
keep 	ranking bank lenchg_tot_no lenchg_nb_no nb_dep_no lenchg_b_no b_dep_no contribution_nb_no contribution_b_no market_share
labmask ranking, values(bank)
compress
estpost tabstat lenchg_tot_no  lenchg_nb_no nb_dep_no lenchg_b_no b_dep_no contribution_nb_no contribution_b_no market_share, by(ranking) 

esttab using "$tables/table2.tex", cells("lenchg_tot_no(fmt(%8.2f))   lenchg_nb_no(fmt(%8.2f))  nb_dep_no(fmt(%8.2f)) lenchg_b_no(fmt(%8.2f)) b_dep_no(fmt(%8.2f)) contribution_nb_no(fmt(%8.2f))  contribution_b_no(fmt(%8.2f)) market_share(fmt(%8.3f)) ") noobs nomtitle ///
nonumber varlabels(`e(labels)') varwidth(30) drop("Total") ///
collab(, lhs("`:var lab bank'")) tex replace	

log close
