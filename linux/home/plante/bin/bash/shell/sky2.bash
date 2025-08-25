#!/bin/bash 

# create a file sky2.sh into: /lib/systemd/system-sleep/ folder with

modprobe -r sky2 # unload sky2 kernel module 
modprobe -i sky2 # reload sky2 kernel module 

# and change the permissions with:

# sudo chmod +x sky2.sh

