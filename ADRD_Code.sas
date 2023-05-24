
/********************************************************************************************************************/
/*  INSTRUCTIONS - PLEASE READ THIS FIRST.																			*/
/*																													*/
/*  The data you requested for your analysis exist in a read-only dataset. 											*/
/*  If/when you update your request, your read-only dataset will be updated. 										*/
/*  																												*/
/*  This code does three things: 																					*/
/* 		1. It reads your data.																						*/
/*		2. It includes some standard code & procedures to help you get started with your data and analysis. 		*/
/* 		3. It can be expanded and saved and copied as you conduct your analysis. 									*/
/*																													*/
/*	There is no need to make copies of your dataset or to save datasets in your project or personal folders.		*/
/*	We encourage you to make temporary or working datasets in your code below.										*/
/* 	This approach--having 1 read-only dataset for your project--reduces data errors & increases data fidelity.		*/
/*																													*/
/*  The standard code & procedures include descriptions of what that code does. 									*/
/*	Feel free to comment-in/comment-out that code as needed for your analysis.										*/
/*																													*/
/*	Save changes to this code in your project folder by adding the date to the file name in the format _MMDDYYYY. 	*/
/********************************************************************************************************************/	
/* 	This code clears the log and output files; comment in or out as you wish										*/
	/*DM "log;clear;";
	DM "output;clear;";


/********************************************************************************************************************/	
/**************** RUN EVERYTHING IN THIS BOX TO GET YOUR PROJECT DATA, CALLED ANALYSIS_READY ************************/
/*	This section reads your data and creates a working dataset for your analysis.									*/
/*  If you generate a new dataset in the app, update the line that starts with %Include								*/
	%Include 'O:\Datasets\10326_ALZMOR\v01\10326_ALZMOR_v01_20221007_1019_assign_data_type_code.sas';
	libname read 'S:\Researcher Projects\CTS Exploratory Data\Read Only Source Files';

data analysis_ready;
*Merging the data to get deaths through 2020;
	merge analytic_data (in=b) 
		read.participant_table_ssap (in=a keep=participant_key date_of_death_dt cause_of_death_cde cause_of_death_dsc);
		if a;
		by participant_key;

*Creating an indicator for dementia cause of death;
	dementia_cod=0;
	if first_moveout_ca_dt=. then do;
			*ICD-10 codes first, then ICD-09 codes;
			if cause_of_death_cde=:'F01' or cause_of_death_cde=:'F03'
				or cause_of_death_cde=:'F04' or cause_of_death_cde=:'F05'
				or cause_of_death_cde=:'G31' or cause_of_death_cde ='F061'
				or cause_of_death_cde ='F068' or cause_of_death_cde=:'G30'
				or cause_of_death_cde=:'G31' or cause_of_death_cde=:'R54'

				or cause_of_death_cde=:'290' or cause_of_death_cde=:'291' 
				or cause_of_death_cde= '2942' or cause_of_death_cde='2948'
				or cause_of_death_cde='2949' or cause_of_death_cde='3310'
				or cause_of_death_cde='3311' or cause_of_death_cde='3312'
				or cause_of_death_cde='3317' or cause_of_death_cde='33182'
				or cause_of_death_cde='33189' or cause_of_death_cde='3319'
				or cause_of_death_cde='797' 
			then dementia_cod=1; 
	end;

*Creating an indicator for vital status;
		deceased=0;
			if date_of_death_dt ne . then deceased=1;

*Creating a censoring date & reason variable;
		endfollowup=mdy(12,31,2020); *<---maximum possible enddate;
		analysis_end_date=min(date_of_death_dt,first_moveout_ca_dt,endfollowup);
		censor_reason=.;
		if analysis_end_date=endfollowup then censor_reason=4;
		if analysis_end_date=first_moveout_ca_dt then censor_reason=3;
		if analysis_end_date=date_of_death_dt then censor_reason=2;
		if analysis_end_date=date_of_death_dt and dementia_cod=1 then censor_reason=1;

	label censor_reason='1=Dementia death, 2=death from other cause, 3=move out of CA, 4=end of study';
run;


