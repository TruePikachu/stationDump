# stationDump
X Rebirth Station Info Dumper

## Running
Assuming you have all the `.cat` and `.dat` files located in `./steamdir`, just run the script. It is recommended to
pipe standard output to a file, so it doesn't get interweaved with debug information from standard error:
```
$ ls steamdir/??.?at
steamdir/01.cat  steamdir/03.dat  steamdir/06.cat  steamdir/08.dat
steamdir/01.dat  steamdir/04.cat  steamdir/06.dat  steamdir/09.cat
steamdir/02.cat  steamdir/04.dat  steamdir/07.cat  steamdir/09.dat
steamdir/02.dat  steamdir/05.cat  steamdir/07.dat
steamdir/03.cat  steamdir/05.dat  steamdir/08.cat
$ perl dump.pl > station-info.txt
Loading cat/dat database.........
Loading wares.xml...
Loading 0001-L044.xml...
Indexing wares...................................................................
Collecting production modules........................................................................
Collecting stations...............................................................
$ _
```
If you, however, have the `.cat` and `.dat` files located somewhere else, tell the script:
```
$ perl dump.pl /path/to/steamdir/
```
The trailing slash is technically optional.
