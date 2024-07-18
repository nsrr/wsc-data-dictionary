*******************************************************************************;
* Program           : prepare-wsc-for-nsrr.sas
* Project           : National Sleep Research Resource (sleepdata.org)
* Author            : Michael Rueschman (mnr)
* Date Created      : 20200511
* Purpose           : Prepare Wisconsin Sleep Cohort (WSC) data for posting on
*                       NSRR.
*******************************************************************************;

*******************************************************************************;
* establish options and libnames ;
*******************************************************************************;
  options nofmterr;
  data _null_;
    call symput("sasfiledate",put(year("&sysdate"d),4.)||put(month("&sysdate"d),z2.)||put(day("&sysdate"d),z2.));
  run;

  *project source datasets;
  libname wscs "\\rfawin\BWH-SLEEPEPI-NSRR-STAGING\20200115-peppard-wsc\nsrr-prep\_source";

  *output location for nsrr sas datasets;
  libname wscd "\\rfawin\BWH-SLEEPEPI-NSRR-STAGING\20200115-peppard-wsc\nsrr-prep\_datasets";
  libname wsca "\\rfawin\BWH-SLEEPEPI-NSRR-STAGING\20200115-peppard-wsc\nsrr-prep\_archive";

  *nsrr id location;
  *libname wsci "\\rfawin\BWH-SLEEPEPI-NSRR-STAGING\20200115-peppard-wsc\nsrr-prep\_ids";

  *set data dictionary version;
  %let version = 0.7.0;

  *set nsrr csv release path;
  %let releasepath = \\rfawin\BWH-SLEEPEPI-NSRR-STAGING\20200115-peppard-wsc\nsrr-prep\_releases;

*******************************************************************************;
* create datasets ;
*******************************************************************************;
  data wsc_in;
    set wscs.nsrr_wsc_2024_0711; /* last updated july 2024 */
  run;

  data wsc_mslt;
    set wscs.nsrr_mslt;
  run;

  data wsc;
    length wsc_id wsc_vst 8.;
    set wsc_in;
  run;

  proc sort data=wsc nodupkey;
    by wsc_id wsc_vst;
  run;

  proc sort data=wsc_mslt nodupkey;
    by wsc_id wsc_vst;
  run;

  data wsc_drug;
    set wscs.nsrr_alldrugs; 
  run;

  proc sort data=wsc_drug nodupkey;
    by wsc_id wsc_vst;
  run;

  /*

  */

*******************************************************************************;
* make all variable names lowercase ;
*******************************************************************************;
  options mprint;
  %macro lowcase(dsn);
       %let dsid=%sysfunc(open(&dsn));
       %let num=%sysfunc(attrn(&dsid,nvars));
       %put &num;
       data &dsn;
             set &dsn(rename=(
          %do i = 1 %to &num;
          %let var&i=%sysfunc(varname(&dsid,&i));    /*function of varname returns the name of a SAS data set variable*/
          &&var&i=%sysfunc(lowcase(&&var&i))         /*rename all variables*/
          %end;));
          %let close=%sysfunc(close(&dsid));
    run;
  %mend lowcase;

  %lowcase(wsc);
  %lowcase(wsc_mslt);
  %lowcase(wsc_drug);

  data wsc_nsrr;
    merge
      wsc (in=a)
      wsc_drug
      ;
    by wsc_id wsc_vst;

    *only keep rows in main wsc dataset;
    if a;
  run;


  *merge sex and race into mslt dataset;

*make small dataset with only sex and race to merge;
 data wsc_sexrace (keep = sex race wsc_id wsc_vst);
    set wsc_nsrr;
 run;


  data wsc_mslt_merge;
    merge
    wsc_mslt (in=a)
    wsc_sexrace
      ;
    by wsc_id wsc_vst;

  if a;

  run;



*******************************************************************************;
* create separate datasets for each visit ;
*******************************************************************************;