/********************************************************************************************************************
 DATA EXPLORATION
/*******************************************************************************************************************/;
/* 	Review the contents of your data																				*/
	proc contents data=analysis_ready varnum;
		title "Data Contents"; 
		run;
* Check for missing or weird values for your relevant variables;
	proc means data=analysis_ready NMISS;
	var qnr_1_fill_dt ses_quartile_ind age_at_baseline participant_race dementia_cod 
		deceased censor_reason analysis_end_date;
		title "Missing Data Check";
	run;

*View frequencies of dementia_cod, vital status, reason follow-up ended, & ADRD ICD code;
	proc freq data=analysis_ready;
		tables dementia_cod deceased censor_reason;
		title "Frequency of Dementia; Deceased status; Censor Reason";
	run;

	proc freq data=analysis_ready;
		tables cause_of_death_cde;
		where censor_reason=1;
		title "ICD Codes for ADRD Deaths";
	run;

*View distribution over time: date of death, analysis end date, censor_reason;
	proc freq data=analysis_ready;
		tables date_of_death_dt analysis_end_date analysis_end_date*censor_reason;
		format date_of_death_dt analysis_end_date YEAR.;
		title "Distribution of death date, analysis end date, censor reason by year";
	run;

*View distribution of date of death where dementia was the cause of death;
	proc freq data=analysis_ready;
		tables date_of_death_dt;
		format date_of_death_dt YEAR.;
		where dementia_cod=1;
		title "ADRD Deaths by Year";
	run;

*Get total in cohort by SES;
	proc freq data=analysis_ready;
		tables ses_quartile_ind;
		title "Total Cohort by SES Quartile";
	run;


************************************************************************************************************************
/*  PART 1: ANALYSIS-SPECIFIC DATA/VARIABLE MANIPULATIONS																					*/
************************************************************************************************************************;
*FULL-COHORT DATASET GENERATED TO GET DEMOGRAPHICS OF ADRD DEATHS LATER;
	data full_cohort; 
		set analysis_ready;

	* creating a variable for follow-up time at time in years from baseline to end of follow-up;
		followuptime=(analysis_end_date - qnr_1_fill_dt)/365.25;

	* creating an Age at Death variable*;
		if deceased=1 then age_at_death=(date_of_death_dt - date_of_birth_dt)/365.25;
			else age_at_death=.;
			label age_at_death='Date of Death minus Date of Birth, in years';
		rd_age_at_death=floor(age_at_death);
		run;

* SETTING UP PARTICIPANTS BY YEAR TABLE - THIS WILL BE USED TO CALCULATE ANNUAL AGE-ADJUSTED RATES LATER
	* Creates separate tables for each single year of the study. 
	* Each person in the study at any time that year will be in the appropriate annual table;
	* Put in your relevant variables in the select statement, but DO NOT take out the '&yyyy AS year' statement
	* Note that rates will start with the year 2000 in this study due to healthy respondent bias;
		%macro annualtables(start,end);
			proc sql;
				%DO yyyy=&start. %TO &end.;
				create table work.annualdata&yyyy as
					select participant_key, date_of_birth_dt, date_of_death_dt, ses_quartile_ind, participant_race, dementia_cod,
							censor_reason, analysis_end_date, qnr_1_fill_dt, 
							&yyyy AS year
						from work.full_cohort
						where analysis_end_date >= mdy(1,1,&yyyy) and qnr_1_fill_dt < mdy(12,31,&yyyy);
							*where statement ensures people already censored in previous years do not appear in that years table;
				%END;
			quit;
		%MEND;

		%annualtables(start=2000, end=2020); *<----put your range of years here;

	*Merge separate annual tables into one combined table;
		data alzdemd_analysis;
			set annualdata2000-annualdata2020; *<----reflect your range of years here;
		run;

	*Delete individual annual tables as they're no longer needed;
		proc delete library=work data=annualdata2000-annualdata2020; *<----reflect your range of years here;
		run;

