#!/bin/bash
export DISPLAY=':0'

#Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BYELLOW='\033[0;93m'
NC='\033[0m' # No Color

USERNAME=$USER

declare -i fanControlState

fanAuto() {
    gpuId=$1
    fanControlState=$(nvidia-settings -q [gpu:$gpuId]/GPUFanControlState | grep '^  Attribute' | grep "gpu:$gpuId" | perl -pe 's/^.*?(\d)\.*$/\1/;')
    if [ $fanControlState -ne 0 ]; then
            eval "nvidia-settings -a [gpu:$gpuId]/GPUFanControlState=0" > /dev/null
            echo -e "$(date +'%d-%m-%Y %H:%M:%S') GPU:$gpuId, Current Fan Speed: ${GREEN}$fanSpeed %${NC}, Setting Fan Speed to ${BYELLOW}Auto${NC}" 2>&1 | tee -a "/home/${USERNAME}/mining-profiles-$(date +%d%m%Y).log"
    fi
}

declare -i powerLimit
powerCap() {
    pCap=$1
    gpuId=$2
    powerLimit=$(nvidia-smi --query-gpu=power.limit --format=csv,noheader,nounits --id=$gpuId | cut -d'.' -f1)

    if [ $powerLimit != $1 ]; then
        echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${BYELLOW}GPU:$gpuId${NC}, Setting power cap to ${BYELLOW}${pCap}W${NC}" 2>&1 | tee -a "/home/${USERNAME}/mining-profiles-$(date +%d%m%Y).log"
        eval "sudo nvidia-smi --id=$gpuId --power-limit=$pCap" > /dev/null
    else
        echo -e "$(date +'%d-%m-%Y %H:%M:%S') GPU:$gpuId, Power cap already at ${GREEN}${pCap}W${NC}" 2>&1 | tee -a "/home/${USERNAME}/mining-profiles-$(date +%d%m%Y).log"
    fi
}

# Emergency cleanup
cleanup() {
        # Get number of GPUs
        numGPUs=$(nvidia-smi --query-gpu=count --format=csv,noheader | sort -u)

        echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}Executing Trap${NC}" 2>&1 | tee -a "/home/${USERNAME}/mining-profiles-$(date +%d%m%Y).log"

        # Loop through each GPU
        for gpuId in $(seq 0 $((numGPUs-1))); do

            eval "nvidia-settings --assign [gpu:$gpuId]/GPUFanControlState=0" > /dev/null
            echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}GPU:$gpuId, Setting Fan Speed to Auto${NC}" | tee -a "/home/${USERNAME}/mining-profiles-$(date +%d%m%Y).log"

            # GPUPowerMizerMode=0 is Adaptive Mode
            echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}GPU:$gpuId, Setting automatic P-State control${NC}" 2>&1 | tee -a "/home/${USERNAME}/mining-profiles-$(date +%d%m%Y).log"
            eval "nvidia-settings --assign [gpu:$gpuId]/GPUPowerMizerMode=0" > /dev/null

            if [ $HOSTNAME == "black8gpu" ];then
                echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}GPU:$gpuId, Setting GPU clock offset to 0MHz${NC}" 2>&1 | tee -a "/home/${USERNAME}/mining-profiles-$(date +%d%m%Y).log"
                eval "nvidia-settings --assign [gpu:$gpuId]/GPUGraphicsClockOffsetAllPerformanceLevels=0" > /dev/null

                echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}GPU:$gpuId, Setting GPU memory offset to 0MHz${NC}" 2>&1 | tee -a "/home/${USERNAME}/mining-profiles-$(date +%d%m%Y).log"
                eval "nvidia-settings --assign [gpu:$gpuId]/GPUMemoryTransferRateOffsetAllPerformanceLevels=0" > /dev/null
            else
                echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}GPU:$gpuId, Setting GPU clock offset to 0MHz${NC}" 2>&1 | tee -a "/home/${USERNAME}/mining-profiles-$(date +%d%m%Y).log"
                eval "nvidia-settings --assign [gpu:$gpuId]/GPUGraphicsClockOffset[4]=0" > /dev/null

                echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}GPU:$gpuId, Setting GPU memory offset to 0MHz${NC}" 2>&1 | tee -a "/home/${USERNAME}/mining-profiles-$(date +%d%m%Y).log"
                eval "nvidia-settings --assign [gpu:$gpuId]/GPUMemoryTransferRateOffset[4]=0" > /dev/null
            fi
        done
        echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}Exit${NC}" 2>&1 | tee -a "/home/${USERNAME}/mining-profiles-$(date +%d%m%Y).log"
        exit
}

