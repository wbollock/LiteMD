#!/bin/bash
# script to be run by cronjob to re-scan directories
# can be run manually

# https://unix.stackexchange.com/questions/38951/what-is-the-working-directory-when-cron-executes-a-job
# cd to pwd
cd "$(dirname "$0")";

virusDir=$(cat virusDir.info)
# debug
hashDir=hashes
hashfile=md5_hash
fullHashFile=hashlist.txt
# key value pairs of hash dir
kvpairs=kvpairs.txt
malFiles=MALICIOUSFILES


# to have a file we can verify the checking mechanism against
virusTest=testvirus.txt



    if [ -f "$hashDir"/"$malFiles" ]; then
    # overwrite existing
      rm -f "$hashDir"/"$malFiles" "$hashDir"/"$kvpairs"
    fi

    # "Calculating hashes of all files in $virusDir..."

    while IFS= read -r -d '' file
    do
        fileHash=$(md5sum "$file"  | head -n1 | awk '{print $1;}')
        echo "$file=$fileHash" >> "$hashDir"/"$kvpairs"; 
        # $kvpairs now has list like this:
        # /srv/http/LIS5362/.git/hooks/pre-applypatch.sample=054f9ffb8bfe04a599751cc757226dda
        # https://stackoverflow.com/questions/4990575/need-bash-shell-script-for-reading-name-value-pairs-from-a-file
        
        # if you find the hash of the tested file in the list of known malware, malware has been found
        if grep -q "$fileHash" "$hashDir"/"$fullHashFile"; then 
            {
                 if grep -q "$file" "$hashDir"/"$malFiles"; then
                    echo "-----Malicious File DETECTED - $file----"  
                    echo "File detected on $(date)"
                    echo "$file=$fileHash" 
                    echo "-----Malicious File $file END-----" 
                else
                    sleep 1
                fi
            } >> "$hashDir"/"$malFiles";
            # UPDATE MOTD
            {
                # https://unix.stackexchange.com/questions/223503/how-to-use-grep-when-file-does-not-contain-the-string
                # if you can't already find $file in /etc/motd, then
                if grep -q "$file" /etc/motd; then
                # if $file NOT in motd
                    echo "-----ALERT | MALWARE FOUND | ALERT-------"  
                    echo "$file"
                    echo "Found on $(date)"
                    echo ""
                else
                # do nothing if $file found in /etc/motd
                    sleep 1
                fi
            } >> "/etc/motd";
        fi
    done <    <(find "$virusDir" -type f  -print0);
    exit

