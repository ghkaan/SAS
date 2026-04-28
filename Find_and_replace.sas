dm "output; clear; log; clear;";
************************************************************************
*        CLIENT NAME:   ******
*       PROGRAM NAME:   Find_and_replace.SAS
*             AUTHOR:   Anton Kamyshev
*       DATE CREATED:   31AUG2017
*            PURPOSE:   Find and replace specified text (case sensitive)
*                       in specified file (mask can be used),
*                       replace tabulate symbols with spaces optionally
*        INPUT FILES:   
*       OUTPUT FILES:   
*
*        USAGE NOTES:   Update options below as required to go through
*                       files to find and replace text
*              NOTES:   
*
*   MODIFICATION LOG:   
*************************************************************************
* DATE          BY              DESCRIPTION
*************************************************************************
* MM/DD/YYYY    USERID          Complete description of modification made
*                               including reference to source of change.
*
*************************************************************************
*    Pharmaceutical Product Development, Inc., 2017
*  All Rights Reserved.
*************************************************************************;

*** Options ***;
%let PATH = ; * Path where files should be processed, if blank, current path will be used *;
%let MASK = *10*.sas; * Mask to select files - in example, vT01*.sas or L14010?.sas *;
%let EXCL = "find_and_replace.sas"; * List of files to exclude in quotation marks separated by space *;

%let SRCH = G_NICKNAME._MAPPING_SPEC.XLS,; * Text to find *;
%let RPLC = G_NICKNAME._MAPPING_SPEC.XLSX,; * Replacement *;

%let SAVEBAK = Y; * If set to Y program will save original files as "filename.ext.bak" and then will update "finename.ext" *;
%let TAB2SPC = 2; * If not blank then all tabulation symbols will be replaced with specified number of spaces *;
***************;

options noquotelenmax noxwait xsync nospool nomprint nomlogic nosymbolgen;
proc datasets library=work memtype=data kill nolist nowarn; quit;
%macro setfullpath;
  proc sql noprint; select count(*) into :TMP from sashelp.VMACRO where SCOPE='GLOBAL' and NAME='G_FULLPATH'; quit;
  %if &TMP=0 %then %do;
    %global G_FULLPATH G_PROJECTPATH G_NICKNAME;
    proc sql noprint; select distinct XPATH into :G_FULLPATH from dictionary.EXTFILES where upcase(XPATH) like "%.SAS";
    %let G_FULLPATH=%substr( &G_FULLPATH,1,%length(&G_FULLPATH)-%index(%sysfunc(reverse(&G_FULLPATH)),%str(\))+1 );
    %put NOTE: G_FULLPATH variable was set to &G_FULLPATH;
    %let G_PROJECTPATH=%scan(&G_FULLPATH,1,%str(\))\%scan(&G_FULLPATH,2,%str(\))\%scan(&G_FULLPATH,3,%str(\))\;
    %if %substr(&G_FULLPATH,1,2)=%str(\\) %then %let G_PROJECTPATH=%str(\\)&G_PROJECTPATH;
    %put NOTE: G_PROJECTPATH variable was set to &G_PROJECTPATH;
  %end;
%mend;
%setfullpath;

