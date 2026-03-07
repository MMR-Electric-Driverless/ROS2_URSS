preset_filename="record.yaml"

# salva nelle variabili i contenuti del file
pcap_grep_val=$(grep "pcap:" $preset_filename)
bag_grep_val=$(grep "bag:" $preset_filename)
bag_args_grep_val=$(grep "bag_args:" $preset_filename)
topics_grep_val=$(grep "topics:" $preset_filename)
pcap_args_grep_val=$(grep "pcap_args:" $preset_filename)

index=$(expr index "$pcap_grep_val" ": ")
length=$(expr length "$pcap_grep_val")
pcap_val=$(expr substr "$pcap_grep_val" $(($index+2)) $(($length-$index)))

index=$(expr index "$bag_grep_val" ": ")
length=$(expr length "$bag_grep_val")
bag_val=$(expr substr "$bag_grep_val" $(($index+2)) $(($length-$index)))

index=$(expr index "$bag_args_grep_val" ": ")
length=$(expr length "$bag_args_grep_val")
bag_args_val=$(expr substr "$bag_args_grep_val" $(($index+2)) $(($length-$index)))

index=$(expr index "$topics_grep_val" ": ")
length=$(expr length "$topics_grep_val")
topics_val=$(expr substr "$topics_grep_val" $(($index+2)) $(($length-$index)))

index=$(expr index "$pcap_args_grep_val" ": ")
length=$(expr length "$pcap_args_grep_val")
pcap_args_val=$(expr substr "$pcap_args_grep_val" $(($index+2)) $(($length-$index)))

# VARIABILI
# variabile bool che decide se il pcap verrà registrato
pcap=1
if [ "$pcap_val" = "true" ]; then
    pcap=0
fi

# variabile bool che decide se la bag verrà registrata
bag=1
if [ "$bag_val" = "true" ]; then
    bag=0
fi

#debug: dovrebbe stampare delle stringhe senza spazi iniziali.
echo \"$pcap_val\" $pcap
echo \"$bag_val\" $bag
echo \"$bag_args_val\"
echo \"$topics_val\"
echo \"$pcap_args_val\"
# variabile stringa che contiene i parametri da dare al comando della bag
bag_args=$bag_args_val
# variabile stringa che contiene i parametri da dare al comando del pcap
pcap_args=$pcap_args_val
# variabile stringa che contiene le topics della bag da registrare
topics=$topics_val


# present time  stamp
timestamp=$(date -d "today" +"%Y_%m_%d-%H_%M_%S")

# variable containing the pcap's raw output file name as is defined in the preset file
pcap_ofile_name_raw=$(./yaml-parser ${preset_filename} pcap_name | sed 's/\x1b\[[0-9;]*m//g')

if [ "$pcap_ofile_name_raw" = "null" ]; then
    # file name is not set so the argument is an empty string
    pcap_ofile_name_arg=""

else
    # the proccessed name of the output file
    pcap_ofile_name=${pcap_ofile_name_raw/TIMESTAMP/$timestamp}

    # the pcap's output file name as the argument to add to tcpdump
    pcap_ofile_name_arg="-w ${pcap_ofile_name}"
fi

# variable containing the bag's raw output file name as is defined in the preset file
bag_ofile_name_raw=$(./yaml-parser ${preset_filename} bag_name | sed 's/\x1b\[[0-9;]*m//g')

if [  "$bag_ofile_name_raw" = "null" ]; then
    # file name is not set so the argument is an empty string
    bag_ofile_name_arg=""

else
    # the proccessed name of the output file
    bag_ofile_name=${bag_ofile_name_raw/TIMESTAMP/$timestamp}

    # the bag's output file name as the argument to add to ros2 bag record
    bag_ofile_name_arg="-o "${bag_ofile_name}
fi


# componi i comandi grazie alle variabili
# esegui i comandi salvando realativi pid

pid_bag=""
pid_pcap=""

# tcpdump
if [ "$pcap" -eq 0 ]; then 
    tcpdump $pcap_args $pcap_ofile_name_arg > pcap.log 2>&1 &
    pid_pcap=$! 
    echo "pid_pcap=$pid_pcap" 
fi
# ros2 bag record $bag_args --topics:$topics
if [ "$bag" -eq 0 ]; then 
    ros2 bag record $bag_args $topics $bag_ofile_name_arg > bag.log 2>&1 &
    pid_bag=$! 
    echo "pid_bag=$pid_bag" 
fi

# pid bag
#pid_bag
# pid pcap
#pid_pcap



# se viene premuto ctrl+c ferma le registrazioni

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

wait
