$presete_filename="record.preset"
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