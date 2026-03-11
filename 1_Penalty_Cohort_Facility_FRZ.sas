*************************************************************************************************************************************************************************
*  Project Name :           SNF VBP Penalties				 																											*
*  Principal Investigator : Burke																																		*
*  Name of Program :        1_Penalty_Cohort_Facility.sas																							*
*  Programmer :             Jonathan Heintz                                                                 															*
*  Start Date :             October 2nd, 2024	                                                               															*
*  Program Description :	Creates a per fiscal year SNF dataset consisting of aggregated visit level measures, LTC Focus data,										*
*							VBP provider data, and cost data.																											*

*  This code requires the following data sources: 
	CMS Provider Information and Skilled Nursing Facility Value-Based Purchasing program performace files from
		https://data.cms.gov/provider-data/topics/nursing-homes
	LTC Focus skilled nursing files from https://ltcfocus.org/
	Skilled nursing cost data from https://www.cms.gov/data-research/statistics-trends-and-reports/cost-reports
							
*************************************************************************************************************************************************************************;

*Run library locations;
%include '[filepath to code writing library locations]';

**************************************************************************************
STEP 1: AGGREGATING PATIENT LEVEL DATA TO FY SNF DATA ALL ELIGIBLE SNF VISITS
****************************************************************************************;
PROC SORT DATA=frz.SNF_PMT_TM_20250226
	(KEEP=PRVDR_NUM ADMSNDT PASSTHRU PMT_AMT
	WHERE=(ADMSNDT>INPUT('09/30/2018',MMDDYY10.)))
	OUT=SNF_PMT_TM_20250226 /*N=5820744 */; BY PRVDR_NUM; 
RUN;

DATA FY2019 FY2020 FY2021; 
SET SNF_PMT_TM_20250226 
	(RENAME=(
	PRVDR_NUM=SNF_PRVDR_NUM
	ADMSNDT=SNF_ADMSNDT
	PASSTHRU=snf_PASS_THRU_AMT
	PMT_AMT=SNF_MDCR_PMT_AMT
	));	
MDCR_REIMBURSEMENT=snf_PASS_THRU_AMT+SNF_MDCR_PMT_AMT;
IF INPUT('10/01/2018',MMDDYY10.)<=SNF_ADMSNDT <=INPUT('09/30/2019',MMDDYY10.) THEN DO; FY=2019; OUTPUT FY2019; END;
	ELSE IF INPUT('10/01/2019',MMDDYY10.)<=SNF_ADMSNDT <=INPUT('09/30/2020',MMDDYY10.) THEN DO; FY=2020; OUTPUT FY2020; END;
		ELSE IF INPUT('10/01/2020',MMDDYY10.)<=SNF_ADMSNDT <=INPUT('09/30/2021',MMDDYY10.) THEN DO; FY=2021; OUTPUT FY2021; END;
PAT_ENCOUNTER=1;
RUN;
*5820744 ; 

PROC MEANS DATA=FY2019 NOPRINT; VAR MDCR_REIMBURSEMENT;  BY SNF_PRVDR_NUM; OUTPUT OUT=MDCR_REIMBURSEMENT_FY2019(RENAME=(_FREQ_=FY_ENCOUNTERS_ALL)) SUM=FY_MDCR_REIMBURSEMENT_ALL; RUN;
PROC MEANS DATA=FY2020 NOPRINT; VAR MDCR_REIMBURSEMENT;  BY SNF_PRVDR_NUM; OUTPUT OUT=MDCR_REIMBURSEMENT_FY2020(RENAME=(_FREQ_=FY_ENCOUNTERS_ALL)) SUM=FY_MDCR_REIMBURSEMENT_ALL; RUN;
PROC MEANS DATA=FY2021 NOPRINT; VAR MDCR_REIMBURSEMENT;  BY SNF_PRVDR_NUM; OUTPUT OUT=MDCR_REIMBURSEMENT_FY2021(RENAME=(_FREQ_=FY_ENCOUNTERS_ALL)) SUM=FY_MDCR_REIMBURSEMENT_ALL; RUN;

