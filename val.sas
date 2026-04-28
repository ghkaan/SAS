/* VAL - macro to store validation information in dataset. The macro creates or         */
/*   updates specified validation dataset with PROC COMPARE result, datetime stamp      */
/*   and description of mismatches. Should be run immediately after proc compare code   */
/* Parameters: ID - output ID (program name without validation prefix if omitted)       */
/*             VALDS - name for validation dataset (compare_<folder name> if omitted)   */
/*             LIB - library for validation dataset (current folder if omitted)         */
/*             RETRY - number of trys to update data if dataset is locked               */
/*             DELAY - pause in seconds before the next try                             */
/*             VALPREF - validation program prefix to derive ID if it was not specified */
/*             CSVOUT - if Y, create copy of validation dataset in CSV format           */
/* Anton Kamyshev, 2025                                                                 */

%macro val(
  id=,
  valds=,
  lib=,
  retry=60,
  delay=1,
  valpref=v_,
  csvout=N);

  %if ^%symexist(sysinfo) %then %let sysinfo=.;
  %let __comprc=&sysinfo;
  %let __rc=%sysfunc(filename(path,.));
  %let __path=%sysfunc(pathname(&path));
  %if %length(&id.)=0 %then %do;
    * batch \ interactive ways to get fullpath *;
    %if %sysfunc(getoption(sysin)) ne %str() %then %let __fullpath=%sysfunc(getoption(sysin));
    %else %let __fullpath=%sysget(SAS_EXECFILEPATH);
    %let __name=%lowcase(%scan(&__fullpath,-1,%str(/\)));
    %if %substr(&__name,1,%length(&valpref.))=&valpref. %then %let id=%scan(%substr(&__name,%eval(%length(&valpref.)+1)),1,%str(.));
    %else %do;
      %put %str(ALE)RT_C: Validation prefix %left(&valpref) was not found in program name %left(&__name).;
      %let id=%scan(&__name,1,%str(.));
    %end;
    %put %str(ALE)RT_I: ID parameter defaulted to: %left(&id);
  %end;
  %if %length(&valds)=0 %then %do;
    %let __folder=%scan(&__path,-1,%str(/\));
    %let valds=compare_%left(&__folder);
    %put %str(ALE)RT_I: VALDS parameter defaulted to: %left(&valds);
  %end;
  %if %length(&lib)=0 %then %do;
    libname HERE "&__path";
    %let lib=here;
    %put %str(ALE)RT_I: LIB parameter defaulted to HERE (current folder): %left(&__path);
  %end;

  * Create validation record *;
  proc format;
    value cmpres
      1  = "Data set labels differ"
      2  = "Data set types differ"
      3  = "Variable has different informat"
      4  = "Variable has different format"
      5  = "Variable has different length"
      6  = "Variable has different label"
      7  = "PROD data set has observation not in VAL"
      8  = "VAL data set has observation not in PROD"
      9  = "PROD data set has BY group not in VAL"
      10 = "VAL data set has BY group not in PROD"
      11 = "PROD data set has variable not in VAL"
      12 = "VAL data set has variable not in PROD"
      13 = "A value comparison was unequal"
      14 = "Conflicting variable types"
      15 = "BY variables do not match"
      16 = "Fatal error: comparison not done"
      ;
  run;

  data __VALREC(drop=i RES01-RES16);
    length ID $100 DATETIME RES 8. DESC $1024 RES01-RES16 $50;
    format DATETIME datetime19.;
    ID=strip("&id");
    DATETIME=datetime();
    RES=&__comprc.;
    DESC=" ";
    array R{*} RES01-RES16;
    do i=1 to hbound(R);
      if band(2**(i-1),RES) then R{i}=put(i,cmpres.);
    end;
    DESC = catx(", ", of RES01-RES16);
    if missing(DESC) then DESC='Ok';
    output;
  run;

  * Check dataset availability - useful for multithread runs *;
  %let __attempt = 1;
  %let __success = 0;

  %do %while(&__attempt <= &retry and &__success=0);
    %let __locked=0;

    %if ^%sysfunc(exist(&lib..&valds)) %then %do; * Validation dataset does not exist, create new one *;
      %put %str(ALE)RT_I: Create validation dataset %left(&lib..&valds);
      data &lib..&valds.;
        set __VALREC;
      run;
      %let __success = 1;
    %end;
    %else %do; * If exist, then check for lock and try to update *;
      * Check dataset *;
      %let dsid = %sysfunc(open(&lib..&valds, i));
      %if &dsid > 0 %then %let __locked=0;
      %else %let __locked=1;
      %let rc = %sysfunc(close(&dsid));
      * Check physical file *;
      filename testfile "%sysfunc(pathname(&lib))\&valds..sas7bdat";
      %let fid = %sysfunc(fopen(testfile));
      %if &fid = 0 %then %let __locked=1;
      %else %let __locked=0;
      %let rc = %sysfunc(fclose(&fid));
      * ... *;
      %if &__locked=1 %then %do; * Dataset is locked *;
        %put %str(ALE)RT_C: Can not open dataset &lib..&valds, maybe locked, waiting &delay seconds...;
        %put SYSRC=&sysrc, SYSMSG=%sysfunc(sysmsg());
        data _null_;
          rc = sleep(&delay.);
        run;
      %end;
      %else %do; * Not locked *;
        %put %str(ALE)RT_I: Update validation dataset %left(&lib..&valds);
        data &lib..&valds;
          update &lib..&valds __VALREC;
          by ID;
        run;
        %let __success = 1;
      %end;
    %end;

    %if &__locked %then %let __attempt=%eval(&__attempt+1);

  %end; * of the while loop *;

  %if &__success=0 %then %do;
    %put %str(ALE)RT_E: Failed to update validation dataset after &retry attempts;
    %put %str(ALE)RT_E: Last %str(er)ror: &%str(syserr)ortext;
  %end;
  %else %do;
    %put %str(ALE)RT_I: Validation status was updated successfully in &lib..&valds;
    %if %upcase(&csvout.)=:Y %then %do;
      %put %str(ALE)RT_I: Create copy of validation dataset in CSV format;
      proc export data=work.mydata outfile="%sysfunc(pathname(&lib))\&valds..csv" dbms=csv replace;
      run;
    %end;
  %end;

  * Remove temporary data *;
  %if %sysfunc(exist(__VALREC)) %then %do; proc sql noprint; drop table __VALREC; quit; %end;

%mend val;
