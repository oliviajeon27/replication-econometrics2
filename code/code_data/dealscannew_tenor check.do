rename *, lower

* 날짜 형식 확인
format tranche_active_date %td
format tranche_maturity_date %td

* 직접 계산한 maturity (month)
gen maturity_months_calc = (tranche_maturity_date - tranche_active_date) / 30.4375

* 반올림 버전도 하나
gen maturity_months_round = round(maturity_months_calc)

* 차이
gen tenor_diff = tenor_maturity - maturity_months_calc
gen tenor_diff_round = tenor_maturity - maturity_months_round

*******기본분포 확인
sum tenor_maturity maturity_months_calc tenor_diff tenor_diff_round, detail

*******0또는 음수, 차이가 큰 케이스 찾기
count if tenor_maturity==0
count if tenor_maturity<0
count if maturity_months_calc<0

count if tenor_maturity==0
count if tenor_maturity<0
count if maturity_months_calc<0

********missing 채우구 나서 다시 확인
replace tenor_maturity = . if tenor_maturity==0
count if missing(tenor_maturity) & !missing(tranche_maturity_date) & !missing(tranche_active_date)


********amendment만 따로 보기
gen amend = strpos(tranche_o_a, "Amendment")>0 if !missing(tranche_o_a)

sum tenor_diff if amend==1
sum tenor_diff if amend!=1

