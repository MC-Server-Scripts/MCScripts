#
# MADE WITH ASSISTANCE OF CHATGPT, STACK OVERFLOW AND THE RCLONE FORUMS
#
# FEATURES
#
# This shell script will automatically identify when a mc server starts, ends and will backup the world after confirming the server to be stopped. It will mirror it with rclone
# to GDrive, MEGA and Dropbox. It will delete the latest {n+1} backup, so only the latest {n} backups will remain, to save space.
#
# The specifications of n vary from provider to provider:
#
# Dropbox: 1 (Only keep latest backup. This is because Dropbox only provides 2 GB of free space.)
# GDrive:  3
# MEGA:    4
#
#
# To do this, it will follow this order:
#
# 1) Be called when the minecraft server .sh script is run                                                                                           SEE STARTSERVER-JAVA9.SH
# 2) Wait until the server script is finished running, i.e the world is saved, all the players have left and server is shut down.                    SEE STARTSERVER-JAVA9.SH
# 3) Upon confirmation that the script is not running, it will use zip to create a zip file to the following specifications:
#     3a) It will include, recursively, the entire "World" folder.
#     3b) The file's name will be determined by: MODPACKNAME_DATE_SIZEOFWORLDFOLDER.zip
#     3c) It will be compressed using the -9 option, to save space
#    3d) The zipfile's comments will include:
#         "This zipfile was created at DATE, is part of the MODPACKNAME modpack and has XXXXX MBs of size. It has been shipped to Dropbox, GDrive and MEGA. In case Oracle ever deletes this server instance, this is a way to have the world files."
#     3e) It will not be encrypted.
# 4) After the zip file is created, it will be sent to the providers in this order (fastest to slowest):
#     4a) GDrive
#     4b) Dropbox
#     4c) Mega
# 5*) After confirmation of all three files being sent, it will delete the zip file and wait for new backups.
#     5a*) NOTE: IF THE FILE TAKES OVER 15 MINUTES TO SEND, IT WILL SKIP THE PROVIDER. IF ALL PROVIDERS FAIL, IT WILL SEND AN URGENT EMAIL NOTIFICATION TO THE USER TO ALERT THEM.
#     5b*) IF ORACLE EVER STARTS THREATENING THE INTEGRITY OF THE SERVER, A FUNCTION CALLED "PANIC MODE" WILL BE RUN THAT WILL SEND AN EMAIL NOTIFICATION TO THE USER, LOGGING THE DATE OF THE INCIDENT AND WILL BACKUP EVERY WORLD AND SEND THEM TO THE PROVIDERS, REGARDLESS OF THE DATE OF THE LAST BACKUP
# 6*) It should log every step to a file named log.txt
#     6*a) It should be formatted like this:
#         [timestamp with year-month-day, hour:minute:second] STEP OF THE THINGY
# 7*) After every backup, it will send the email log to the user
#
# NOTE: THE * order are optional and low-priority for development.

# 1) Start Modpack HUB Script is called -> Pick server wanted -> Calls startserver-modpack.sh script -> In game, /stop command is sent (op 4 needed) -> startserver-modpack.sh stops running -> calls rclone_backup_modpack.sh

# THANKS CHATGPT, STACKOVERFLOW AND THE RCLONE FORUMS FOR HELP IN THIS
# YOU WILL NEED THE PACKAGES rclone (https://rclone.org/) AND zip (https://infozip.sourceforge.net/)
# YOU WILL ALSO NEED TO SETUP A GDrive, MEGA AND Dropbox REMOTES. (or at least one of those.). RUN "rclone config" TO DO IT.
### CONFIGURATION ZONE ###

# CONFIGURE THE SUBDIRECTORY EACH MODPACK BACKUP FOLDER WILL BE IN. TO MAKE THOSE, RUN "rclone mkdir REMOTE:/[subdirectory_name]/" (NOTE: REMOTE MEANS GDrive, MEGA, Dropbox.). Also run rclone mkdir REMOTE:/[subdirectory_name]/modpack_name for every modpack.

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
world_name= $(sed -n '18{p;q}' server.properties | cut -d'=' -f2)
world_size=$(du -hs ${world_name} | cut -f1)
zip_name="${modpack_name}_${current_date}_${world_size}"
precise_date=$(date '+%H:%M:%S.%3N')
time_zone=$(date '+%:z')
easy_time_log="[UTC${time_zone}][${current_date}, ${precise_date}]:"
logf="${modpack_name}_${current_date} log"

