#!/bin/sh

LIGHT_RED='\033[1;31m'
NC='\033[0m'

echo -e "${LIGHT_RED}

 █████╗ ███╗   ██╗███████╗██╗   ██╗███████╗██╗     
██╔══██╗████╗  ██║██╔════╝██║   ██║██╔════╝██║     
███████║██╔██╗ ██║███████╗██║   ██║█████╗  ██║     
██╔══██║██║╚██╗██║╚════██║██║   ██║██╔══╝  ██║     
██║  ██║██║ ╚████║███████║╚██████╔╝███████╗███████╗
╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚══════╝╚══════╝
(Modified Gui UpgradeScript)               (Christo)
${NC}
"

wget=/usr/bin/wget
bzcat=/usr/bin/bzcat
tar=/bin/tar

if [ "$1" ]; then
	if [ $1 == "SetTime" ]; then
		hour=$(uci get env.var.autoupgrade_hour)
		autoupgrade=$(uci get env.var.autoupgrade)
		if [ $autoupgrade == "1" ]; then
			if [ "$(cat /etc/crontabs/root | grep upgradegui )" ]; then
				sed -i '/upgradegui/d' /etc/crontabs/root
			fi
			echo "* "$hour" * * * /usr/share/transformer/scripts/upgradegui.sh AutoUpgrade" >> /etc/crontabs/root
		else
			if [ "$(cat /etc/crontabs/root | grep upgradegui )" ]; then
				sed -i '/upgradegui/d' /etc/crontabs/root
			fi
		fi
		exit 0
	fi	
	
	if [ $1 == "AutoUpgrade" ]; then
		/usr/share/transformer/scripts/checkver.sh
		if [ $(uci get env.var.outdated_ver) == "0" ]; then
			logger -s -t "Upgrade Script" "Already at latest version. Abort upgrade."
			exit 0
		fi
	fi
fi

# Check update_branch
if [ ! $(uci get -q env.var.update_branch) ] ||  [ $(uci get env.var.update_branch) == "stable" ]; then
	update_branch=""
else
	update_branch="_dev"
fi

WORKING_DIR="/tmp"
PERMANENT_STORE_DIR="/root"
TARGET_DIR="/"
FILE_NAME='GUI'$update_branch'.tar.bz2'
URL_BASE="https://repository.ilpuntotecnicoeadsl.com/files/Ansuel/AGTEF"
CHECKSUM_FILE="version"

if [ ! -f $WORKING_DIR/$FILE_NAME ]; then #Check if file exist as offline upload is now present
	logger -s -t "Upgrade Script" "Downloading GUI file..."
	# Enter /tmp folder
	if ! cd "$WORKING_DIR"; then
	logger -s -t "Upgrade Script" "ERROR: can't access $WORKING_DIR" >&2
	exit 1
	fi
	
	# Clean older GUI archive if present
	for file in "$WORKING_DIR"/*; do
	rm -f "$FILE_NAME"*
	done
	
	# Download new GUI to /tmp
	if ! $wget -q $URL_BASE/$FILE_NAME; then
	logger -s -t "Upgrade Script" "ERROR: can't find new GUI file" >&2
	exit 1
	fi
	
	# Check GUI hash
	if [ -f /tmp/$CHECKSUM_FILE ]; then
		rm $WORKING_DIR/$CHECKSUM_FILE
	fi
	$wget -q $URL_BASE/$CHECKSUM_FILE
	if ! grep -q $(md5sum $WORKING_DIR/$FILE_NAME | awk '{print $1}') $WORKING_DIR/$CHECKSUM_FILE ; then
	logger -s -t "Upgrade Script" "ERROR: file corrupted" >&2
	exit 1
	fi
else
	logger -s -t "Upgrade Script" "Found file in /tmp dir... Except offline upgrade!"
fi

logger -s -t "Upgrade Script" "Stopping nginx..."
/etc/init.d/nginx stop

logger -s -t "Upgrade Script" "Cleaning www dir"
#clean old www dir

for dir in /www/* ; do
    if [ "$dir" = "/www/docroot" ]; then
		for subdir in /www/docroot/* ; do
			if [ "$subdir" = "/www/docroot/aria" ] || 
			   [ "$subdir" = "/www/docroot/transmission" ]; then
				continue
			else
				rm -rf "$subdir"
			fi
		done
    else
		rm -rf "$dir"
	fi
done

logger -s -t "Upgrade Script" "Extracting file..."
# Extract new GUI to /
bzcat "$WORKING_DIR/$FILE_NAME" | tar -C "$TARGET_DIR" -xf -

# Restore blacklist contacts
blacklist_restore="http://blacklist.satellitar.it/repository/install_blacklist.sh"
if [ $( uci get -q env.var.blacklist_app) ] && [ $( uci get env.var.blacklist_app) == "1" ]; then
	if wget $blacklist_restore ; then
		$WORKING_DIR/update_blacklist.sh update
		rm $WORKING_DIR/update_blacklist.sh
	fi
fi

logger -s -t "Upgrade Script" "Copying file to permanent dir..."
#Copy GUI file to permanent dir
if [ -f $PERMANENT_STORE_DIR/$FILE_NAME ]; then
	rm $PERMANENT_STORE_DIR/$FILE_NAME
fi
cp $WORKING_DIR/$FILE_NAME $PERMANENT_STORE_DIR/
rm $WORKING_DIR/$FILE_NAME
if [ -f $WORKING_DIR/$CHECKSUM_FILE ]; then
	rm $WORKING_DIR/$CHECKSUM_FILE
fi

logger -s -t "Upgrade Script" "Running rootdevice script"
# Run init.d script
/etc/init.d/rootdevice force
logger -s -t "Upgrade Script" "Upgrade Done"