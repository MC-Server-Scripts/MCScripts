# THANKS CHATGPT, STACKOVERFLOW AND THE RCLONE FORUMS FOR HELP IN THIS
### CONFIGURATION ZONE ###

# CONFIGURE THE SUBDIRECTORY EACH MODPACK BACKUP FOLDER WILL BE IN. TO MAKE THOSE, RUN "rclone mkdir REMOTE:/[subdirectory_name]/" (NOTE: REMOTE MEANS GDrive, MEGA, Dropbox.). Also run "rclone mkdir REMOTE:/[subdirectory_name]/modpack_name for each modpack."
subdirectory_name=backups_mc

# CONFIGURE EACH REMOTE'S NAME

gdrive_remote=GDrive
dropbox_remote=Dropbox
mega_remote=MEGA

# CONFIGURE HOW MANY BACKUPS SHOULD BE KEPT FOR EACH MODPACK, IN EACH PROVIDER

gdrive_cutoff_number=3
mega_cutoff_number=4
dropbox_cutoff_number=1

# CONFIGURE THE ZIP FILE COMPRESSION FACTOR (AFFECTS PROCESSING TIME FOR LARGE WORLDS). GOES FROM 0-9, 0 BEING NO COMPRESSION AND 9 BEING MAXIMUM COMPRESSION

compression_factor=9

### CONFIGURATION ZONE ###
#### PART 0 - GET VARIABLES ####
modpack_name=$(basename "$(pwd)")
current_date=$(date '+%Y-%m-%d')
world_name=$(sed -n '18{p;q}' server.properties | cut -d'=' -f2)
world_size=$(du -hs "${world_name}/" | cut -f1)
zip_name="${modpack_name}_${current_date}_${world_size}"
precise_date=$(date '+%H:%M:%S.%3N')
time_zone=$(date '+%:z')
easy_time_log="[UTC${time_zone}][${current_date}, ${precise_date}]:"
logf="${modpack_name}_${current_date} log"

#### PART 1 - ZIP FILE ####

# CREATE COMMENT, LOG AND ZIP FILE. LOG.
echo "Creating ZIP File."
touch "${logf}.txt"
zip_comment="This zipfile was created at ${current_date}, is part of the ${modpack_name} modpack and has ${world_size}Bs. It has been shipped to Dropbox, GDrive and MEGA. In case Oracle ever deletes this server instance, this is a way to salvage it."
echo "${zip_comment}" > zip_comment_file.txt
zip -q -r -"${compression_factor}" "${zip_name}".zip "${world_name}/"
zip -z "${zip_name}".zip < zip_comment_file.txt
rm zip_comment_file.txt

echo "Created zip file. Sending to providers."
echo "${easy_time_log} Created zip world file. Size is ${world_size}Bs." >> "${logf}.txt"

#### PART 2 - SEND ZIP FILE ####

# SEND ZIP FILE TO REMOTES

rclone sync --metadata "${zip_name}.zip" "${gdrive_remote}:${subdirectory_name}/${modpack_name}"
echo "${easy_time_log} Sent zip file to Google Drive." >> "${logf}.txt"
rclone sync --metadata "${zip_name}.zip" "${dropbox_remote}:${subdirectory_name}/${modpack_name}"
echo "${easy_time_log} Sent zip file to Dropbox." >> "${logf}.txt"
rclone sync --metadata "${zip_name}.zip" "${mega_remote}:${subdirectory_name}/${modpack_name}"
echo "${easy_time_log} Sent zip file to MEGA." >> "${logf}.txt"

echo "File has been sent to providers!"

#REMOVE n-LATEST BACKUPS

echo "Removing n-latest backups."

gdrive_backups_delete="$(rclone lsf ${gdrive_remote}:${subdirectory_name}/${modpack_name} | sort | head -n -${gdrive_cutoff_number})"
dropbox_backups_delete="$(rclone lsf ${dropbox_remote}:${subdirectory_name}/${modpack_name} | sort | head -n -${dropbox_cutoff_number})"
mega_backups_delete="$(rclone lsf ${mega_remote}:${subdirectory_name}/${modpack_name} | sort | head -n -${mega_cutoff_number})"

echo "${gdrive_backups_delete}" > gdrive_backups.txt
echo "${dropbox_backups_delete}" > dropbox_backups.txt
echo "${mega_backups_delete}" > mega_backups.txt

rclone delete "${gdrive_remote}:${subdirectory_name}/${modpack_name}" --files-from "gdrive_backups.txt"
echo "${easy_time_log} Deleted latest GDrive backups." >> "${logf}.txt"
rclone delete "${dropbox_remote}:${subdirectory_name}/${modpack_name}" --files-from "dropbox_backups.txt"
echo "${easy_time_log} Deleted latest Dropbox backups." >> "${logf}.txt"
rclone delete "${mega_remote}:${subdirectory_name}/${modpack_name}" --files-from "mega_backups.txt"
echo "${easy_time_log} Deleted latest MEGA backups." >> "${logf}.txt"

echo "N-latest files removed!"

rm gdrive_backups.txt
rm mega_backups.txt
rm dropbox_backups.txt

#DELETE REMAINING ZIP FILE

rm "${zip_name}.zip"
echo "${easy_time_log} ZIP FILE REMOVED!" >> "${logf}.txt"

echo "Remaining zip file deleted!"
echo "${easy_time_log} Sending myself to the backup providers." >> "${logf}.txt"
echo "${easy_time_log} Tasks over." >> "${logf}.txt"

rclone sync --metadata "${logf}.txt" "${gdrive_remote}:${subdirectory_name}"
rclone sync --metadata "${logf}.txt" "${dropbox_remote}:${subdirectory_name}"
rclone sync --metadata "${logf}.txt" "${mega_remote}:${subdirectory_name}"

echo "I am finished here!"
exit