PROC SORT DATA=FY2019 OUT=FY2019B(KEEP=SNF_PRVDR_NUM FY) NODUPKEY; BY SNF_PRVDR_NUM; RUN;
PROC SORT DATA=FY2020 OUT=FY2020B(KEEP=SNF_PRVDR_NUM FY) NODUPKEY; BY SNF_PRVDR_NUM; RUN;
PROC SORT DATA=FY2021 OUT=FY2021B(KEEP=SNF_PRVDR_NUM FY) NODUPKEY; BY SNF_PRVDR_NUM; RUN;

DATA FY2019C; MERGE FY2019B MDCR_REIMBURSEMENT_FY2019; BY SNF_PRVDR_NUM; RUN;
DATA FY2020C; MERGE FY2020B MDCR_REIMBURSEMENT_FY2020; BY SNF_PRVDR_NUM; RUN;
DATA FY2021C; MERGE FY2021B MDCR_REIMBURSEMENT_FY2021; BY SNF_PRVDR_NUM; RUN;

DATA FY_2019_2021; SET FY2019C FY2020C FY2021C ; RUN;
PROC SORT DATA=FY_2019_2021 NODUPKEY; BY SNF_PRVDR_NUM FY; RUN; *CHECKING 0 REMOVED;


****************************************************************************************
STEP 2: PULLING LTCFOCUS VARIABLES
****************************************************************************************;
%MACRO LTC_19_21;
	%DO YEAR=2019 %TO 2021;
		%IF &YEAR<2021 %THEN %DO;
			DATA facility_&YEAR.; SET raw.facility_&YEAR.; 
			CCN=PUT(compress(PROV1680),6.);
			if length(CCN) = 5 then CCN = cat('0', CCN);
			YEAR=&YEAR.;
			RUN;
		%END;
		%IF &YEAR=2021 %THEN %DO;
			PROC import datafile = '[filepath]/facility_2021.xls'
				out = facility_2021 DBMS = XLS REPLACE;
			RUN;
			DATA facility_2021; SET facility_2021; 
			CCN=PUT(compress(PROV1680),6.);
			if length(CCN) = 5 then CCN = cat('0', CCN);
			YEAR=&YEAR.;
			RUN;
		%END;
	%END;
	
	DATA facility_2019_2021; RETAIN CCN;
	LENGTH 
		totbeds $12
		PROV3225 $20
		PROV2905 $12
		state $12
		county $12
		agg_cmi_mds3 $6
		multifac $12
		PROFIT $12;
	SET %do YEAR=2019 %TO 2021; facility_&YEAR. %end;;
	totbeds_NUM=INPUT(totbeds,8.);
	IF SNF_agg_cmi_mds3='LNE' THEN SNF_agg_cmi_mds3='';
	SNF_agg_cmi_mds3_NUM=INPUT(SNF_agg_cmi_mds3,8.);
	RUN;

	PROC SQL;
		CREATE TABLE FY_2019_2021B AS
			SELECT A.*, B.totbeds_NUM as totbeds, b.PROV3225 as SNF_CITY, b.PROV2905 AS SNF_ZIP, b.state AS SNF_STATE , B.county AS SNF_COUNTY, b.multifac, B.PROFIT, b.SNF_agg_cmi_mds3_NUM as SNF_agg_cmi_mds3					
			FROM FY_2019_2021 AS A LEFT JOIN facility_2019_2021 AS B
			ON A.SNF_PRVDR_NUM=B.CCN AND A.FY=B.YEAR;
	QUIT;
%MEND;
%LTC_19_21;


