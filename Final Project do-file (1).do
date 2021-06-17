*cd"U:\ECO 392\Final Project"
*Import data from excel file RSFHFSN
*import excel "U:\ECO 392\Final Project\RSFHFSN.xls",sheet("Sheet1") firstrow
*save final_project.dta
*Format the date
gen year=year(obs)
sort year
gen month=month(obs)
gen date = ym(year,mon)
format date %tm
tsset date
tsappend, add(6)
gen t=_n
tsset t
replace year=2019 if t>121
replace month=2 if t==122
replace month=3 if t==123
replace month=4 if t==124
replace month=5 if t==125
replace month=6 if t==126
replace month=7 if t==127

****************************Method 1: Smoothers*********************************
tsset date
*Graph shows trend and seasonality
tsline sales

*Using Winter's Smoother

tssmooth shwinters sales_winters_f = sales, forecast(6) iterate (25)
	*2019m2 9071.429
	*2019m3 10390.81
	*2019m4 9567.326
	*2019m5 10275.47
	*2019m6 10071.95
	*2019m7 10229.61
	
*Psudo-Winters
	tssmooth shwinters psudo_sales_winters_f = sales if date<m(2018m8), forecast(6) iterate (25)
	*Psudo rmse
	gen e_psudo_winters = psudo_sales_winters_f - sales if date>m(2018m7)
	gen e_psudo_winters_sq = e_psudo_winters*e_psudo_winters
	egen psudo_MSE_winters = mean(e_psudo_winters_sq)
	gen psudo_RMSE_winters = (psudo_MSE_winters)^0.5

	*Psudo MAPE
	gen abs_e_psudo_winters = abs(e_psudo_winters)
	gen pct_e_psudo_winters = abs_e_psudo_winters/sales
	egen psudo_MAPE_winters = mean(pct_e_psudo_winters)

*In-sample Winters
	*RMSE
	gen e_insample_w = sales-sales_winters_f
	gen e_insample_w_sq = e_insample_w*e_insample_w
	egen insample_w_MSE = mean(e_insample_w_sq)
	gen insample_w_RMSE = (insample_w_MSE)^0.5

	*MAPE
	gen abs_e_insample_w = abs(e_insample_w)
	gen pct_e_insample_w = abs_e_insample_w/sales
	egen insample_MAPE_w = mean(pct_e_insample_w)

	sum psudo_RMSE_winters psudo_MAPE_winters insample_w_RMSE insample_MAPE_w
	
	
*    Variable |        Obs        Mean    Std. Dev.       Min        Max
*-------------+---------------------------------------------------------
*psudo_RMSE~s |        127    493.0598           0   493.0598   493.0598
*psudo_MAPE~s |        127    .0366981           0   .0366981   .0366981
*insampl~RMSE |        127    211.2607           0   211.2607   211.2607
*insample_M~w |        127    .0201705           0   .0201705   .0201705

****************************Method 2: TSDM**********************************
tsset t
*I. Seasonality
	*Get moving average for time t
	tssmooth ma sales_ma = sales,window(6,1,5)
	*Get CMAt
	tssmooth ma sales_cma = sales_ma,window(0,1,1)
	*The first and last six observations do not exist for monthly data
	*There are no actual observations
	replace sales_cma = . if t<7
	replace sales_cma = . if t>115
	gen sf = sales/sales_cma
	sort month
	by month:egen S = mean(sf)
	by month: sum S
	sort date

*II. Time Trend
	tsline sales sales_cma
	*From the graph, we could see CMA is deseasonalized but has trend and cyclicality
	*Regress deseasonalized sales on time t
	reg sales_cma t
	predict T
	*The difference between CMA and T is that CMA shows cyclicality
	tsline sales_cma T

*III. Cyclicality
	gen cf = sales_cma/T
	*Look at the graph for cyclical pattern
	tsline cf
	*Forecast for 12 monthes, because the last 6 are not existing
	tssmooth hwinters C1 = cf, forecast(12) iterate (25)
	tsline cf C1

*Time Series Decomposition Model forecast on Y
	gen sales_TSDM_f = S * T * C1 * 1
	tsline sales_TSDM_f sales
	
		*2019m2 9274.98
		*2019m3 10499.62
		*2019m4 9689.596
		*2019m5 10347.1
		*2019m6 10115.8
		*2019m7 10444.75
		
*Psudo-TSDM
	tssmooth ma psudo_sales_ma = sales,window(6,1,5)
	tssmooth ma psudo_sales_cma = sales_ma,window(0,1,1)
	replace psudo_sales_cma = . if t<7
	replace psudo_sales_cma = . if t>109
	gen psudo_sf = sales/psudo_sales_cma
	sort month
	by month:egen S_psudo = mean(psudo_sf)
	by month: sum S_psudo
	sort date

	reg psudo_sales_cma t
	predict T_psudo 

	gen psudo_cf = psudo_sales_cma/T_psudo
	tssmooth hwinters C_psudo = psudo_cf, forecast (12) iterate (25)

	gen psudo_sales_forecast = S_psudo * T_psudo * C_psudo * 1 

	*RMSE
	gen e_psudo = psudo_sales_forecast - sales if t<122 & t >115
	gen e_psudo_sq = e_psudo*e_psudo
	egen psudo_MSE = mean(e_psudo_sq)
	gen psudo_RMSE = (psudo_MSE)^0.5

	*MAPE
	gen abs_e_psudo = abs(e_psudo)
	gen pct_e_psudo = abs_e_psudo/sales
	egen psudo_MAPE = mean(pct_e_psudo)

