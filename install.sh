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
# key value pairs of hash dir
kvpairs=kvpairs.txt
malFiles=MALICIOUSFILES

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
    echo -e "${RED}Proceed? [y/N]${NC}"
    read -r rmChoice
    case $rmChoice in
    # N default letter
		y|Y) ;;
		n|N|"") exit ;;
		*) echo -e "${RED}Error...${NC}" && sleep .5
	esac
    echo ""
    echo "Removing hashes"
    rm -f "$hashDir"/"$fullHashFile"
    echo "Removing calculated hashes of directory"
    rm -f "$hashDir"/"$kvpairs"
    echo "Removing potential malicious file list"
    rm -f "$hashDir"/"$malFiles"
}

allHashes(){

    if [ -f $hashDir/$fullHashFile ]; then
        echo -e "${BLUE}Hashes already found. Skipping download.${NC}"
        echo "Remove $hashDir/$fullHashFile if you believe this is in error."
        hashCheck #break out of allHashes
        return
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
    rm -f $hashRootPage

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



    hashCheck
}

# TODO: cron should run this function again
hashCheck(){
    echo -e "${BLUE}Please specify the directory you'd like LiteMD to focus on:${NC}"
    # example: Arch Apache2 default = /srv/http
    read -r virusDir

    if [ ! -f $hashDir/$kvpairs ]; then
        # used to store $file=$hash
        touch $hashDir/$kvpairs
    fi

    if [ ! -f $hashDir/$malFiles ]; then
        # used to store path of $files that are potentially malicious and their hash value
        touch $hashDir/$malFiles
        echo "------------LiteMD's list of potentially malicious files----------" >> "$hashDir"/"$malFiles"

    fi


    echo "Calculating hashes of all files in $virusDir..."
    sleep 2
    for file in $(find $virusDir -type f);
    do 
        fileHash=$(md5sum "$file"  | head -n1 | awk '{print $1;}')
        echo "$file=$fileHash" >> "$hashDir"/"$kvpairs"; 
        # $kvpairs now has list like this:
        # /srv/http/LIS5362/.git/hooks/pre-applypatch.sample=054f9ffb8bfe04a599751cc757226dda
        # https://stackoverflow.com/questions/4990575/need-bash-shell-script-for-reading-name-value-pairs-from-a-file

        if grep -q "$fileHash" "$hashDir"/"$fullHashFile"; then 
            echo "-----Malicious File DETECTED - $file----" >> "$hashDir"/"$malFiles"; 
            echo "$file=$fileHash" >> "$hashDir"/"$malFiles"; 
            echo "-----Malicious File $file END-----" >> "$hashDir"/"$malFiles"; 
        fi
    done
    exit

    #fileHash=$(md5sum "$scaryVirus"  | head -n1 | awk '{print $1;}')

    #echo "Thanks for that. Doing some really smart algorithm..."
    #sleep 1

    #echo "File hash is: $fileHash"
    #sleep 1

    # Compare hash of user file to my big list of hashes
    # 48fe63b00f90279979cc4ea85446351f  testclean.txt
    # ed0335c6becd00a2276481bb7561b743  testvirus.txt
    # if [ -f "$hashDir"/"$fullHashFile" ]; then
    #     if grep -q "$fileHash" "$hashDir"/"$fullHashFile"; then
    #         echo -e "${RED}Match found! If you actually suspect this file is malicious, please .${NC}"
    #         echo ""
    #         echo -e "Would you like to quarantine ${RED}$scaryVirus${NC}?"
    #         echo -e "It will be moved to the folder ${BLUE}jail${NC} and stripped of all permissions. [y/N]"
    #         read -r quarChoice
    #         case $quarChoice in
    #             y|Y) sudo chmod 000 $scaryVirus
    #                  sudo mv "$scaryVirus" jail/
    #                  echo ""
    #                  echo -e "$scaryVirus has been moved to ${BLUE}jail${NC}."
    #                  sudo ls -l jail;;
    #             n|N|"") echo "$scaryVirus will not be quarantined."
    #             sleep 1 ;;
    #             *) echo -e "${RED}Error...${NC}" && sleep .5
    #         esac

    #     else
    #         echo -e "${BLUE}Your file is safe. Chmod 777 to your heart's desire.${NC}"
    #     fi
    # else
    #     echo -e "${YELLOW} Oh no. Couldn't find any hashes. Did you download virus definitions?${NC}"
    # fi

    #   if [ -f webflag ]; then
    #   # get file run against hashes
    #   sed -ri "s@<p(|\s+[^>]*)>Last file checked against hashes:(.*?)<\/p\s*>@<p>Last file checked against hashes: $scaryVirus</p>@g" crappyavweb/index.html
    #  fi

    # sleep 3

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