****************************************************************************************
STEP 3: PULLING PROVIDER INFO RATINGS
****************************************************************************************;
%MACRO RATING_19_21;
	*SNF Overall Star Rating;
	OPTIONS VALIDVARNAME=V7;
	proc import dataFILE="[filepath, 2019]/ProviderInfo_Download.csv"
		out=ProviderInfo_2019
		dbms=CSV
		replace;
		guessingrows=300;
	run;

	OPTIONS VALIDVARNAME=V7;
	proc import dataFILE="[filepath, 2020]/ProviderInfo_Download.csv"
		out=ProviderInfo_2020
		dbms=CSV
		replace;
		guessingrows=300;
	run;

	OPTIONS VALIDVARNAME=V7;
	proc import dataFILE="[filepath, 2021]/NH_ProviderInfo_Jan2021.csv"
		out=ProviderInfo_2021
		dbms=CSV
		replace;
		guessingrows=300;
	run;

	%DO YEAR=2019 %TO 2021;
		%IF &YEAR.<2021 %THEN %DO;
			DATA ProviderInfo_&YEAR._2; SET ProviderInfo_&YEAR.;
			CMS=PUT(compress(PROVNUM),6.);
			if length(CMS) = 5 then CMS = cat('0', CMS);
			YEAR=&YEAR.;
			KEEP CMS overall_rating  Staffing_Rating SS_Quality_Rating YEAR;
			RUN;
		%END;
		%IF &YEAR.>2020  %THEN %DO;
			DATA ProviderInfo_&YEAR._2; SET ProviderInfo_&YEAR.;
			CMS=PUT(compress(Federal_Provider_Number),6.);
			if length(CMS) = 5 then CMS = cat('0', CMS);
			YEAR=&YEAR.;
			RENAME Short_Stay_QM_Rating=SS_Quality_Rating;
			KEEP CMS overall_rating  Staffing_Rating Short_Stay_QM_Rating YEAR;
			RUN;
		%END;

	%END;
	
	DATA ProviderInfo_2019_2021; RETAIN CMS;
	SET %do YEAR=2019 %TO 2021; ProviderInfo_&YEAR._2 %end;;
	Overall_Rating_NUM=INPUT(Overall_Rating,8.);
	Staffing_Rating_NUM=INPUT(Staffing_Rating,8.);
	SS_Quality_Rating_NUM=INPUT(SS_Quality_Rating,8.);

	RUN;

	PROC SQL;
		CREATE TABLE FY_2019_2021C AS
			SELECT A.*, B.Overall_Rating_NUM as overall_rating, b.Staffing_Rating_NUM as Staffing_Rating, b.SS_Quality_Rating_NUM as SS_Quality_Rating
			FROM FY_2019_2021B AS A LEFT JOIN ProviderInfo_2019_2021 AS B
			ON A.SNF_PRVDR_NUM=B.CMS AND A.FY=B.YEAR;
	QUIT;
%MEND;
%RATING_19_21;


****************************************************************************************
STEP 4: COST DATA
****************************************************************************************;
%MACRO COSTDATA_19_21_OPTIONB;
	%DO YEAR=2019 %TO 2021;
		OPTIONS VALIDVARNAME=V7;
		proc import dataFILE="[filepath]/SNF_Cost_Report_&YEAR..csv"
			out=COST_REPORT_&YEAR.
			dbms=CSV
			replace;
			getnames=YES;
			guessingrows=300;
		run;
		DATA COST_REPORT_&YEAR._2; SET COST_REPORT_&YEAR.;
		Net_Income_NUM=INPUT(Net_Income,12.);
		Net_Patient_Revenue_NUM=INPUT(Net_Patient_Revenue,12.);
		Total_Income_NUM=INPUT(Total_Income,12.);
		Gross_Revenue_NUM=INPUT(Gross_Revenue,12.);
		Net_Income_from_service_to_NUM=INPUT(Net_Income_from_service_to_pati,12.);
		Total_Other_Income_NUM=INPUT(Total_Other_Income,12.);
		Inpatient_Revenue_num=input(Inpatient_Revenue,12.);
		Outpatient_Revenue_num=input(Outpatient_Revenue,12.);
		IF Net_Patient_Revenue_NUM NE . & Total_Other_Income_NUM NE . THEN NET_OPERATING_EXP=Net_Patient_Revenue_NUM+Total_Other_Income_NUM;
		
		NET_OPERATING_MARGIN1=Net_Income_NUM/Net_Patient_Revenue_NUM;
		NET_OPERATING_MARGIN2=Total_Income_NUM/Net_Patient_Revenue_NUM;
		NET_OPERATING_MARGIN3=Total_Income_NUM/Gross_Revenue_NUM;
		NET_OPERATING_MARGIN4=Total_Income_NUM/NET_OPERATING_EXP;
		NET_OPERATING_MARGIN5=Net_Income_NUM/NET_OPERATING_EXP;
		
		YEAR=&YEAR.;
			CCN=PUT(compress(Provider_CCN),6.);
			if length(CCN) = 5 then CCN = cat('0', CCN);

		RUN;
		PROC SORT DATA=COST_REPORT_&YEAR._2 NODUPKEY; BY CCN;RUN;
	%END;
	
	DATA COST_REPORT_2019_2021;
	SET %do YEAR=2019 %TO 2021; COST_REPORT_&YEAR._2 %end;;
	RUN;

		PROC SQL;
			CREATE TABLE FY_2019_2021D AS
			SELECT A.*, B.NET_OPERATING_MARGIN5 AS NET_OPERATING_MARGIN, B.Net_Income_NUM as Net_Income, B.NET_OPERATING_EXP, b.Gross_Revenue_NUM AS Gross_Revenue, B.Net_Patient_Revenue_NUM AS Net_Patient_Revenue, B.Total_Other_Income_NUM AS Total_Other_Income
			FROM FY_2019_2021C AS A LEFT JOIN COST_REPORT_2019_2021 AS B
			ON A.SNF_PRVDR_NUM=B.CCN AND A.FY=B.YEAR;
		QUIT;
