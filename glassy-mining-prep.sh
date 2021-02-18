#!/bin/bash
# Based on https://gist.github.com/MihailJP/7318694#gistcomment-2162350


set -e

MINING_SPEED = 75
POWER_CAP = 210

# Set power cap to required level
# Set fans to start level
preMiningSetup() {
    eval "nvidia-smi -i 0 -p $POWER_CAP" > /dev/null
    echo "Set power cap to $POWER_CAP W"

    setFanSpeed $MINING_SPEED $1
}


sudo nvidia-smi -i 0 -p 210



setFanSpeed() {
        eval "nvidia-settings -a [gpu:0]/GPUFanControlState=1 -a [fan:0]/GPUTargetFanSpeed=$1 -a [fan:1]/GPUTargetFanSpeed=$1" > /dev/null
        echo "$(date +'%d-%m-%Y %H:%M:%S') Updating fans speed to $1"
}


declare -i gpuTemp

# Set cleanup function (clean up and exit when interrupted)
trap cleanup 1 2 3 15 20

checkGpu(){
        #echo "Checking GPU"
        gpuTemp=$(nvidia-settings -q gpucoretemp | grep '^  Attribute' | grep "gpu:0" | \
                perl -pe 's/^.*?(\d+)\.\s*$/\1/;')
        echo "$(date +'%d-%m-%Y %H:%M:%S') Current GPU temperature: $gpuTemp"

        # Set GPU fan speed
        if   [ $gpuTemp -ge 60 ]; then
                setFanSpeed 100 $1
        elif [ $gpuTemp -ge 50 ]; then
                setFanSpeed 90 $1
        elif [ $gpuTemp -ge 45 ]; then
                setFanSpeed 75 $1
        elif [ $gpuTemp -ge 40 ]; then
                setFanSpeed 60 $1
        else
                setFanSpeed 30 $1
        fi

}

cleanup() {
        eval "nvidia-settings -a [gpu:0]/GPUFanControlState=0"
        exit
}


while : # Loop
do
        checkGpu
        # Interval
        sleep 5
done