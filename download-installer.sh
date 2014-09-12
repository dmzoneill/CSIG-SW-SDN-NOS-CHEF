#!/bin/bash
if [ ! -f input/server/downloads/chef-11.12.8-1.el6.x86_64.rpm ]; then
    wget --no-check-certificate -O input/server/downloads/chef-11.12.8-1.el6.x86_64.rpm https://opscode-omnibus-packages.s3.amazonaws.com/el/6/x86_64/chef-11.12.8-1.el6.x86_64.rpm
fi 

if [ ! -f input/server/downloads/chef-server-11.1.3-1.el6.x86_64.rpm ]; then
    wget --no-check-certificate -O input/server/downloads/chef-server-11.1.3-1.el6.x86_64.rpm https://opscode-omnibus-packages.s3.amazonaws.com/el/6/x86_64/chef-server-11.1.3-1.el6.x86_64.rpm 
fi

