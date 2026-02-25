$preset_filename="record.preset"
# leggi il file preset

# salva nelle variabili i contenuti del file


# VARIABILI
# variabile bool che decide se il pcap verrà registrato
$pcap
# variabile bool che decide se la bag verrà registrata
$bag
# variabile stringa che conteiene e parametri da dare al comando della bag
$bag_args
# variabile stringa che conteiene e parametri da dare al comando del pcap
$pcap_args
#
$topics



# componi i comandi grazie alle variabili
# esegui i comandi salvando realativi pid

# tcpdump
# ros2 bag record $bag_args --topics:$topics

# pid bag
$pid_bag
# pid pcap
$pid_pcap



# se viene premuto ctrl+c ferma le registrazioni

stop_record(){
    echo ""
    echo "stoping recording..."
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

trap stop_record SIGINT

wait