# Set cleanup function (clean up and exit when interrupted)
trap cleanup 1 2 3 15 20

declare -i fanSpeed

#Get fan speed
getFanSpeed() {
    gpuId=$1
    fanSpeed=$(nvidia-smi --query-gpu=fan.speed --format=csv,noheader,nounits --id=$gpuId)
}

#Control fan
setFanSpeed() {
    gpuId=$2
    getFanSpeed $gpuId

    if [ $gpuId == 0 ]; then
        fanIdOne=0
        fanIdTwo=1
    elif [ $gpuId == 1 ]; then
        fanIdOne=2
        fanIdTwo=3
    elif [ $gpuId == 2 ]; then
        fanIdOne=4
        fanIdTwo=5
    elif [ $gpuId == 3 ]; then
        fanIdOne=6
        fanIdTwo=7
    elif [ $gpuId == 4 ]; then
        fanIdOne=8
        fanIdTwo=9
    elif [ $gpuId == 5 ]; then
        fanIdOne=10
        fanIdTwo=11
    elif [ $gpuId == 6 ]; then
        fanIdOne=12
        fanIdTwo=13
    elif [ $gpuId == 7 ]; then
        fanIdOne=14
        fanIdTwo=15
    else
        echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}Unknown GPU id $gpuId, Executing Trap${NC}" 2>&1 | tee -a "/home/${USERNAME}/mining-profiles-$(date +%d%m%Y).log"
        cleanup
    fi

    if [ $fanSpeed -ne $1 ]; then
        eval "nvidia-settings --assign [gpu:$gpuId]/GPUFanControlState=1 --assign [fan:$fanIdOne]/GPUTargetFanSpeed=$1 --assign [fan:$fanIdTwo]/GPUTargetFanSpeed=$1" > /dev/null
        echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${BYELLOW}GPU:$gpuId${NC}, Current Fan Speed: ${GREEN}$fanSpeed%${NC}, Setting Fan Speed to ${BYELLOW}$1%${NC}" 2>&1 | tee -a "/home/${USERNAME}/mining-profiles-$(date +%d%m%Y).log"
    else
        echo -e "$(date +'%d-%m-%Y %H:%M:%S') GPU:$gpuId, Fan Speed already at: ${GREEN}$fanSpeed%${NC}" 2>&1 | tee -a "/home/${USERNAME}/mining-profiles-$(date +%d%m%Y).log"
    fi
}

gpuClockOffset() {
    gpuOffset=$1
    gpuId=$2

    echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${BYELLOW}GPU:$gpuId${NC}, Setting GPU clock offset to ${BYELLOW}${gpuOffset}MHz${NC}" 2>&1 | tee -a "/home/${USERNAME}/mining-profiles-$(date +%d%m%Y).log"
    if [ $HOSTNAME == "black8gpu" ];then
        eval "nvidia-settings --assign [gpu:$gpuId]/GPUGraphicsClockOffsetAllPerformanceLevels=$gpuOffset" > /dev/null
    else
        eval "nvidia-settings --assign [gpu:$gpuId]/GPUGraphicsClockOffset[4]=$gpuOffset" > /dev/null
    fi

}

memRateOffset() {
    memOffset=$1
    gpuId=$2

    echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${BYELLOW}GPU:$gpuId${NC}, Setting GPU memory offset to ${BYELLOW}${memOffset}MHz${NC}" 2>&1 | tee -a "/home/${USERNAME}/mining-profiles-$(date +%d%m%Y).log"
    if [ $HOSTNAME == "black8gpu" ];then
        eval "nvidia-settings --assign [gpu:$gpuId]/GPUMemoryTransferRateOffsetAllPerformanceLevels=$memOffset" > /dev/null
    else
        eval "nvidia-settings --assign [gpu:$gpuId]/GPUMemoryTransferRateOffset[4]=$memOffset" > /dev/null
    fi
}

declare -A thermalThrottle

thermThrottleCheck() {
    gpuId=$1
    thermThrottle=$(nvidia-smi --query-gpu=clocks_throttle_reasons.sw_thermal_slowdown --format=csv,noheader,nounits --id=$gpuId)

    if [[ "$thermThrottle" == "Active" ]]; then
        thermalThrottle[$gpuId] = $gpuId
    fi
}

