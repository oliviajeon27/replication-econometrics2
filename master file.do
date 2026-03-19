set more off
clear all 
set scheme s1color

*** change here!!!!! ********************************************************
global package "C:\Users\Eunkyung\ASU Dropbox\Eunkyung Jeon\2026-1\econometrics\12. replicate\nonbank lending and credit cyclicality"
*****************************************************************************

global data `"$package\data"'
global code `"$package\code"'
global figures `"$package\figures"'
global tables `"$package\tables"'


******************************************************************************
* clean raw datasets
******************************************************************************

cd "$package/code/code_data"

*check if I need dealscan old for generating figure/table
do "1a_dealscan_old_load.do"
do "1b_dealscan_old_main_facility.do"
do "1c_dealscan_old_cr_replication.do"


do "2_main_facility_new_DS.do" 

do "3a_clo_capital_structure.do"
do "3b_clo_bank_leverage_panel.do"
do "3c_clo_bank_spread_panel.do"

do "4a_aggregate_AuM.do"
do "4b_nonbank_lender_composition.do"

******************************************************************************
* result
******************************************************************************

cd "$package/code/code_results

***** Figures
do "dofile figure2.do"
do "dofile figure3.do"
do "dofile figure4.do"
do "dofile figure5.do"
do "dofile figure6.do"
do "dofile figure7.do"

graph close

***** Tables
do "dofile table1.do"
do "dofile table2.do"
do "dofile table3.do"
do "dofile table4.do"
do "dofile table5.do"
do "dofile table6.do"
do "dofile table7.do"
do "dofile table8.do"
do "dofile table9.do"

