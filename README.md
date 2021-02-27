# Overview
This is a simple GAMS implementation that solves
nonograms/paint-by-number/crucipixel/picross puzzles as integer linear
programs (ILP). An [efficient new ILP formulation](https://doi.org/10.1109/TG.2020.3036687) is employed, and does not proceed by coloring the cells one by one.

# Usage

## Required input files

This implementation applies to a nonogram instance that is encoded as the following files. 
Here `[name]` indicates any user-specified name that is compatible with GAMS's naming requirements for compile-time variables.

*   `[name]sR.csv`: spreadsheet containing block lengths in each row
*   `[name]sC.csv`: spreadsheet containing block lengths in each column
*   `[name]cR.csv`: spreadsheet containing block colors in each row
*   `[name]cC.csv`: spreadsheet containing block colors in each column
*   `[name].inc`: GAMS code to define compile-time variables `size`
    and `nColors`. `size` is an upper bound on the number of rows and
    the number of columns in the instance, and `nColors` is an upper
    bound on the number of colors in the instance (not including
    white/colorless).

Examples of these input files are included with `p16` as the
"`[name]`", illustrating the files' expected formats. These
input files were generated automatically using the Python utility
described in the next section.

#### Importing from Webpbn

A [Python utility](pbnToCsv.py) is included to translate puzzle instances from [Web Paint-by-Number](https://webpbn.com) into the input files required by this implementation. For example, Puzzle #16 would be imported as follows; adapt these instructions as appropriate.

1. At https://webpbn.com/export.cgi, enter 16 as the "Puzzle ID".
2. Choose ".CWC file" as the export format.
3. Save the resulting text file as "16.cwc" in the same folder as this script.
4. In the command line, navigate to this folder, and enter:

        python pbnToCsv.py 16

   This will create the files `p16sR.csv`, `p16sc.csv`, `p16cR.csv`, `p16cC.csv`, and `p16.inc` demanded by the implementation.

At this point, the GAMS implementation may be called with `p16` as the puzzle name.

## Solving the instance in GAMS

Once the required input files are placed in the working folder, the included [GAMS script](nonogram.gms) may be called in GAMS to solve the considered puzzle as an integer linear program (ILP). To do this, update the puzzle name at the end of the line:
    
    $if not set nonogramName $set nonogramName p16

by replacing "`p16`" with the prefix `[name]` of the supplied input file. Set the desired ILP solver in GAMS by adjusting the line:

    option MIP=cplex;
    
and include any desired solver options. Run the script `nonogram.gms` in GAMS; if successful, the solved puzzle will be constructed as `[name]Solution.csv`. This solution may be visualized using Excel's "Conditional Formatting" feature, for example.

This implementation has been tested in GAMS 24.2.3, with the ILP solvers CPLEX 12.6 and GUROBI 5.6.

# References

- K.A. Khan, [Solving nonograms using integer programming without
  coloring](https://doi.org/10.1109/TG.2020.3036687), /IEEE T. Games/,
  in press. This article presents the new nonogram formulation used by
  this implementation, and demonstrates its effectiveness.
