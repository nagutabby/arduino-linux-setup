#!/bin/bash
# arduino-linux-setup.sh : A simple Arduino setup script for Linux systems
# Copyright (C) 2015 Arduino Srl
#
# Author : Arturo Rinaldi
# E-mail : arty.net2@gmail.com
# Project URL : https://github.com/artynet/arduino-linux-setup
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Release v15 changelog :
#
#   + Fixed the bug that can't uninstall ModemManager and install uucp in openSUSE
#
# Release v14 changelog :
#
#   + Installing uucp package for different Linux distros
#   + Rewriting UDEV rule for STM32 bootloader mode
#
# Release v13 changelog :
#
#   + Disabling serial port HW flow
#
# Release v12 changelog :
#
#   + Improving rules for DFU mode
#
# Release v11 changelog :
#
#   + Fixing ModemManager removal for Fedora Core
#   + Adding Atmel ICE Debugger CMSIS-DAP rule
#
# Release v10 changelog :
#
#   + Adding support for Slackware
#   + Changed distribution not supported message
#   + Changed distribution check sort order (thanks to thenktor @github.com)
#   + Small fix for ArchLinux
#
# Release v9 changelog :
#
#   + Adding support for ArchLinux
#   + Adding support for systemd
#   + Fixing a couple of wrong kernel entries
#
# Release v8 changelog :
#
#   + rules are now created in /tmp folder
#
# Release v7 changelog :
#
#	+ Adding project URL
#	+ minor bugfixing
#
# Release v6 changelog :
#
#	+ removing sudocheck function and control
#
# Release v5 changelog :
#
#	+ adding UDEV rule for stm32 DFU mode
#
# Release v4 changelog :
#
#	+ The rules are generated in a temporary folder
#
#	+ the user should run it without sudo while having its permissions
#
# Release v3 changelog :
#
#	+ The most common linux distros are now fully supported
#
#	+ now the script checks for SUDO permissions
#

#!/bin/bash

# if [[ $EUID != 0 ]] ; then
#   echo This must be run as root!
#   exit 1
# fi

refreshudev () {

    echo ""
    echo "Restarting udev"
    echo ""

    sudo udevadm control --reload-rules
    sudo udevadm trigger

    if [ -d /lib/systemd/ ]
    then
        sudo systemctl restart systemd-udevd
    else
        sudo service udev restart
    fi

}

groupsfunc () {

    echo ""
    echo "******* Add User to dialout,tty, uucp, plugdev groups *******"
    echo ""

    sudo groupadd tty
    sudo groupadd dialout
    sudo groupadd uucp
    sudo groupadd plugdev

    sudo usermod -a -G tty $1
    sudo usermod -a -G dialout $1
    sudo usermod -a -G uucp $1
    sudo usermod -a -G plugdev $1

}

acmrules () {

    echo ""
    echo "# Setting serial port rules"
    echo ""

cat <<EOF
KERNEL=="ttyUSB[0-9]*", TAG+="udev-acl", TAG+="uaccess", OWNER="$1"
KERNEL=="ttyACM[0-9]*", TAG+="udev-acl", TAG+="uaccess", OWNER="$1"
EOF

}

openocdrules () {

    echo ""
    echo "# Adding Arduino M0/M0 Pro, Primo, Atmel ICE Debugger UDEV Rules for CMSIS-DAP port"
    echo ""

cat <<EOF
ACTION!="add|change", GOTO="openocd_rules_end"
SUBSYSTEM!="usb|tty|hidraw", GOTO="openocd_rules_end"

#Please keep this list sorted by VID:PID

#Atmel ICE Debugger
ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="2141", MODE="664", GROUP="plugdev", TAG+="uaccess"

#CMSIS-DAP compatible adapters
ATTRS{product}=="*CMSIS-DAP*", MODE="664", GROUP="plugdev"

LABEL="openocd_rules_end"
EOF

}

avrisprules () {

    echo ""
    echo "# Adding AVRisp UDEV rules"
    echo ""

cat <<EOF
SUBSYSTEM!="usb_device", ACTION!="add", GOTO="avrisp_end"
# Atmel Corp. JTAG ICE mkII
ATTR{idVendor}=="03eb", ATTRS{idProduct}=="2103", MODE="660", GROUP="dialout"
# Atmel Corp. AVRISP mkII
ATTR{idVendor}=="03eb", ATTRS{idProduct}=="2104", MODE="660", GROUP="dialout"
# Atmel Corp. Dragon
ATTR{idVendor}=="03eb", ATTRS{idProduct}=="2107", MODE="660", GROUP="dialout"

LABEL="avrisp_end"
EOF

}

dfustm32rules () {

    echo ""
    echo "# Adding STM32 bootloader mode UDEV rules"
    echo ""

cat <<EOF
# Example udev rules (usually placed in /etc/udev/rules.d)
# Makes STM32 DfuSe device writeable for the "plugdev" group

# STM32
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE="664", GROUP="plugdev", TAG+="uaccess"

# GD32VF103
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="28e9", ATTRS{idProduct}=="0189", MODE="664", GROUP="plugdev", TAG+="uaccess"

# On older systems, a user group like "plugdev" can be given access:
# ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE="664", GROUP="plugdev"
EOF

}

