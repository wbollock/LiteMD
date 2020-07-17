#!/bin/bash

#================================================================
#% SYNOPSIS
#+    LiteMD Install Script
#%
#% DESCRIPTION
#%    Installer file for LiteMD
#%    A lightweight Linux malware detector
#% USAGE
#%    ./install.sh $flag
#% FLAGS
#%     none   Install proceeds
#%     -r     Uninstalls LiteMD and related files
#%
#% AUTHOR
#% Will Bollock
#%
#% LICENSE
#% MIT
#%
#================================================================


hashDir=hashes
hashfile=md5_hash
fullHashFile=hashlist.txt
# key value pairs of hash dir
kvpairs=kvpairs.txt
malFiles=MALICIOUSFILES
virusDir=$(cat virusDir.info)
motdFile=/etc/motd

# to have a file we can verify the checking mechanism against
virusTest=testvirus.txt
scriptLocation=$(readlink -f litemd.sh)


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
    echo -e "${RED}Removal hashes? ~1.1GB+ [Y/n]${NC}"
    read -r rmChoice
    case $rmChoice in
    # N default letter
		y|Y|"") 
        echo "✅ Removing hashes" &&  rm -f "$hashDir"/"$fullHashFile"
        ;;
		n|N)  ;;
		*) echo -e "${RED}Error...${NC}" && sleep .5
	esac

    # if $file exists, rm it

    if [ -f "$hashDir"/"$kvpairs" ]; then
    echo "✅ Removing calculated hashes of directory"
    rm -f "$hashDir"/"$kvpairs"
    elif [ -f "$hashDir"/"$malFiles" ]; then
    echo "✅ Removing potential malicious file list"
    rm -f "$hashDir"/"$malFiles"
    fi

    echo "✅ Removing crontab entries"
    # list crontab, take out the lite.md stuff, put back into crontab
    crontab -l | grep -v 'litemd.sh'  | crontab -

    echo "✅ Cleaning up MOTD"
    # remove the match, and the next 3 lines after it
    cp $motdFile motdtmp 
    # sed has to make a temp file and cant in /etc
    sed -i '/-----ALERT | MALWARE FOUND | ALERT-------/,+3 d' motdtmp
    # cp it back
    cp motdtmp $motdFile
    # return perms to standard
    sudo chown "root:root" $motdFile
    echo "Removal complete."
    
}

# ensures app requirements are met
requirements(){

    echo -e "${RED}Please note this project is designed for Arch Linux.${NC}"

    # if pacman not insatlled
    if [ ! -e "/usr/bin/pacman" ]; then
    echo -e "${RED}Pacman not detected. You're probably not on Arch/Manjaro. Proceed anyway? Who knows what may break. [y/N] ${NC}"
    read -r choice
        case $rmChoice in
        # N default letter
            y|Y) allHashes ;;
            n|N|"") exit ;;
            *) echo -e "${RED}Error...${NC}" && sleep .5
        esac
    fi

    echo ""
    echo "Installing requirements (cron and wget), bypassing prompts:"
    cat pkglist.txt
    echo ""
    sleep 1

    sudo pacman -S --needed --noconfirm - < pkglist.txt

    echo "Starting and enabling cronie systemd service"
    sudo systemctl enable cronie.service
    sudo systemctl start cronie.service

    echo ""
    allHashes

}