tempControl() {
    # Get number of GPUs
    numGPUs=$(nvidia-smi --query-gpu=count --format=csv,noheader | sort -u)

    # Loop through each GPU
    for gpuId in $(seq 0 $((numGPUs-1))); do
        # Checking fan speed
        getFanSpeed $gpuId

        # Checking GPU temp
        gpuTemp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits --id=$gpuId)

        # Get Thermal Throttle status
        thermThrottleCheck $gpuId
    done

    #Executing thermal control
    if [ ! -z ${thermalThrottle[@]} ]; then
        for id in ${thermalThrottle[@]}; do
            echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}GPU:$id, Thermal Throttle Active, Executing Auto Fans${NC}" 2>&1 | tee -a "/home/${USERNAME}/mining-profiles-$(date +%Y%m%d).log"
            fanAuto $id
        done
        sleep 90
        unset thermalThrottle
    fi

    # Loop through each GPU
    for gpuId in $(seq 0 $((numGPUs-1))); do
        # Checking fan speed
        getFanSpeed $gpuId

        # Checking GPU temp
        gpuTemp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits --id=$gpuId)

        # Set GPU fan speed
        if [ $gpuTemp -ge 60 ] && [ $fanSpeed -lt 90 ]; then
                echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}GPU:$gpuId Temp >= 60 C, Executing Auto Fans${NC}"  2>&1 | tee -a "/home/${USERNAME}/mining-profiles-$(date +%d%m%Y).log"
                # Looks like 3060 nd 3070 have high temp tresholds i.e 60C for the fans to kick in
                if [ $HOSTNAME == "glassy" ];then
                    fanAuto
                else
                    setFanSpeed "90" $gpuId
                fi
        elif [ $gpuTemp -ge 52 ] && [ $fanSpeed -lt 90 ]; then
                echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}GPU:$gpuId Temp >= 52 C, Setting Fans to 90%${NC}" 2>&1 | tee -a "/home/${USERNAME}/mining-profiles-$(date +%d%m%Y).log"
                setFanSpeed "90" $gpuId
        else
            setFanSpeed ${defaultFanSpeed[$gpuId]} $gpuId

        fi
    done

}

declare -A defaultFanSpeed
#Set profile settings
profile() {
    gpuId=$2
    defaultFanSpeed[$gpuId]=$3
    echo -e "$(date +'%d-%m-%Y %H:%M:%S') GPU:$gpuId, Enabling mode: ${GREEN}$1${NC}" 2>&1 | tee -a "/home/${USERNAME}/mining-profiles-$(date +%d%m%Y).log"
    setFanSpeed ${defaultFanSpeed[$gpuId]} $gpuId
    powerCap $4 $gpuId
    gpuClockOffset $5 $gpuId
    memRateOffset $6 $gpuId
    echo -e "$(date +'%d-%m-%Y %H:%M:%S') GPU:$gpuId, ${BYELLOW}$1 mode enabled${NC}" 2>&1 | tee -a "/home/${USERNAME}/mining-profiles-$(date +%d%m%Y).log"
}

