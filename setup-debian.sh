#!/bin/bash

############################################################
# core functions
############################################################

function force_install {
    executable=$1
    shift
    while [ -n "$1" ]
    do
        DEBIAN_FRONTEND=noninteractive apt-get -q -y install "$1"
        apt-get clean
        print_info "$1 installed for $executable"
        shift
    done
}

function check_install {
    if [ -z "`which "$1" 2>/dev/null`" ]
    then
        executable=$1
        shift
        while [ -n "$1" ]
        do
            DEBIAN_FRONTEND=noninteractive apt-get -q -y install "$1"
            apt-get clean
            print_info "$1 installed for $executable"
            shift
        done
    else
        print_warn "$2 already installed"
    fi
}

function check_remove {
    if [ -n "`which "$1" 2>/dev/null`" ]
    then
        DEBIAN_FRONTEND=noninteractive apt-get -q -y remove --purge "$2"
        apt-get clean
        print_info "$2 removed"
    else
        print_warn "$2 is not installed"
    fi
}

function check_sanity {
    # Do some sanity checking.
    if [ $(/usr/bin/id -u) != "0" ]
    then
        die 'Must be run by root user'
    fi

    if [ ! -f /etc/debian_version ]
    then
        die "Distribution is not supported"
    fi
}

function die {
    echo "ERROR: $1" > /dev/null 1>&2
    exit 1
}

function get_domain_name() {
    # Getting rid of the lowest part.
    domain=${1%.*}
    lowest=`expr "$domain" : '.*\.\([a-z][a-z]*\)'`
    case "$lowest" in
    com|net|org|gov|edu|co|me|info|name)
        domain=${domain%.*}
        ;;
    esac
    lowest=`expr "$domain" : '.*\.\([a-z][a-z]*\)'`
    [ -z "$lowest" ] && echo "$domain" || echo "$lowest"
}

function get_password() {
    # Check whether our local salt is present.
    SALT=/var/lib/radom_salt
    if [ ! -f "$SALT" ]
    then
        head -c 512 /dev/urandom > "$SALT"
        chmod 400 "$SALT"
    fi
    password=`(cat "$SALT"; echo $1) | md5sum | base64`
    echo ${password:0:13}
}

function print_info {
    echo -n -e '\e[1;36m'
    echo -n $1
    echo -e '\e[0m'
}

function print_warn {
    echo -n -e '\e[1;33m'
    echo -n $1
    echo -e '\e[0m'
}


############################################################
# applications
############################################################

function install_nano {
    check_install nano nano
}

function install_htop {
    check_install htop htop
}

function install_iotop {
    check_install iotop iotop
}

function install_jdk {
    check_install default-jdk default-jdk
}

function install_git {
    check_install git git
}

function install_sshd {
    check_install openssh-server openssh-server
    
    SSHD_CONFIG=/etc/ssh/sshd_config

    sed -i "s/#AuthorizedKeysFile/AuthorizedKeysFile/g" "$SSHD_CONFIG"
    
    sed -i "s/#PasswordAuthentication/PasswordAuthentication/g" "$SSHD_CONFIG"
    sed -i "s/PasswordAuthentication yes/PasswordAuthentication no/g" "$SSHD_CONFIG"

    sed -i "s/#PermitRootLogin/PermitRootLogin/g" "$SSHD_CONFIG"
    sed -i "s/PermitRootLogin yes/PermitRootLogin no/g" "$SSHD_CONFIG"
    
    service ssh reload
}

function config_hostname {
    echo "$1" >> "/etc/hostname"
    hostname "$1"
}

function install_zsh {
    check_install git git
    check_install zsh zsh
    chsh -s /bin/zsh "$1"
    su - "$1" -c "wget https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O - | sh"
    USER_DIR=$( getent passwd "$1" | cut -d: -f6 )
    cat > "$USER_DIR/.zshrc" <<END
export ZSH=\$HOME/.oh-my-zsh
ZSH_THEME="gentoo"
export UPDATE_ZSH_DAYS=90
plugins=(git)
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"
source \$ZSH/oh-my-zsh.sh
alias lg="log --graph --pretty=format:'%Cred%h%Creset - %C(bold blue)%an%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)' --abbrev-commit"
alias ll="ls -la"
export TERM=xterm-256color
END
    chown "$1" "$USER_DIR/.zshrc"
}


function add_user {
    check_install sudo sudo
    useradd "$1"
    mkdir -p "/home/$1/.ssh"
    mkdir -p "/home/$1/.i2p"
    chown -R $1 "/home/$1"
    echo "$1:$2" | chpasswd
    echo "$1 ALL=(ALL:ALL) ALL" >> /etc/sudoers
    echo "$3" >> "/home/$1/.ssh/authorized_keys"
}

