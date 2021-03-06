$ontext

Nonogram solver, using new ILP formulation published in IEEE T. Games.
Publication: https://doi.org/10.1109/TG.2020.3036687

Written by Kamil Khan on February 22, 2019.
Last updated: February 26, 2021

Expects the following files in the same directory, concerning a puzzle instance
named [name]:
* [name]sR.csv: spreadsheet containing block lengths in each row
* [name]sC.csv: spreadsheet containing block lengths in each column
* [name]cR.csv: spreadsheet containing block colors in each row
* [name]cC.csv: spreadsheet containing block colors in each column
* [name].inc: GAMS code to define compile-time variables "size" and "nColors"

These may be constructed using my Python script "pbnToCsv.py", which translates
CWC files exported from https://webpbn.com/export.cgi into the above files.

Before use, set the compile-time variable "nonogramName" to [name] below,
along with other solver settings.

Output is written to [name]Solution.csv.

$offtext

* name of nonogram, used to find input files and name output files
$if not set nonogramName $set nonogramName p16

* set the following compile-time variables:
*   size: upper bound on number of rows and number of columns
*   nColors: upper bound on number of colors
$ifThen.a exist %nonogramName%.inc
  $include %nonogramName%.inc
$else.a
  $if not set size $set size 60
  $if not set nColors $set nColors 5
$endIf.a

* ILP solver
option MIP=cplex;

* read CPLEX options from file 'cplex.opt'?
* $set useCplexOptionsFile

* use unnecessary additional constraints?
* $set useExtraConstraints

* maximum wall-clock time [s] allocated for each "solve" statement
option resLim=1200;

sets
  i              "rows"          /i1 * i%size%/,
  j              "columns"       /j1 * j%size%/,
  t              "blocks"        /t1 * t%size%/,
  c              "colors"        /c1 * c%nColors%/
;
alias
  (i,ii),
  (j,jj),
  (t,tt)
;

* read block sizes from input files
table sR(i,t)    "size of t^th block in row i"
$ondelim
$include %nonogramName%sR.csv
$offdelim
;

table sC(j,t)    "size of t^th block in column j"
$ondelim
$include %nonogramName%sC.csv
$offdelim
;

* if color-specifying files exist, then read those. Otherwise, set all block colors to 1.
$ifThen exist %nonogramName%cR.csv
table cR(i,t)    "color of t^th block in row i"
$ondelim
$include %nonogramName%cR.csv
$offdelim
;

table cC(j,t)    "color of t^th block in column j"
$ondelim
$include %nonogramName%cC.csv
$offdelim
;
$else
parameters
  cR(i,t)        "color of t^th block in row i",
  cC(j,t)        "color of t^th block in column j"
;
cR(i,t)$sR(i,t) = 1;
cC(j,t)$sC(j,t) = 1;
$endIf

* check that number of colors is bounded properly
if (%nColors%<smax((i,t)$sR(i,t),cR(i,t)) or %nColors%<smax((j,t)$sC(j,t),cC(j,t)),
  abort "Number of colors in input exceeds specified upper bound nColors";
);

* compute intermediate quantities used to formulate model
parameters
  sigmaR(i,t)    "is t^th block in row i the same color as (t+1)^th block?"
  sigmaC(j,t)    "is t^th block in column j the same color as (t+1)^th block?"

  lR(i,t)        "index of leftmost possible column of t^th block in row i"
  lC(j,t)        "index of topmost possible row of t^th block in column j"
;

sigmaR(i,t)$(sR(i,t) and sR(i,t+1) and (cR(i,t)=cR(i,t+1))) = 1;

sigmaC(j,t)$(sC(j,t) and sC(j,t+1) and (cC(j,t)=cC(j,t+1))) = 1;

lR(i,t)$(sR(i,t) and ord(t)=1) = 1;
loop(t,
  lR(i,t)$(sR(i,t-1) and sR(i,t)) = lR(i,t-1) + sR(i,t-1) + sigmaR(i,t-1);
);

lC(j,t)$(sC(j,t) and ord(t)=1) = 1;
loop(t,
  lC(j,t)$(sC(j,t-1) and sC(j,t)) = lC(j,t-1) + sC(j,t-1) + sigmaC(j,t-1);
);

* computing uR and uC is more complicated than computing lR and lC
parameters
  m              "number of rows"
  n              "number of columns"
  nBlocksR(i)    "number of blocks in row i"
  nBlocksC(j)    "number of blocks in column j"
  uOffsetR(i)   "wiggle-room in row i"
  uOffsetC(j)   "wiggle-room in column j"
  uR(i,t)        "index of rightmost possible leftmost column of t^th block in row i"
  uC(j,t)        "index of bottommost possible topmost row of t^th block in column j"
;
m = sum((i,t)$(sR(i,t) and (ord(t)=1)),1);
n = sum((j,t)$(sC(j,t) and (ord(t)=1)),1);
bR(i) = sum(t$sR(i,t),1);
bC(j) = sum(t$sC(j,t),1);
uOffsetR(i)$bR(i) = sum(t$(ord(t)=bR(i)), n+1-sR(i,t)-lR(i,t));
uOffsetC(j)$bC(j) = sum(t$(ord(t)=bC(j)), m+1-sC(j,t)-lC(j,t));
uR(i,t)$sR(i,t) = lR(i,t) + uOffsetR(i);
uC(j,t)$sC(j,t) = lC(j,t) + uOffsetC(j);