%MEND;
%COSTDATA_19_21_OPTIONB;


****************************************************************************************
STEP 5: SNF VALUE_BASED PURCHASING PROGRAM METRICS 
****************************************************************************************;
OPTIONS VALIDVARNAME=V7;

proc import dataFILE="[filepath]/SNF VBP Facility Performance01 2019.csv"
	out=SNF_PERF_01_2019
	dbms=CSV
	replace;
run;
proc import dataFILE="[filepath]/SNF VBP Facility Performance01 2020.csv"
	out=SNF_PERF_01_2020
	dbms=CSV
	replace;
run;
proc import dataFILE="[filepath]/SNF VBP Facility Performance01 2021.csv"
	out=SNF_PERF_01_2021
	dbms=CSV
	replace;
run;


DATA SNF_PERF_01_2019B; SET SNF_PERF_01_2019;
RENAME 	Baseline_Period__CY_2015_Risk_S=B_RSRR_2015
		Performance_Period__CY_2017_Ris=P_RSRR_01012017_12312017
		Incentive_Payment_Multiplier=IPM_FY2019;
		
B_START_TIME_2015=input('01/01/2015',mmddyy10.);
B_END_TIME_2015=input('12/31/2015',mmddyy10.);
P_START_TIME_01012017_12312017=input('01/01/2017',mmddyy10.); 
P_END_TIME_01012017_12312017=input('12/31/2017',mmddyy10.);
ID_SNF_PERF_01_2019=PUT(Provider_Number__CCN_,Z6.);

FORMAT B_START_TIME_2015 B_END_TIME_2015 P_START_TIME_01012017_12312017 P_END_TIME_01012017_12312017 MMDDYY10.;
KEEP ID_SNF_PERF_01_2019 Baseline_Period__CY_2015_Risk_S Performance_Period__CY_2017_Ris   B_START_TIME_2015 B_END_TIME_2015 P_START_TIME_01012017_12312017 P_END_TIME_01012017_12312017 Incentive_Payment_Multiplier;
RUN;

DATA SNF_PERF_01_2020B; SET SNF_PERF_01_2020;
RENAME 	Baseline_Period__FY_2016_Risk_S=B_RSRR_01012016_09302016
		Performance_Period__FY_2018_Ris=P_RSRR_10012017_09302018
		Incentive_Payment_Multiplier=IPM_FY2020;
		
B_START_TIME_01012016_09302016=input('01/01/2016',mmddyy10.);
B_END_TIME_01012016_09302016=input('09/30/2016',mmddyy10.);
P_START_TIME_10012017_09302018=input('10/01/2017',mmddyy10.); 
P_END_TIME_10012017_09302018=input('09/30/2018',mmddyy10.);
ID_SNF_PERF_01_2020=PUT(Provider_Number__CCN_,Z6.);

FORMAT B_START_TIME_01012016_09302016 B_END_TIME_01012016_09302016 P_START_TIME_10012017_09302018 P_END_TIME_10012017_09302018 MMDDYY10.;
KEEP ID_SNF_PERF_01_2020 Baseline_Period__FY_2016_Risk_S Performance_Period__FY_2018_Ris  B_START_TIME_01012016_09302016 B_END_TIME_01012016_09302016 P_START_TIME_10012017_09302018 P_END_TIME_10012017_09302018 Incentive_Payment_Multiplier;
RUN;

