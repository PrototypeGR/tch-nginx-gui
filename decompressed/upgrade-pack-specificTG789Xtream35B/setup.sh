#!/bin/sh

move_files_and_clean(){
  for file in $(find "$1"*/ -xdev | cut -d '/' -f4-); do
    if [[ -d "$1$file" && ! -d "/$file" ]]; then
			mkdir "/$file"
			continue
		fi
    echo mv "$1$file" "/$file"
    [ ! -d "$1$file" ] && mv "$1$file" "/$file"

  done
  rm -rf "$1"
}
move_files_and_clean /tmp/upgrade-pack-specificTG789Xtream35B/

#needed to fix opkg update from https feed
opkg install /tmp/wget_1.17.1-1_brcm63xx-tch.ipk
rm /tmp/wget_1.17.1-1_brcm63xx-tch.ipk

if [ ! -f /etc/config/telnet ]; then
  touch /etc/config/telnet
  uci set telnet.general=telnet
  uci set telnet.general.enable='0'
  uci commit telnet
fi

if [ -f /bin/busybox_telnet ] && [ ! -f /usr/sbin/telnetd ]; then
  ln -s /bin/busybox_telnet /usr/sbin/telnetd
fi

if [ ! -f /etc/init.d/telnet ]; then
  ln -s /etc/init.d/telnetd /etc/init.d/telnet
fi