*VARIABLE CREATION IN COMBINED PERSON-YEAR ANNUAL TABLE
	*Create age variable accounting for if person censored during that year;
		data alzdemd_analysis; set alzdemd_analysis;
			if analysis_end_date <= mdy(12,31,year) then age = YRDIF(date_of_birth_dt, analysis_end_date, "AGE");
			if analysis_end_date > mdy(12,31,year) then age = YRDIF(date_of_birth_dt, mdy(7,1,year), "AGE"); *<---age at midyear for those not censored during the year;

	*Create personyears for each annual observation, accounting for leap years
		*No personyear calculation in any single row should be greater than 1 or <= 0. 
		*There should also be a lot of annual observations with values of 1, as most people make it though an entire year.;
			if MOD(year,4)^=0 OR (MOD(year,100)=0 AND MOD(year,400)^=0) 
				then personyears = (min(analysis_end_date, mdy(12,31,year))+1 - max(qnr_1_fill_dt, mdy(01,01,year)))/365;
			else personyears = (min(analysis_end_date, mdy(12,31,year))+1 - max(qnr_1_fill_dt, mdy(01,01,year)))/366;
	
	*Create age groups for age-adjustment;
			if age<65 then age_group=1;
	 		else if age<70 then age_group=2;
	 		else if age<75 then age_group=3;
	 		else if age<80 then age_group=4;
	 		else if age<85 then age_group=5;
	 		else if age<90 then age_group=6;
	 		else if age<95 then age_group=7;
	 		else if age>=95 then age_group=8;
		label age_group= '(1) <65 (2) 65-69 (3) 70-74 (4) 75-79 (5) 80-84 (6) 85-89 (7) 90-94 (8) 95+';

	*Create Demetia Death Event variable. If it happened in that year, then '1'. 
	******THIS IS THE OUTCOME VARIABLE FOR AGE-ADJUSTED ANNUAL RATE CALCULATIONS*******;
			if dementia_cod=1 and censor_reason=1 and (date_of_death_dt =< mdy(12,31,year) and date_of_death_dt >= mdy(1,1,year))
				then dem_death = 1;
				else dem_death= 0;

	*Create grouped race (nonwhite or white) variable because of low number of ADRD deaths in individual racial/ethnic groups;
			if participant_race=1 then nonwhite=0;
			if participant_race=2 then nonwhite=1;
			if participant_race=3 then nonwhite=1;
			if participant_race=4 then nonwhite=1;
			if participant_race=5 then nonwhite=1;
			if participant_race=6 then nonwhite=1;
			label nonwhite='0=white, 1=nonwhite, .=none provided';

	*Creating 4 separate fields for SES Quartile status;
			if ses_quartile_ind=1 then SES_Q1 = 1; else SES_Q1=0;
			if ses_quartile_ind=2 then SES_Q2 = 1; else SES_Q2=0;
			if ses_quartile_ind=3 then SES_Q3 = 1; else SES_Q3=0;
			if ses_quartile_ind=4 then SES_Q4 = 1; else SES_Q4=0;

	*Create SES below and above median variable;
			if (ses_quartile_ind=1 or ses_quartile_ind=2) then SES_AboveMed = 0; else SES_AboveMed=1;

	*Create 10-year age groups to calculate crude age rates;
			if age_group=1 then age_group_coll = 1;
			if age_group=2 or age_group=3 then age_group_coll = 2;
			if age_group=4 or age_group=5 then age_group_coll = 3;
			if age_group=6 or age_group=7 then age_group_coll = 4;
			if age_group=8 then age_group_coll = 5;
			label age_group_coll = '(1)=below 65, (2)=65-74, (3)=75-84, (4)=85-94, (5)=95+';
		run;