function install_i2p {
    check_install git git
    check_install default-jdk default-jdk
    force_install gettext gettext
    check_install ant ant

    cd /opt
    USER_DIR=$( getent passwd "$1" | cut -d: -f6 )
    INSTALL_PATH="/opt/i2p"

    git clone https://github.com/i2p/i2p.i2p.git
    cd i2p.i2p
    git pull

    ant installer-linux
    mv i2pinstall*.jar i2pinstall.jar
    trap 'rm $CONFIG; exit' 0 1 2 15
    CONFIG=$(mktemp)
    echo INSTALL_PATH=$INSTALL_PATH > "$CONFIG"
    chmod 666 "$CONFIG"
    su "$1" -c "java -jar i2pinstall.jar -options $CONFIG"

    sed -ie "s/#wrapper.java.maxmemory=[0-9]*/wrapper.java.maxmemory=500/g" "$INSTALL_PATH/wrapper.config"
    sed -ie "s/#wrapper.java.maxmemory=[0-9]*/wrapper.java.maxmemory=900/g" "$INSTALL_PATH/wrapper.config"

    cp "$INSTALL_PATH/clients.config" "$USER_DIR/.i2p/clients.config"
    chown -R "$1" "/opt/i2p"
    chown -R "$1" "$USER_DIR"

    cat > "/home/$1/.i2p/router.config" <<END
i2np.bandwidth.inboundBurstKBytes=143000
i2np.bandwidth.inboundBurstKBytesPerSecond=7150
i2np.bandwidth.inboundKBytesPerSecond=6500
i2np.bandwidth.outboundBurstKBytes=143000
i2np.bandwidth.outboundBurstKBytesPerSecond=7150
i2np.bandwidth.outboundKBytesPerSecond=6500
i2np.ntcp.autoip=true
i2np.ntcp.autoport=false
i2np.ntcp.enable=true
i2np.ntcp.maxConnections=8000
i2np.ntcp.port=18887
i2np.udp.addressSources=local,upnp,ssu
i2np.udp.enable=true
i2np.udp.internalPort=18887
i2np.udp.maxConnections=8000
i2np.udp.port=18887
i2np.upnp.enable=true
router.floodfillParticipant=true
router.maxParticipatingTunnels=40000
router.minThrottleTunnels=40000
router.sharePercentage=100
router.updatePolicy=install
router.updateProxyHost=127.0.0.1
router.updateProxyPort=4444
router.updateThroughProxy=true
routerconsole.graphEvents=false
routerconsole.graphPeriods=131040
routerconsole.graphPersistent=true
stat.summaries=bw.recvRate.60000,bw.sendRate.60000,router.memoryUsed.60000,router.activePeers.60000,tunnel.participatingTunnels.60000
END

    cat > /etc/rc.local <<END
su ${1} -c "/opt/i2p/i2prouter start"
exit 0
END
    su "$1" -c "/opt/i2p/i2prouter start"
}

function install_iftop {
    check_install iftop iftop
    print_warn "Run IFCONFIG to find your net. device name"
    print_warn "Example usage: iftop -i venet0"
}


function remove_unneeded {
    # Some Debian have portmap installed. We don't need that.
    check_remove /sbin/portmap portmap
    
    # Remove rsyslogd, which allocates ~30MB privvmpages on an OpenVZ system,
    # which might make some low-end VPS inoperatable. We will do this even
    # before running apt-get update.
    check_remove /usr/sbin/rsyslogd rsyslog

    # Other packages that are quite common in standard OpenVZ templates.
    check_remove /usr/sbin/apache2 'apache2*'
    check_remove /usr/sbin/named 'bind9*'
    check_remove /usr/sbin/smbd 'samba*'
    check_remove /usr/sbin/nscd nscd
    check_remove /usr/sbin/postfix postfix

    # Need to stop sendmail as removing the package does not seem to stop it.
    if [ -f /usr/lib/sm.bin/smtpd ]
    then
        invoke-rc.d sendmail stop
        check_remove /usr/lib/sm.bin/smtpd 'sendmail*'
    fi
}

############################################################
# Download ps_mem.py
############################################################
function install_ps_mem {
    wget http://www.pixelbeat.org/scripts/ps_mem.py -O ~/ps_mem.py
    chmod 700 ~/ps_mem.py
    print_info "ps_mem.py has been setup successfully"
    print_warn "Use ~/ps_mem.py to execute"
}

############################################################
# Update apt sources (Ubuntu only; not yet supported for debian)
############################################################
function update_apt_sources {
    codename=`lsb_release --codename | cut -f2`

    if [ "$codename" == "" ]
    then
        die "Unknown Ubuntu flavor $codename"
    fi

    cat > /etc/apt/sources.list <<END
## main & restricted repositories
deb http://us.archive.ubuntu.com/ubuntu/ $codename main restricted
deb-src http://us.archive.ubuntu.com/ubuntu/ $codename main restricted

deb http://security.ubuntu.com/ubuntu $codename-updates main restricted
deb-src http://security.ubuntu.com/ubuntu $codename-updates main restricted

deb http://security.ubuntu.com/ubuntu $codename-security main restricted
deb-src http://security.ubuntu.com/ubuntu $codename-security main restricted

## universe repositories - uncomment to enable
deb http://us.archive.ubuntu.com/ubuntu/ $codename universe
deb-src http://us.archive.ubuntu.com/ubuntu/ $codename universe

deb http://us.archive.ubuntu.com/ubuntu/ $codename-updates universe
deb-src http://us.archive.ubuntu.com/ubuntu/ $codename-updates universe

deb http://security.ubuntu.com/ubuntu $codename-security universe
deb-src http://security.ubuntu.com/ubuntu $codename-security universe
END

    print_info "/etc/apt/sources.list updated for "$codename
}