*******************************************************************************;
* create permanent sas datasets ;
*******************************************************************************;
  data wscd.wsc_nsrr wsca.wsc_nsrr_&sasfiledate;
    set wsc_nsrr;
  run;

   data wscs.wsc_mslt_merge wsca.wsc_mslt_merge_nsrr_&sasfiledate;
    set wsc_mslt_merge;
  run;

  proc contents data=wsc_nsrr;
  run;

   proc contents data=wsc_mslt_merge;
  run;

*******************************************************************************;
* create harmonized datasets ;
*******************************************************************************;
data wsc_harmonized_temp;
  set wsc_nsrr;
  *subset wsc visit variable for Spout to use for graph generation;
   *if wsc_vst = 1 then output;
run;

data wsc_harmonized;
set wsc_harmonized_temp;

*demographics
*age;
*use age;
  format nsrr_age 8.2;
  if age gt 89 then nsrr_age = 90;
  else if age le 89 then nsrr_age = age;

*age_gt89;
*use age;
  format nsrr_age_gt89 $10.; 
  if age gt 89 then nsrr_age_gt89='yes';
  else if age le 89 then nsrr_age_gt89='no';

*sex;
*use sex;
  format nsrr_sex $10.;
  if sex = 'M' then nsrr_sex = 'male';
  else if sex = 'F' then nsrr_sex = 'female';
  else if sex = '.' then nsrr_sex = 'not reported';

*race;
*use race;
    format nsrr_race $100.;
  if race = '00' then nsrr_race = 'asian';
    else if race = '01' then nsrr_race = 'black or african american';
    else if race = '02' then nsrr_race = 'hispanic';
  else if race = '03' then nsrr_race = 'american indian or alaska native';
  else if race = '05' then nsrr_race = 'white';
    *else if race = '03' then nsrr_race = 'other';
    else if race = '.' then nsrr_race = 'not reported';

*ethnicity;
*no ethnicity variable in wsc;

*anthropometry
*bmi;
*use bmi;
  format nsrr_bmi 10.9;
  nsrr_bmi = bmi;

*clinical data/vital signs
*bp_systolic;
*use sbp_mean;
  format nsrr_bp_systolic 8.2;
  nsrr_bp_systolic = sbp_mean;

*bp_diastolic;
*use dbp_mean;
  format nsrr_bp_diastolic 8.2;
  nsrr_bp_diastolic = dbp_mean;
  
*lifestyle and behavioral health
*current_smoker;
*use smoke_curr;
  format nsrr_current_smoker $100.;
  if smoke_curr = 'N' then nsrr_current_smoker = 'no';
  else if smoke = 'N' then nsrr_current_smoker = 'no';
  else if smoke_curr = 'Y' then nsrr_current_smoker = 'yes';
  else if smoke_curr = . then nsrr_current_smoker = 'not reported';


*ever_smoker;
*use smoke; 
  format nsrr_ever_smoker $100.;
  if smoke = 'N' then nsrr_ever_smoker = 'no';
  else if smoke = 'Y' then nsrr_ever_smoker = 'yes';
  else if smoke = . then nsrr_ever_smoker = 'not reported';

*polysomnography;
*nsrr_ahi_hp4u_aasm15;
*use ahi;
  format nsrr_ahi_hp4u_aasm15 8.2;
  nsrr_ahi_hp4u_aasm15 = ahi;

*nsrr_ahi_hp3u;
  format nsrr_ahi_hp3u 8.2;
  nsrr_ahi_hp3u = ahi3;

*nsrr_ttldursp_f1;
*use tst;
  format nsrr_ttldursp_f1 8.2;
  nsrr_ttldursp_f1 = tst;

*nsrr_ttleffsp_f1;
*use se;
  format nsrr_ttleffsp_f1 8.2;
  nsrr_ttleffsp_f1 = se;  

*nsrr_ttllatsp_f1;
*use sleep_latency;
  format nsrr_ttllatsp_f1 8.2;
  nsrr_ttllatsp_f1 = sleep_latency; 

*nsrr_ttlprdsp_s1sr;
*use rem_latency;
  format nsrr_ttlprdsp_s1sr 8.2;
  nsrr_ttlprdsp_s1sr = rem_latency; 

