/******************************************************************************************************************************************************
*  Project Name :           SNF VBP Penalties				 																											
*  Principal Investigator : Burke																																	
*  Name of Program :        0_Penalty_Cohort_Visit_FRZ.sas																							
*  Programmer :             J Heintz, F Hutchins                                                                 															
*  Start Date :            	2/26/25	                                                               															
*  Program Description :	Creates a visit level dataset from CMS MedPAR and denominator (MBSF) files																											*

********************************************************************************************************************************************************/

*Run library locations;
%include '[filepath to code writing library locations]';

*Step 1. MBSF: Identify beneficiary Medicare coverage type, 2019 - 2021; 
proc sql noprint;
create table BENE_in as 
select * from bene.dn100mod_2018
(keep= bene_id rfrnc_yr 
HMOIND01-HMOIND12 BUYIN01 -BUYIN12 
MDCR_STATUS_CODE_01-MDCR_STATUS_CODE_12 
 PTC_PLAN_TYPE_CD_01-PTC_PLAN_TYPE_CD_12 
DUAL_STUS_CD_01-DUAL_STUS_CD_12) 

outer union corr 
select * from bene.dn100mod_2019
(keep= bene_id rfrnc_yr 
HMOIND01-HMOIND12 BUYIN01 -BUYIN12 
MDCR_STATUS_CODE_01-MDCR_STATUS_CODE_12 
PTC_PLAN_TYPE_CD_01-PTC_PLAN_TYPE_CD_12 
DUAL_STUS_CD_01-DUAL_STUS_CD_12 ) 

outer union corr
select 	*, BENE_ENROLLMT_REF_YR AS rfrnc_yr, 
		HMO_IND_01 AS HMOIND01,	HMO_IND_02 AS HMOIND02,	
		HMO_IND_03 AS HMOIND03,	HMO_IND_04 AS HMOIND04,	
		HMO_IND_05 AS HMOIND05,	HMO_IND_06 AS HMOIND06,	
		HMO_IND_07 AS HMOIND07,	HMO_IND_08 AS HMOIND08,	
		HMO_IND_09 AS HMOIND09,	HMO_IND_10 AS HMOIND10,
		HMO_IND_11 AS HMOIND11,	HMO_IND_12 AS HMOIND12,	
		MDCR_ENTLMT_BUYIN_IND_01 AS BUYIN01,	
		MDCR_ENTLMT_BUYIN_IND_02 AS BUYIN02,	
		MDCR_ENTLMT_BUYIN_IND_03 AS BUYIN03,	
		MDCR_ENTLMT_BUYIN_IND_04 AS BUYIN04,	
		MDCR_ENTLMT_BUYIN_IND_05 AS BUYIN05,	
		MDCR_ENTLMT_BUYIN_IND_06 AS BUYIN06,	
		MDCR_ENTLMT_BUYIN_IND_07 AS BUYIN07,	
		MDCR_ENTLMT_BUYIN_IND_08 AS BUYIN08,	
		MDCR_ENTLMT_BUYIN_IND_09 AS BUYIN09,	
		MDCR_ENTLMT_BUYIN_IND_10 AS BUYIN10,	
		MDCR_ENTLMT_BUYIN_IND_11 AS BUYIN11,	
		MDCR_ENTLMT_BUYIN_IND_12 AS BUYIN12
from bene.MBSF_ABCD_SUMMARY_2020
(keep= 	bene_id BENE_ENROLLMT_REF_YR  
		HMO_IND_01-HMO_IND_12 
		MDCR_ENTLMT_BUYIN_IND_01-MDCR_ENTLMT_BUYIN_IND_12 
		MDCR_STATUS_CODE_01-MDCR_STATUS_CODE_12 
		PTC_PLAN_TYPE_CD_01-PTC_PLAN_TYPE_CD_12 
		DUAL_STUS_CD_01-DUAL_STUS_CD_12 ) 
 
outer union corr
select 	*, BENE_ENROLLMT_REF_YR AS rfrnc_yr, 
		HMO_IND_01 AS HMOIND01,	HMO_IND_02 AS HMOIND02,	
		HMO_IND_03 AS HMOIND03,	HMO_IND_04 AS HMOIND04,	
		HMO_IND_05 AS HMOIND05,	HMO_IND_06 AS HMOIND06,	
		HMO_IND_07 AS HMOIND07,	HMO_IND_08 AS HMOIND08,	
		HMO_IND_09 AS HMOIND09,	HMO_IND_10 AS HMOIND10,
		HMO_IND_11 AS HMOIND11,	HMO_IND_12 AS HMOIND12,	
		MDCR_ENTLMT_BUYIN_IND_01 AS BUYIN01,	
		MDCR_ENTLMT_BUYIN_IND_02 AS BUYIN02,	
		MDCR_ENTLMT_BUYIN_IND_03 AS BUYIN03,	
		MDCR_ENTLMT_BUYIN_IND_04 AS BUYIN04,	
		MDCR_ENTLMT_BUYIN_IND_05 AS BUYIN05,	
		MDCR_ENTLMT_BUYIN_IND_06 AS BUYIN06,	
		MDCR_ENTLMT_BUYIN_IND_07 AS BUYIN07,	
		MDCR_ENTLMT_BUYIN_IND_08 AS BUYIN08,	
		MDCR_ENTLMT_BUYIN_IND_09 AS BUYIN09,	
		MDCR_ENTLMT_BUYIN_IND_10 AS BUYIN10,	
		MDCR_ENTLMT_BUYIN_IND_11 AS BUYIN11,	
		MDCR_ENTLMT_BUYIN_IND_12 AS BUYIN12