DATA SNF_PERF_01_2021B; SET SNF_PERF_01_2021;
RENAME 	Baseline_Period__FY_2017_Risk_S=B_RSRR_10012016_09302017
		Performance_Period__FY_2019_Ris=P_RSRR_10012018_09302019
		Incentive_Payment_Multiplier=IPM_FY2021;

B_START_TIME_10012016_09302017=input('10/01/2016',mmddyy10.);
B_END_TIME_10012016_09302017=input('09/30/2017',mmddyy10.);
P_START_TIME_10012018_09302019=input('10/01/2018',mmddyy10.);
P_END_TIME_10012018_09302019=input('09/30/2019',mmddyy10.);
ID_SNF_PERF_01_2021=PUT(Provider_Number__CCN_,Z6.);

FORMAT B_START_TIME_10012016_09302017 B_END_TIME_10012016_09302017 P_START_TIME_10012018_09302019 P_END_TIME_10012018_09302019 MMDDYY10.;
KEEP ID_SNF_PERF_01_2021 Baseline_Period__FY_2017_Risk_S Performance_Period__FY_2019_Ris  B_START_TIME_10012016_09302017 B_END_TIME_10012016_09302017 P_START_TIME_10012018_09302019 P_END_TIME_10012018_09302019 Incentive_Payment_Multiplier;
RUN;


PROC SQL;
	CREATE TABLE TEMP_2019_2020 AS SELECT A.*, B.* FROM SNF_PERF_01_2019B AS A FULL OUTER JOIN SNF_PERF_01_2020B AS B ON A.ID_SNF_PERF_01_2019=B.ID_SNF_PERF_01_2020;
QUIT;
DATA TEMP_2019_2020_2; SET TEMP_2019_2020;
IF ID_SNF_PERF_01_2019 NE '' THEN ID=ID_SNF_PERF_01_2019; ELSE ID=ID_SNF_PERF_01_2020;
RUN;
PROC SQL;
	CREATE TABLE TEMP_2019_2021A AS SELECT A.*, B.* FROM TEMP_2019_2020_2 AS A FULL OUTER JOIN SNF_PERF_01_2021B AS B ON A.ID=B.ID_SNF_PERF_01_2021;
QUIT;
DATA TEMP_2019_2021A_2; SET TEMP_2019_2021A;
IF ID = '' THEN ID=ID_SNF_PERF_01_2021;
RUN;

PROC SQL;
	CREATE TABLE FY_2019_2021D_TEMP AS
		SELECT A.*, B.IPM_FY2019, B.IPM_FY2020, B.IPM_FY2021
		FROM FY_2019_2021D AS A LEFT JOIN TEMP_2019_2021A_2 AS B
		ON A.SNF_prvdr_num=B.ID;
QUIT;
DATA FY_2019_2021E /*N=40944*/; SET FY_2019_2021D_TEMP /*N=44928*/;
IF FY=2019 THEN Incentive_Payment_Multiplier=IPM_FY2019;
	ELSE IF FY=2020 THEN Incentive_Payment_Multiplier=IPM_FY2020;
	ELSE IF FY=2021 THEN Incentive_Payment_Multiplier=IPM_FY2021;
IF Incentive_Payment_Multiplier=. THEN DELETE;
IF FY_MDCR_REIMBURSEMENT_ALL=. THEN DELETE;
IF NET_OPERATING_MARGIN=. THEN DELETE;
RUN;


****************************************************************************************
STEP 6: CREATING DERIVED ANNUAL PAYMENT/PENALTY VARIABLES
****************************************************************************************;

DATA FY_2019_2021F; SET FY_2019_2021E;

FY_MDCR_REIMBURSEMENT_WMULT_ALL=FY_MDCR_REIMBURSEMENT_ALL*Incentive_Payment_Multiplier;
FY_Incentive_Payment_ALL=FY_MDCR_REIMBURSEMENT_WMULT_ALL-FY_MDCR_REIMBURSEMENT_ALL;
MAX_PENALTY_ALL=FY_MDCR_REIMBURSEMENT_ALL*0.02;

