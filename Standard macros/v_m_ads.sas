dm 'log;clear;';
%include "call setup.sas";
proc delete data = work._all_; run;

* Merge back supplementary and comments, go throuth the list of specified domains - separate macro call *;
%macro prepsdtm(domains);
  %do i=1 %to %sysfunc(countw(&domains));
    %let _DS=%upcase(%scan(&domains,&i));
    %let SUPPDS=SUPP%upcase(%scan(&domains,&i));
    %if %sysfunc(exist(sdtm.&_ds)) %then %do;
      %put NOTE: SDTM dataset sdtm.&_ds identified, copy to work library.;
      proc copy in=sdtm out=work;
        select &_ds.;
      run;
      %if %sysfunc(exist(sdtm.&suppds)) %then %do;
        %put NOTE: Supplementary SDTM dataset sdtm.&SUPPDS identified, merge with the main dataset.;
        proc transpose data=sdtm.&SUPPDS out=SUPPT(drop=_:);
          by USUBJID IDVARVAL;
          id QNAM;
          var QVAL;
        run;
        proc sql noprint;
          select cats("b.",NAME) into :SUPPV separated by ", " from sashelp.VCOLUMN where LIBNAME="WORK" and MEMNAME="SUPPT" and NAME not in ("USUBJID" "IDVARVAL");
        quit;
        proc sql;
          create table &_ds. as select a.*, &suppv.
            from sdtm.&_ds. as a left join SUPPT as b on a.USUBJID=b.USUBJID and input(b.IDVARVAL,best.)=
              %if &_ds=DM %then %do; . %end;
              %else %if &_ds=SV %then %do; VISITNUM %end;
              %else %do; a.&_ds.SEQ %end; ;
          drop table SUPPT;
        quit;
      %end;
      %if %sysfunc(exist(sdtm.CO)) %then %do;
        %let comcnt=0;
          proc sql noprint; select count(*) into :comcnt from sdtm.CO where COREF="&_ds."; quit;
          %if &comcnt. %then %do;
          %put NOTE: Comments related to dataset &_ds. were identified in SDTM dataset sdtm.CO, merge with the main dataset.;
          proc transpose data=sdtm.CO(where=(COREF="&_ds.")) out=COMMT;
            by USUBJID IDVARVAL;
            var COVAL CODTC;
          run;
          data COMMTMP; set &_ds.; run;
          proc sql;
            create table &_ds. as select a.*, b.COL1 as COVAL, c.COL1 as CODTC
              from COMMTMP as a
                left join COMMT(where=(_NAME_="COVAL")) as b on a.USUBJID=b.USUBJID and input(b.IDVARVAL,best.)=
                  %if &_ds=DM %then %do; . %end;
                  %else %if &_ds=SV %then %do; VISITNUM %end;
                  %else %do; a.&_ds.SEQ %end;
                left join COMMT(where=(_NAME_="CODTC")) as c on a.USUBJID=c.USUBJID and input(c.IDVARVAL,best.)=
                  %if &_ds=DM %then %do; . %end;
                  %else %if &_ds=SV %then %do; VISITNUM %end;
                  %else %do; a.&_ds.SEQ %end; ;
            drop table COMMT, COMMTMP;
          quit;
        %end;
      %end;
    %end;
    %else %do;
      %put %str(WAR)NING: Dataset sdtm.&_ds was not found, please re-check.;
    %end;
  %end;
%mend prepsdtm;