*** Macro to get list of files ***;
%macro files(path,mask,ds=FILES);
  %if %length(&path)=0 %then %let PATH=&G_FULLPATH;
  %if %length(&mask)=0 %then %let MASK=*.*;
  %if %length(&excl)=0 %then %let EXCL="";
  %let EXCL=%upcase(&EXCL);
  %global fpath fdir fname;
  %let cmd=%nrbquote(dir "&path\&mask" /b /s /od); * Bare format, files with paths in current dir and subdirs, order by date  *;
  filename DIR pipe "%nrbquote(&cmd)";
  data &DS;
    infile DIR pad truncover;
    length path dir name ext $255;
    input path $ 1-255;
    if not index(path, ".svn-");
    if index(path, '\') then do;
      dir=substr(path,1,find(path,'\',-255)-1);
      name=substr(path,find(path,'\',-255)+1);
    end;
    else do;
      dir=".";
      name=path;
    end;
    if index(name, '.') then ext=substr(name, find(name,'.',-255)+1);
    else ext="";
    if compress(upcase(DIR),"\")=compress(upcase("&PATH"),"\"); * keep only files in specified directory, remove records for sub-directories *;
    if not (upcase(NAME) in (&EXCL)); * Remove files specified in list of exclusions *;
    call symput('fpath', path); * for one with latest date *;
    call symput('fdir',  dir);  * for one with latest date *;
    call symput('fname', name); * for one with latest date *;
  run;
%mend;

*** Macro to load and update file ***;
%macro SRCH_RPLC(PATH,NAME,SRCH,RPLC,NOUPD);
  %put %str(W)ARNING-%STR(A)LERT_I: [SRCH_RPLC] ************************************************************;
  %put %str(W)ARNING-%STR(A)LERT_I: [SRCH_RPLC] Process file &NAME.;
  %put %str(W)ARNING-%STR(A)LERT_I: [SRCH_RPLC]   SRCH=[&SRCH],;
  %put %str(W)ARNING-%STR(A)LERT_I: [SRCH_RPLC]   RPLC=[&RPLC].;
  %if %length(&SRCH)=0 %then %do;
    %put %str(W)ARNING-%STR(A)LERT_P: [SRCH_RPLC]: SRCH is empty, %str(a)borting.;
    %goto EXIT;
  %end;
  %let TAB2SPC=%sysfunc(compress(&TAB2SPC,,kd));
  %let CNTRPL=0;
  /*%let RND=%sysfunc(int(%sysfunc(ranuni(0)) * 1000));*/
 
  filename SRFILE "&PATH.";
  data SRCH_RPLC;
    infile SRFILE truncover end=last;
    length REC REC_ORIG $1000;
    input @1 REC 1-1000;
    LINE=_N_;
    REC=_INFILE_;
    REC_ORIG=REC;
    retain CNT 0;
    %if %length(&TAB2SPC) ne 0 %then %do;
      do while(index(REC,byte(9))); REC=tranwrd(REC,byte(9),repeat(" ",%eval(&TAB2SPC-1))); end; * Replace all tabulate symbols with two spaces *;
    %end;
    do while(index(REC,"&SRCH")); REC=tranwrd(REC,"&SRCH","[SRCH_RPLC]"); CNT+1; end;       * Replace specified text with replacement text *;
    do while(index(REC,"[SRCH_RPLC]")); REC=tranwrd(REC,"[SRCH_RPLC]","&RPLC"); end; * This was done in two steps to avoid infinite loop when &RPLC include &SRCH *;
    TEXTSTART=length(trim(REC))-length(strip(REC))+1; * Get number of leading spaces and assign starting position *;
    SYMBSTART=rank(substr(REC,1,1)); * Get code of first character to determine if it is space (32) ot tabulation symbol (9) *;
    if last then call symput("CNTRPL",put(CNT,??best.));
  run;
  %let CNTRPL=&CNTRPL;
  filename SRFILE clear;

  %put %str(W)ARNING-%STR(A)LERT_I: [SRCH_RPLC] File &NAME - &CNTRPL replacement(s) identified.; 
  %if &CNTRPL=0 %then %put %str(W)ARNING-%STR(A)LERT_I: [SRCH_RPLC] File will be kept as is.;

  %if %length(&NOUPD)=0 %then %do;
    %if &CNTRPL>0 %then %do;
      %let ORIGRC=;
      %if %upcase(&SAVEBAK)=Y %then %do;
        data _null_;
          rc=system(" copy ""&PATH"" ""&PATH..bak"" ");
          call symput("BAKRC",put(rc,??best.));
        run;
        %let BAKRC=&BAKRC;
        %if &BAKRC=0 %then
          %put %str(W)ARNING-%STR(A)LERT_I: [SRCH_RPLC] File &NAME was saved as &NAME..bak;
        %else %put %str(W)ARNING-%STR(A)LERT_I: [SRCH_RPLC] Problem occured during saving original &NAME (RC=&BRC), stopped.;
      %end; *SAVEBAK*;
      %if (%upcase(&SAVEBAK)=Y and &BAKRC=0) or (%upcase(&SAVEBAK) ne Y) %then %do;
        filename SRFILE "&PATH.";
        data _null_;
          set SRCH_RPLC;
          file SRFILE;
          if SYMBSTART=32 then put @TEXTSTART REC;
          else put @1 REC;
        run;
        filename SRFILE clear;
        %put %str(W)ARNING-%STR(A)LERT_I: [SRCH_RPLC] File &NAME was updated.;
      %end; *SAVEBAK,BAKRC*;
    %end; *CNTRPL*;
  %end; *NOUPD*;
%EXIT:
%mend;
*%SRCH_RPLC(u:\SAS code\Find and replace\M10AE.sas,M10AE.sas,%str(G_NICKNAME,,._MAPPING_SPE,C.XLS),%str(G_NICKNA,ME._MAPPING_SPEC.XLSx));

*** Get list of files in specified folder and call SRCH_RPLC macro for each file ***;
%macro data_checker;
  %files(&PATH,&MASK,ds=FILES); * list of FILES *;
  proc sort data=FILES; by PATH; run;
  proc sql noprint; select count(*) into :NOBS from FILES; quit;
  %if &NOBS ne 0 %then %do;
    data _NULL_;
      set FILES;
      call execute('%nrstr(%srch_rplc('||PATH||','||NAME||',%str(&SRCH),%str(&RPLC)))');
    run;
  %end;
  %else %put %str(W)ARNING-%STR(A)LERT_P: [SRCH_RPLC] There are no files to process.;
%mend;
%data_checker;