*SENSITIVITY ANALYSIS SETUP - calculating separate rates for 1/1/20-3/10/20 & 4/1/20-12/31/20
	*Create 1/1 to 3/10 table;
		proc sql;
			create table work.sensitivity1 as
				select *
				from work.alzdemd_analysis
				where year=2020;
		quit;
	
	*Create 4/1 to 12/31 table;
		proc sql;
			create table work.sensitivity2 as
				select *
				from work.alzdemd_analysis
				where year=2020 and analysis_end_date >=mdy(4,1,2020);
		quit;
	*Adjust person-time, outcome code, age, and age group for 1/1-3/10 group;
		data sensitivity1; set sensitivity1;
		*set year label;
			year=20201;

		*person-years;
			if analysis_end_date < mdy(3,11,2020)
			then personyears = (analysis_end_date - mdy(12,31,2019))/366;
			else personyears = (mdy(3,11,2020) - mdy(01,01,2020))/366;
		
		*Outcome during time period;
			if dementia_cod=1 and censor_reason=1 and (date_of_death_dt < mdy(3,11,2020) and date_of_death_dt >= mdy(1,1,2020))
				then dem_death = 1;
				else dem_death= 0;

		*age;
			if analysis_end_date < mdy(3,11,2020) 
				then age = YRDIF(date_of_birth_dt, analysis_end_date, "AGE");*<---age at death;
			if analysis_end_date > mdy(3,11,2020) 
				then age = YRDIF(date_of_birth_dt, (mdy(1,1,2020)+mdy(3,11,2020))/2, "AGE"); *<---age at midpoint;

		*age group;
			if age<65 then age_group=1;
	 		else if age<70 then age_group=2;
	 		else if age<75 then age_group=3;
	 		else if age<80 then age_group=4;
	 		else if age<85 then age_group=5;
	 		else if age<90 then age_group=6;
	 		else if age<95 then age_group=7;
	 		else if age>=95 then age_group=8;
			label age_group= '(1) <65 (2) 65-69 (3) 70-74 (4) 75-79 (5) 80-84 (6) 85-89 (7) 90-94 (8) 95+';
		run;

	*Adjust person-time, outcome code, age, and age group for 4/1-12/31 group;
		data sensitivity2; set sensitivity2;
		*set year label;
			year=20202;
		*person-years;
			if analysis_end_date <= mdy(12,31,2020)
			then personyears = (analysis_end_date - mdy(3,31,2020))/366;
			else personyears = (mdy(1,1,2021) - mdy(3,31,2020))/366;

		*outcome during time period;
			if dementia_cod=1 and censor_reason=1 and (date_of_death_dt < mdy(1,1,2021) and date_of_death_dt >= mdy(4,1,2020))
				then dem_death = 1;
				else dem_death= 0;

		*age;
			if analysis_end_date <= mdy(12,31,2020) 
				then age = YRDIF(date_of_birth_dt, analysis_end_date, "AGE");*<---age at censor;
			if censor_reason=4 
				then age = YRDIF(date_of_birth_dt, (mdy(4,1,2020)+mdy(1,1,2021))/2, "AGE"); *<---age at midpoint;
			if analysis_end_date = mdy(12,31,2020) and censor_reason ne 4 
				then age = YRDIF(date_of_birth_dt, analysis_end_date, "AGE");

		*age group;
			if age<65 then age_group=1;
	 		else if age<70 then age_group=2;
	 		else if age<75 then age_group=3;
	 		else if age<80 then age_group=4;
	 		else if age<85 then age_group=5;
	 		else if age<90 then age_group=6;
	 		else if age<95 then age_group=7;
	 		else if age>=95 then age_group=8;
			label age_group= '(1) <65 (2) 65-69 (3) 70-74 (4) 75-79 (5) 80-84 (6) 85-89 (7) 90-94 (8) 95+';
		run;
	*Combine tables;
		data sensitivity;
			set sensitivity1-sensitivity2;
			label year='20201 = 1/1/20-3/10/20; 20202 = 4/1/20-12/31/20';
		run;
	*delete separate sensitivity tables;
		proc delete library=work data=sensitivity1-sensitivity2;
		run;

*CREATE STANDARD AGE TABLE (US 2010 Census for women in this case);
		data work.stdage;
			input age_group age_group_desc $ pop;
			datalines;
			1 0-64 134059188
			2 65-69 6582716
			3 70-74 5034194
			4 75-79 4135407
			5 80-84 3448953
			6 85-89 2346592
			7 90-94 1023979
			8 95+ 333183
			;
		run;

************************************************************************************************************************
/*  PART 2: DEMOGRAPHICS OF AD&DEMENTIA DEATHS AND AGE-ADJUSTED RATE CALCULATIONS														*/
************************************************************************************************************************

