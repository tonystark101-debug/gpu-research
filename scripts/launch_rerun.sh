#!/bin/bash
# After the sweep finishes, rerun its non-passing cases with the fixed code.
O=~/runs/correctness
while [ ! -f $O/done.txt ]; do sleep 20; done
python3 ~/rerun_failed.py 0 4 ~/vortex_ours  $O > $O/rerun0.out 2>&1 &
python3 ~/rerun_failed.py 1 4 ~/vortex_ours1 $O > $O/rerun1.out 2>&1 &
python3 ~/rerun_failed.py 2 4 ~/vortex_ours2 $O > $O/rerun2.out 2>&1 &
python3 ~/rerun_failed.py 3 4 ~/vortex_ours3 $O > $O/rerun3.out 2>&1 &
wait
echo "RERUN DONE" > $O/rerun_done.txt
