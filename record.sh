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

# Yaml read function, gently borrowed by the following repository: https://github.com/PigneInTesta/yaml-parser . The main changes involve the formatting of
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

topics="topics "$topics_val
if [ "$topics_val" = "" ]; then
    topics=""
fi
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

## DEBUG
# echo \""$pcap_val"\" $pcap
# echo \""$bag_val"\" $bag
# echo \""$bag_args_val"\"
# echo \""$topics_val"\"
# echo \""$pcap_args_val"\"


## PROCESSING OUTPUT FILE NAMES
timestamp=$(date -d "today" +"$date_format")


if [ "$pcap_ofile_name_raw" = "" ]; then
    pcap_ofile_name_arg=""
else
    pcap_ofile_name=${pcap_ofile_name_raw/TIMESTAMP/$timestamp}
    pcap_ofile_name_arg="-w ""$pcap_ofile_name"
fi


if [  "$bag_ofile_name_raw" = "" ]; then
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
        echo "error: pcap did not started, maybe pcap got bad arguments, see pcap.log"
        exit
    elif [ "$pids_size" -gt 1 ]; then
        echo "error: to many processes, cannot find pcap process, more processes have the same name"
        exit
    fi
    pid_pcap=${pids[0]}

    echo pcap started with pid "$pid_pcap"
fi

if [ "$bag" -eq 0 ]; then 
    ros2 bag record $bag_args $topics $bag_ofile_name_arg > bag.log 2>&1 &
    pid_bag=$! 
    echo bag started with pid "$pid_bag"
fi

## ROSBAG AND TCPDUMP PROCESSES KILLS

trap stop_record INT

## CHECK IF AT LEAST ONE PROCESS HAS STOPPED EXECUTING AND CHECK ITS EXIT CODE. TERMINATE THE OTHER IF NECESSARY.
tail --pid $pid_pcap -f /dev/null &
pid_tail_check_pcap=$!
wait -n -p exited_pid

status=$?

if [ "$pcap" -eq 0 ] && [ "$pid_tail_check_pcap" = "$exited_pid" ]; then
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