*In-Sample --- TSDM
	*RMSE
	gen e_insample = sales-sales_TSDM_f
	gen e_insample_sq = e_insample*e_insample
	egen insample_MSE = mean(e_insample_sq)
	gen insample_RMSE = (insample_MSE)^0.5

	*MAPE
	gen abs_e_insample = abs(e_insample)
	gen pct_e_insample = abs_e_insample/sales
	egen insample_MAPE = mean(pct_e_insample)

sum psudo_RMSE psudo_MAPE insample_RMSE insample_MAPE

*    Variable |        Obs        Mean    Std. Dev.       Min        Max
*-------------+---------------------------------------------------------
*  psudo_RMSE |        127    538.9611           0   538.9611   538.9611
*  psudo_MAPE |        127    .0394191           0   .0394191   .0394191
*insample_R~E |        127    173.5122           0   173.5122   173.5122
*insample_~PE |        127    .0162394           0   .0162394   .0162394



******************************Method 3: Time Trend Model************************
tab month,gen(m)
reg sales t m1-m11
*All the coefficients were significant, suggesting that my dataset is seasonal
predict sales_tt_f
*9414.032
*10357.63
*9741.532
*10277.33
*10114.33
*10356.53
tsline sales_tt_f sales
*Psudo-Time Trend

reg sales t m1-m11 if t<116
predict psudo_sales_tt
*RMSE
	gen e_psudo_tt = psudo_sales_tt - sales if t<122 & t >115
	gen e_psudo_sq_tt = e_psudo_tt*e_psudo_tt
	egen psudo_MSE_tt = mean(e_psudo_sq_tt)
	gen psudo_RMSE_tt = (psudo_MSE_tt)^0.5
*MAPE
	gen abs_e_psudo_tt = abs(e_psudo_tt)
	gen pct_e_psudo_tt = abs_e_psudo_tt/sales
	egen psudo_MAPE_tt = mean(pct_e_psudo_tt)

*In-Sample Time-Trend

*RMSE
	gen e_insample_tt = sales-sales_tt_f
	gen e_insample_sq_tt = e_insample_tt*e_insample_tt
	egen insample_MSE_tt = mean(e_insample_sq_tt)
	gen insample_RMSE_tt = (insample_MSE_tt)^0.5

*MAPE
	gen abs_e_insample_tt = abs(e_insample_tt)
	gen pct_e_insample_tt = abs_e_insample_tt/sales
	egen insample_MAPE_tt = mean(pct_e_insample_tt)

sum psudo_RMSE_tt psudo_MAPE_tt insample_RMSE_tt insample_MAPE_tt


*    Variable |        Obs        Mean    Std. Dev.       Min        Max
*-------------+---------------------------------------------------------
*psudo_RMSE~t |        127    318.8628           0   318.8628   318.8628
*psudo_MAPE~t |        127    .0288202           0   .0288202   .0288202
*insample_R~t |        127    271.3823           0   271.3823   271.3823
*insamp~PE_tt |        127    .0264257           0   .0264257   .0264257


****************************Combined Forecast***********************************
reg sales sales_winters_f sales_TSDM_f sales_tt_f
*This is the best I could get, which is significant at 23% percent
reg sales sales_TSDM_f sales_tt_f,noc
predict sales_composite
list sales_composite if t>121

*In sample forecast
	*MAPE
	gen abs_pct_err_c = abs(sales - sales_composit)/sales
	egen mape_c_insample = mean(abs_pct_err_c)
	*RMSE
	gen e_insample_c = sales-sales_composite
	gen e_insample_sq_c = e_insample_c*e_insample_c
	egen insample_MSE_c = mean(e_insample_sq_c)
	gen insample_RMSE_c = (insample_MSE_c)^0.5

*Psudo forecast
	reg sales psudo_sales_winters_f psudo_sales_forecast psudo_sales_tt if t<116
	reg sales psudo_sales_winters_f psudo_sales_forecast if t<116
	reg sales psudo_sales_winters_f psudo_sales_forecast if t<116,noc
	predict psudo_sales_c
	*MAPE
	gen abs_pct_err_c_p = abs(sales - psudo_sales_c)/sales if t>115
	egen mape_c_psudo_p = mean(abs_pct_err_c_p)
	*RMSE
	gen e_psudo_c = psudo_sales_c - sales if t<122 & t >115
	gen e_psudo_sq_c = e_psudo_c*e_psudo_c
	egen psudo_MSE_c = mean(e_psudo_sq_c)
	gen psudo_RMSE_c = (psudo_MSE_c)^0.5
sum mape_c_insample insample_RMSE_c mape_c_psudo_p psudo_RMSE_c


*    Variable |        Obs        Mean    Std. Dev.       Min        Max
*-------------+---------------------------------------------------------
*mape_c_ins~e |        127    .0162569           0   .0162569   .0162569
*insample_R~c |        127     172.178           0    172.178    172.178
*mape_c_psu~p |        127      .03975           0     .03975     .03975
*psudo_RMSE_c |        127    548.0291           0   548.0291   548.0291


*Graphs
tsset date
tsline sales sales_winters_f sales_TSDM_f sales_tt_f sales_composite if date>m(2018m1),tline(2019m2)

tsline sales sales_winters_f if date>m(2015m1),tline(2019m2)
tsline sales sales_TSDM_f if date>m(2015m1),tline(2019m2)
tsline sales sales_tt_f if date>m(2015m1),tline(2019m2)
tsline sales sales_composite if date>m(2015m1),tline(2019m2)
