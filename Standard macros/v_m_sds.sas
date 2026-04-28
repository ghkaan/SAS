************************************************************ ;
*  Program name     : v_macros.sas
*  Project          : X:\BioMetrics\SAS programming\ALZPROTECT\CO4EXT\csr\val\pg\sds\
*  Written by       : Anton Kamyshev  
*  Date of creation : Fri 05/16/2025 (mm/dd/yyyy) 
*  Description      : Validation macros 
*  Input file       : 
*  Output file      : 
*  Revision History : 
*  Date      Author   Description of the change 
********************************************************************************** ; 
dm 'out;clear;odsresults;clear;log;clear;';
%include "call setup.sas"; 
options MISSING=" " REPLACE NOQUOTELENMAX NOMPRINT NOMLOGIC NOSPOOL NOSYMBOLGEN NOMRECALL COMPRESS=NO THREADS CPUCOUNT=ACTUAL DSACCEL=ANY VALIDVARNAME=V7;

******   Delete all datasets from work  ; 
proc delete data=work._all_; run; 

proc sql noprint; select distinct STUDYID into :G_STUDYID from sds.DM; quit;
%put NOTE: &=g_studyid;

proc format;
  value eln
    1 = "Screening"
    2 = "Baseline"
    3 = "Dose Titration"
    4 = "Stable Dose"
    5 = "Dose Tappering"
    6 = "Follow-up";
  invalue visn
    "Screening" = 0
    "Screening Check-In" = 1
    "Baseline" = 2
    "Dose Titration (Day 7)" = 3
    "Stable Dose (Day 1)" = 4
    "IMP D/C" = 5
    "Unscheduled 01" = 10.01
    "Unscheduled 02" = 10.02
    "Unscheduled 03" = 10.03
    "Unscheduled 04" = 10.04
    "Unscheduled 05" = 10.05
    "Unscheduled 06" = 10.06
    "Unscheduled 07" = 10.07
    "Unscheduled 08" = 10.08
    "Unscheduled 09" = 10.09
    "Unscheduled 10" = 10.10
    "Day 1"  = 20.01
    "Day 2"  = 20.02
    "Day 3"  = 20.03
    "Day 4"  = 20.04
    "Day 5"  = 20.05
    "Day 6"  = 20.06
    "Day 7"  = 20.07
    "Day 8"  = 20.08
    "Day 9"  = 20.09
    "Day 10" = 20.10
    "Day 11" = 20.11
    "Day 12" = 20.12
    "Day 13" = 20.13
    "Day 14" = 20.14
    "Day 15" = 20.15
    "Day 16" = 20.16
    "Day 17" = 20.17
    "Safety Follow Up" = 30
    "Study Exit" = 99
    other = .;
run;

* Create VISIT\VISITNUM in SV *;
%macro svvis(INDS, OUTDS, byvars=USUBJID INTERVAL_NAME RECORD_ID, addnum=N);
  %put %str(ALE)RT_I: SVVIS macro started.;
  %let INTEXIST=0;
  %let VISEXIST=0;
  proc sql ;
    select count(NAME) into :INTEXIST from sashelp.VCOLUMN where LIBNAME='WORK' and upcase(MEMNAME)=upcase("&INDS") and upcase(NAME)='INTERVAL_NAME';
    select count(NAME) into :VISEXIST from sashelp.VCOLUMN where LIBNAME='WORK' and upcase(MEMNAME)=upcase("&INDS") and upcase(NAME)='VISIT';
  quit;
  %let VISVAR=INTERVAL_NAME;
  %if &intexist=0 and &visexist %then %do;
    %put %str(ALE)RT_I: VISIT variable found, will be used instead of INTERVAL_NAME.;
    %let BYVARS = %sysfunc(tranwrd(&byvars,INTERVAL_NAME,VISIT));
    %let VISVAR=VISIT;
  %end;
  %else %if &intexist=0 and &visexist=0 %then %do;
    %put %str(ALE)RT_P: No INTERVAL_NAME nor VISIT were identified, SVVIS macro stopped.;
    %abort;
  %end;
  proc sort data=&inds. out=&outds.; by &byvars.; run;
  data &outds.(drop=__UVNUM);
    set &outds.;
    retain __UVNUM 0;
    %if &visexist=0 %then %do; length VISIT $200; %end;
    by &byvars.;
    if first.USUBJID then __UVNUM=0;
    if missing(&VISVAR) then do;
      if first.%scan(&byvars.,-1) then __UVNUM+1;
      VISIT="Unscheduled "||put(__UVNUM,z2.);
    end;
    else do;
      __UVNUM=0;
      VISIT=&VISVAR;
    end;
    %if %upcase(&addnum)=Y %then %do;
      VISITNUM=input(VISIT,visn.);
    %end;
  run;
  %put %str(ALE)RT_I: SVVIS macro completed.;
