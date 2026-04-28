
*** Useful macrovariables: ***;
&_CLIENTAPP;        *Name of the client application.;
&_CLIENTMACHINE;    *Client machine node name.;
&_CLIENTPROJECTNAME;*The filename for the project.;
&_CLIENTPROJECTPATH;*The full path and filename for the project.;
&_CLIENTTASKFILTER; *The filter that is defined for the task. You can use this macro variable in the titles and footnotes of the task, so that the filter information is displayed in the title or footnote of your results.;
&_CLIENTTASKLABEL;  *Label for the current task. This is the text label that is displayed in the project tree and the process flow.;
&_CLIENTUSERID;     *User ID of the client user.;
&_CLIENTUSERNAME;   *Full user name, if that information is available.;
&_CLIENTVERSION;    *Application version, including build number.;
&_SASHOSTNAME;      *Server node name (IP address or DNS name).;
&_SASPROGRAMFILE;   *The full path and filename of the SAS program that is currently being run. This macro variable is available only for SAS program files that are saved on the same server on which your SAS Enterprise Guide code is being run.;
&_SASSERVERNAME;    *Name of the logical server.;

*** Page X of Y in RTF ***;
   /* SAS 8.2 */ /* CAUTION: Make sure the raw RTF code is on ONE line */
   ods listing close;
   options nonumber;
   ods rtf file="temp.rtf";
   proc print data=sashelp.retail;
    footnote j=r
     "{\field{\*\fldinst{\b\i PAGE}}}\~{\b\i of}\~{\field{\*\fldinst{\b\i NUMPAGES}}}";
   run;
   ods rtf close;

   /* SAS 9.0 and later */
   ods listing close;
   options nonumber;
   ods escapechar="^";
   ods rtf file="temp.rtf";
   proc print data=sashelp.retail;
    footnote j=r "^{pageof}";
   run;
   ods rtf close;

**Merge supplemental data onto parent domain**;
%macro rev(ds);
  %let SUPPEXIST=0;
  %let lib=TRANS;
  proc sql noprint; select count(*) into :SUPPEXIST from sashelp.VTABLE where libname=upcase("&lib") and MEMNAME=upcase(compress("SUPP&ds")); quit;
  %if &SUPPEXIST>0 %then %do;
    %put %str(ALE)RT_I: &lib..SUPP&ds was found, merging back to the main dataset.;
    %revsupp(
      libin=&lib,
      libout=work,
      ds=&DS.,
      supp=&lib.SUPP&ds.
      );
  %end;
  %else %do;
    %put %str(ALE)RT_I: &lib..SUPP&ds was not found, copying only main dataset.;
    proc copy in=&lib. out=work memtype=data;
      select &DS.;
    run;
  %end;
%mend;

*** clear log, output, odsresult windows ***;
%macro CLN; %if %sysfunc(getoption(dms))=DMS %then %do; dm "output; clear; odsresults; clear; log; clear"; %end; %mend;
%cln;

/* Clean work library */
proc datasets library=work memtype=data kill nolist nowarn;
quit;

/* Create history files and rewrite them in the loop */
proc datasets library=PREV nolist nowarn;
  age ASDV_CASCADE_QC ASDV_CASCADE_QC1-ASDV_CASCADE_QC4;
run;

** Convert country names to 3-character format *;
COUNTRY_3C=put(upcase(COUNTRY_FULL),$isosu3a.);

** Get attributes **;
%let dsid  = %sysfunc(open(ravedata.dm));  
%let modte = %sysfunc(attrn(&dsid, modte), datetime20.);
%let exdt  = %sysfunc(attrn(&dsid, modte));
%let rc    = %sysfunc(close(&dsid)); 

  * Macro get sort order and label of the specified dataset in order to restore them after processing *;
  %macro DSATTR(lib=POSTPRO, ds=, svar=SRT, lvar=LBL);
    %global &SVAR &LVAR;
    data _null_;
      dsid=open("&lib..&ds","i");
      call symput("&SVAR",compbl(attrc(dsid,"SORTEDBY")));
      call symput("&LVAR",compbl(attrc(dsid,"LABEL")));
      rc=close(dsid);
    run;
    %let &SVAR = &&&SVAR;
    %let &LVAR = &&&LVAR;
    %put %str(W)ARNING- DSATTR: Sort order of [&LIB..&DS]: &SVAR = &&&SVAR;
    %put %str(W)ARNING- DSATTR: Label of [&LIB..&DS]: &LVAR = &&&LVAR;
  %mend DSATTR;

** Additional formats **;
proc sql noprint; select strip(compress(SETTING,'()')) into: SEARCHFMT from sashelp.VOPTION where OPTNAME='FMTSEARCH'; quit;
options fmtsearch=(&SEARCHFMT. sashelp.MAPFMTS);

*** TITLES ***;

** Dynamic titles **;
title%eval(&title_count+1) j=l "Dose &dose";

** Additional title from BYVAL variable: **;
%if &parcat ne %then %do;
  title%eval(&title_count + 2) j=l "&parcattxt: #byval1";
%end;
proc report data=DS5 nowindows headline headskip split='|' missing ;
  by &parcat PAGE;
* ... *;


** Sequential numbering of records **;
* datastep   \ SQL                  *;
* SEQN = _n_ \ monotonic() as SEQN  *;

** RTF codes in proc report: **;
columns page patientid ("^S={just=l pretext= 'Age/'}" asr) ("^S={just=c pretext= 'Date of'}" icdtl) protver AVISIT ("&text. criteria [*] ^R/RTF'\brdrb\brdrs'" _1-_10)

%put %str(W)ARNING- [this text will be printed in green color];


/* Merge data from a1 with alone record from a2 */;
data A3;
  if _n_=1 then set A2;
  set A1;
run;

%* Create multilabel format and numeric version from MHTERM *;
proc sql;
  create table FMTTRM as select distinct 'TRM' as FMTNAME, MHTERM as LABEL label='', 'M' as HLO from ADMH order by MHTERM;
quit;

data FMTTRM; set FMTTRM; START=_N_; run;

data FMTTRM; set FMTTRM(in=a) FMTTRM(in=b); if b then LABEL='Any Condition'; run;

proc format library=work cntlin=FMTTRM;
run;


&SQLOBS - created after any sql query, contain number of records in the created(processed) dataset.

Check and remove macrovariable;
%let rc = %symexist(VAR1);
%if &RC=1 %then %let rc = %symdel(VAR1);

  proc format;
    value pcnt
    low - <1 = "<1"
    1 - 99 = [2]
    >99 - <100 = ">99"
    100 = "100"
    ;
  run;


* Go through records in dataset and use them as parameters for macros *;
data _null_;
  set sashelp.vtable (where=(libname eq "WORK") );
  call execute('%nrstr(%comp('||strip(memname)||'))');
run;


proc import datafile="&IND" out=&OUT dbms=EXCEL replace; 
  getnames=no;
  textsize=32767;
  mixed=yes;
  range="A4:Z9999";
  /*dbdsopts="DBSASTYPE=('Subject Number'='CHAR(8)')"; * This option can change type and length of imported variable *; */
run;


* OVERLINE - lines above\below the table and above footnotes *;
Line below the table can be removed by updating TLF styles:
---
proc template;
…some definitions here…
style table from table / frame=above * <-should be ABOVE to output only one line, HSIDES to output both above and below *;
…another definitions…
run;
---

Line above footnote can be removed by adding option in .tf file:
---
…some properties here…
*** End of Document Properties *** * <-SHOULD BE ADDED AFTER THAT LINE *
GET_TF»FOOTNOTE_OVERLINE»No
…titles and footnotes here…
---
