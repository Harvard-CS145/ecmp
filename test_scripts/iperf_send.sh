#!/bin/bash

USER_HOME=/home/p4

rm -rf tcpdump_logs
mkdir tcpdump_logs

for i in {1..8}
do
if [ "$1" -eq 1 ];
then
    tcpdump -enn -i a$i-eth1 > tcpdump_logs/log${i}_1.output 2> /dev/null &
    tcpdump -enn -i a$i-eth2 > tcpdump_logs/log${i}_2.output 2> /dev/null &
else
    tcpdump -enn -i a$i-eth3 > tcpdump_logs/log${i}_1.output 2> /dev/null &
    tcpdump -enn -i a$i-eth4 > tcpdump_logs/log${i}_2.output 2> /dev/null &
fi
done

count=0
for server in {1..16}
do
    port=5000
    for client in {1..16}
    do
        if [ "$server" -ne "$client" ]
        then
            count=$(($count+1))
            printf "\r%.3f%%" "$(bc -l <<< "(($count*100/240))")"
            port=$(($port+1))
            $USER_HOME/mininet/util/m h$server iperf3 -s --port $port 2> /dev/null > /dev/null &
            sleep 0.5
            $USER_HOME/mininet/util/m h$client iperf3 -c 10.0.0.$server -t 0.1 --port $port 2> /dev/null > /dev/null &
            sleep 0.5
            pkill iperf3
        fi
    done
done

pkill tcpdump
echo
