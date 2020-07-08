#!/bin/bash
# script to be run by cronjob to re-scan directories
# can be run manually
    
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
                echo "-----Malicious File DETECTED - $file----"  
                echo "File detected on $(date)"
                echo "$file=$fileHash" 
                echo "-----Malicious File $file END-----" 
            } >> "$hashDir"/"$malFiles";
            # UPDATE MOTD
            {
                echo "-----ALERT | MALWARE FOUND | ALERT-------"  
                echo "$file"
                echo "Found on $(date)"
                echo ""
            } >> "/etc/motd";
        fi
    done <    <(find "$virusDir" -type f  -print0);
    exit

