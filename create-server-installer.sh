#!/bin/bash
mkdir output
mkdir input/server/downloads
./download-installer.sh
./contrib/makeself.sh --follow --nox11 --nowait ./input/server ./output/server.run "Chef Server Setup" ./chef-server.sh