* Add common vars and some other vars if required - separate macro call *;
%macro comvars(dsin,dsout,addvars);
  %let dsin=%upcase(&dsin);
  %if %length(&dsout)=0 %then %let dsout=&dsin;
  %put NOTE: Adding common variables prespecified in the setup.sas to the dataset &ds..;
  %put NOTE: &=COMMON_VARS;
  %put NOTE: &=ADDVARS;
  %let CV = &COMMON_VARS &ADDVARS;
  %let CV_CHK = %sysfunc(tranwrd(%sysfunc(compbl(&CV)),%str( ), %str(" ") ));
  %let CV_CHK = %upcase("&CV_CHK");
  %let CV_SQL = b.%sysfunc(tranwrd(%sysfunc(compbl(&CV)),%str( ), %str(, b.) ));
  %let CV_FND=;
  proc sql noprint;
    select NAME into :CV_FND separated by " " from sashelp.VCOLUMN where upcase(LIBNAME)='WORK' and upcase(MEMNAME)="&dsin" and upcase(NAME) in (&CV_CHK.);
  quit;
  %if %length(&CV_FND)>0 %then %do;
    %put NOTE: Some common variables are already exist in input dataset, macro will remove them before adding from ADSL.;
    %put NOTE: &=CV_FND;
    data &dsin;
      set &dsin(drop=&CV_FND.);
    run;
  %end;
  proc sql;
    create table COMVARS_TMP as select a.*, &CV_SQL.
      from &dsin() as a left join ads.ADSL as b on a.USUBJID=b.USUBJID;
  quit;
  data &dsout;
    set COMVARS_TMP;
  run;
  proc sql; drop table COMVARS_TMP; quit;
%mend comvars;

* Transform selected tests to columns - separate macro call *;
%macro tst2col(inds,where=1,outds=&inds._T2C,by=USUBJID,tst=,var=);
%if %length(&tst)=0 %then %do; proc sql noprint; select NAME into :tst from sashelp.VCOLUMN where LIBNAME='WORK' and MEMNAME=upcase("&inds") and NAME like '%TESTCD'; quit; %end;
%if %length(&var)=0 %then %do; proc sql noprint; select NAME into :var from sashelp.VCOLUMN where LIBNAME='WORK' and MEMNAME=upcase("&inds") and NAME like '%STRESC'; quit; %end;
%if %length(&var)=0 %then %put %str(WAR)NING: Parameter VAR is blank, please specify.;
proc sort data=&inds.(where=(&where and not missing(&var.))) out=&inds._t2c_1;
  by &by. &tst. &var.;
run;
proc transpose data=&inds._t2c_1 out=&outds.(drop=_:);
  by &by.;
  id &tst.;
  var &var.;
run;
proc sql; drop table &inds._t2c_1; quit;
%mend tst2col;

* 4 macros to derive date, time, datetime variables - inside of the datastep *;
%macro dt(dtc,dt);
  if not missing(&dtc) then &dt=input(substr(&dtc||"          ",1,10),??YYMMDD10.);
  format &dt. date9.;
%mend dt;

%macro tm(dtc,tm);
  if index(&dtc,'T') then
    &tm=input(substr(&dtc||"        ",12,8),is8601tm.); ;
  format &tm. tod5.;
%mend tm;

%macro dtm(dtc,dtm);
  if not missing(&dtc) then &dtm=input(&dtc,??is8601dt.);
  format &dtm. datetime20.;
%mend dtm;

%macro dt3(dtc,pref);
  %dt(&dtc,&pref.DT);
  %tm(&dtc,&pref.TM);
  %dtm(&dtc,&pref.DTM);
%mend dt3;

* Derive APHASE\APHASEN variables - inside of the datastep *;
%macro aphase(dt);
do;
  length APHASE $200;
  if not missing(&dt.) then do;
    if      . < PH01SDT <= &dt. <= PH01EDT or &dt.=PH01SDT or &dt.=PH01EDT then do; APHASE = 'Titration Phase';  APHASEN = 1; end;
    else if . < PH02SDT <= &dt. <= PH02EDT or &dt.=PH02SDT or &dt.=PH02EDT then do; APHASE = 'Stable Dose Phase';APHASEN = 2; end;
    else if . < PH03SDT <= &dt. <= PH03EDT or &dt.=PH03SDT or &dt.=PH03EDT then do; APHASE = 'Tappering Phase';  APHASEN = 3; end;
    else if . < PH04SDT <= &dt. <= PH04EDT or &dt.=PH04SDT or &dt.=PH04EDT then do; APHASE = 'Follow-up Phase';  APHASEN = 4; end;
  end;
