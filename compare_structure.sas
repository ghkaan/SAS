** Macro to compare structure and data in datasets from 2 libraries **;
** Dependencies: %val macro to store proc compare results, can be disabled with compdata=N **;
** (c) Anton Kamyshev, 20260424 **;

%macro compare_structure(
    lib_old=,
    lib_new=,
    outds=,
    outxls=,
    compdata=Y,
    memname_old=MEMNAME,
    memname_new=MEMNAME);
*** LIB_OLD, LIB_NEW - library names with old and new versions of datasets to be compared 
    OUTDS, OUTXLS - dataset and excel report names
    COMPDATA - if Y then also compare the data
    MEMNAME_OLD, MEMNAME_NEW - if dataset names are slightly different, specify the code to transform MEMNAME to unique values which can be used to match datasets
      for example, if old dataset name contaisn underscore and new does not, then specify MEMNAME_OLD=compress(MEMNAME,"_") ***;

    %let outname = compare_structure_%sysfunc(today(), yymmddn8.);
    %if %length(&outds.)=0  %then %let outds  = &outname;
    %if %length(&outxls.)=0 %then %let outxls = &outname..xlsx;

    %local lib_old_u lib_new_u;
    %let lib_old_u = %upcase(&lib_old);
    %let lib_new_u = %upcase(&lib_new);

    %put NOTE: Comparing libraries &lib_old_u vs &lib_new_u ...;

    /* Get metadata */
    proc sql;
      create table _OLD as select &memname_old. as MEMNAME, MEMNAME as OLD_MEMNAME, NAME as VARNAME, NAME as OLD_VARNAME, TYPE as OLD_TYP, LENGTH as OLD_LEN, LABEL as OLD_LBL, FORMAT as OLD_FMT
        from dictionary.columns where libname="&lib_old_u" order by MEMNAME, VARNAME;
      create table _NEW as select &memname_new. as MEMNAME, MEMNAME as NEW_MEMNAME, NAME as VARNAME, NAME as NEW_VARNAME, TYPE as NEW_TYP, LENGTH as NEW_LEN, LABEL as NEW_LBL, FORMAT as NEW_FMT
        from dictionary.columns where libname="&lib_new_u" order by MEMNAME, VARNAME;
    quit;

    data _OLD_NEW;
      merge _OLD _NEW;
      by MEMNAME VARNAME;
    run;

    /* Compare structure */
    proc sql;
      create table _BASE1 as select distinct
          ifc(not missing(a.MEMNAME),"Y","") as OLD length=1,
          ifc(not missing(b.MEMNAME),"Y","") as NEW length=1,
          coalescec(a.memname,b.memname) as MEMNAME length=32,
          a.OLD_MEMNAME,
          b.NEW_MEMNAME
        from _OLD as a
        full join _NEW as b on a.MEMNAME=b.MEMNAME;

      create table _BASE2 as select distinct
        z.*, 
        a.OLD_VARNAME,
        a.OLD_TYP,
        a.OLD_LEN,
        a.OLD_LBL,
        a.OLD_FMT,
        a.NEW_VARNAME,
        a.NEW_TYP,
        a.NEW_LEN,
        a.NEW_LBL,
        a.NEW_FMT
        from _BASE1 as z
        full join _OLD_NEW as a on a.MEMNAME=z.MEMNAME;

      create table &outds. as select distinct
          OLD, NEW, MEMNAME,
          coalescec(OLD_VARNAME, NEW_VARNAME) as VARNAME length=32,
          case
            when missing(OLD) then "Dataset missing in OLD"
            when missing(NEW) then "Dataset missing in NEW"
            when missing(OLD_VARNAME) then "Variable missing in OLD"
            when missing(NEW_VARNAME) then "Variable missing in NEW"
            when OLD_TYP ne NEW_TYP then "Type mismatch"
            when OLD_LEN ne NEW_LEN then "Length mismatch"
            when OLD_LBL ne NEW_LBL then "Label mismatch"
            when OLD_FMT ne NEW_FMT then "Format mismatch"
            else "OK"
          end as STATUS length=50,
          OLD_VARNAME,
          NEW_VARNAME,
          OLD_TYP,
          NEW_TYP,
          OLD_LEN,
          NEW_LEN,
          OLD_LBL,
          NEW_LBL,
          OLD_FMT,
          NEW_FMT
        from _BASE2
        order by MEMNAME, VARNAME;
    quit;

    /* Status summary */
    title "Summary of structure comparison: &lib_old_u vs &lib_new_u";
    proc freq data=&outds.;
      tables status / nocum;
    run;

    /* Summary for datasets */
    proc sql;
      create table _summary as
        select memname,
          sum(status='OK')                     as same_vars,
          sum(status like '%type%')            as mismatched_type,
          sum(status not like '%type%' and status like '%mismatch%') as mismatched_attr,
          sum(status like 'Variable missing%') as missing_vars,
          sum(status like 'Dataset missing%')  as missing_dataset
        from &outds.
        group by memname
        order by memname;
    quit;

    %if %upcase(&compdata)=Y %then %do;
      %let DSOLD=;
      %let DSNEW=;
      %let DSCNT=0;
      proc sql noprint;
        select cats("old.",OLD_MEMNAME), cats("new.",NEW_MEMNAME), count(*) into :DSOLD separated by "|", :DSNEW separated by "|", :DSCNT from _BASE1 where OLD="Y" and NEW="Y";
      quit;
      %if &DSCNT>0 %then %do i=1 %to &DSCNT.;
        %let DSO=%scan(&DSOLD,&i,%str(|));
        %let DSN=%scan(&DSNEW,&i,%str(|));
        proc compare base=&dso. comp=&dsn.;
        run;
        %val(id=%scan(&dso.,2),valds=&outds.);
      %end;
    %end;

    /* Export to Excel */
    ods excel file="&outxls" style=pearl;

    /* First tab: detailed status */
    ods excel options(sheet_name="Comparison" sheet_interval='none' flow='Tables' frozen_headers='YES' autofilter='ALL');
    title "Detailed comparison of libraries &lib_old_u vs &lib_new_u";

    proc report data=&outds. style(header)={background=gray22 color=lime font_weight=bold};
      columns memname varname status old_typ new_typ old_len new_len old_lbl new_lbl old_fmt new_fmt;
      define memname / display "Dataset";
      define varname / display "Variable";
      define status  / display "Comparison Result";
      define old_typ / display "Old Type";
      define new_typ / display "New Type";
      define old_len / display "Old Length";
      define new_len / display "New Length";
      define old_lbl / display "Old Label";
      define new_lbl / display "New Label";
      define old_fmt / display "Old Format";
      define new_fmt / display "New Format";

      /* Highlight differences */
      compute status;
        if status in ("Dataset missing in OLD", "Dataset missing in NEW", "Variable missing in OLD", "Variable missing in NEW") then
          call define(_row_, "style", "style={background=orange}");
        else if status="Type mismatch" then
          call define(_row_, "style", "style={background=lightred}");
        else if status ne "OK" then
          call define(_row_, "style", "style={background=peachpuff}");
      endcomp;
    run;

    /* Secod tab: Summary by dataset */
    ods excel options(sheet_name="Summary" sheet_interval='table' flow='Tables' frozen_headers='YES' autofilter='ALL');
    title "Summary by dataset: number of variables by comparison result";

    proc report data=_summary style(header)={background=gray22 color=lime font_weight=bold};
      columns memname same_vars mismatched_type mismatched_attr missing_vars missing_dataset;
      define memname          / display "Dataset";
      define same_vars        / display "Same Variables";
      define mismatched_type  / display "Mismatched Type";
      define mismatched_attr  / display "Mismatched Attr";
      define missing_vars     / display "Missing Vars";
      define missing_dataset  / display "Missing Dataset Flag";
      /* Highlight missings */
      compute missing_dataset;
        if missing_dataset then call define(_row_, "style", "style={background=orange}");
        else if mismatched_type then call define(_row_, "style", "style={background=lightred}");
        else if mismatched_attr then call define(_row_, "style", "style={background=peachpuff}");
      endcomp;
    run;

    ods excel close;

    %put NOTE: Comparison complete. Excel report saved to &outxls;

%mend compare_structure;

libname OLD "x:\...path...\raw_old\";
libname NEW "x:\...path...\raw\";

%compare_structure(lib_old=OLD, lib_new=NEW);
