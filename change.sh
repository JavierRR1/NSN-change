#!/bin/bash
# Change Location Code of an MP and any related files


# Prompt the user to enter the new location code
read -p "Enter the new location code: " value


CURRENT_LOCATION_CODE=$(</var/lib/switchboard/data/location)
CURRENT_HQ_VPN_IP=$(</var/lib/switchboard/data/network.hq)
CURRENT_LOCATION_CODE=$(</var/lib/switchboard/data/location)
CURRENT_HOSTNAME="$(hostname)"
MP_STATE=$(</var/lib/switchboard/data/keepalived.state)
new_location_code=$value


# Prompt the user to confirm the value
read -p "Confirm the new location code (Y/N): " confirm
# Check if the user confirmed the value
if [ "${confirm^^}" == "Y" ]; then

validate_args(){
  if [[ -z "$new_location_code" ]]; then
    echo "No new_location_code argument passed"
    echo "$USAGE"
    exit 1
  fi
  if [[ "$MP_STATE" != "MASTER" && "$MP_STATE" != "SLAVE" ]]; then
    echo "Please check the MP_STATE data file as there seems to be a problem with it"
    exit 1
  fi
}

change_location_code(){
  if [[ "$CURRENT_LOCATION_CODE" == "$new_location_code" ]]; then
    echo " Old code is already New code"
    exit 0
  fi
  mp_ip_fourth_octet=$(/usr/local/switchboard/shell/ip-address.sh | cut -d '.' -f 4)
  new_hostname="$new_location_code-$mp_ip_fourth_octet"
  echo "Old code     : $CURRENT_LOCATION_CODE"
  echo "Old Hostname : $CURRENT_HOSTNAME"
  echo "New code     : $new_location_code"
  echo "New Hostname : $new_hostname"
  echo;
  echo "Changing location code"
  read -p "Are you sure? [N/y]" -n 1 -r
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
  echo;
  read -p "Are you REALLY sure? [N/y]" -n 1 -r
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
  echo;

  # Sleep to give a moments extra thought
  echo "Executing as $MP_STATE"
  sleep 3

  # Change location code
  switchboard location "$new_location_code"

  # Replace location code in ccommand file
  sudo sed -i "s/$CURRENT_LOCATION_CODE/$new_location_code/" /etc/ccommand/ccommand.conf

  # Prepare for new manifest
  rm -f /var/lib/switchboard/cache/jwt.json
  rm -rf /var/lib/switchboard/package/"$CURRENT_LOCATION_CODE"/*
  rm -rf /var/lib/switchboard/muppet/api/*

  # Ask HQ for new manifest
  switchboard update -v

  # Inform HQ of new_device_name
  switchboard hq "$CURRENT_HQ_VPN_IP" "$new_hostname"

  # Inform HQ of self
  switchboard heartbeat -v

  # Inform MP to run Umpa
  rm /var/lib/umpa/status.json ; umpa -v
	
  # Sendreport to update IOT
  sendreport -v 

  # prime will require a manual reboot after but second will reboot automatically
  if [[ "$MP_STATE" == "MASTER" ]]; then
    sb package -v
    echo " - Leave this device online"
    echo " - Run tool on remaining second devices"
    echo " - Reboot this device manually when all second devices have finished content download"
  else
    sudo reboot
  fi
}

main(){
  validate_args
  change_location_code
}

main
 
  echo "Location code changed successfully."
else
  echo "This procedure was cancelled"
fi
