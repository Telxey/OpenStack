#! /bin/bash

sudo netplan --debug generate

sleep 20

ip -br link show

sleep 5

sudo netplan get

sudo netplan apply

ip -br link show

ip -br addr show br-extvm

sleep 

ip -br addr show