end;
%mend aphase;

* Create PARCAT1\2, PARAM, PARAMCD variables as required - separate macro call *;
%macro PARNAM(dsin, dsout);
  %if %length(&dsout)=0 %then %let dsout=&dsin._PARNAM;
  %local cat sct pcd pnm unt;
  proc sql noprint;
    select NAME into :cat from sashelp.VCOLUMN where LIBNAME="WORK" and upcase(MEMNAME)=upcase("&dsin") and upcase(substr(NAME,3))='CAT';
    select NAME into :sct from sashelp.VCOLUMN where LIBNAME="WORK" and upcase(MEMNAME)=upcase("&dsin") and upcase(substr(NAME,3))='SCAT';
    select NAME into :pcd from sashelp.VCOLUMN where LIBNAME="WORK" and upcase(MEMNAME)=upcase("&dsin") and upcase(substr(NAME,3))='TESTCD';
    select NAME into :pnm from sashelp.VCOLUMN where LIBNAME="WORK" and upcase(MEMNAME)=upcase("&dsin") and upcase(substr(NAME,3))='TEST';
    select NAME into :unt from sashelp.VCOLUMN where LIBNAME="WORK" and upcase(MEMNAME)=upcase("&dsin") and upcase(substr(NAME,3))='STRESU';
    %let cat=&cat;
    %let sct=&sct;
    %let pcd=&pcd;
    %let pnm=&pnm;
    %let unt=&unt;
    %put NOTE: &=cat &=sct &=pcd &=pnm &=unt;
    create table PARAM as select distinct
      %if %length(&cat)>0 %then &cat. as PARCAT1 length=40,;
      %if %length(&sct)>0 %then &sct. as PARCAT2 length=40,;
      &pcd. as PARAMCD length=8
      %if %length(&unt.)>0 %then ,strip(strip(&pnm.)||ifc(not missing(&unt.)," ("||strip(&unt.)||")","")) as PARAM length=40; %else ,strip(&pnm.) as PARAM length=40;
      %if %length(&unt.)>0 %then ,&unt. as PARAMU;
      from &dsin. %if %length(&unt.)>0 %then %do;
        group by %if %length(&cat)>0 %then &cat.,; %if %length(&sct)>0 %then &sct.,; PARAMCD having PARAMU=max(PARAMU)
      %end; ;
    create table &dsout. as select a.*, %if %length(&cat)>0 %then p.PARCAT1,; %if %length(&sct)>0 %then p.PARCAT2,; p.PARAMCD, p.PARAM
      from &dsin. as a left join PARAM as p on %if %length(&cat)>0 %then a.&cat.=p.PARCAT1 and %if %length(&sct)>0 %then a.&sct.=p.PARCAT2 and; a.&pcd.=p.PARAMCD;
  quit;
%mend PARNAM;

%macro BASECHG(dsin, dsout, dt=ADT);
  %if %length(&dsout)=0 %then %let dsout=&dsin._BASECHG;
  proc sql noprint; select NAME into :byvars separated by " " from sashelp.VCOLUMN
    where LIBNAME="WORK" and upcase(MEMNAME)=upcase("&dsin") and upcase(NAME) in ("USUBJID" "PARCAT1" "PARCAT2" "PARAMCD");
  quit;
  %put NOTE: &=byvars;
  %let BYVARS2=%sysfunc(tranwrd(%str(&byvars),%str( ),%str(,)));
  proc sql;
    create table &dsout. as select a.*, b.AVAL as BASE, case when cmiss(a.AVAL, b.AVAL)=0 then a.AVAL-b.AVAL else . end as CHG
      from &dsin. as a
      left join (select distinct &byvars2., ADT, AVAL from &dsin. where ABLFL="Y") as b
        on %do i=1 %to %sysfunc(countw(&byvars.)); a.%scan(&byvars.,&i.)=b.%scan(&byvars.,&i.) and %end; a.ADT>b.ADT;
  quit;
%mend basechg;