* summation ranges used by model
sets
  setFR(i,t,j)   "columns j in which t^th block in row i may begin"
  setFC(j,t,i)   "rows i in which t^th block in column j may begin"
  setMOR(i,t,j,jj,c) "if t^th block in row i starts in col jj, would cell (i,j) be part of the same block with color c?"
  setMOC(j,t,i,ii,c) "if t^th block in col j starts in row ii, would cell (i,j) be part of the same block with color c?"
;
setFR(i,t,j)$(sR(i,t) and lR(i,t)<=ord(j) and ord(j)<=uR(i,t)) = yes;
setFC(j,t,i)$(sC(j,t) and lC(j,t)<=ord(i) and ord(i)<=uC(j,t)) = yes;
setMOR(i,t,j,jj,c)$(cR(i,t)=ord(c) and setFR(i,t,jj) and ord(j)<=n and ord(jj)<=ord(j) and ord(j)<ord(jj)+sR(i,t)) = yes;
setMOC(j,t,i,ii,c)$(cC(j,t)=ord(c) and setFC(j,t,ii) and ord(i)<=m and ord(ii)<=ord(i) and ord(i)<ord(ii)+sC(j,t)) = yes;

* decision variables
variables
  y(i,t,j)       "to equal 1 iff t^th block in row i has its leftmost cell in column j"
  x(j,t,i)       "to equal 1 iff t^th block in column j has its topmost cell in row i"
  dummyObjective "dummy objective function value"
;
binary variables y,x;

* model constraints; a nonogram is a constraint satisfaction problem
equations
  blockBeginsOnceR(i,t)  "each block in a row begins once"
  blockBeginsOnceC(j,t)  "each block in a column begins once"
  blockOrderR(i,t)       "in row i, (t+1)^th block is to the right of t^th block"
  blockOrderC(j,t)       "in col j, (t+1)^th block is below t^th block"
  consistentColor(i,j,c) "i^th row and j^th column agree that cell (i,j) is either colored c or not colored c"

$ifThen set useExtraConstraints
  oneBlockR(i,j)         "cell (i,j) is in at most one of row i's blocks (unnecessary but valid cut)"
  oneBlockC(i,j)         "cell (i,j) is in at most one of column j's blocks (unnecessary but valid cut)"
$endIf

  dummyEq                "set dummy objective value to 0"
;

blockBeginsOnceR(i,t)$sR(i,t)..
  sum(setFR(i,t,j),y(i,t,j)) =e= 1;

blockBeginsOnceC(j,t)$sC(j,t)..
  sum(setFC(j,t,i),x(j,t,i)) =e= 1;

blockOrderR(i,t)$(sR(i,t) and sR(i,t+1))..
  sum(setFR(i,t,j),ord(j)*y(i,t,j)) + lR(i,t+1) - lR(i,t)
    =l= sum(setFR(i,t+1,j),ord(j)*y(i,t+1,j));

blockOrderC(j,t)$(sC(j,t) and sC(j,t+1))..
  sum(setFC(j,t,i),ord(i)*x(j,t,i)) + lC(j,t+1) - lC(j,t)
    =l= sum(setFC(j,t+1,i),ord(i)*x(j,t+1,i));

consistentColor(i,j,c)$(ord(i)<=m and ord(j)<=n)..
  sum(setMOR(i,t,j,jj,c),y(i,t,jj))
    =e= sum(setMOC(j,t,i,ii,c),x(j,t,ii));

$ifThen set useExtraConstraints
oneBlockR(i,j)$(ord(i)<=m and ord(j)<=n)..
   sum(setMOR(i,t,j,jj,c),y(i,t,jj)) =l= 1;
oneBlockC(i,j)$(ord(i)<=m and ord(j)<=n)..
   sum(setMOC(j,t,i,ii,c),x(j,t,ii)) =l= 1;
$endIf

dummyEq..
  dummyObjective =e= 0;

* initial values
loop((i,t,j)$(sR(i,t) and ord(j)=lR(i,t)),
  y.l(i,t,j) = 1;
);

loop((j,t,i)$(sC(j,t) and ord(i)=lC(j,t)),
  x.l(j,t,i) = 1;
);

* collect nonogram model and solve it
model nonogram /all/;
$ifThen set useCplexOptionsFile
nonogram.OptFile=1;
$endIf
solve nonogram minimizing dummyObjective using MIP;

* construct and export solved nonogram
parameter z(i,j)         "color of cell (i,j) in completed nonogram";
z(i,j) = sum(setMOR(i,t,j,jj,c),y.l(i,t,jj)*cR(i,t));
option decimals = 0;
File solutionFile /%nonogramName%Solution.csv/;
put solutionFile;
loop(i$(ord(i)<=m),
  loop(j$(ord(j)<=n),
    put z(i,j):1:0, ",";
  );
  put /;
);
putclose;
