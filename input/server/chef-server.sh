#!/bin/bash

USEHTTPPROXY=1
HTTPPROXYHOST=proxy.ir.intel.com
HTTPPROXYPORT=911

NOPROXY=localhost,intel.com

CHEF=https://opscode-omnibus-packages.s3.amazonaws.com/el/6/x86_64/chef-11.12.8-1.el6.x86_64.rpm
CHEFSERVER=https://opscode-omnibus-packages.s3.amazonaws.com/el/6/x86_64/chef-server-11.1.3-1.el6.x86_64.rpm

LOGFILE=/root/chef_install_log
CHEFSERVERHOSTNAME=`hostname -f`
DOWNLOADDIR=downloads

CHEFUSER=tester
CHEFPASS=tester


#=== FUNCTION =========================================================================
# NAME: preparelog
# DESCRIPTION: prepares log file
#======================================================================================

function preparelog()
{
	if [ ! -f "$LOGFILE" ]; then
		touch $LOGFILE
	fi
	
	echo "Begin" > $LOGFILE
}


#=== FUNCTION =========================================================================
# NAME: log
# DESCRIPTION: logs to file
#======================================================================================

function log()
{
	echo $1 >> $LOGFILE
}


#=== FUNCTION =========================================================================
# NAME: logverbose
# DESCRIPTION: logs to file and prints to screen
#======================================================================================

function logverbose()
{
	echo $1
	log $1
}


#=== FUNCTION =========================================================================
# NAME: configurehttpProxy
# DESCRIPTION: Configures http proxy for curl and wget
#======================================================================================

function configureHttpProxy()
{
	if [ "$USEHTTPPROXY" -eq "1" ]; then
		logverbose "Configuring http proxy..."
		
		export http_proxy=http://$HTTPPROXYHOST:$HTTPPROXYPORT
		export https_proxy=$http_proxy
		export HTTP_PROXY=$http_proxy
		export HTTPS_PROXY=$http_proxy
		export no_proxy=$NOPROXY
		export NO_PROXY=$NOPROXY
	fi
}


#=== FUNCTION =========================================================================
# NAME: download
# DESCRIPTION: downloads files via tool
# PARAMETER 1: file to download
#======================================================================================

function download()
{
	which curl > /dev/null 2>&1
	
	logverbose "Downloading $1..."
	
    if [ -f $DOWNLOADDIR/`basename $1` ]; then
        return 0
    fi

	if [ "$?" -eq "0" ]; then
		curl -o $DOWNLOADDIR/`basename $1` $1 >> $LOGFILE 2>&1
		
		if [ "$?" -eq "0" ]; then
			return 0
		fi
	fi
	
	which wget > /dev/null 2>&1
	
	if [ "$?" -eq "0" ]; then
		wget -O $DOWNLOADDIR/`basename $1` $1 >> $LOGFILE 2>&1
		
		if [ "$?" -eq "0" ]; then
			return 0
		fi
	fi
	
	return 1
}
 
 
#=== FUNCTION =========================================================================
# NAME: installRpm
# DESCRIPTION: installs rpms 
# PARAMETER 1: the rpm file
#======================================================================================

function installRpm()
{
	echo "Installing rpm $DOWNLOADDIR/$1..."
	
	rpm -i $DOWNLOADDIR/$1 >> $LOGFILE 2>&1
		
	return $?
}


#=== FUNCTION =========================================================================
# NAME: install
# DESCRIPTION: installs package via yum 
# PARAMETER 1: the package to install
#======================================================================================

function install()
{
	echo "Installing $1..."
	
	yum -y install $1 >> $LOGFILE 2>&1
		
	return $?
}


#=== FUNCTION =========================================================================
# NAME: configureChef
# DESCRIPTION: Configures chef
#======================================================================================

