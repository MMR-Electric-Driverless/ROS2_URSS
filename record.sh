#!/bin/bash

# COMMAND LINE PARSING
if [ $# -ne 1 ]; then
    echo "error: wrong number of arguments"
    exit
fi
if [ ! -f $1 ]; then
    echo "file named '$1' not found"
    exit
fi
preset_filename="$1"

# Yaml read function, gently borrowed from the following repository: https://github.com/PigneInTesta/yaml-parser . The main changes involve the formatting of
# the parsed values, which now are not color coded.
yaml_read(){
    result1=$(awk -F ": " -v key="${2}" '{sub(/#.*/, "", $2); gsub(/^[ \t]+|[ \t]+$/, "", $2)} $1 == key {gsub(/"/, "", $2); print $2}' "${1}")
    count1=$(awk -v key="^${2}:" '$0 ~ key {count++} END {if (count) print count; else print 0}' "${1}")
    if [ "${count1}" -gt 1 ]; then
      echo ""
    elif [ -z "${result1}" ]; then
      echo ""
    else
      echo "${result1}"
    fi
}

parse_yaml(){
    val=$(yaml_read ${preset_filename} "$1")
    echo "$val"
}

stop_record(){
    echo ""
    echo "stopping recording..."
    echo
    if [ "$bag" -eq 0 ] && kill $pid_bag > /dev/null 2>&1; then
        echo "bag stopped"
    elif [ "$bag" -ne 0 ]; then
        echo "bag recording not started"
    else
        echo "bag proccess not found"
    fi
    echo

    if [ "$pcap" -eq 0 ] && [ "$pcap_permission_granted" -eq 0 ] && sudo kill $pid_pcap > /dev/null 2>&1; then
        echo "pcap stopped"
    elif [ "$pcap" -ne 0 ]; then
        echo "pcap recording not started"
    else
        echo "pcap proccess not found"
    fi
    echo
    exit
}

## RECORD YAML PARSING
pcap_val=$(parse_yaml "pcap")
bag_val=$(parse_yaml "bag")
bag_dir_val=$(parse_yaml "bag_dir")
pcap_dir_val=$(parse_yaml "pcap_dir")
bag_args_val=$(parse_yaml "bag_args")
topics_val=$(parse_yaml "topics")
pcap_args_val=$(parse_yaml "pcap_args")
pcap_ofile_name_raw=$(parse_yaml "pcap_name")
bag_ofile_name_raw=$(parse_yaml "bag_name")
date_format=$(parse_yaml "date_format")
enable_ids_val=$(parse_yaml "enable_ids")

pcap=1
bag=1
enable_ids=1
topics="topics "$topics_val
[ "$pcap_val" = "true" ] && pcap=0
[ "$bag_val" = "true" ] && bag=0
[ "$enable_ids_val" = "true" ] && enable_ids=0
[ "$topics_val" = "" ] && topics=""

if [[ "$bag_args_val" == *"topics"*  ]]; then
    topics=""
    echo "Illegal: specify topic list inside topics, not inside the bag_args"
    exit 1
fi

if [[ "$bag_args_val" == *"-o "*  ]]; then
    topics=""
    echo "Illegal: specify bag output filename inside bag_name, not inside the bag_args"
    exit 1
fi

if [[ "$pcap_args_val" == *"-w "*  ]]; then
    topics=""
    echo "Illegal: specify pcap output filename inside pcap_name, not inside the pcap_args"
    exit 1
fi

bag_args=$bag_args_val

pcap_args=$pcap_args_val

bag_dir=$bag_dir_val

pcap_dir=$pcap_dir_val

## DEBUG
echo \""$pcap_val"\" $pcap
echo \""$bag_val"\" $bag
echo \""$bag_dir"\"
echo \""$pcap_dir"\"
echo \""$bag_args_val"\"
echo \""$topics_val"\"
echo \""$pcap_args_val"\"

## BAG AND PCAP DIRS INTEGRITY CHECKS
case $bag_dir in
    */);;
    *) bag_dir="$bag_dir/"
        ;;
esac

case $pcap_dir in
    */);;
    *) pcap_dir="$pcap_dir/"
        ;;
esac

if [[ ! -d "$bag_dir" ]]; then
    if [ "$(mkdir -p "$bag_dir")" ]; then
        echo "Error: unable to create \"$bag_dir\""
        exit
    else
        echo "Info: \"$bag_dir\" created as it didn't exist"
    fi
fi

if [[ ! -d "$pcap_dir" ]]; then
    if [ "$(mkdir -p "$pcap_dir")" ]; then
        echo "Error: unable to create \"$pcap_dir\""
        exit
    else
        echo "Info: \"$pcap_dir\" created as it didn't exist"
    fi
fi