%mend svvis;

* Merge VISIT\VISITNUM from SV *;
%macro vis(INDS, OUTDS, byvars=USUBJID INTERVAL_NAME PARENT_RECORD_ID);
  %put %str(ALE)RT_I: VIS macro started.;
  %let INTEXIST=0;
  %let VISEXIST=0;
  proc sql noprint;
    select count(NAME) into :INTEXIST from sashelp.VCOLUMN where LIBNAME='WORK' and upcase(MEMNAME)=upcase("&INDS") and upcase(NAME)='INTERVAL_NAME';
    select count(NAME) into :VISEXIST from sashelp.VCOLUMN where LIBNAME='WORK' and upcase(MEMNAME)=upcase("&INDS") and upcase(NAME)='VISIT';
    %let INTEXIST=&INTEXIST;
    %let VISEXIST=&VISEXIST;
    %put NOTE: &=INTEXIST, &=VISEXIST;
  quit;
  %let VISVAR=INTERVAL_NAME;
  %if &intexist=0 and &visexist %then %do;
    %put %str(ALE)RT_I: VISIT variable found, will be used instead of INTERVAL_NAME.;
    %let BYVARS = %sysfunc(tranwrd(&byvars,INTERVAL_NAME,VISIT));
    %let VISVAR=VISIT;
  %end;
  %else %if &intexist=0 and &visexist=0 %then %do;
    %put %str(ALE)RT_P: No INTERVAL_NAME nor VISIT were identified, VIS macro stopped.;
    %abort;
  %end;
  %put NOTE: &=BYVARS, &=VISVAR;
  proc sql;
    create table &outds. as select a.*, s.VISIT as _SV, s.VISITNUM as _SVN, u.VISIT as _UV, u.VISITNUM as _UVN
      from &inds. as a
      left join sds.SV(where=(int(VISITNUM) ne 10)) as s on a.USUBJID=s.USUBJID and a.&VISVAR=s.VISIT
      left join sds.SV(where=(int(VISITNUM) eq 10)) as u on a.USUBJID=u.USUBJID and (missing(a.&VISVAR) or index(upcase(a.&VISVAR),'UNSCH')) and a.PARENT_RECORD_ID=input(u.UVRECID,best.);
  quit;
  %put NOTE: &=SQLOBS;
  data &outds.;
    length VISIT $200;
    set &outds.;
    VISIT = coalescec(_SV, _UV);
    %if &intexist. %then %do; VISIT = coalescec(VISIT, INTERVAL_NAME); %end;
    VISITNUM = coalesce(_SVN, _UVN);
    if VISIT=: "Day " and missing(VISITNUM) then VISITNUM=20+input(compress(VISIT,,'kd'),best.)/100;
    drop _SV: _UV:;
  run;
  %put %str(ALE)RT_I: VIS macro completed.;
%mend vis;

* Derive xxBLFL variable *;
%macro blfl(inds,outds,dtc,domain,byvars);
%put %str(ALE)RT_I: BLFL macro started.;
%local blvis blrec blres blcat bltst;
%if %length(&domain)=0 %then %do;
  proc sql noprint;
    select distinct DOMAIN into :domain from &inds.;
    %let domain=&domain;
  quit;
%end;
%if %length(&byvars)=0 %then %do;
  proc sql noprint;
    select distinct NAME into :blvis separated by " " from sashelp.VCOLUMN where libname="WORK" and MEMNAME=upcase("&inds") and NAME="VISITNUM";
    select distinct NAME into :blrec separated by " " from sashelp.VCOLUMN where libname="WORK" and MEMNAME=upcase("&inds") and NAME="RECORD_ID";
    select distinct NAME into :blres separated by " " from sashelp.VCOLUMN where libname="WORK" and MEMNAME=upcase("&inds") and substr(NAME,length(NAME)-4)="ORRES";
    select distinct NAME into :blcat separated by " " from sashelp.VCOLUMN where libname="WORK" and MEMNAME=upcase("&inds") and substr(NAME,length(NAME)-2)="CAT";
    select distinct NAME into :bltst separated by " " from sashelp.VCOLUMN where libname="WORK" and MEMNAME=upcase("&inds") and substr(NAME,length(NAME)-5)="TESTCD";
  quit;
  %let byvars = %sysfunc(compbl(USUBJID &blcat &bltst));
