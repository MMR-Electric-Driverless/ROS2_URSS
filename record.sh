#!/bin/bash

preset_filename="record.yaml"


## RECORD YAML PARSING
pcap_val=$(yaml-parser ${preset_filename} "pcap" | sed 's/\x1b[[0-9;]*m//g')
bag_val=$(yaml-parser ${preset_filename} "bag" | sed 's/\x1b[[0-9;]*m//g')
bag_args_val=$(yaml-parser ${preset_filename} "bag_args" | sed 's/\x1b[[0-9;]*m//g')
topics_val=$(yaml-parser ${preset_filename} "topics" | sed 's/\x1b[[0-9;]*m//g')
pcap_args_val=$(yaml-parser ${preset_filename} "pcap_args" | sed 's/\x1b[[0-9;]*m//g')
pcap_ofile_name_raw=$(yaml-parser ${preset_filename} pcap_name | sed 's/\x1b[[0-9;]*m//g')
bag_ofile_name_raw=$(yaml-parser ${preset_filename} bag_name | sed 's/\x1b[[0-9;]*m//g')

date_format=$(yaml-parser ${preset_filename} date_format | sed 's/\x1b[[0-9;]*m//g')

pcap=1
echo "$pcap_val" = "true"
if [ "$pcap_val" = "true" ]; then
    pcap=0
fi


bag=1
if [ "$bag_val" = "true" ]; then
    bag=0
fi

## DEBUG
# echo \""$pcap_val"\" $pcap
# echo \""$bag_val"\" $bag
# echo \""$bag_args_val"\"
# echo \""$topics_val"\"
# echo \""$pcap_args_val"\"

# bag_args=$bag_args_val

# pcap_args=$pcap_args_val

# topics=$topics_val



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
    tcpdump $pcap_args $pcap_ofile_name_arg > pcap.log 2>&1 &
    pid_pcap=$! 
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

    if [ "$pcap" -eq 0 ] && kill $pid_pcap > /dev/null 2>&1; then
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