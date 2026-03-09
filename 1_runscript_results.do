******************************************************************************
******************************************************************************
** This file provides code to replicate results in 
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

global package "C:\Users\shillenbrand\Dropbox (Harvard University)\2_Nonbank lending and credit cyclicality\0_NEW FOLDER\replication_package_final"

global data `"$package\data"'
global code `"$package\code"'
global figures `"$package\figures"'
global tables `"$package\tables"'

*Changes the directory to the directy in which the code do files are located
cd "$package/code/code_results"


******************************************************************************
* Run all the do files to generate the data
******************************************************************************

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