#!/bin/bash

preset_filename="record.yaml"

if_null_then_empty_string(){
    if [ "$1" == "null" ]; then
        echo ""
    else
        echo "$1"
    fi
}

parse_yaml(){
    val=$(yaml-parser ${preset_filename} "$1" | sed 's/\x1b[[0-9;]*m//g')
    val=$(if_null_then_empty_string "$val")
    echo "$val"
}

## RECORD YAML PARSING
pcap_val=$(parse_yaml "pcap")
bag_val=$(parse_yaml "bag")
bag_args_val=$(parse_yaml "bag_args")
topics_val=$(parse_yaml "topics")
pcap_args_val=$(parse_yaml "pcap_args")
pcap_ofile_name_raw=$(parse_yaml "pcap_name")
bag_ofile_name_raw=$(parse_yaml "bag_name")
date_format=$(parse_yaml "date_format")

pcap=1
if [ "$pcap_val" = "true" ]; then
    pcap=0
fi


bag=1
if [ "$bag_val" = "true" ]; then
    bag=0
fi

bag_args=$bag_args_val

pcap_args=$pcap_args_val

topics=$topics_val


## DEBUG
# echo \""$pcap_val"\" $pcap
# echo \""$bag_val"\" $bag
# echo \""$bag_args_val"\"
# echo \""$topics_val"\"
# echo \""$pcap_args_val"\"


## PROCESSING OUTPUT FILE NAMES
timestamp=$(date -d "today" +"$date_format")


if [ "$pcap_ofile_name_raw" = "null" ]; then
    pcap_ofile_name_arg=""
else
    pcap_ofile_name=${pcap_ofile_name_raw/TIMESTAMP/$timestamp}
    pcap_ofile_name_arg="-w ""$pcap_ofile_name"
fi


if [  "$bag_ofile_name_raw" = "null" ]; then
    bag_ofile_name_arg=""
else
    bag_ofile_name=${bag_ofile_name_raw/TIMESTAMP/$timestamp}
    bag_ofile_name_arg="-o ""$bag_ofile_name"
fi

## ROSBAG AND TCPDUMP PID
pid_bag=""
pid_pcap=""

if [ "$pcap" -eq 0 ]; then
    # important!!! keep tcpdump start before bag record, because of sudo not starting tcpdump until password is given
    tail -f /dev/null &
    pid_tail=$!

    id_pcap="tcpdump""$pid_tail""$EPOCHREALTIME"

    sudo -b bash -c "exec -a $id_pcap tcpdump $pcap_args $pcap_ofile_name_arg < /dev/null &> pcap.log"

    pids=($(pgrep -f "^$id_pcap"))

    kill $pid_tail > /dev/null

    pids_size=${#pids[@]}
    if [ "$pids_size" -eq 0 ]; then
        echo "error: no proccesss found"
        exit
    elif [ "$pids_size" -gt 1 ]; then
        echo "error: to many proccess"
        exit
    fi
    pid_pcap=${pids[0]}

    echo "pid_pcap=""$pid_pcap"
fi

if [ "$bag" -eq 0 ]; then 
    ros2 bag record $bag_args $topics $bag_ofile_name_arg > bag.log 2>&1 &
    pid_bag=$! 
    echo "pid_bag=""$pid_bag" 
fi

## ROSBAG AND TCPDUMP PROCESSES KILLS
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

    if [ "$pcap" -eq 0 ] && sudo kill $pid_pcap > /dev/null 2>&1; then
        echo "pcap stopped"
    elif [ "$pcap" -ne 0 ]; then
        echo "pcap recording not started"
    else
        echo "pcap proccess not found"
    fi
    echo
    exit
}

trap stop_record INT

## CHECK IF AT LEAST ONE PROCESS HAS STOPPED EXECUTING AND CHECK ITS EXIT CODE. TERMINATE THE OTHER IF NECESSARY.
wait -n

status=$?

if [ "$pcap" -eq 0 ] && kill -0 $pid_pcap 2>/dev/null; then
    if [ ! "$status" -eq 0 ]; then
        echo "error: pcap terminated with code $status"
    fi

    if [ "$bag" -eq 0 ]; then
        kill $pid_bag
    fi
fi

if [ "$bag" -eq 0 ] && kill -0 $pid_bag 2>/dev/null; then
    if [ ! "$status" -eq 0 ]; then
        echo "error: bag record terminated with code $status"
    fi

    if [ "$pcap" -eq 0 ]; then
        kill $pid_pcap
    fi
fi