#Menu
mainMenu() {
    modes=(
        "Extension Cold"
        "Extension Warm"
        "Extension Hot"
        "Extension Experimental"
        "Exit"
    )
    select mode in "${modes[@]}"; do
        case $mode in
            ${modes[0]})
                if [ $HOSTNAME == "micro" ];then
                    # ~122 Mh
                    profile "Extension Cold" "0" "70" "130" "-300" "2200"
                    profile "Extension Cold" "1" "70" "125" "-300" "2500"
                elif [ $HOSTNAME == "precision" ];then
                    profile "Extension Cold" "0" "70" "125" "-300" "2400"
                    profile "Extension Cold" "1" "70" "125" "-300" "2400"
                    profile "Extension Cold" "2" "70" "125" "-300" "2400"
                    profile "Extension Cold" "3" "70" "125" "-300" "2400"
                elif [ $HOSTNAME == "black8gpu" ];then
                    profile "Extension Cold" "0" "70" "125" "-300" "2400" #3060
                    profile "Extension Cold" "1" "70" "125" "-300" "2500" #3070
                    profile "Extension Cold" "2" "70" "130" "-300" "2200" #3070 in PCI 0 ID swapped to 2 in xorg.conf
                    profile "Extension Cold" "3" "70" "125" "-300" "2400" #3060
                    profile "Extension Cold" "4" "70" "125" "-300" "2400" #3060
                    profile "Extension Cold" "5" "70" "125" "-300" "2400" #3060
                    profile "Extension Cold" "6" "70" "125" "-300" "2400" #3060
                else
                    # ~96 Mh
                    profile "Extension Cold" "0" "75" "230" "-400" "2000"
                fi
                break
            ;;
            ${modes[1]})
                if [ $HOSTNAME == "micro" ];then
                    # ~122 Mh
                    profile "Extension Warm" "0" "80" "130" "-300" "2200"
                    profile "Extension Warm" "1" "80" "125" "-300" "2500"
                elif [ $HOSTNAME == "precision" ];then
                    profile "Extension Warm" "0" "80" "125" "-300" "2400"
                    profile "Extension Warm" "1" "80" "125" "-300" "2400"
                    profile "Extension Warm" "2" "80" "125" "-300" "2400"
                    profile "Extension Warm" "3" "80" "125" "-300" "2400"
                elif [ $HOSTNAME == "black8gpu" ];then
                    profile "Extension Warm" "0" "80" "125" "-300" "2400" #3060
                    profile "Extension Warm" "1" "80" "125" "-300" "2500" #3070
                    profile "Extension Warm" "2" "80" "130" "-300" "2200" #3070 in PCI 0 ID swapped to 2 in xorg.conf
                    profile "Extension Warm" "3" "80" "125" "-300" "2400" #3060
                    profile "Extension Warm" "4" "80" "125" "-300" "2400" #3060
                    profile "Extension Warm" "5" "80" "125" "-300" "2400" #3060
                    profile "Extension Warm" "6" "80" "125" "-300" "2400" #3060
                else
                    # ~96 Mh
                    profile "Extension Warm" "0" "85" "230" "-400" "2000"
                fi
                break
            ;;
            ${modes[2]})
                if [ $HOSTNAME == "micro" ];then
                    # ~122 Mh
                    profile "Extension Hot" "0" "85" "130" "-300" "2200"
                    profile "Extension Hot" "1" "85" "125" "-300" "2500"
                elif [ $HOSTNAME == "precision" ];then
                    profile "Extension Hot" "0" "90" "125" "-300" "2400"
                    profile "Extension Hot" "1" "90" "125" "-300" "2400"
                    profile "Extension Hot" "2" "90" "125" "-300" "2400"
                    profile "Extension Hot" "3" "90" "125" "-300" "2400"
                elif [ $HOSTNAME == "black8gpu" ];then
                    profile "Extension Hot" "0" "80" "125" "-300" "2400" #3060
                    profile "Extension Hot" "1" "80" "125" "-300" "2500" #3070
                    profile "Extension Hot" "2" "80" "130" "-300" "2200" #3070 in PCI 0 ID swapped to 2 in xorg.conf
                    profile "Extension Hot" "3" "80" "125" "-300" "2400" #3060
                    profile "Extension Hot" "4" "80" "125" "-300" "2400" #3060
                    profile "Extension Hot" "5" "80" "125" "-300" "2400" #3060
                    profile "Extension Hot" "6" "80" "125" "-300" "2400" #3060
                else
                    profile "Extension Hot" "0" "90" "230" "-400" "2000"
                fi
                break
            ;;
            ${modes[3]})
                if [ $HOSTNAME == "black8gpu" ];then
                    profile "Extension Hot" "0" "40" "125" "-300" "2400" #3060
                    profile "Extension Hot" "1" "40" "125" "-300" "2500" #3070
                    profile "Extension Hot" "2" "40" "130" "-300" "2200" #3070 in PCI 0 ID swapped to 2 in xorg.conf
                    profile "Extension Hot" "3" "40" "125" "-300" "2400" #3060
                    profile "Extension Hot" "4" "40" "125" "-300" "2400" #3060
                    profile "Extension Hot" "5" "40" "125" "-300" "2400" #3060
                    profile "Extension Hot" "6" "40" "125" "-300" "2400" #3060
                fi
                break
            ;;
            ${modes[4]})
                exit
            ;;
            *)
                echo -e "${RED}Invalid Option${NC}" 2>&1 | tee -a "/home/${USERNAME}/mining-profiles-$(date +%d%m%Y).log"
                exit
            ;;
        esac
    done
}
mainMenu

echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${GREEN}Running Temp Control${NC}" 2>&1 | tee -a "/home/${USERNAME}/mining-profiles-$(date +%d%m%Y).log"
while :
do
    tempControl
    # Interval
    sleep 20
done
