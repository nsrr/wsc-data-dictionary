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
  %let version = 0.2.0.pre;

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