# downloads hashes needed to check for malware
allHashes(){

    if [ -f $hashDir/$fullHashFile ]; then
        echo -e "${BLUE}Hashes already found. Skipping download.${NC}"
        #echo "Remove $hashDir/$fullHashFile if you believe this is in error."
        hashCheck #break out of allHashes
        return
    fi

    echo -e "${RED}**Please** note downloading all of these hashes requires ~1.1GB of disk space.${NC}"
    echo ""
    
    sleep 1
    echo -e "${RED}Do you want to download all hashes? [Y/n]${NC}"
    read -r choice
    
    case $choice in
    # N default letter
        y|Y|"") echo "It is recommended you get up, drink water, get some tea, and leave the terminal running. This takes a while."
        sleep 2
        mkdir hashes > /dev/null 2>&1 ;;
        n|N) exit  ;;
        *) echo -e "${RED}Error...${NC}" && sleep .5
    esac


    # root page of web directory
    hashRootPage="hashPage.txt"
    curl -s $hashSource -o $hashRootPage

    # use a slimey regex to get the max page number
    maxPage=$(grep -Eo '(00)[0-9]+' $hashRootPage | sort -rn | head -n 1 | cut -c 3-)

    echo -e "${RED}Downloading $maxPage hash files${NC}"
    echo ""
    sleep 1
    # can iterate easily through the links. https://virusshare.com/hashes/VirusShare_00001.md5
    # https://virusshare.com/hashes/VirusShare_00002.md5, etc
    # ends at highest number on page

    #download all 374++ hash files
    for ((i=1;i<="$maxPage";i++))
    do
    # have to adjust url based on file number
        if ((i < 10 ))
        then
            wget -O $hashDir/"$hashfile"_"$i" https://virusshare.com/hashes/VirusShare_0000"$i".md5
        elif ((i >= 10 && i < 100 ))
        then
            wget -O $hashDir/"$hashfile"_"$i" https://virusshare.com/hashes/VirusShare_000"$i".md5
        elif ((i >= 100 ))
        then
            wget -O $hashDir/"$hashfile"_"$i" https://virusshare.com/hashes/VirusShare_00"$i".md5
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
    # hashlist.txt should be ~1.1G+
    done



    hashCheck
}

# runs malware check for first time
hashCheck(){

    echo ""
    echo -e "${BLUE}Please specify the directory you'd like LiteMD to focus on (e.g /srv/http, /var/www/html):${NC}"
    # example: Arch Apache2 default = /srv/http
    if [ -f virusDir.info ]; then
    echo ""
    echo -e "${RED}Do you still want to use $(cat virusDir.info)? [Y/n] ${NC}"
    read -r choice
        case $choice in
        # N default letter
            y|Y|"")  ;;
            n|N) echo "Alright, please specify the directory you'd like LiteMD to focus on:" ; read -r virusDir; echo "$virusDir" > virusDir.info  ;;
            *) echo -e "${RED}Error...${NC}" && sleep .5
        esac
    else
    # first run
    read -r virusDir
    echo "$virusDir" > virusDir.info
    fi
    # for cron job

    if [ ! -f $hashDir/$kvpairs ]; then
        # used to store $file=$hash
        touch $hashDir/$kvpairs
    fi

    if [ ! -f $hashDir/$malFiles ]; then
        # used to store path of $files that are potentially malicious and their hash value
        touch $hashDir/$malFiles
        echo "------------LiteMD's list of potentially malicious files----------" >> "$hashDir"/"$malFiles"

    fi

    # shellcheck doesnt like for file in $(find "$virusDir" -type f);

    if [ -f "$hashDir"/"$malFiles" ]; then
        echo -e "${RED}Overwrite previous hash results? [y/N]${NC}"
        read -r choice
        case $choice in
        # N default letter
            y|Y) rm -f "$hashDir"/"$malFiles" "$hashDir"/"$kvpairs" ;;
            n|N|"") cronjobAdd  ;;
            *) echo -e "${RED}Error...${NC}" && sleep .5
        esac
    fi

    echo "Calculating hashes of all files in $virusDir..."
    echo "This could take a while on a big directory (recursive)."
    sleep 2

    # actually does the hash calculation with key value pairs
    while IFS= read -r -d '' file
    do
        fileHash=$(md5sum "$file"  | head -n1 | awk '{print $1;}')
        echo "$file=$fileHash" >> "$hashDir"/"$kvpairs"; 
        # $kvpairs now has list like this:
        # /srv/http/LIS5362/.git/hooks/pre-applypatch.sample=054f9ffb8bfe04a599751cc757226dda
        # https://stackoverflow.com/questions/4990575/need-bash-shell-script-for-reading-name-value-pairs-from-a-file

        if grep -q "$fileHash" "$hashDir"/"$fullHashFile"; then 
            {
                echo "-----Malicious File DETECTED - $file----"
                echo "File detected on $(date)"  
                echo "$file=$fileHash" 
                echo "-----Malicious File $file END-----" 
            } >> "$hashDir"/"$malFiles";
        fi
    done <    <(find "$virusDir" -type f  -print0);
    

    cronjobAdd
}

