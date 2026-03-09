


******************************************************************************
******************************************************************************
** This file creates Compustat Annual Panel: Bank vs. Nonbank Lending
** in "Nonbank Lending and Credit Cyclicality" by Fleckenstein et. al. (2024)
******************************************************************************
******************************************************************************

set more off
clear all
set scheme s1color
global package "C:\Users\Eunkyung\ASU Dropbox\Eunkyung Jeon\2026-1\econometrics\12. replicate\nonbank lending and credit cyclicality"

global output `"$package\results"'
global data `"$package\data"'
global code `"$package\code"'
global figures `"$package\figures"'
global code `"$package\tables"'

capture log close
log using "$package/logs/prep_dealscan_new.log", replace

******************************************************************************

*We split the data set due to the large size
*** Since 2010
clear all
odbc load, exec("select * from dealscan.dealscan where deal_active_date >= '2010-01-01'") dsn("wrds-pgdata-64")
compress
save "$data/Raw Data/dealscan_new/Dealscan_data_since2010.dta", replace


*** 2000 - 2010
clear all
odbc load, exec("select * from dealscan.dealscan where deal_active_date >= '2000-01-01' and deal_active_date < '2010-01-01'") dsn("wrds-pgdata-64")
compress
save "$data/Raw Data/dealscan_new/Dealscan_data_2000to2010.dta", replace

*** Prior to 2000
clear all
odbc load, exec("select * from dealscan.dealscan where deal_active_date < '2000-01-01'") dsn("wrds-pgdata-64")
compress
save "$data/Raw Data/dealscan_new/Dealscan_data_prior2000.dta", replace

*Combine the data
use "$data/Raw Data/dealscan_new/Dealscan_data_since2010.dta", clear
append using "$data/Raw Data/dealscan_new/Dealscan_data_2000to2010.dta"
append using "$data/Raw Data/dealscan_new/Dealscan_data_prior2000.dta"

recast strL lender_parent_name                 
recast strL lender_name
recast strL additional_roles
recast strL lender_operating_country 
recast strL borrower_name
recast strL additional_borrowers                
recast strL city                                
recast strL country                             
recast strL major_industry_group                
recast strL sic_code                            
recast strL naic                                
recast strL borrower_type                       
recast strL parent                              
recast strL sponsor                             
recast strL guarantor                           
recast strL target                              
recast strL organization_type                   
recast strL company_url                         
recast strL lead_arranger                       
recast strL bookrunner                          
recast strL top_tier_arranger                   
recast strL lead_left                           
recast strL arranger                            
recast strL co_arranger                         
recast strL agent                               
recast strL lead_manager                        
recast strL all_lenders                         
recast strL lender_region                       
recast strL lender_parent_region                
recast strL lender_institution_type             
recast strL deal_currency                       
recast strL deal_purpose                        
recast strL project_finance                     
recast strL purpose_remark                      
recast strL deal_remark                         
recast strL tranche_type                        
recast strL tranche_currency                    
recast strL market_segment                      
recast strL repayment_schedule                  
recast strL collateral_security_type            
recast strL tranche_remark                      
recast strL primary_purpose                     
recast strL secondary_purpose                   
recast strL tertiary_purpose                    
recast strL project_finance_sponsor             
recast strL base_reference_rate                 
recast strL all_base_rate_spread_margin         
recast strL call_protection_text                
recast strL base_rate_comment                   
recast strL repayment_comment                   
recast strL performance_pricing                 
recast strL performance_pricing_remark          
recast strL tiered_upfront_fee                  
recast strL all_fees                            
recast strL max_leverage_ratio                  
recast strL max_debt_to_cash_flow               
recast strL max_sr_debt_to_cash_flow            
recast strL min_fixed_charge_coverage_ratio     
recast strL min_debt_service_coverage_ratio     
recast strL min_interest_coverage_ratio         
recast strL min_cash_interest_coverage_ratio    
recast strL max_debt_to_tangible_net_worth      
recast strL max_debt_to_equity_ratio            
recast strL min_current_ratio                   
recast strL max_loan_to_value_ratio             
recast strL all_covenants_financial             
recast strL covenant_comment                    
recast strL all_covenants_general               
recast strL law_firm_name                       
recast strL law_firm_lender_primary             
recast strL law_firm_lender_other               
recast strL law_firm_borrower_primary           
recast strL law_firm_borrower_other
             
save "$data/Raw Data/dealscan_new/Dealscan_data_full_compress.dta", replace

*Delete the individual files
erase "$data/Raw Data/dealscan_new/Dealscan_data_since2010.dta"
erase "$data/Raw Data/dealscan_new/Dealscan_data_2000to2010.dta"
erase "$data/Raw Data/dealscan_new/Dealscan_data_prior2000.dta"