function configureChef()
{
	echo "Configuring chef..."
	
	chef-server-ctl reconfigure >> $LOGFILE 2>&1
    chef-server-ctl reconfigure >> $LOGFILE 2>&1

	chef-server-ctl restart >> $LOGFILE 2>&1
	chef-server-ctl test >> $LOGFILE 2>&1
	
	INSTALLDIR=`pwd`
	
	cd /root
	
	cp -fv $INSTALLDIR/id_rsa /root/.ssh/ >> $LOGFILE 2>&1
	cp -fv $INSTALLDIR/id_rsa.pub /root/.ssh/ >> $LOGFILE 2>&1
	
	chmod 600 /root/.ssh/* >> $LOGFILE 2>&1
	
	git config --global user.name "root"
	git config --global user.email root@$CHEFSERVERHOSTNAME
	
	echo -e "Host github.intel.com\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config
	git clone git@github.intel.com:CSIG-NOS/CSIG-SW-SDN-NOS-CHEF-REPO.git chef-repo >> $LOGFILE 2>&1
		
    cd chef-repo

	EXPECT=`which expect`
    CHEFREPO=`pwd`
    mkdir -vp .chef >> $LOGFILE 2>&1
	
	echo "Configuring knife..."
	echo ""
	sed -i s:EXPECT:$EXPECT:g $INSTALLDIR/knife-setup
	sed -i s:CHEFREPO:$CHEFREPO:g $INSTALLDIR/knife-setup
	sed -i s:CHEFSERVERHOSTNAME:$CHEFSERVERHOSTNAME:g $INSTALLDIR/knife-setup
	sed -i s:CHEFUSER:$CHEFUSER:g $INSTALLDIR/knife-setup
	sed -i s:CHEFPASS:$CHEFPASS:g $INSTALLDIR/knife-setup
	
    $INSTALLDIR/knife-setup >> $LOGFILE 2>&1

    cp $CHEFREPO/.chef/knife.rb $CHEFREPO/.chef/knife-proxy.rb >> $LOGFILE 2>&1

    echo "local_mode                                true                   " >> $CHEFREPO/.chef/knife-proxy.rb
    echo "http_proxy               \"http://$HTTPPROXYHOST:$HTTPPROXYPORT\"" >> $CHEFREPO/.chef/knife-proxy.rb
    echo "https_proxy              \"http://$HTTPPROXYHOST:$HTTPPROXYPORT\"" >> $CHEFREPO/.chef/knife-proxy.rb
    echo "require 'rest-client'                                            " >> $CHEFREPO/.chef/knife-proxy.rb
    echo "RestClient.proxy = \"http://$HTTPPROXYHOST:$HTTPPROXYPORT\"      " >> $CHEFREPO/.chef/knife-proxy.rb
    echo "Ohai::Config[:disabled_plugins] = [:Passwd]                      " >> $CHEFREPO/.chef/knife-proxy.rb
    
    sed -i s:CHEFSERVERHOSTNAME:$CHEFSERVERHOSTNAME:g $CHEFREPO/.chef/bootstrap/nosclient.erb

	echo "Bootstrap client via:"
    echo ""
    echo "    knife bootstrap IP --distro \"nosclient\" --environment \"sie_lab|or_lab\""
    echo ""
    echo "Install packages from supermarket:";
    echo ""
    echo "    knife cookbook site install PKG -c ./.chef/knife-proxy.rb"
	echo ""
}


#=== FUNCTION =========================================================================
# NAME: main
# DESCRIPTION: main function
#======================================================================================
 
function main()
{
	preparelog
	
	if [ "$(id -u)" != "0" ]; then
		logverbose "Please run this script as root"
		exit 1
	fi 
	
	configureHttpProxy
	
	install git 
	install wget
	install curl
	install socat
    install expect
    install httpd

    sed -i 's:Listen 80:Listen 8080:g' /etc/httpd/conf/httpd.conf
    chkconfig httpd on
    /etc/init.d/httpd restart

    mkdir -vp $DOWNLOADDIR

	download $CHEFSERVER
	if [ "$?" -eq "0" ]; then
		rpm=`basename $CHEFSERVER`
		installRpm $rpm
		res2=$?
	else
		logverbose "Problem downloading chef server"
	fi
	
	download $CHEF
	if [ "$?" -eq "0" ]; then
		rpm=`basename $CHEF`
		installRpm $rpm
        res1=$?
        cp -rv $DOWNLOADDIR/$rpm /var/www/html/ >> $LOGFILE 2>&1
        chmod 666 /var/www/html/$rpm
        chown apache:apache /var/www/html/$rpm
	else
		logverbose "Problem downloading chef workstation"
	fi
	
	if [[ "$res1" -eq "0" && "$res2" -eq "0" ]]; then
		configureChef
	else
		logverbose "Problem installing server/workstation.  Check log: $LOGFILE"
	fi
	
}

main