# sets up a cronjob to run litemd.sh, to re-check for malicious files at an interval
cronjobAdd() {

    echo -e "${RED}Would you like to add a cronjob to monitor this directory at an interval? [Y/n]${NC}"
    read -r choice
    
    case $choice in
    # N default letter
        y|Y|"")  ;;
        n|N) exit  ;;
        *) echo -e "${RED}Error...${NC}" && sleep .5
    esac

    if ( crontab -l | grep -q "litemd.sh" ); then
    echo -e "${RED}Crontab already found. Overwrite? [Y/n]${NC}"
    read -r choice
        case $choice in
            y|Y|"") crontab -l | grep -v 'litemd.sh'  | crontab - /dev/null 2>&1 ;;
            n|N)   ;;
            *) echo -e "${RED}Error...${NC}" && sleep .5
        esac
    
    fi

    echo -e "${BLUE}Please choose the interval you'd like for the cronjob:${NC}"
    echo "(Defaults to 3am of day/week, and will run under $(echo $USER))"
    echo "1) Every Hour"
    # 0 * * * *
    echo "2) Every Day"
    # 0 3 * * *
    echo "3) Every Week"    
    # 0 3 * * 0
    echo "4) [DEBUG] Every Minute"
    # * * * * *
    read -r choice
    case $choice in
    # > /dev/null 2>&1
        1) ! (crontab -l | grep -q "litemd.sh" ) && (crontab -l; echo "0 * * * * $scriptLocation") | crontab - && interval="hourly" ;;
        2) ! (crontab -l | grep -q "litemd.sh"  ) && (crontab -l; echo "0 3 * * * $scriptLocation" ) | crontab - && interval="daily" ;;
        3) ! (crontab -l | grep -q "litemd.sh" ) && (crontab -l; echo "0 3 * * 0 $scriptLocation" ) | crontab - && interval="weekly" ;;
        4) ! (crontab -l | grep -q "litemd.sh" ) && (crontab -l; echo "* * * * * $scriptLocation" ) | crontab - && interval="minutely" ;;
        *) echo -e "${RED}Error...${NC}" && sleep .5
    esac
    #! (crontab -l | grep -q "SCRIPT_FILENAME") && (crontab -l; echo "20 10 * * * SCRIPT_FILENAME") | crontab -

    echo ""
    echo ""
    echo -e "LiteMD will recheck ${BLUE}$virusDir${NC} for malicious files at the interval: $interval."
    echo ""
    echo -e "${RED}One last thing, your /etc/motd file will be chowned as $USER:$USER ${NC}"
    # ugh this is shitty but i dont know an alternative
    sudo chown "$USER:$USER" /etc/motd

    echo "$(pwd)" > pwd.info
    
    exit
}

# helps with the flag to uninstall
while getopts ":r:" opt; do
  case $opt in
    :)
      removeLMD
      exit 1
      ;;
     *)
      echo "Invalid flag."
      exit
  esac
done

echo -e "${RED}Welcome to LiteMD. This is a lightweight malware detector, best used on web servers or file servers with many users.${NC}"
echo ""
echo "Note: a capital letter [y/N] means that is the default response"
echo ""
echo "Install or Configuration Commencing"
echo ""
sleep 3

# start the function loop
requirements



