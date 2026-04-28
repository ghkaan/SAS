%let folder1 = X:\BioMetrics\SAS programming\Qualitec\MIN-001P-1501\csr\dev\data\raw\02-10-2025 raw;
%let folder2 = X:\BioMetrics\SAS programming\Qualitec\MIN-001P-1501\csr\dev\data\raw\20251022\CSV2;

%macro flist(path,ds,whr);
  %if %length(&ds)=0 %then %let ds=FLIST1;
  %put NOTE: &=path;
  data &ds.;
    length FPATH FNAME NAME EXT $256;
    FPATH = strip("&path");
    RC = filename('folderid', "&path");
    DID = dopen('folderid');
    /* Open the directory */
    DID = dopen('folderid');
    if DID > 0 then do;
      NUMFILES = dnum(did);
      do i = 1 to numfiles;
        FNAME = dread(did, i);
        if index(FNAME,".") then do;
          EXT = scan(FNAME,-1,".");
          NAME = substr(FNAME,1,length(FNAME)-length(EXT)-1);
          end;
        else NAME = FNAME;
        output;
      end;
      rc = dclose(did);
    end;
    rc = filename('folderid');
    drop DID RC I NUMFILES;
  run;
  %if %length(&whr)>0 %then %do;
    data &ds.; set &ds(where=(&whr)); run;
  %end;
%mend;

%flist(&folder1.,whr=EXT eq "csv");
%flist(&folder2.,FLIST2);

proc sql; 
  create table FILES_COMP as select distinct coalescec(a.FNAME, b.FNAME) as FNAME, a.FNAME as FNAME1, b.FNAME as FNAME2
    from FLIST1 as a full join FLIST2 as b on a.FNAME=b.FNAME order by FNAME;
quit;
