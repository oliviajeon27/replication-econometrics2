******************************************************************************
******************************************************************************
** This file creates all the datasets needed to replicate results in 
** in "Nonbank Lending and Credit Cyclicality" by Fleckenstein et. al. (2024)
******************************************************************************
******************************************************************************

set more off
clear all 
set scheme s1color

******************************************************************************
* Set location of files 
* each user needs to set the location of their main replication package once 
* in this file - all other locations are derived from package location 
******************************************************************************

global package "C:\Users\Eunkyung\ASU Dropbox\Eunkyung Jeon\2026-1\econometrics\12. replicate\nonbank lending and credit cyclicality"


global data `"$package\data"'
global code `"$package\code"'
global figures `"$package\figures"'
global tables `"$package\tables"'

*Changes the directory to the directy in which the code cleaning do files are located
cd "$package/code/code_data"


******************************************************************************
* Download raw datasets
******************************************************************************

// dealscan 
do "0_dealscan_new_download.do"
do "0_dealscan_old_download.do"

// compustat 
do "0_compustat_annual_download.do"
do "0_compustat_firm_annual_download.do"
do "0_compustat_quarterly_download.do"

// credit cycle measures
do "0_credit_cycles_measures"

******************************************************************************
* Run all the do files to generate the data
******************************************************************************

***************************************
*** Dealscan old
***************************************

do "1a_dealscan_old_load.do"
do "1b_dealscan_old_main_facility.do"
do "1c_dealscan_old_cr_replication.do"

***************************************
*** Dealscan New
***************************************

do "2_main_facility_new_DS.do" 

***************************************
*** CLO data 
***************************************

do "3a_clo_capital_structure.do"
do "3b_clo_bank_leverage_panel.do"
do "3c_clo_bank_spread_panel.do"

***************************************
*** Aggregate numbers
***************************************

do "4a_aggregate_AuM.do"
do "4b_nonbank_lender_composition.do"