*DESCRIPTIVE STATS ON DEATHS
 	*Distribution of dementia deaths by race, ses, age at baseline, and age at death;
	*Note that rates calculated only from 2000 forward to account for healthy participant bias;
		proc freq data=full_cohort;
			tables participant_race ses_quartile_ind;
			where censor_reason=1 and analysis_end_date > mdy(12,31,1999);
			title "Total ADRD Deaths by Race and by SES";

		proc means data=full_cohort;
			var age_at_baseline age_at_death;
			where censor_reason=1 and analysis_end_date > mdy(12,31,1999);
			title "Mean Age at Baseline and at Death - ADRD Deaths";

		proc freq data=full_cohort;
			tables date_of_death_dt*participant_race date_of_death_dt*ses_quartile_ind / nopercent norow nocol;
			format date_of_death_dt YEAR.;
			where censor_reason=1 and analysis_end_date > mdy(12,31,1999);
			title "Year of ADRD Death by Race and by SES";

		proc freq data=alzdemd_analysis;
			tables age_group_coll*dem_death / nopercent norow nocol;
			title "Year of ADRD Death by Age";
		run;

*AGE-ADJUSTED RATES
	*Age-adjusted rates by year - All;
		ods results off;
		ods table stdrate=annual_rate_all;

		proc sort data=alzdemd_analysis;
			by year;
		run;
		proc stdrate data=alzdemd_analysis
					refdata = stdage
					method = direct
					stat=rate (mult=100000)
					CL=normal
					plots = none;
			population event=dem_death total=personyears;
			reference total=pop;
			strata age_group;
			by year;
			title "Age-Adjusted Rates by Year - Overall";
		run;

	*Age-adjusted rates by white/nonwhite;
		*create table removing annual observations with 'not reported' values for race-ethnicity;
		proc sql; create table alzdemd_analysis_race as
			select * from alzdemd_analysis
			where nonwhite <> .;
		quit;

		*calculate rates;
		ods table stdrate=annual_rate_byrace;
		ods table effect=rateratio_byrace;
		proc stdrate data=alzdemd_analysis_race
					refdata = stdage
					method = direct
					stat=rate (mult=100000)
					CL=normal
					effect=ratio
					plots = none;
			population group=nonwhite event=dem_death total=personyears;
			reference total=pop;
			strata age_group / effect;
			by year;
			title "Age-Adjusted Rates by Year and by Race";
		run;


	*Age-adjusted rates by SES quartile;
		*create table removing annual observations with null SES values;
		proc sql; create table alzdemd_analysis_ses as
			select * from alzdemd_analysis
			where ses_quartile_ind <> .;
		quit;
		
		*get rates by quartile;
		*Q1;
		ods table stdrate=annual_rate_SESQ1;
		proc stdrate data=alzdemd_analysis_ses
					refdata = stdage
					method = direct
					stat=rate (mult=100000)
					CL=normal
					plots=none;
			population group=SES_Q1 event=dem_death total=personyears;
			reference total=pop;
			strata age_group;
			by year;
			title "Age-Adjusted Rates for Q1 SES";
		run;

		*Q2;
		ods table stdrate=annual_rate_SESQ2;
		proc stdrate data=alzdemd_analysis_ses
					refdata = stdage
					method = direct
					stat=rate (mult=100000)
					CL=normal
					plots=none;
			population group=SES_Q2 event=dem_death total=personyears;
			reference total=pop;
			strata age_group;
			by year;
			title "Age-Adjusted Rates for Q2 SES";
		run;

		*Q3;
		ods table stdrate=annual_rate_SESQ3;
		proc stdrate data=alzdemd_analysis_ses
					refdata = stdage
					method = direct
					stat=rate (mult=100000)
					CL=normal
					plots=none;
			population group=SES_Q3 event=dem_death total=personyears;
			reference total=pop;
			strata age_group;
			by year;
			title "Age-Adjusted Rates for Q3 SES";
		run;

		*Q4;
		ods table stdrate=annual_rate_SESQ4;
		proc stdrate data=alzdemd_analysis_ses
					refdata = stdage
					method = direct
					stat=rate (mult=100000)
					CL=normal
					plots=none;
			population group=SES_Q4 event=dem_death total=personyears;
			reference total=pop;
			strata age_group;
			by year;
			title "Age-Adjusted Rates for Q4 SES";
		run;

		*Combine separate quartile rates into one table for summarizing;
		proc sql; create table annualrates_SES as
			select annual_rate_sesq1.year, 
			   		annual_rate_sesq1.stdrate as Q1,
			   		annual_rate_sesq2.stdrate as Q2,
			   		annual_rate_sesq3.stdrate as Q3,
			   		annual_rate_sesq4.stdrate as Q4
			from annual_rate_sesq1
			join annual_rate_sesq2 on annual_rate_sesq1.year=annual_rate_sesq2.year
			join annual_rate_sesq3 on annual_rate_sesq2.year=annual_rate_sesq3.year
			join annual_rate_sesq4 on annual_rate_sesq3.year=annual_rate_sesq4.year
			where ses_q1=1 and ses_q2=1 and ses_q3=1 and ses_q4=1;
		quit;

	*Create age-adjusted rates by SES above/below median;
		ods table stdrate=annual_rate_bySESmedian;
		ods table effect=rateratio_bySESmedian;
		proc stdrate data=alzdemd_analysis_ses
					refdata = stdage
					method = direct
					stat=rate (mult=100000)
					CL=normal
					effect=ratio
					plots=none;
			population group=SES_AboveMed event=dem_death total=personyears;
			reference total=pop;
			strata age_group / effect;
			by year;
			title "Age-Adjusted Rates for SES Above & Below Median";
		run;
	ods results on;

	*Calculate crude rates by 10-year age strata*;
		proc sql;
			create table annual_crude_agegroup as
				select year, age_group_coll, sum(dem_death) as dem_death, sum(personyears) as personyears
				from alzdemd_analysis
				group by year, age_group_coll;
		quit;

		data annual_crude_agegroup; set annual_crude_agegroup;
			cruderate= (alzdem_death/personyears)*100000;
		run;

		proc sort data=annual_crude_agegroup;
			by age_group_coll;
		run;

	*Sensitivity Analysis;
		ods table stdrate=rate_2020sensitivity;
		ods table effect=rateratio_2020sensitivity;
		proc stdrate data=sensitivity
					refdata = stdage
					method = direct
					stat=rate (mult=100000)
					CL=normal
					effect=ratio
					plots=none;
			population group=year event=dem_death total=personyears;
			reference total=pop;
			strata age_group / effect;
			title "2020 COVID-19 Sensitivity Analysis";
		run;

