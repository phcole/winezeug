#!/bin/sh
# Script to run "make test" under valgrind and find changes from yesterday
set -x
set -e
DATE=`date +%F`

export WINEPREFIX=$HOME/.wine-test
if true
then
  git pull
  ##./configure CC=gcc-3.3 --prefix=/usr/local/wine
  ./configure CFLAGS="-g -O0" --prefix=/usr/local/wine
  make clean
  make -j3
fi
make testclean
rm -rf $WINEPREFIX
tools/wineprefixcreate
export RUNTEST_USE_VALGRIND=1
set -e
export WINE=$HOME/wine-git/wine
export WINEPREFIXCREATE=$HOME/wine-git/tools/wineprefixcreate
sh winetricks gecko
set +e
# keep a notepad up to avoid repeated startup penalty
server/wineserver -k
./wine notepad &
make -k test > logs-$DATE.log 2>&1
server/wineserver -k
rm -f vg*.txt
rm -rf logs-$DATE
mkdir logs-$DATE
perl tools/valgrind-split.pl logs-$DATE.log
mv vg*.txt logs-$DATE

# Generate histogram of errors
cat logs-$DATE.log |
egrep -C3 'uninitialised|Unhandled exception:|Invalid read|Invalid write|Invalid free|Source and desti|Mismatched free|unaddressable byte|vex x86' | grep == | sed 's/.*=//' > sum
cat sum | 
sed "/Warning: set add/s/.*//" |
sed "/ERROR SUMMARY/s/.*//" |
sed "/malloc.free/s/.*//" |
sed "/Reachable blocks/s/.*//" |
sed "/searching for pointer/s/.*//" |
sed "/Your program just tried to execute an instruction that Valgrind/s/.*//" |
sed "/did not recognise. There are two possible reasons for this.*/s/.*//" |
sed "/More than 100 errors detected/s/.*//" |
sed "/will still be recorded/s/.*//" |
sed "/For counts of detected/s/.*//" |
sed "/suppressed:/s/.*//" |
sed "/Thread [0-9]*:/s/.*//" |
sed "/^yes/s/.*//" |
sed 's,/home/dank/.wine-test/drive_c/windows/,,' |
cat > sum2
cat sum2 | sed 's/by 0x[0-9a-fA-F]*:/by /' | sed 's/at 0x[0-9a-fA-F]*:/at /'  > sum3
sed 's/^ \([^ ]\)/|\1/' < sum3 > sum4
cat sum4 | tr '\012' '\011' | tr '|' '\012' | sed 's/  */ /g' | sed 's/[ 	]*$//' | grep . > sum5
sort < sum5 | uniq -c | sort -rn > logs-$DATE.counts.txt

PREV=`ls -d logs-????-??-?? | tail -2 | head -1`
diff -Nu  -x '*diff.txt' $PREV logs-$DATE >  logs-$DATE-diff.txt
cat logs-$DATE-diff.txt | egrep '^[-+].*(uninitialised|Unhandled exception:|Invalid read|Invalid write|Invalid free|Source and desti|Mismatched free|unaddressable byte|Uninitialised value was created|vex x86)|diff' >  logs-$DATE-summary.txt
cd logs-$DATE
for file in `ls vg*.txt | grep -v .-diff.txt`
do
	out=`basename $file .txt`-diff.txt
	diff -Nu ../$PREV/$file $file > $out
done
chmod 644 *
chmod 755 .

