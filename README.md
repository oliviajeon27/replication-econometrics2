# Replication: Nonbank Lending and Credit Cyclicality

This replication package reproduces the main tables and figures from:

**Fleckenstein, Gopal, Gutiérrez, and Hillenbrand (JFE)**  
*"Nonbank Lending and Credit Cyclicality"*

The paper studies the role of banks and nonbanks in driving fluctuations in syndicated loan supply. The main finding is that nonbank lending accounts for most of the contraction in credit during downturns such as the Global Financial Crisis and is substantially more cyclical than bank lending.

---

# Instructions to Run the Code

1. Open the Stata do-file: master file.do
2. Set the working directory to the replication folder.
3. Run the master file. It will:
- clean raw data
- construct variables
- reproduce all tables and figures

---

# Folder Structure
- code/ Stata scripts for cleaning and estimation
- tables/ Regression output tables
- figures/ Generated figures
- master file.do Main replication script

---

# Data Requirements

This replication uses Stata.

The following datasets must be downloaded from WRDS:

- DealScan syndicated loan data: Dealscan has 2 dataset: (1) The legacy DealScan dataset covers approximately 1987–2017 and corresponds to the version traditionally used in the syndicated loan literature. It is used to replicate earlier results and to analyze lending behavior around the Global Financial Crisis. (2) Beginning around 2018, Refinitiv introduced a redesigned DealScan structure with extended coverage and improved loan-level and lender-level information (DealScan New). This dataset is used to extend the analysis to more recent years and examine credit cycles over a longer horizon.
- Compustat firm financial data

The Excess Bond Premium (EBP) time series is from: Gilchrist and Zakrajšek (2012)

The following datasets are not publicly accessible:

- CLO data
- Shared National Credit (SNC) data
- Morningstar mutual fund data

Processed versions of these datasets are provided by the authors.  
Therefore scripts:3a, 3b, 3c, 4a, 4b 
are excluded from the master file.

---

# Mapping Between Code and Outputs

| Output | Dataset Used | Description |
|-------|-------------|------------|
| Table 1 | main_facility_dataset | Summary statistics |
| Table 2 | GFC_data | Loan decrease of bank and nonbank during GFC |
| Table 3 | GFC_data | Impact of various bank health indexes in loan change |
| Table 4 | oldDS_main_facility_dataset | Contribution of bank and nonbank credit supply decrease to employment loss during the crisis |
| Table 5 | main_facility_dataset | Nonbank  reduce lending more than bank when credit premium goes up (time series regression) |
| Table 6 | main_facility_dataset | When comparing same borrower, nonbank reduce lending more than bank when credit condition tightnened |
| Table 7 | main_facility_dataset | After controlling the impact of bank health on nonbank credit supply, nonbank are more cyclical |
| Table 8 | main_facility_dataset_deallead | Nonbank reduce lending more than both lead bank and participant bank |
| Table 9 | main_facility_dataset_deallead | Limited support for explanation that nonbank reduce lending more for opaque borrowers (young, small, private) |
| Figure 2 | nonbank_lender_composition | Composition of nonbank lenders over time |
| Figure 3 | oldDS_main_facility_dataset | Negative relationship between bank capital and nonbank dependence |
| Figure 4 | GFC_data | Negative relationship between lending change and nonbank dependence |
| Figure 5 | main_facility_dataset | Nonbank originating loans are more cyclical than bank originating loan |
| Figure 6 | main_facility_dataset | Nonbank lending share’s sensitivity for credit condition |
| Figure 7 | clo_bank_spreads | CLO funding cost rise more than bank funding cost during bad times | 