## PROCESSING OUTPUT FILE NAMES
if [ $enable_ids -eq 0 ]; then
    bag_max_id=$(find "$bag_dir" -maxdepth 1 -type d -regex ".*_[0-9]+" -printf "%f\n" | sed -E 's/.*_([0-9]+)/\1/' | sort -r | head -n 1)
    pcap_max_id=$(find "$pcap_dir" -maxdepth 1 -regex ".*_[0-9]+\.pcap" -printf "%f\n" | sed -E 's/.*_([0-9]+).*/\1/' | sort -r | head -n 1)

    next_id=0
    [ "$bag_max_id" = "" ] && [ ! "$pcap_max_id" = "" ] && next_id=$pcap_max_id
    [ ! "$bag_max_id" = "" ] && [ "$pcap_max_id" = "" ] && next_id=$bag_max_id

    if [ ! "$pcap_max_id" = "" ] && [ ! "$bag_max_id" = "" ]; then
        if [ "$pcap_max_id" -gt "$bag_max_id" ]; then
            next_id=$pcap_max_id
        else
            next_id=$bag_max_id
        fi
    fi

    next_id=$((next_id + 1))
fi

timestamp=$(date -d "today" +"$date_format")


if [ "$pcap_ofile_name_raw" = "" ]; then
    pcap_ofile_name_arg=""
else
    pcap_ofile_name=${pcap_ofile_name_raw/TIMESTAMP/$timestamp}
    pcap_full_path="$pcap_dir/$pcap_ofile_name""_$next_id"".pcap"
    pcap_ofile_name_arg="-w ""$pcap_full_path"
fi


if [  "$bag_ofile_name_raw" = "" ]; then
    bag_ofile_name_arg=""
else
    bag_ofile_name=${bag_ofile_name_raw/TIMESTAMP/$timestamp}
    bag_full_path="$bag_dir/$bag_ofile_name""_$next_id"
    bag_ofile_name_arg="-o ""$bag_full_path"
fi

## CHECK AND DISPLAY DISK SPACE
echo
echo "Disk space:"
echo "$(df -h)"
echo

## ROSBAG AND TCPDUMP PID
pid_bag=""
pid_pcap=""
pcap_permission_granted=0

if [ "$pcap" -eq 0 ]; then
    # ASKING PERMISSION TO KEEP RECORDING THE PCAP FILE. ONLY NEEDED AFTER DISK SPACE CHECK AND IF PCAP: TRUE IN YAML FILE.
    
    read -p "Continue? [Y/N]: " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] || $confirm == [sS] || $confirm == [sS][iI] ]] || pcap_permission_granted=1

    if [ "$pcap_permission_granted" -eq 0 ]; then
        # important!!! keep tcpdump start before bag record, because of sudo not starting tcpdump until password is given
        # create a dummy process to get its pid
        tail -f /dev/null &
        # pid of the created process needed to create a random unique number 
        unique_number=$!
        # the unique name of the tcpdump process
            id_pcap="tcpdump""$unique_number""$EPOCHREALTIME"
        # to give a custom name to a process exec will be used
        # exec is a shell built-in so its not a executable
        # sudo can be used with executables only
        # so a bash is created with sudo to run the exec command to give a unique custom name to the tcpdump process
            sudo -b bash -c "exec -a $id_pcap tcpdump $pcap_args $pcap_ofile_name_arg < /dev/null &> \"${pcap_full_path}.log\""
        # array of pids of found processes with that unique name
            pids=($(pgrep -f "^$id_pcap"))
        # the dummy process is no longer needed
            kill $unique_number > /dev/null
        # check if there isn't only one occurrence
        pids_size=${#pids[@]}
        if [ "$pids_size" -eq 0 ]; then
            echo "error: pcap did not started, maybe pcap got bad arguments, see pcap.log"
            exit
        elif [ "$pids_size" -gt 1 ]; then
            echo "error: to many processes, cannot find pcap process, more processes have the same name"
            exit
        fi
        pid_pcap=${pids[0]}

        echo pcap started with pid "$pid_pcap"
    fi
    
fi

if [ "$bag" -eq 0 ]; then 
    ros2 bag record $bag_args $topics $bag_ofile_name_arg > "${bag_full_path}.log" 2>&1 &
    pid_bag=$! 
    echo bag started with pid "$pid_bag"
fi

## ROSBAG AND TCPDUMP PROCESSES KILLS

trap stop_record INT

## CHECK IF AT LEAST ONE PROCESS HAS STOPPED EXECUTING AND CHECK ITS EXIT CODE. TERMINATE THE OTHER IF NECESSARY.
if [ "$pcap" -eq 0 ] && [ "$pcap_permission_granted" -eq 0 ]; then
    tail --pid $pid_pcap -f /dev/null &
fi
pid_tail_check_pcap=$!
wait -n -p exited_pid

status=$?

if [ "$pcap" -eq 0 ] && [ "$pid_tail_check_pcap" = "$exited_pid" ] && [ "$pcap_permission_granted" -eq 0 ]; then
    if ps -p $pid_pcap > /dev/null; then
        echo "error: process that was checking for pcap process existence unexpectedly terminated"
        sudo kill $pid_pcap
    else
        echo "pcap terminated unexpectedly"
    fi
    if [ ! "$status" -eq 0 ]; then
        echo "error: pcap terminated with code $status"
    fi

    if [ "$bag" -eq 0 ]; then
        kill $pid_bag
    fi
fi

if [ "$bag" -eq 0 ] && [ "$pid_bag" = "$exited_pid" ]; then
    echo "bag terminated unexpectedly"
    if [ ! "$status" -eq 0 ]; then
        echo "error: bag record terminated with code $status"
    fi

    if [ "$pcap" -eq 0 ]; then
        sudo kill $pid_pcap
    fi
fi