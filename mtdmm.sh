#!/bin/bash

echo "Welcome to MTDMM. A tool for mounting multiple teamdrives"
# Ask the user for their specified remote
echo "Which remote do you want to mount?"
# Accept input and store as variable 'rcloneremote'
read rcloneremote
# Confirm with user the specified remote is correct.
echo "MTDMM will now now try to create a mount for the $rcloneremote Rclone remote. Is this correct? "
select yn in "Yes" "No"; do
  case $tn in
    Yes) make install; break;;
    No ) exit;;
  esac
done