dfuarduino101rules (){

    echo ""
    echo "# Arduino 101 in DFU Mode"
    echo ""

cat <<EOF
SUBSYSTEM=="tty", ENV{ID_REVISION}=="8087", ENV{ID_MODEL_ID}=="0ab6", MODE="0666", ENV{ID_MM_DEVICE_IGNORE}="1", ENV{ID_MM_CANDIDATE}="0"
SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0aba", MODE="0666", ENV{ID_MM_DEVICE_IGNORE}="1"
EOF

}

usbgenericrules (){

    echo ""
    echo "# Arduino Generic USB rules"
    echo ""

cat <<EOF
SUBSYSTEM=="usb", MODE="0660", GROUP="$(id -gn)"
EOF

}

hardwareflowdisable (){

    echo ""
    echo "# Disabling Hardware Control Flow on Serial"
    echo "#"
    echo "# https://access.redhat.com/solutions/209663"
    echo ""

cat <<EOF
#
# port		This file defines the possible dialout ports you have
#		on your system. Normally you have only one, and it's
#		most probably /dev/ttyS[0-3]. Define that port here.
#
#		If you have multiple dialout ports, you can ofcourse
#		define them all if you want.
#
port ACU
type modem
#
# NOTE: Make SURE this device is owned by root:dialout, mode 0660 (crw-rw---)
#
device /dev/ttyS3
dialer hayes
speed 57600

#
# Description for the TCP port - pretty trivial. DON'T DELETE.
#
port TCP
type tcp

# Everything after a '#' character is a comment.
port ttyACM0        # Port name
type direct         # Direct connection to other system
device /dev/ttyACM0 # Port device node
hardflow false      # No hardware flow control
speed 115200        # Line speed
EOF

}

removemm () {

    echo ""
    echo "******* Removing modem manager *******"
    echo ""

    if [ -f /etc/os-release ] && [[ $(sed -En 's/^NAME="(.*)"/\1/gp' /etc/os-release) =~ openSUSE ]]
    then
        #Only for openSUSE
        sudo zypper remove -y ModemManager
    elif [ -f /etc/fedora-release ] || [ -f /etc/redhat-release ]
    then
        #Only for Red Hat/Fedora/CentOS
        sudo rpm -e --nodeps ModemManager
        sudo rpm -e --nodeps ModemManager-glib
    elif [ -f /etc/arch-release ]
    then
        #Only for ArchLinux
        sudo pacman -Rdd modemmanager
    elif [ -f /etc/slackware-version ]
    then
        #Only for Slackware
        sudo removepkg ModemManager
    elif [ -f /etc/lsb-release ] || [ -f /etc/debian_version ] || [ -f /etc/linuxmint/info ]
    then
        #Only for Ubuntu/Mint/Debian
        sudo apt-get -y purge modemmanager
    else
        echo ""
        echo "Your system is not supported, please remove the ModemManager package with your package manager!"
        echo ""
    fi

}

adduucp () {

    echo ""
    echo "******* UUCP *******"
    echo ""

    if [ -f /etc/os-release ] && [[ $(sed -En 's/^NAME="(.*)"/\1/gp' /etc/os-release) =~ openSUSE ]]
    then
        #Only for openSUSE
        sudo zypper update -y && sudo zypper in -y -n uucp
    elif [ -f /etc/fedora-release ] || [ -f /etc/redhat-release ]
    then
        #Only for Red Hat/Fedora/CentOS
				sudo yum update -y && sudo yum install -y uucp
    elif [ -f /etc/arch-release ]
    then
        #Only for ArchLinux
        yes | sudo pacman -Sy uucp
    elif [ -f /etc/slackware-version ]
    then
        #Only for Slackware
        sudo slackpkg update && yes | sudo slackpkg install uucp
    elif [ -f /etc/lsb-release ] || [ -f /etc/debian_version ] || [ -f /etc/linuxmint/info ]
    then
        #Only for Ubuntu/Mint/Debian
        sudo apt-get update && sudo apt install -y uucp
    else
        echo ""
        echo "Your system is not supported, please remove the ModemManager package with your package manager!"
        echo ""
    fi

}

if [ "$1" = "" ]
then
    echo ""
    echo "Run the script with command ./arduino-linux-setup.sh \$USER"
    echo ""
else

    [ `whoami` != $1 ] && echo "" && echo "The user name is not the right one, please double-check it !" && echo "" && exit 1

    groupsfunc $1

    adduucp

    removemm

    acmrules $1 > /tmp/90-extraacl.rules

    openocdrules > /tmp/98-openocd.rules

    avrisprules > /tmp/avrisp.rules

    dfustm32rules > /tmp/40-dfuse.rules

    dfuarduino101rules > /tmp/99-arduino-101.rules

    usbgenericrules > /tmp/00-usb-permissions.rules

    hardwareflowdisable > /tmp/uucp-port

    sudo mv /tmp/*.rules /etc/udev/rules.d/

    sudo mv /tmp/uucp-port /etc/uucp/port

    refreshudev

    echo ""
    echo "*********** Please Reboot your system ************"
    echo ""
fi
