#!/bin/bash

#================================================================
#% SYNOPSIS
#+    LiteMD Install Script
#%
#% DESCRIPTION
#%    Installer file for LiteMD
#%
#% USAGE
#%    ./install.sh $flag
#% FLAGS
#%     none   Install proceeds
#%     -r     Uninstalls LiteMD and related files
#%
#%
#================================================================

# source: https://stackoverflow.com/questions/14447406/bash-shell-script-check-for-a-flag-and-grab-its-value

hashDir=hashes
hashfile=md5_hash
fullHashFile=hashlist.txt

# to have a file we can verify the checking mechanism against
virusTest=testvirus.txt

# hash source
hashSource="https://virusshare.com/hashes.4n6"


# used for changing text color

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
BLUE='\033[0;34m'
BOLD="\033[1m"
YELLOW='\033[0;33m'
# FUNCTIONS:

# removeLMD- Uninstalls LMD
removeLMD() {
    # TODO: removal of hashes and related files, probably the crontab too
    echo "Starting removal of LiteMD."
    echo -e "${RED}Proceed? ${NC}"
    read -r rmChoice
    case $rmChoice in
    # N default letter
		y|Y) ;;
		n|N|"") exit ;;
		*) echo -e "${RED}Error...${NC}" && sleep .5
	esac
    echo ""
    echo "Removing hashes"
    rm -f $hashDir/$fullHashFile

}

allHashes(){

    if [ -f $hashDir/$fullHashFile ]; then
        echo -e "${BLUE}Hashes already found. Skipping download.${NC}"
        echo "Remove $hashDir/$fullHashFile if you believe this is in error."
        return #break out of allHashes
    fi

    # root page of web directory
    hashRootPage="hashPage.txt"
    curl -s $hashSource -o $hashRootPage

    # use a slimey regex to get the max page number
    maxPage=$(grep -Eo '(00)[0-9]+' $hashRootPage | sort -rn | head -n 1 | cut -c 3-)

    echo "Downloading $maxPage hash files"
    sleep 1
    # can iterate easily through the links. https://virusshare.com/hashes/VirusShare_00001.md5
    # https://virusshare.com/hashes/VirusShare_00002.md5, etc
    # ends at 374
    # ends at highest number on page

    #download all 374 hash files
    for ((i=1;i<="$maxPage";i++))
    do
    # have to adjust url based on file number
        if ((i < 10 ))
        then
            wget -O $hashDir/"$hashfile"_$i https://virusshare.com/hashes/VirusShare_0000$i.md5
        elif ((i >= 10 && i < 100 ))
        then
            wget -O $hashDir/"$hashfile"_$i https://virusshare.com/hashes/VirusShare_000$i.md5
        elif ((i >= 100 ))
        then
            wget -O $hashDir/"$hashfile"_$i https://virusshare.com/hashes/VirusShare_00$i.md5
        fi

    done
 
    # clean up my earlier curl sins
    rm $hashRootPage

    sleep 2
    echo -e "${RED}Trimming and combining files...${NC}"
    sleep 2
    # need to remove headers now (#)
    for file in "${hashDir:?}/"*
    do
        sed '/^#/ d' < "$file" > "$file"_fixed
        rm "$file"
        cat "$file"_fixed >> $hashDir/$fullHashFile
        rm "$file"_fixed
        md5sum "$virusTest"  | head -n1 | awk '{print $1;}' >> $hashDir/$fullHashFile
    # hashlist.txt should be 1.1G
    done


}

while getopts ":r:" opt; do
  case $opt in
    :)
      removeLMD
      exit 1
      ;;
  esac
done


echo "Install Commencing"

# TODO: install cronie? on arch at least

#if -e [ /etc/cron.X/ then...]
# else, pacman -S cronie


echo -e "${RED}Please note downloading all of these hashes requires ~1.1GB of disk space and bandwith.${NC}"
echo ""
sleep 1
echo -e "${RED}Do you want to download all hashes? [y/N]${NC}"
read -r hashChoice
case $hashChoice in
# N default letter
	y|Y) allHashes ;;
	n|N|"")  ;;
	*) echo -e "${RED}Error...${NC}" && sleep .5
esac



