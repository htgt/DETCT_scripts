#!/bin/bash

# source this script e.g. source 0-init.sh 11869_8

if [ ! $# == 1 ]; then
    echo "Please specify run and lane in form run_lane"
    echo "e.g. 11869_8"
  return
fi

# set $LSB_DEFAULTGROUP ( currently hard coded to team87-grp )
export LSB_DEFAULTGROUP='team87-grp'

# Set appropriate run_lane and then follow the recipe:
run_lane=$1
export RUN_LANE=$run_lane

# initialise kerberos account ( handles auth for irods commands )
kinit