*nsrr_ttldurws_f1;
*use waso;
  format nsrr_ttldurws_f1 8.2;
  nsrr_ttldurws_f1 = waso;
  
*nsrr_pctdursp_s1;
*use pcttststagen1;
  format nsrr_pctdursp_s1 8.2;
  nsrr_pctdursp_s1 = pcttststagen1;

*nsrr_pctdursp_s2;
*use pcttststagen2;
  format nsrr_pctdursp_s2 8.2;
  nsrr_pctdursp_s2 = pcttststagen2;

*nsrr_pctdursp_s3;
*use pcttststage34;
  format nsrr_pctdursp_s3 8.2;
  nsrr_pctdursp_s3 = pcttststage34;

*nsrr_pctdursp_sr;
*use pcttstrem;
  format nsrr_pctdursp_sr 8.2;
  nsrr_pctdursp_sr = pcttstrem;
  
  keep 
    wsc_id
    wsc_vst
    nsrr_age
    nsrr_age_gt89
    nsrr_sex
    nsrr_race
    nsrr_bmi
    nsrr_bp_diastolic
    nsrr_bp_systolic
    nsrr_current_smoker
    nsrr_ever_smoker
    nsrr_ahi_hp4u_aasm15
    nsrr_ahi_hp3u
    nsrr_ttldursp_f1
    nsrr_ttleffsp_f1
  nsrr_ttllatsp_f1
  nsrr_ttlprdsp_s1sr
  nsrr_ttldurws_f1
  nsrr_pctdursp_s1
  nsrr_pctdursp_s2
  nsrr_pctdursp_s3
  nsrr_pctdursp_sr
    ;
run;

*******************************************************************************;
* checking harmonized datasets ;
*******************************************************************************;

/* Checking for extreme values for continuous variables */
proc means data=wsc_harmonized;
VAR   nsrr_age
    nsrr_bmi
  nsrr_ahi_hp4u_aasm15
  nsrr_ahi_hp3u
  nsrr_ttldursp_f1
  nsrr_bp_diastolic
  nsrr_bp_systolic
  nsrr_ttleffsp_f1
  nsrr_ttllatsp_f1
  nsrr_ttlprdsp_s1sr
  nsrr_ttldurws_f1
  nsrr_pctdursp_s1
  nsrr_pctdursp_s2
  nsrr_pctdursp_s3
  nsrr_pctdursp_sr
  ;
run;

/* Checking categorical variables */
proc freq data=wsc_harmonized;
table   nsrr_age_gt89
    nsrr_sex
    nsrr_race
    nsrr_current_smoker
    nsrr_ever_smoker;
run;

*******************************************************************************;
* make all variable names lowercase ;
*******************************************************************************;
  options mprint;
  %macro lowcase(dsn);
       %let dsid=%sysfunc(open(&dsn));
       %let num=%sysfunc(attrn(&dsid,nvars));
       %put &num;
       data &dsn;
             set &dsn(rename=(
          %do i = 1 %to &num;
          %let var&i=%sysfunc(varname(&dsid,&i));    /*function of varname returns the name of a SAS data set variable*/
          &&var&i=%sysfunc(lowcase(&&var&i))         /*rename all variables*/
          %end;));
          %let close=%sysfunc(close(&dsid));
    run;
  %mend lowcase;

  %lowcase(wsc_nsrr);
  %lowcase(wsc_harmonized);

*******************************************************************************;
* export nsrr csv datasets ;
*******************************************************************************;
  proc export data=wsc_nsrr
    outfile="&releasepath\&version\wsc-dataset-&version..csv"
    dbms=csv
    replace;
  run;

    proc export data=wsc_harmonized
    outfile="&releasepath\&version\wsc-harmonized-dataset-&version..csv"
    dbms=csv
    replace;
  run;

      proc export data=wsc_mslt_merge
    outfile="&releasepath\&version\wsc-mslt-dataset-&version..csv"
    dbms=csv
    replace;
  run;
