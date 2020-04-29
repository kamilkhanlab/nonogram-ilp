# Converts CWC files exported from webpbn.com to CSV files and an INC file
# intended for input to GAMS
#
# USAGE: e.g. to construct files pertaining to puzzle #48 listed in webpbn.com:
#
# 1. At https://webpbn.com/export.cgi, enter 48 as the "Puzzle ID".
#
# 2. Choose ".CWC file" as the export format.
#
# 3. Save the resulting text file as "48.cwc" in the same folder as this script.
#
# 4. At the command line, enter "python pbnToCsv.py 48". This will construct:
#    * p48sR.csv, listing block lengths in puzzle rows
#    * p48sC.csv, listing block lengths in puzzle columns
#    * p48cR.csv, listing block colors in puzzle rows
#    * p48cC.csv, listing block colors in puzzle columns
#    * p48.inc, listing puzzle dimensions and number of colors
#
# Written by Kamil Khan on April 26, 2019

import csv

def pbnToCsv(n):
    """Convert a CWC file to CSV files for input to GAMS"""
    
    # load "[n].cwc" and read it
    try:
        with open(str(n) + '.cwc', 'r') as inputFile:
            # read nonogram specifications and write to p[n].inc
            with open('p' + str(n) + '.inc', 'w') as outFile:
                nRows = int(inputFile.readline())
                nColumns = int(inputFile.readline())
                nColors = int(inputFile.readline())

                outFile.write('* upper bound on number of rows and number of columns\n')
                outFile.write('$if not set size $set size ' + str(max(nRows, nColumns)) + '\n\n')
                outFile.write('* upper bound on number of colors\n')
                outFile.write('$if not set nColors $set nColors ' + str(nColors))

            # read row-block lengths and write to p[n]sR.csv
            with open('p' + str(n) + 'sR.csv', 'w') as outFile:
                writer = csv.writer(outFile)
                
                headerRow = ['']
                for j in range(nColumns):
                    headerRow.append('t' + str(j+1))
                writer.writerow(headerRow)
                
                for i in range(nRows):
                    blockData = inputFile.readline().split()
                    bodyRow = (['i' + str(i+1)]
                                   + blockData
                                   + ['']*(nColumns - len(blockData)))
                    writer.writerow(bodyRow)

            inputFile.readline()

            # read row-block colors and write to p[n]cR.csv
            with open('p' + str(n) + 'cR.csv', 'w') as outFile:
                writer = csv.writer(outFile)
                
                headerRow = ['']
                for j in range(nColumns):
                    headerRow.append('t' + str(j+1))
                writer.writerow(headerRow)
                
                for i in range(nRows):
                    blockData = inputFile.readline().split()
                    bodyRow = (['i' + str(i+1)]
                                   + blockData
                                   + ['']*(nColumns - len(blockData)))
                    writer.writerow(bodyRow)

            inputFile.readline()

            # read column-block lengths and write to p[n]sC.csv
            with open('p' + str(n) + 'sC.csv', 'w') as outFile:
                writer = csv.writer(outFile)
                
                headerRow = ['']
                for i in range(nRows):
                    headerRow.append('t' + str(i+1))
                writer.writerow(headerRow)
                
                for j in range(nColumns):
                    blockData = inputFile.readline().split()
                    bodyRow = (['j' + str(j+1)]
                                   + blockData
                                   + ['']*(nRows - len(blockData)))
                    writer.writerow(bodyRow)

            inputFile.readline()

            # read column-block colors and write to p[n]cC.csv
            with open('p' + str(n) + 'cC.csv', 'w') as outFile:
                writer = csv.writer(outFile)
                
                headerRow = ['']
                for i in range(nRows):
                    headerRow.append('t' + str(i+1))
                writer.writerow(headerRow)
                
                for j in range(nColumns):
                    blockData = inputFile.readline().split()
                    bodyRow = (['j' + str(j+1)]
                                   + blockData
                                   + ['']*(nRows - len(blockData)))
                    writer.writerow(bodyRow)
                    
    except IOError:
        print('Error: did not locate "' + str(n) + '.cwc" in current directory')
        sys.exit()
        
# permit execution from command line
if __name__ == "__main__":
    import sys
    pbnToCsv(int(sys.argv[1]))
    
