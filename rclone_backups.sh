#
#
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
# 1) Be called when the minecraft server .sh script is run
# 2) Wait until the server script is finished running, i.e the world is saved, all the players have left and server is shut down.
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
# 5) After confirmation of all three files being sent, it will delete the zip file and wait for new backups.
#     5a) NOTE: IF THE FILE TAKES OVER 15 MINUTES TO SEND, IT WILL SKIP THE PROVIDER. IF ALL PROVIDERS FAIL, IT WILL SEND AN URGENT EMAIL NOTIFICATION TO THE USER TO ALERT THEM.
#     5b) IF ORACLE EVER STARTS THREATENING THE INTEGRITY OF THE SERVER, A FUNCTION CALLED "PANIC MODE" WILL BE RUN THAT WILL SEND AN EMAIL NOTIFICATION TO THE USER, LOGGING THE DATE OF THE INCIDENT AND WILL BACKUP EVERY WORLD AND SEND THEM TO THE PROVIDERS, REGARDLESS OF THE DATE OF THE LAST BACKUP
# 6*) It should log every step to a file named log.txt
#     6*a) It should be formatted like this:
#         [timestamp with year-month-day, hour:minute:second] STEP OF THE THINGY
# 7*) After every backup, it will send the email log to the user
#
# NOTE: THE * order are optional and low-priority for development.