************************************************************************************************************************
/*  PART 3: *VIEW SUMMARY TABLES FOR ANNUAL AGE-ADJUSTED RATES*														*/	
************************************************************************************************************************;
	*total cohort by year;
		proc print data=annual_rate_all; 
			var year stdrate lowercl uppercl;
			format stdrate lowercl uppercl 5.1;
			title 'Age-adjusted annual mortality rates from AD/dementia per 100,000';
		run;
	*By white/nonwhite;
		proc print data=rateratio_byrace;
			var year rate comprate rateratio probz;
			label rate='White' comprate='Nonwhite' probz='p' year='Year';
			format rate comprate 5.1 rateratio probz 5.2;
			title 'Age-adjusted annual mortality rates from AD/dementia per 100,000 by race';
			footnote1 'Rate=white, Comprate=Nonwhite';
		run; 
	*BY SES Quartile;
		proc print data=annualrates_SES;
			format q1 q2 q3 q4 5.1;
			title 'Age-adjusted annual mortality rates from AD/dementia per 100,000 by SES quartile';
			footnote1 '1=highest quartile';
		run;
	*By SES above/below median;
		proc print data=rateratio_bysesmedian;
			var year rate comprate rateratio probz;
			label rate='below median' comprate='above median' probz='p';
			format rate comprate 5.1 rateratio probz 5.2;
			title 'Age-adjusted annual mortality rates from AD/dementia per 100,000 by SES (above or below median)';
			footnote1 'Rate=below median; Comprate=above median';
		run; 
	*Sensitivity for 2020 Covid;
		proc print data=rateratio_2020sensitivity;
			var rate comprate rateratio probz;
			label rate='Before 3/11/20' comprate='4/1/20 - 12/31/20' probz='p';
			format rate comprate 5.1 rateratio probz 5.2;
			title 'Age-adjusted annual mortality rates - pre-Covid and post-Covid';
			footnote1 'Rate=Before Mar 11, Comprate=Apr 1 to Dec 31';
		run;
