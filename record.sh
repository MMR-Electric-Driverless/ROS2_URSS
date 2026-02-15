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



# componi i comandi grazie alle variabili
# esegui i comandi salvando realativi pid

# tcpdump
# ros2 bag record $bag_args --topics:$topics

# pid bag
#pid_bag
# pid pcap
#pid_pcap



# se viene premuto ctrl+c ferma le registrazioni