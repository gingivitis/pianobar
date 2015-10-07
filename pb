#!/bin/bash

CHECK_PERIOD=${CHECK_PERIOD:-"1"}
OUTPUT_LINES=${OUTPUT_LINES:-"30"}
ACT_SONGPLAY=P
ACT_SONGPAUSETOGGLE=p
ACT_SONGPAUSETOGGLE2=' ' # space
XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
FIFO=$XDG_CONFIG_HOME/pianobar/ctl
OUT=$XDG_CONFIG_HOME/pianobar/out
CONFIG=$XDG_CONFIG_HOME/pianobar/config


# Load the pianobar config file as bash variables
# also strip password info for security reasons
# ex: act_upcoming becomes ACT_UPCOMING
# ex: user becomes PIANOBAR_USER (in order to avoid conflicts with the user environment variable)
load_config(){
        if [[ -r $CONFIG ]]
        then
                source <(sed -n \
                        -e 's/password.*//' \
                        -e 's/user/pianobar_user/' \
                        -e 's/\([0-9A-Za-z_]*\) = \(.*\)/\U\1\E="\2"/p' < $CONFIG)
        else
                echo "Couldn't load config file $CONFIG, using defaults"
                false
        fi
}

is_running(){
        ps -u $(id -u) -o comm | grep -q "^pianobar$"
}

# Launch pianobar if it is not already running.
launch(){
        if ! is_running
        then
                ensure_fifo true
                echo "Pianobar not running, launching Pianobar"
                nohup pianobar &>$OUT &disown
                sleep 1
        else
                ensure_fifo
        fi
}

# Check on a regular basis that pianobar is still running.
# If pianobar stops running, stop this script as well.
running(){
        while is_running
        do
        	sleep $CHECK_PERIOD
        done
        rm ~/tmp/current
        pkill -RTMIN+11 i3blocks
        echo "Pianobar died, quitting"
        quit
}

# Function to cleanly quit.  Ensures that the two backgrounded processes (the
# output, tail, and the check, running()) both exit along with the parent (this
# script itself)
quit(){
	# tail and running() might both die when the parent dies as there was no
	# nohup, but double-check just to make sure.  Don't want to leave a mess
	# behind.
	if [ ! -z $TAILPID ]
	then
		kill $TAILPID 2>/dev/null
	fi
	if [ ! -z $RUNNINGPID ]
	then
		kill $RUNNINGPID 2>/dev/null
	fi
	trap - HUP INT TERM
	kill $$
	exit 0
}

# Print pianobar's output.
output(){
        # Sanity check: ensure pianobar's output can be read.
        if [ ! -f $OUT ]
        then
                echo "pianobar does not seem to be outputting to $OUT, try killing it and starting $0 again"
                exit 2
        fi

        tail -n$OUTPUT_LINES -f $OUT &
        TAILPID=$!
}

# Get input from user, character by character, and feed it to pianobar's ctl
# fifo.  Note that no newline character is given with `read`.  Rather, one
# simply gets an empty variable back.  Detect this situation and pass a newline
# along to pianobar.  Otherwise, send the character read from input to
# pianobar. If ^D or EOF is given, quit
input(){
        IFS=""
        while /bin/true
        do
                read -n1 -s INPUT
                if [[ $? == "1" || "$INPUT" == $'\004' ]]
                then
                        quit
                elif [ "$INPUT" == "" ]
                then
                        send_input "\n"
                else
                        send_input "$INPUT"
                fi
        done
}

# send the first argument to the control fifo
send_input(){
        echo -ne "$1" > $FIFO
}

# Ensure the ctrl fifo exists. Arg1: create if it doesn't exist
ensure_fifo(){
        if [ ! -p $FIFO ]
        then
                if [[ $1 ]]
                then
                        echo "Pianobar ctl fifo not present at $FIFO, creating"
                        mkfifo $FIFO
                        if [ ! -p $FIFO ]
                        then
                                echo "Failed to create fifo, aborting"
                                exit 1
                        fi
                else
                        echo "Pianobar ctl fifo not present at $FIFO, aborting"
                        exit 1
                fi
        fi
}

# Ensure quit() is called to clean up when exiting
trap quit HUP INT TERM

mkdir -p $XDG_CONFIG_HOME/pianobar

# load the main pianobar config file
# Don't use $XDG_CONFIG_HOME or $HOME after this because it may have changed if set in the config file.
load_config

# if no arguments, launch pianobar if not running, then connect to the pianobar ui
if [[ $# == 0 ]]
then
        launch

        # Run running() in the background to detect when pianobar closes.
        running &
        RUNNINGPID=$!

        output

        input
else
        if ! is_running
        then
# if there are arguments, and pianobar is not running, start pianobar if it makes sense to
                case $1 in
                        $ACT_SONGPLAY | $ACT_SONGPAUSETOGGLE | $ACT_SONGPAUSETOGGLE2)
                                launch
                                shift ;;
                        *)
                                echo "Pianobar not running, nothing executed"
                                exit 0
                                ;;
                esac
        fi
# if there are arguments and pianobar is running, send arguments to pianobar, then exit
        ensure_fifo
        while [[ $# > 0 ]]; do
                send_input "$1"
                shift
        done
fi