IF Incentive_Payment_Multiplier<1.0 THEN PENALTY_FLAG_ALL=1; ELSE PENALTY_FLAG_ALL=0;

FY_INCENTIVE_PER_REVENUE_ALL=FY_Incentive_Payment_ALL/Net_Patient_Revenue;
FY_INCENTIVE_PER_NETOPINCOME_ALL=FY_Incentive_Payment_ALL/NET_OPERATING_EXP;
RUN;


****************************************************************************************
STEP 7: CREATING PERCENT PENALTY VARIABLE, AGGREGATING ACROSS ALL YEARS, 
		AND CREATING QUARTILES
****************************************************************************************;
DATA FY_2019_2021G; SET FY_2019_2021F;
ABS_NET_OPERATING_EXP=abs(NET_OPERATING_EXP);
FY_IPN_ALL=FY_Incentive_Payment_ALL/ABS_NET_OPERATING_EXP;
RUN;

PROC SQL;
CREATE TABLE SNF_AGGREGATED_FY_2019_2021 AS
SELECT SNF_PRVDR_NUM, SUM(FY_MDCR_REIMBURSEMENT_ALL) AS SUM_FY_MDCR_REIMBURSEMENT_ALL, 
	SUM(FY_Incentive_Payment_ALL) AS SUM_FY_Incentive_Payment_ALL, SUM(ABS(NET_OPERATING_EXP)) AS SUM_NET_OPERATING_INC
FROM FY_2019_2021G
GROUP BY SNF_PRVDR_NUM;
QUIT;

DATA SNF_AGGREGATED_FY_2019_2021_2; SET SNF_AGGREGATED_FY_2019_2021;
SUM_FY_IPN_ALL=SUM_FY_Incentive_Payment_ALL/SUM_NET_OPERATING_INC;
RUN;

PROC MEANS DATA=SNF_AGGREGATED_FY_2019_2021_2 N NMISS MEAN STD MIN Q1 MEDIAN Q3 MAX;
VAR SUM_FY_IPN_ALL; 
OUTPUT OUT=SUM_FY_IPN_ALL Q1=Q1 MEDIAN=Q2 Q3=Q3;
RUN;

PROC SQL;
	SELECT Q1, Q2, Q3
	INTO :Q1_FY_IPN_SUM, :Q2_FY_IPN_SUM, :Q3_FY_IPN_SUM
	FROM SUM_FY_IPN_ALL;
QUIT;

DATA SNF_AGGREGATED_FY_2019_2021_3; SET SNF_AGGREGATED_FY_2019_2021_2;
IF SUM_FY_IPN_ALL NE . THEN DO;
	IF SUM_FY_IPN_ALL<&Q1_FY_IPN_SUM. THEN FY_IPN_Q_ALL=1;
	ELSE IF SUM_FY_IPN_ALL<&Q2_FY_IPN_SUM. THEN FY_IPN_Q_ALL=2;
	ELSE IF SUM_FY_IPN_ALL<&Q3_FY_IPN_SUM. THEN FY_IPN_Q_ALL=3;
	ELSE FY_IPN_Q_ALL=4;
end;
RUN;

*MERGING AGGREGATED PENALTY VARIABLES TO ORIGINAL DATASET;
PROC SQL;
CREATE TABLE FY_2019_2021H AS
SELECT A.*, B.SUM_FY_IPN_ALL, B.FY_IPN_Q_ALL
FROM FY_2019_2021G AS A LEFT JOIN SNF_AGGREGATED_FY_2019_2021_3 AS B
ON A.SNF_PRVDR_NUM=B.SNF_PRVDR_NUM;
QUIT;

DATA FY_2019_2021I; SET FY_2019_2021H;
IF FY_IPN_Q_ALL=1 THEN FY_IPN_Q_GRAPH_ALL="Total Penalty Quartile 1";
IF FY_IPN_Q_ALL=2 THEN FY_IPN_Q_GRAPH_ALL="Total Penalty Quartile 2";
IF FY_IPN_Q_ALL=3 THEN FY_IPN_Q_GRAPH_ALL="Total Penalty Quartile 3";
IF FY_IPN_Q_ALL=4 THEN FY_IPN_Q_GRAPH_ALL="Total Penalty Quartile 4";
run;