%end;
%put &=blvis &=blrec &=blres &=blcat &=bltst;
proc sql;
  create table &inds._bl as select a.*, b.RFXSTDTC as __RFDTC
    from &inds.(where=(cmiss(&dtc.,&blres.)=0)) as a
    left join sds.DM(where=(not missing(RFXSTDTC))) as b on a.USUBJID=b.USUBJID
    order by %sysfunc(tranwrd(&byvars,%str( ),%str(,))), &dtc.;
quit;
data &inds._bl;
  set &inds._bl;
  __DSDTC=&dtc;
  %dtc2num(dtc=__RFDTC);
  %dtc2num(dtc=__DSDTC);
  * Drop records where numeric dates were not derived *;
  if cmiss(__DSDTC_DT, __RFDTC_DT) then delete;
  * Drop post-bl records *;
  if __DSDTC_DT > __RFDTC_DT > . then delete;
  if __DSDTC_DT and __RFDTC_DT and __DSDTC_DT=__RFDTC_DT then
    if __DSDTC_TM > __RFDTC_TM > . then delete;
run;
%put NOTE: &=byvars, &=dtc;
proc sort data=&inds._bl; by &byvars. __DSDTC_DT __DSDTC_TM &blvis. &blrec.; run;
data &inds._bl(keep=&byvars. &dtc. &blvis. &blrec. &domain.BLFL __RFDTC);
  set &inds._bl;
  by &byvars.;
  * Keep only 1 record before or on ref date for each byvars-block *;
  if not last.%scan(&byvars,-1) then delete;
  length &domain.BLFL $1;
  &domain.BLFL="Y";
run;
proc sort data=&inds.; by &byvars. &dtc. &blvis. &blrec.; run;
proc sort data=&inds._bl; by &byvars. &dtc. &blvis. &blrec.; run;
data &outds.;
  merge &inds. &inds._bl(drop=__RFDTC);
  by &byvars. &dtc. &blvis. &blrec.;
run;
%put %str(ALE)RT_I: BLFL macro completed.;
%mend blfl;

%macro IDs; * Derive SITEID, SUBJID and USUBJID *;
  SITEID  = strip(scan(PATIENT_DISPLAY_ID_FULL,1,"-"));
  SUBJID  = PATIENT_DISPLAY_ID_FULL;
  USUBJID = catx("-", STUDYID, SUBJID);
%mend IDs;

*** Macros for dates ***;

* Create numeric date and time from charcter dtc *;
%macro dtc2num(dtc,dt=&dtc._dt,tm=&dtc._tm);
  %if %length(&dtc.)>0 %then %do;
    %if %length(&dt.)>0 %then %do; if length(&dtc.)>=10 then &dt.=input(substr(&dtc.,1,10),??yymmdd10.); format &dt. date9.;%end;
    %if %length(&dt.)>0 %then %do; if index(&dtc.,"T")  then &tm.=input(substr(&dtc.,index(&dtc.,'T')+1),time8.); format &tm. time8.; %end;
  %end;
%mend dtc2num;

* Create ISO8601 DTC variable from character DT and numeric TM variables *;
%macro dttm(dtc,dt,tm);
  %if %length(&tm.)>0 %then %do;
    if not missing(&dt.) then &DTC = catx("T", &dt., ifc(length(strip(put(&tm.,time8.)))=7,cats("0",put(&tm.,time8.)),put(&tm.,time8.)));
  %end;
  %else %do;
    if not missing(&dt.) then &DTC = &dt.;
  %end;
  &DTC. = tranwrd(tranwrd(&DTC.,'UNK','--'),'UK','--');
%mend;

* Increase or decrease selected character date *;
%macro chgdtc(cond,dtc,dif); 
  if &cond. then do;
    __TMPDT=.;
    format __TMPDT date9.;
    if not missing(&dtc.) then do;
      __TMPDT=input(&dtc.,yymmdd10.)+(&dif.);
      if __TMPDT then &dtc.=put(__TMPDT,yymmdd10.);
    end;
    drop __TMPDT;
  end;
%mend chgdtc;
