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
  libname wsci "\\rfawin\BWH-SLEEPEPI-NSRR-STAGING\20200115-peppard-wsc\nsrr-prep\_ids";

  *set data dictionary version;
  %let version = 0.3.0.pre;

  *set nsrr csv release path;
  %let releasepath = \\rfawin\BWH-SLEEPEPI-NSRR-STAGING\20200115-peppard-wsc\nsrr-prep\_releases;

*******************************************************************************;
* create datasets ;
*******************************************************************************;
  data wsc_in;
    set wscs.nsrr_wsc;
  run;

  data wsc;
    length wsc_id wsc_vst 8.;
    set wsc_in;
  run;

  proc sort data=wsc nodupkey;
    by wsc_id wsc_vst;
  run;

  data wsc_incident_in;
    set wscs.nsrr_inc_cvd_stroke;
  run;

  data wsc_incident_in;
    set wsc_incident_in;

    death_dt_year = year(death_dt);
    inc_censor_dt_year = year(inc_censor_dt);

    drop
      death_dt
      inc_censor_dt
      ;
  run;

  data wsc_incident;
    merge
      wsc_incident_in (in=a)
      wsc (keep=wsc_id wsc_vst sex race where=(wsc_vst = 1));
    by wsc_id;

    *only keep those in incident dataset;
    if a;

    *change visit indicator to '99';
    wsc_vst = 99;

    rename
      death_dt_year = death_dt
      inc_censor_dt_year = inc_censor_dt
      ;
  run;

  proc sort data=wsc_incident nodupkey;
    by wsc_id;
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

  %lowcase(wsc);
  %lowcase(wsc_incident);

  /*

  proc contents data=wsc_nsrr_censored out=wsc_nsrr_contents;
  run;

  proc contents data=wsc_incident;
  run;

  */

*******************************************************************************;
* create separate datasets for each visit ;
*******************************************************************************;
  data wsc_nsrr;
    set wsc;

    *do this later;
  run;

  data wsc_incident_nsrr;
    set wsc_incident;
  run;

*******************************************************************************;
* create permanent sas datasets ;
*******************************************************************************;
  data wscd.wsc_nsrr wsca.wsc_nsrr_&sasfiledate;
    set wsc_nsrr;
  run;

  data wscd.wsc_incident_nsrr wsca.wsc_incident_nsrr_&sasfiledate;
    set wsc_incident_nsrr;
  run;

*******************************************************************************;
* create harmonized datasets ;
*******************************************************************************;

data wsc_harmonized;
  set wsc_nsrr;
  *create wsc_visit variable for Spout to use for graph generation;
    wsc_vst = 1;

*demographics
*age;
*use age;
  format nsrr_age 8.2;
  nsrr_age = age;

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
  *format nsrr_ethnicity $100.;
    *if ethnicity = '01' then nsrr_ethnicity = 'hispanic or latino';
    *else if ethnicity = '02' then nsrr_ethnicity = 'not hispanic or latino';
    *else if ethnicity = '.' then nsrr_ethnicity = 'not reported';

*anthropometry
*bmi;
*use bmi;
  format nsrr_bmi 10.9;
  nsrr_bmi = bmi;

*clinical data/vital signs
*bp_systolic;
*use sitsysm;
  format nsrr_bp_systolic 8.2;
  nsrr_bp_systolic = sitsysm;

*bp_diastolic;
*use sitdiam;
  format nsrr_bp_diastolic 8.2;
  nsrr_bp_diastolic = sitdiam;

*lifestyle and behavioral health
*current_smoker;
*use smoke_curr;
  format nsrr_current_smoker $100.;
  if smoke_curr = 'N' then nsrr_current_smoker = 'no';
  else if smoke_curr = 'Y' then nsrr_current_smoker = 'yes';
  else if smoke_curr = . then nsrr_current_smoker = 'not reported';


*ever_smoker;
*use smoke; 
  format nsrr_ever_smoker $100.;
  if smoke = 'N' then nsrr_ever_smoker = 'no';
  else if smoke = 'Y' then nsrr_ever_smoker = 'yes';
  else if smoke = . then nsrr_ever_smoker = 'not reported';

  keep 
    wsc_id
    wsc_vst
    nsrr_age
    nsrr_age_gt89
    nsrr_sex
    nsrr_race
    nsrr_bmi
    nsrr_bp_systolic
    nsrr_bp_diastolic
    nsrr_current_smoker
    nsrr_ever_smoker
    ;
run;

*******************************************************************************;
* checking harmonized datasets ;
*******************************************************************************;

/* Checking for extreme values for continuous variables */

proc means data=wsc_harmonized;
VAR   nsrr_age
    nsrr_bmi
    nsrr_bp_systolic
    nsrr_bp_diastolic;
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
  %lowcase(wsc_incident_nsrr);
  %lowercase(wsc_harmonized);

*******************************************************************************;
* export nsrr csv datasets ;
*******************************************************************************;
  proc export data=wsc_nsrr
    outfile="&releasepath\&version\wsc-dataset-&version..csv"
    dbms=csv
    replace;
  run;

  proc export data=wsc_incident_nsrr
    outfile="&releasepath\&version\wsc-incident-dataset-&version..csv"
    dbms=csv
    replace;
  run;

    proc export data=wsc_harmonized
    outfile="&releasepath\&version\wsc-harmonized-dataset-&version..csv"
    dbms=csv
    replace;
  run;