#### PART 1 - ZIP FILE ####

# CREATE COMMENT, LOG AND ZIP FILE. LOG.
echo "Creating ZIP File."
touch "${logf}.txt"
zip_comment="This zipfile was created at ${current_date}, is part of the ${modpack_name} modpack and has ${world_size}Bs. It has been shipped to Dropbox, GDrive and MEGA. In case Oracle ever deletes this server instance, this is a way to have the world files."
echo "${zip_comment}" > zip_comment_file.txt
zip -q -r -${compression_factor} "${zip_name}" ${world_name}
zip -z "${zip_name}".zip < zip_comment_file.txt
rm zip_comment_file.txt

echo "Created zip file. Sending to providers."
echo "${easy_time_log} Created zip world file. Size is "${world_size}"Bs." >> "${logf}.txt"


#### PART 2 - SEND ZIP FILE ####

#SEND ZIP FILE TO REMOTES

rclone sync --metadata "${zip_name}.zip" ${gdrive_remote}:${subdirectory_name}/"${modpack_name}"
echo "${easy_time_log} Sent zip file to Google Drive." >> "${logf}.txt"
rclone sync --metadata "${zip_name}.zip" ${dropbox_remote}${subdirectory_name}/"${modpack_name}"
echo "${easy_time_log} Sent zip file to Dropbox." >> "${logf}.txt"
rclone sync --metadata "${zip_name}.zip" ${mega_remote}${subdirectory_name}/"${modpack_name}"
echo "${easy_time_log} Sent zip file to MEGA." >> "${logf}.txt"

echo "File has been sent to providers!"

#REMOVE n-LATEST BACKUPS

echo "Removing n-latest backups."

gdrive_backups_delete="$(rclone lsf ${gdrive_remote}:${subdirectory_name}/"${modpack_name}" | sort | head -n -"${gdrive_cutoff_number}")"
dropbox_backups_delete="$(rclone lsf ${dropbox_remote}${subdirectory_name}/"${modpack_name}" | sort | head -n -"${dropbox_cutoff_number}")"
mega_backups_delete="$(rclone lsf ${mega_remote}${subdirectory_name}/"${modpack_name}" | sort | head -n -"${mega_cutoff_number}")"

echo "${gdrive_backups_delete}" > gdrive_backups.txt
echo "${dropbox_backups_delete}" > dropbox_backups.txt
echo "${mega_backups_delete}" > mega_backups.txt

rclone delete ${gdrive_remote}:${subdirectory_name}/"${modpack_name}" --files-from "gdrive_backups.txt"
echo "${easy_time_log} Deleted latest GDrive backups." >> "${logf}.txt"
rclone delete ${dropbox_remote}${subdirectory_name}/"${modpack_name}" --files-from "dropbox_backups.txt"
echo "${easy_time_log} Deleted latest Dropbox backups." >> "${logf}.txt"
rclone delete ${mega_remote}${subdirectory_name}/"${modpack_name}" --files-from "mega_backups.txt"
echo "${easy_time_log} Deleted latest MEGA backups." >> "${logf}.txt"

echo "N-latest files removed!"

rm gdrive_backups.txt
rm mega_backups.txt
rm dropbox_backups.txt

#DELETE REMAINING ZIP FILE

rm "${zip_name}.zip" 
echo "${easy_time_log} ZIP FILE REMOVED!" >> "${logf}.txt"

echo "Remaining zip file deleted!"

#insert mail functionality here

echo "${easy_time_log} Sending myself to the backup providers." >> "${logf}.txt"
echo "${easy_time_log} Tasks over." >> "${logf}.txt"

rclone sync --metadata "${logf}.txt" ${gdrive_remote}:${subdirectory_name}/"${modpack_name}"
rclone sync --metadata "${logf}.txt" ${dropbox_remote}${subdirectory_name}/"${modpack_name}"
rclone sync --metadata "${logf}.txt" ${mega_remote}${subdirectory_name}/"${modpack_name}"

echo "I am finished here!"
exit 