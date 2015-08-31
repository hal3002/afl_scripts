#!/bin/bash

# Variables needed to create the session
SESSION_NAME=7za
SESSION_BIN="/mnt/fuzzing/bin/7za"
SESSION_FLAGS="x @@ -o/mnt/fuzzing/tmp/blah -y"
CPUS=$( cat /proc/cpuinfo  | egrep 'processor\s+:' | wc -l )

# AFL specific variables
AFL_TESTCASE_BASE=/mnt/fuzzing/test_files
AFL_FINDINGS_BASE=/mnt/fuzzing/findings
AFL_TIMEOUT_LIMIT=10000
AFL_MEMORY_LIMIT=10000

# Check input and output directories
TESTCASE_PATH=$AFL_TESTCASE_BASE/$SESSION_NAME 
if [ ! -d $TESTCASE_PATH ]
then
	echo "Test case directory does not exist: $TESTCASE_PATH"
	exit
fi

FINDINGS_PATH=$AFL_FINDINGS_BASE/$SESSION_NAME
if [ -d $FINDINGS_PATH ]
then
	echo "The findings directory already exists: $FINDINGS_PATH"
	exit
fi

# Create the new session
tmux new-session -d -s $SESSION_NAME

# Create the master window and start the instance
tmux rename-window -t $SESSION_NAME:0 Master
tmux send-keys -t $SESSION_NAME:0 "afl-fuzz -M master -m $AFL_MEMORY_LIMIT -t $AFL_TIMEOUT_LIMIT -i $TESTCASE_PATH -o $FINDINGS_PATH $SESSION_BIN $SESSION_FLAGS" C-m

# Now we need to create the workers
for x in $(seq $( expr $CPUS - 1 ))
do
	tmux new-window -t $SESSION:$x -n "Worker$x"
	tmux send-keys -t $SESSION_NAME:$x "afl-fuzz -S worker$x -m $AFL_MEMORY_LIMIT -t $AFL_TIMEOUT_LIMIT -i $TESTCASE_PATH -o $FINDINGS_PATH $SESSION_BIN $SESSION_FLAGS" C-m
done

# Create a status window
tmux new-window -t $SESSION:$CPUS -n "Status"
tmux send-keys -t $SESSION:$CPUS "watch -n 1 afl-whatsup $FINDINGS_PATH" C-m

# Finally, attach to the new session
tmux attach -t $SESSION_NAME
