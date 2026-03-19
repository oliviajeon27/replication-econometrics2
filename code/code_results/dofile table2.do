******************************************************************************
******************************************************************************
** This file creates Table 2
** in "Nonbank Lending and Credit Cyclicality" by Fleckenstein et. al. (2024)
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
replace ranking = 999 if bank == "Aggregate Market" //market is last line, not first line
replace market_share = 1 if bank == "Aggregate Market"

*Bank dependence
generate b_dep_no = 1 - nb_dep_no

*Compute the contributions to the declines in lending for banks and nonbanks
generate contribution_nb_no = (nb_dep_no * lenchg_nb_no)/lenchg_tot_no
generate contribution_b_no = ((1-nb_dep_no) * lenchg_b_no)/lenchg_tot_no

label var bank                 "Bank"
label var lenchg_tot_no        "$\Delta$ Loans in all deals"
label var lenchg_nb_no         "$\Delta$ Loans in nonbank deals"
label var nb_dep_no            "Nonbank dependence"
label var lenchg_b_no          "$\Delta$ Loans in bank deals"
label var b_dep_no             "Bank dependence"
label var contribution_nb_no   "Nonbank contribution"
label var contribution_b_no    "Bank contribution"
label var market_share         "Market share" //variable name

order 	ranking bank lenchg_tot_no lenchg_nb_no nb_dep_no lenchg_b_no b_dep_no contribution_nb_no contribution_b_no market_share
keep 	ranking bank lenchg_tot_no lenchg_nb_no nb_dep_no lenchg_b_no b_dep_no contribution_nb_no contribution_b_no market_share

/*
*labmask ranking, values(bank)
preserve //instead of labmask
keep ranking bank
duplicates drop
sort ranking

capture label drop ranking_lbl
levelsof ranking, local(ranks)

foreach r of local ranks {
    quietly levelsof bank if ranking == `r', local(lbl)
    label define ranking_lbl `r' `"`lbl'"', add
}
restore

label values ranking ranking_lbl

compress
estpost tabstat lenchg_tot_no  lenchg_nb_no nb_dep_no lenchg_b_no b_dep_no contribution_nb_no contribution_b_no market_share, by(ranking) 

esttab using "$tables/table2.tex", cells("lenchg_tot_no(fmt(%8.2f))   lenchg_nb_no(fmt(%8.2f))  nb_dep_no(fmt(%8.2f)) lenchg_b_no(fmt(%8.2f)) b_dep_no(fmt(%8.2f)) contribution_nb_no(fmt(%8.2f))  contribution_b_no(fmt(%8.2f)) market_share(fmt(%8.3f)) ") noobs nomtitle ///
nonumber varlabels(`e(labels)') varwidth(30) drop("Total") ///
collab(, lhs("`:var lab bank'")) tex replace	
*/

sort ranking
drop ranking
compress

format lenchg_tot_no        %9.2f
format lenchg_nb_no         %9.2f
format nb_dep_no            %9.2f
format lenchg_b_no          %9.2f
format b_dep_no             %9.2f
format contribution_nb_no   %9.2f
format contribution_b_no    %9.2f
format market_share         %9.3f

listtex bank lenchg_tot_no lenchg_nb_no nb_dep_no lenchg_b_no b_dep_no ///
        contribution_nb_no contribution_b_no market_share ///
    using "$tables/table2.tex", replace rstyle(tabular) ///
    head("\begin{tabular}{lcccccccc} \hline\hline" ///
         "Bank & $\Delta$ Loans in all deals & $\Delta$ Loans in nonbank deals & Nonbank dependence & $\Delta$ Loans in bank deals & Bank dependence & Nonbank contribution & Bank contribution & Market share \\ \hline") ///
    foot("\hline\hline \end{tabular}") //show the name directly in table

log close