############################################################
# Install vzfree (OpenVZ containers only)
############################################################
function install_vzfree {
    print_warn "build-essential package is now being installed which will take additional diskspace"
    check_install build-essential build-essential
    cd ~
    wget https://github.com/lowendbox/vzfree/archive/master.zip -O vzfree.zip
    unzip vzfree.zip
    cd vzfree-master
    make && make install
    cd ..
    vzfree
    print_info "vzfree has been installed"
    rm -fr vzfree-master vzfree.zip
}


############################################################
# Configure MOTD at login
############################################################
function configure_motd {
    apt_clean_all
    update_upgrade
    check_install landscape-common landscape-common
    dpkg-reconfigure landscape-common
}

############################################################
# Classic Disk I/O and Network speed tests
############################################################
function runtests {
    print_info "Classic I/O test"
    print_info "dd if=/dev/zero of=iotest bs=64k count=16k conv=fdatasync && rm -fr iotest"
    dd if=/dev/zero of=iotest bs=64k count=16k conv=fdatasync && rm -fr iotest

    print_info "Network test"
    print_info "wget cachefly.cachefly.net/100mb.test -O 100mb.test && rm -fr 100mb.test"
    wget cachefly.cachefly.net/100mb.test -O 100mb.test && rm -fr 100mb.test
}

############################################################
# Print OS summary (OS, ARCH, VERSION)
############################################################
function show_os_arch_version {
    # Thanks for Mikel (http://unix.stackexchange.com/users/3169/mikel) for the code sample which was later modified a bit
    # http://unix.stackexchange.com/questions/6345/how-can-i-get-distribution-name-and-version-number-in-a-simple-shell-script
    ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')

    if [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VERSION=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        # Work on Debian and Ubuntu alike
        OS=$(lsb_release -si)
        VERSION=$(lsb_release -sr)
    elif [ -f /etc/redhat-release ]; then
        # Add code for Red Hat and CentOS here
        OS=Redhat
        VERSION=$(uname -r)
    else
        # Pretty old OS? fallback to compatibility mode
        OS=$(uname -s)
        VERSION=$(uname -r)
    fi

    OS_SUMMARY=$OS
    OS_SUMMARY+=" "
    OS_SUMMARY+=$VERSION
    OS_SUMMARY+=" "
    OS_SUMMARY+=$ARCH
    OS_SUMMARY+="bit"

    print_info "$OS_SUMMARY"
}

############################################################
# Fix locale for OpenVZ Ubuntu templates
############################################################
function fix_locale {
    check_install multipath-tools multipath-tools
    export LANGUAGE=en_US.UTF-8
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8

    # Generate locale
    locale-gen en_US.UTF-8
    dpkg-reconfigure locales
}

function apt_clean {
    apt-get -q -y autoclean
    apt-get -q -y clean
}

function update_upgrade {
    # Run through the apt-get update/upgrade first.
    # This should be done before we try to install any package
    apt-get -q -y update
    apt-get -q -y upgrade

    # also remove the orphaned stuff
    apt-get -q -y autoremove
}

function update_timezone {
    dpkg-reconfigure tzdata
}


######################################################################## 
# START OF PROGRAM
########################################################################
export PATH=/bin:/usr/bin:/sbin:/usr/sbin

check_sanity
case "$1" in
ps_mem)
    install_ps_mem
    ;;
apt)
    update_apt_sources
    ;;
vzfree)
    install_vzfree
    ;;
motd)
    configure_motd
    ;;
locale)
    fix_locale
    ;;
test)
    runtests
    ;;
info)
    show_os_arch_version
    ;;
system)
    fix_locale
    remove_unneeded
    update_upgrade
    
    add_user $3 $4 $5
    config_hostname $2

    install_sshd
    install_git
    install_zsh root
    install_zsh $3
    install_jdk
    install_i2p $3
    install_nano
    install_htop
    install_iotop
    install_iftop
    
    apt_clean
    ;;
*)
    show_os_arch_version
    echo '  '
    echo 'Usage:' `basename $0` '[option] [argument]'
    echo 'Available options (in recomended order):'
    echo '  - system [hostname] [user] [pass] [ssh_pub_key] (remove unneeded, upgrade system, install software)'
    echo '  '
    echo '... and now some extras'
    echo '  - info                   (Displays information about the OS, ARCH and VERSION)'
    echo '  - apt                    (update sources.list for UBUNTU only)'
    echo '  - ps_mem                 (Download the handy python script to report memory usage)'
    echo '  - vzfree                 (Install vzfree for correct memory reporting on OpenVZ VPS)'
    echo '  - motd                   (Configures and enables the default MOTD)'
    echo '  - locale                 (Fix locales issue with OpenVZ Ubuntu templates)'
    echo '  - test                   (Run the classic disk IO and classic cachefly network test)'
    echo '  '
    ;;
esac