from bene.MBSF_ABCD_SUMMARY_2021
(keep= 	bene_id BENE_ENROLLMT_REF_YR  
		HMO_IND_01-HMO_IND_12 
		MDCR_ENTLMT_BUYIN_IND_01-MDCR_ENTLMT_BUYIN_IND_12 
		MDCR_STATUS_CODE_01-MDCR_STATUS_CODE_12 
		PTC_PLAN_TYPE_CD_01-PTC_PLAN_TYPE_CD_12 
		DUAL_STUS_CD_01-DUAL_STUS_CD_12 ) 
;

quit;
*260,304,530 ;

proc freq data=bene_in; tables BUYIN12 HMOIND12; run;
 
*Convert HMO and Buy-in variables to fee-for-service (F) vs Medicare Advantage (M);
data covtype; set bene_in;
length 	HMO_01 HMO_02 HMO_03 HMO_04 HMO_05 HMO_06 
		HMO_07 HMO_08 HMO_09 HMO_10 HMO_11 HMO_12 $1.;
		
array cov_in [12] $		BUYIN01 BUYIN02 BUYIN03 BUYIN04 BUYIN05 BUYIN06
						BUYIN07 BUYIN08 BUYIN09 BUYIN10 BUYIN11 BUYIN12;
							
array hmo_in [12] $		HMOIND01 HMOIND02 HMOIND03 HMOIND04 HMOIND05 HMOIND06 
						HMOIND07 HMOIND08 HMOIND09 HMOIND10 HMOIND11 HMOIND12;
						
array hmo_out [12] $	HMO_01 HMO_02 HMO_03 HMO_04 HMO_05 HMO_06 
						HMO_07 HMO_08 HMO_09 HMO_10 HMO_11 HMO_12 ; 

do i=1 to 12; 
	hmo_out[i]=" "; 
		
	if hmo_in[i]="0" and cov_in[i]="0" then hmo_out[i]="X"; 
		else if hmo_in[i] in ("0", "4") then hmo_out[i]="F";
		else if hmo_in[i] in ("1", "C") then hmo_out[i]="M";
end; 
run; 
*260,304,530 beneficiary-years from 2018 through 2021;

*Create monthly coverage dataset by bene and year;
proc sort 	data=covtype (keep= bene_id rfrnc_yr HMO_01-HMO_12)
			out=covsort; 
by bene_id rfrnc_yr; 
run;

proc transpose data=covsort out=covlong; 
by bene_id rfrnc_yr; 
var HMO_01-HMO_12;
run; 

data cov_by_month; set covlong; 
month=input(substr(_name_, 5), 5.);

*restrict to fiscal years 2019 - 2021;
if (rfrnc_yr=2018 and month<10)
	or (rfrnc_yr=2021 and month>9)	then delete;
run; 
*Only 2,356,153,974 beneficiary-months;

*STEP 2. Bring in SNF stays from Medpar; 
proc sql noprint;
create table medpar_in as 
select *, year(admsndt) as year, month(admsndt) as month
from medpar.mp100mod_2018 
	(keep=bene_id ADMSNDT PMT_AMT PASSTHRU prvdr_num medpar_id) 
where'5000' <= SUBSTR(PRVDR_NUM,3,4)<= '6499'
		
outer union corr 
select *, year(admsndt) as year, month(admsndt) as month
from medpar.mp100mod_2019 
	(keep=bene_id ADMSNDT PMT_AMT PASSTHRU prvdr_num medpar_id) 
where'5000' <= SUBSTR(PRVDR_NUM,3,4)<= '6499'

outer union corr 
select 	*, year(admsn_dt) as year, month(admsn_dt) as month,
		ADMSN_DT as ADMSNDT, MDCR_PMT_AMT as PMT_AMT,
		PASS_THRU_AMT as PASSTHRU
from medpar.medpar_all_file_2020  (keep=bene_id medpar_id ADMSN_DT MDCR_PMT_AMT PASS_THRU_AMT prvdr_num) 
where'5000' <= SUBSTR(PRVDR_NUM,3,4)<= '6499'

outer union corr 
select 	*, year(admsn_dt) as year, month(admsn_dt) as month,
		ADMSN_DT as ADMSNDT, MDCR_PMT_AMT as PMT_AMT,
		PASS_THRU_AMT as PASSTHRU
from medpar.medpar_all_file_2021 (keep=bene_id medpar_id ADMSN_DT MDCR_PMT_AMT PASS_THRU_AMT prvdr_num) 
where'5000' <= SUBSTR(PRVDR_NUM,3,4)<= '6499'
;
quit;
 *7264244 ;
 
*STEP 3. Join SNF visit and Medicare coverage data; 
proc sql noprint; 
create table SNF_PMT as 
select 	a.BENE_ID, a.COL1 as COVTYPE, b.year, b.month, 
		b.PMT_AMT, b.PASSTHRU, b.admsndt, b.prvdr_num, b.medpar_id
from cov_by_month a 
inner join medpar_in b 
on a.bene_id=b.bene_id and a.rfrnc_yr=b.year and a.month=b.month;
quit;
*5315703 ; 
 
proc means data=snf_pmt; var pmt_amt passthru; class COVTYPE; 
run;
*Pass through amount is 0 for all visits;

*STEP 4. Restrict to beneficiaries in fee-for-service during 
the month of SNF admission date, & for fiscal years;

data /*frz.SNF_PMT_TM_20250226*/ snf_pmt_tm; set snf_pmt;
where COVTYPE="F" and '01OCT2018'd<=ADMSNDT<='30SEP2021'd;

label 	COVTYPE = "Medicare coverage type during month of SNF admission (F=FFS aka Traditional Medicare)"
		month="Month of SNF admission"
		year="Calendar year of SNF admission";
		
run; 
*n=5820744  visits;
 