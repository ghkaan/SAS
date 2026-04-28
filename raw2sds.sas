*********************************************************************************;
* Program to create source data specification for datasets in specified library *;
* (c) Anton Kamyshev, 20260424                                                  *;
********** Parameters ***********************************************************;
%let lib=RAW;      * Specify SAS libname - RAW, EXTRACT etc. *;
%let out=SDS.xlsx; * Specify correct file name with xlsx extension *;
%let frm=FORM;     * Specify name of the variable in the data with form name *;
*********************************************************************************;

%macro export_sds_to_xlsx(inlib=&lib., outfile=&out., formname=&frm.);
  ** inlib - SAS library name
  ** outfile - report file name
  ** formname - name of the variable with form name ;

  proc sql;
    create table SDS1 as select distinct MEMNAME, NAME, LABEL, TYPE, LENGTH, FORMAT, VARNUM
      from sashelp.VCOLUMN where upcase(LIBNAME)=upcase("&inlib")
      order by MEMNAME, VARNUM;
  quit;

  data SDS2;
    retain MEMNAMEN 0;
    set SDS1;
    by MEMNAME;
    if first.MEMNAME then MEMNAMEN+1;
    attrib
      SDTM1 length=$200 label="XX"
      SDTM2 length=$200 label="YY"
      SDTM3 length=$200 label="ZZ"
      LINK  length=$200;
    call missing(of SDTM:);
    DUMMY=" ";
    LINK=cats('=HYPERLINK("#', "'", "Datasets", "'!A", MEMNAMEN+3, '", "', MEMNAME, '")');
  run;

  * Information for tab "Datasets" *;
  proc sql;
    create table RAWDS as select distinct
      MEMNAME, " " as INFO label="Info" length=200, " " as PAGE label="Page", " " as DOMAINS label="SDTM domains", " " as COMMENTS label="Comments",
      cats('=HYPERLINK("#', "'", MEMNAME, "'!A1", '", "', MEMNAME, '")') as LINK length=200
      from SDS2 order by MEMNAME;
  quit;

  * Check form names *;
  %if %length(&formname)>0 %then %do;
    %let FORMCNT=0;
    proc sql noprint; select count(*) into :FORMCNT from sashelp.VCOLUMN where upcase(LIBNAME)=upcase("&inlib") and upcase(NAME)=upcase("&formname"); quit;
    %if &formcnt=0 %then %do;
      %put %str(WAR)NING: Variable %upcase(&formname) was not found.;
      %goto end_formname;
    %end;
    proc sql noprint;
      select distinct "&inlib.."||strip(MEMNAME)||"(keep=&formname)" into :rawds separated by " " from sashelp.VCOLUMN where upcase(LIBNAME)=upcase("&inlib") and upcase(NAME)=upcase("&formname");
    quit;
    data FORMNAME;
      length DS FORM $200;
      set &rawds. indsname=DSN;
      DS=scan(DSN,2);
      keep DS FORM;
    run;
    proc sort data=FORMNAME noduprecs; by DS; run;
    proc sql; create table RAWDS_FN as select a.*, b.FORM from RAWDS as a left join FORMNAME as b on upcase(a.MEMNAME)=upcase(b.DS) order by MEMNAME; quit;
    data RAWDS;
      set RAWDS_FN;
      INFO = FORM;
    run;
    %end_formname:
  %end;

  proc sql noprint;
    select distinct MEMNAME into :memnames separated by ' ' from SDS2;
    select max(MEMNAMEN) into :count from SDS2;
  quit;

  ods escapechar='^';
  ods listing close;
  ods excel file="&outfile" options(sheet_interval="table");
  ods excel options(sheet_name="Datasets" embedded_titles="yes" embed_titles_once="yes" autofilter="ALL" frozen_headers="ON");

  proc report data=RAWDS nowd;
    title "List of RAW datasets";
    column LINK INFO PAGE DOMAINS COMMENTS;
    define LINK / display "RAW data (click to open)";
    define INFO / style(column)=[cellwidth=2in];
    define PAGE / style(column)=[cellwidth=0.5in];
    define DOMAINS / style(column)=[cellwidth=2in];
    define COMMENTS / style(column)=[cellwidth=2in];
    compute LINK;
      call define("LINK", 'url', "");
      call define("LINK", 'style', 'style={textdecoration=underline color=blue}');
    endcomp;
  run;

  ods text='Use this formulas to summarize column C (remove leading square bracket, some fucntions can not work in different excel versions):';
  ods text=' ';
  ods text='[="Distinct list of domains: "&IFERROR(TEXTJOIN(", ",TRUE,UNIQUE(TRIM(FILTERXML("<t><s>"&SUBSTITUTE(TEXTJOIN(", ",TRUE,UNIQUE(FILTER(C4:C999,C4:C999<>" "))),",","</s><s>")&"</s></t>","//s")))),"None")';
  ods text='[="Number of SDTM domains: "&MIN(COUNTA(C4:C999),COUNTA(UNIQUE(TRIM(FILTERXML("<t><s>"&SUBSTITUTE(TEXTJOIN(", ",TRUE,UNIQUE(FILTER(C4:C999,C4:C999<>" "))),",","</s><s>")&"</s></t>","//s")))))';
  ods text='[="Distinct list of domains: "&TEXTJOIN(", ",TRUE,IFERROR(SUBSTITUTE(SORT(UNIQUE(TRIM(FILTERXML("<k><m>"&SUBSTITUTE(SUBSTITUTE(TEXTJOIN(" ", TRUE, C4:C999), ",", " "), " ", "</m><m>")&"</m></k>", "//m")))),"Столбец1",""),""))';
  ods text='[="Number of SDTM domains: "&LEN(TRIM(A59))-LEN(SUBSTITUTE(TRIM(A59)," ",""))-3';
  ods text=' ';
  ods text='[="Number of CRF panels: "&COUNTA(A4:A54)&" / "&COUNTA(C4:C54)';

  %do i=1 %to &count;
    %let CURRENT_MEMNAME=%scan(&memnames,&i.);
    %put &=i &=current_memname;
    ods excel options(sheet_name="%left(&current_memname)" embedded_titles="yes" embed_titles_once="yes" autofilter="ALL" frozen_headers="ON");
    proc report data=SDS2(where=(MEMNAMEN=&i.)) nowd;
      title "Source Data Specification for &current_memname";
      column ("Source dataset" /*MEMNAME*/ LINK NAME LABEL TYPE LENGTH FORMAT VARNUM) (">>>>" DUMMY) ("SDTM domains" SDTM1 SDTM2 SDTM3);
      define /*MEMNAME*/ LINK / "Dataset (click to return)";
      define NAME    / "Variable";
      define LABEL   / "Label";
      define TYPE    / "Type";
      define LENGTH  / "Length";
      define FORMAT  / "Format";
      define VARNUM  / "Order";
      define DUMMY   / "" style(header)=[background=white];
      define SDTM1   / display style(column)=[cellwidth=1.5in];
      define SDTM2   / display style(column)=[cellwidth=1.5in];
      define SDTM3   / display style(column)=[cellwidth=1.5in];
      compute LINK;
        call define("LINK", 'url', "");
        call define("LINK", 'style', 'style={textdecoration=underline color=blue}');
      endcomp;
    run;
  %end;

  ods excel close;
  ods listing;

%mend export_sds_to_xlsx;

%export_sds_to_xlsx;