****************************************************************************************
STEP 8: FINALIZING FY-SNF DATASET 
****************************************************************************************;
DATA FRZ.SNF_FY_2019_2021; SET FY_2019_2021I;

LABEL 
SNF_PRVDR_NUM='MedPar: SNF CCN'
FY='Fiscal Year'
FY_ENCOUNTERS_ALL='Patient Aggregation from ALL SNF VISITS: Fiscal Year total number of patient encounters'
FY_MDCR_REIMBURSEMENT_ALL='Patient Aggregation from ALL SNF VISITS: Fiscal Year total Medicare reimbursement'
totbeds='LTC Focus: CALENDAR YEAR # of Beds'
SNF_CITY='LTC Focus: CALENDAR YEAR City'
SNF_ZIP='LTC Focus: CALENDAR YEAR ZIP'
SNF_STATE='LTC Focus: CALENDAR YEAR State'
SNF_COUNTY='LTC Focus: CALENDAR YEAR County code'
multifac='LTC Focus: CALENDAR YEAR multiple facilities'
PROFIT='LTC Focus: CALENDAR YEAR Profit status'
SNF_agg_cmi_mds3='LTC Focus: CALENDAR YEAR Average Resource Utilization Group Nursing Case Index'
overall_rating='VBP Provider Data: Fiscal Year SNF Overall Rating'
Staffing_Rating='VBP Provider Data: Fiscal Year SNF Staffing Rating'
SS_Quality_Rating='VBP Provider Data: Fiscal Year SNF Short Stay Rating'
NET_OPERATING_MARGIN='Cost Data: Net_Income / (Net_Patient_Revenue+Total_Other_Income)'
Net_Income='Cost Data: Net_Income'
NET_OPERATING_EXP='Cost Data: Net_Patient_Revenue+Total_Other_Income'
Gross_Revenue='Cost Data: Gross_Revenue'
Net_Patient_Revenue='Cost Data: Net_Patient_Revenue'
Total_Other_Income='Cost Data: Total_Other_Income'
IPM_FY2019='Derived: 2019 Incentive Payment per Net Operating Income'
IPM_FY2020='Derived: 2020 Incentive Payment per Net Operating Income'
IPM_FY2021='Derived: 2021 Incentive Payment per Net Operating Income'
Incentive_Payment_Multiplier='VBP: Incentive_Payment_Multiplier'
FY_MDCR_REIMBURSEMENT_WMULT_ALL='Derived: From ALL SNF VISITS, Fiscal Year Medicare Reimbursement * Incentive Payment Multiplier'
FY_Incentive_Payment_ALL='Derived: ALL SNF VISITS, Adjusted Medicare Reimbursement - Raw Medicare Reimbursement'
MAX_PENALTY_ALL='Derived: From ALL SNF VISITS, Fiscal Year 2% of Raw Medicare Reimbursement (2% * Raw Medicare Reimbursement)'
PENALTY_FLAG_ALL='Derived: From ALL SNF VISITS, 0 = Incentive_Payment_Multiplier>=1 | 1 = Incentive_Payment_Multiplier<1'
FY_INCENTIVE_PER_REVENUE_ALL='Derived: From ALL SNF VISITS, Incentive Payment per Net Patient Revenue'
FY_INCENTIVE_PER_NETOPINCOME_ALL='Derived: From ALL SNF VISITS, Incentive Payment per Net Operating Income'
ABS_NET_OPERATING_EXP='Derived: Absolute value of net operating expenses'
FY_IPN_ALL='Derived: From ALL SNF VISITS, Incentive Payment per |Net Operating Income|'
SUM_FY_IPN_ALL='Derived: From ALL SNF VISITS, sum(Incentive Payment) per sum(|Net Operating Income|)'
FY_IPN_Q_ALL='Derived: From ALL SNF VISITS, quartile of SUM_FY_IPN_ALL'
FY_IPN_Q_GRAPH_ALL='Derived: Graph ready percent_penalty_Q_ALL'
;

DROP _TYPE: ;

RUN;