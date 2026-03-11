******************************************************************************************************************************************************;
*  Project Name :           SNF VBP Penalties				 																											*
*  Principal Investigator : Burke																																		*
*  Name of Program :        2_Table_FRZ.sas																							
*  Programmer :             Jonathan Heintz                                                                 															*
*  Start Date :             October 2nd, 2024	                                                               															*
*  Program Description :	Describes SNF penalties overall and by fiscal year, 2019-2021
 																											*
*************************************************************************************************************************************************************;

*Run library locations;
%include '[filepath to code writing library locations]';

data penalty ; set FRZ.SNF_FY_2019_2021;

max_flag=0; 
if incentive_Payment_multiplier <0.9805 then max_flag=1; 

IPN_PCT=100*(FY_IPN_ALL);

run; 
*n=40944 SNF-years;

proc sql noprint; 
create table unique_snfs as 
select distinct snf_prvdr_num, count(*) as n_years
from penalty /*nomiss*/
group by snf_prvdr_num;
quit;
*14,189;

proc freq data=unique_snfs; table n_years; run;

*Values for Exhibit 1;
title "N";
proc means data=penalty n ;
var FY_Incentive_Payment_ALL; run;
proc means data=penalty n ;
var FY_Incentive_Payment_ALL; class fy; run;
proc freq data=unique_snfs; table n_years; run;

title "Incentive Payment Multiplier Range";
proc means data=penalty n min max maxdec=4;
var Incentive_Payment_multiplier;  run;
proc means data=penalty n min max maxdec=4;
var Incentive_Payment_multiplier; class fy; run;

title "Percent Penalized";
proc freq data=HDATA_F.SNF_FY_2019_2021; tables  fy*penalty_flag_ALL; run; 
title "Percent with Max Penalty";
proc freq data=penalty; tables  fy*max_flag; run; 

title "Incentive Payment Amount";
proc means data=penalty n median p25 p75 maxdec=0; 
var  FY_Incentive_Payment_ALL;
run; 
proc means data=penalty n median p25 p75 maxdec=0; 
var  FY_Incentive_Payment_ALL;
class fy ; run; 

title "Incentive Payment Amount as Percent NOI";
proc means data=penalty n median p25 p75 maxdec=2; 
var  IPN_PCT;
run; 
proc means data=penalty n median p25 p75 maxdec=2; 
var  IPN_PCT;
class fy ; run; 

title; 
