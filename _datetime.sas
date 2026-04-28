/*Intervals*/
N=intck(interval, from, to);

lastDay=intnx('month',"01DEC2001"d,0,'E'); * Return end date for the specified interval *;


/*20110131->numeric SAS date*/
%macro DT(indt,outdt);
  &OUTDT=input(&INDT,??yymmdd8.);
  &OUTDT.L=put(&OUTDT,??date9.);
%mend DT;

/*1230->numeric SAS time*/
%macro TM(intm,outtm);
  &OUTTM=input(catx(':',substr(&INTM,1,2),substr(&INTM,3)),??time5.);
  &OUTTM.L=put(&OUTTM,??time5.);
%mend TM;

***********;
proc format;
  picture FD  -1 = 'UNK';
  picture FM  -1 = 'UNK'
              1  = 'JAN'
              2  = 'FEB'
              3  = 'MAR'
              4  = 'APR'
              5  = 'MAY'
              6  = 'JUN'
              7  = 'JUL'
              8  = 'AUG'
              9  = 'SEP'
              10 = 'OCT'
              11 = 'NOV'
              12 = 'DEC';
  picture FY  -1 = 'UNK'
              other = '9999';
  picture FT  -1 = 'UNK'
              other = '99';
run;

data _null_;
  length DT $22;
  y=1998;
  m=12;
  d=-1;
  hr=02;
  mn=3;
  sc=-1;
  DT=cats(put(d,FD.),put(m,FM.),put(y,FY.))||':'||catx(':',put(hr,FT.),put(mn,FT.),put(sc,FT.));
  put DT;
run;

/* result: "UNKDEC1998:02:03:UNK" */
***********;

%macro convdate(indt=, outdt=);
  if length(strip(&indt)) = 8 then  &outdt = put(input(&indt, yymmdd8.), date9.);
 
  else  if length(strip(&indt)) = 6 then do;
    &indt = strip(&indt)||'01';
    &outdt = 'UN'||substr(put(input(&indt, yymmdd8.), date9.), 3);
  end;
 
  else  if length(strip(&indt)) = 4 then do;
    &outdt = 'UNUNK'||strip(&indt);
  end;
%mend convdate;

/*result: 011982 -> UNJAN1982*/
***********;


DGN1O_1=put(input(DGN1O_1,??yymmdd8.),??date9.);


/* num. 20120613 -> numeric SAS date */
%macro NUMDT2DT(ds,var);
data &DS;
  set &DS(rename=(&VAR=TMP));
  &VAR=input( compress(put(TMP,best8.)),YYMMDD8. );
  format &VAR date9.;
  drop TMP;
run;
%mend;

* ISO date\time formats: *;
* DATETIME: *;
ADTM = input(ADTC,is8601dt.);
* DATE: *;
ADT = input(ADTC,is8601da.);
* TIME: *;
ATM = input(substr(ADTC,12,8),is8601tm.); 

* Derive numeric xxDTN datetime and xxTM time variables from character xxDTC variables with iso datetime values YYYY-MM-DDTHH:MM:SS or YYYY-MM-DD *;
  %let DTC = RFSTDTC RFENDTC CMSTDTC CMENDTC;
  %let DTC2 = %sysfunc(tranwrd(%upcase(&dtc),DTC,DTC2)); %let DTN = %sysfunc(tranwrd(&dtc2,DTC2,DTN)); %let DTM = %sysfunc(tranwrd(&dtc2,DTC2,TM));
  array DTC{*}$19 &dtc.; array DTC2{*}$19 &dtc2.; array DTN{*} &dtn.; array DTM{*} &dtm.;
    do i=1 to hbound(DTC);
      if not index(DTC{i}, "T") and not missing(DTC{i}) then DTC2{i}=cats(DTC{i}, "T00:00:00"); else DTC2{i}=DTC{i};
      DTN{i}=input(DTC2{i},??is8601dt.);
      DTM{i}=input(scan(DTC2{i},2,"T"),??time5.);
    end;
  format &dtn. is8601dt. &dtm. time5.;
  drop i;