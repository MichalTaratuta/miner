#!/bin/bash
export DISPLAY=':0'

LOG_PATH = "/home/omen/mining-profiles-$(date +%d%m%Y).log"

#Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BYELLOW='\033[0;93m'
NC='\033[0m' # No Color


declare -i fanControlState

fanAuto() {
    gpuId=$1
    fanControlState=$(nvidia-settings -q [gpu:$gpuId]/GPUFanControlState | grep '^  Attribute' | grep "gpu:$gpuId" | perl -pe 's/^.*?(\d)\.*$/\1/;')
    if [ $fanControlState -ne 0 ]; then
            eval "nvidia-settings -a [gpu:$gpuId]/GPUFanControlState=0" > /dev/null
            echo -e "$(date +'%d-%m-%Y %H:%M:%S') GPU:${GREEN}$gpuId${NC}, Current Fan Speed: ${GREEN}$fanSpeed %${NC}, Setting Fan Speed to ${BYELLOW}Auto${NC}" | tee -a "/home/omen/mining-profiles-$(date +%d%m%Y).log"
    fi
}

declare -i powerLimit
powerCap() {
    gpuId=$2
    powerLimit=$(nvidia-smi --query-gpu=power.limit --format=csv,noheader,nounits --id=$gpuId | cut -d'.' -f1)

    if [ $powerLimit != $1 ]; then
        echo -e "$(date +'%d-%m-%Y %H:%M:%S') GPU:${BYELLOW}$gpuId${NC}, Setting power cap to ${BYELLOW}$1W${NC}" | tee -a "/home/omen/mining-profiles-$(date +%d%m%Y).log"
        eval "sudo nvidia-smi --id=$gpuId --power-limit=$1" > /dev/null

    else
        echo -e "$(date +'%d-%m-%Y %H:%M:%S') GPU:${GREEN}$gpuId${NC}, Power cap already at ${GREEN}$1 W${NC}" | tee -a "/home/omen/mining-profiles-$(date +%d%m%Y).log"
    fi
}

# Emergency cleanup
cleanup() {
        echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}Executing Trap${NC}" | tee -a "/home/omen/mining-profiles-$(date +%d%m%Y).log"

        eval "nvidia-settings --assign [gpu:0]/GPUFanControlState=0" > /dev/null
        echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}Setting Fan Speed to Auto${NC}" | tee -a "/home/omen/mining-profiles-$(date +%d%m%Y).log"

        # GPUPowerMizerMode=0 is Adaptive Mode
        echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}Setting automatic P-State control${NC}" | tee -a "/home/omen/mining-profiles-$(date +%d%m%Y).log"
        eval "nvidia-settings --assign [gpu:0]/GPUPowerMizerMode=0" > /dev/null

        echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}Setting GPU clock offset to 0MHz${NC}" | tee -a "/home/omen/mining-profiles-$(date +%d%m%Y).log"
        eval "nvidia-settings --assign [gpu:0]/GPUMemoryTransferRateOffset[4]=0" > /dev/null

        echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}Setting GPU memory offset to 0MHz${NC}" | tee -a "/home/omen/mining-profiles-$(date +%d%m%Y).log"
        eval "nvidia-settings --assign [gpu:0]/GPUMemoryTransferRateOffset[4]=0" > /dev/null

        echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}Exit${NC}" | tee -a "/home/omen/mining-profiles-$(date +%d%m%Y).log"
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

    if [ $fanSpeed -ne $1 ]; then
        eval "nvidia-settings --assign [gpu:$gpuId]/GPUFanControlState=1 --assign [fan:0]/GPUTargetFanSpeed=$1 --assign [fan:1]/GPUTargetFanSpeed=$1" > /dev/null
        echo -e "$(date +'%d-%m-%Y %H:%M:%S') GPU:${GREEN}$gpuId${NC}, Current Fan Speed: ${GREEN}$fanSpeed%${NC}, Setting Fan Speed to ${BYELLOW}$1%${NC}" | tee -a "/home/omen/mining-profiles-$(date +%d%m%Y).log"
    else
        echo -e "$(date +'%d-%m-%Y %H:%M:%S') GPU:${GREEN}$gpuId${NC}, Fan Speed already at: ${GREEN}$fanSpeed%${NC}" | tee -a "/home/omen/mining-profiles-$(date +%d%m%Y).log"
    fi
}

gpuClockOffset() {
    gpuId=$2
    echo -e "$(date +'%d-%m-%Y %H:%M:%S') GPU:${BYELLOW}$gpuId${NC}, Setting GPU clock offset to ${BYELLOW}$1MHz${NC}" | tee -a "/home/omen/mining-profiles-$(date +%d%m%Y).log"
    eval "nvidia-settings --assign [gpu:$gpuId]/GPUGraphicsClockOffset[4]=$1" > /dev/null
}

memRateOffset() {
    gpuId=$2
    echo -e "$(date +'%d-%m-%Y %H:%M:%S') GPU:${BYELLOW}$gpuId${NC}, Setting GPU memory offset to ${BYELLOW}$1MHz${NC}" | tee -a "/home/omen/mining-profiles-$(date +%d%m%Y).log"
    eval "nvidia-settings --assign [gpu:$gpuId]/GPUMemoryTransferRateOffset[4]=$1" > /dev/null
}

decalre -A thermalThrottle

thermThrottleCheck() {
    gpuId=$1
    thermThrottle=$(nvidia-smi --query-gpu=clocks_throttle_reasons.sw_thermal_slowdown --format=csv,noheader,nounits --id=$gpuId)

    if [[ "$thermThrottle" == "Active" ]]; then
        thermalThrottle[$gpuId] = $gpuId
    fi
}

tempControl() {
    # Get number of GPUs
    numGPUs=$(nvidia-smi --query-gpu=count --format=csv,noheader -id=0)

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
            echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}GPU:$id, Thermal Throttle Active, Executing Auto Fans${NC}" | tee -a "/home/omen/mining-profiles-$(date +%Y%m%d).log"
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
                echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}GPU Temp >= 60 C, Executing Auto Fans${NC}"  2>&1 | tee -a "/home/omen/mining-profiles-$(date +%d%m%Y).log"
                fanAuto
        elif [ $gpuTemp -ge 52 ] && [ $fanSpeed -lt 90 ]; then
                echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}GPU Temp >= 52 C, Setting Fans to 90%${NC}" 2>&1 | tee -a "/home/omen/mining-profiles-$(date +%d%m%Y).log"
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
    echo -e "$(date +'%d-%m-%Y %H:%M:%S') Enabling mode: ${GREEN}$1${NC}, GPU:${GREEN}$gpuId${NC}" | tee -a "/home/omen/mining-profiles-$(date +%d%m%Y).log"
    setFanSpeed ${defaultFanSpeed[$gpuId]} $gpuId
    powerCap $4 $gpuId
    gpuClockOffset $5 $gpuId
    memRateOffset $6 $gpuId
    echo -e "$(date +'%d-%m-%Y %H:%M:%S') GPU:${GREEN}$gpuId${NC}, ${BYELLOW}$1 mode enabled${NC}" | tee -a "/home/omen/mining-profiles-$(date +%d%m%Y).log"
}

getHostname() {
    if [ $HOSTNAME
}

#Menu
mainMenu() {
    modes=(
        "Extension Cold"
        "Extension Warm"
        "Extension Hot"
        "Exit"
    )
    select mode in "${modes[@]}"; do
        case $mode in
            ${modes[0]})
                if [ $HOSTNAME == "micro" ];then
                    # ~122 Mh
                    profile "Extension Cold" "0" "75" "125" "-300" "2500"
                    profile "Extension Cold" "1" "75" "125" "-300" "2500"
                else
                    # ~98 Mh
                    profile "Extension Cold" "0" "75" "230" "-400" "2300"
                done
                break
            ;;
            ${modes[1]})
                if [ $HOSTNAME == "micro" ];then
                    # ~122 Mh
                    profile "Extension Warm" "0" "85" "125" "-400" "2500"
                    profile "Extension Warm" "1" "85" "125" "-400" "2500"
                else
                    # ~96 Mh
                    profile "Extension Warm" "0" "85" "230" "-400" "2300"
                done
                break
                ;;
            ${modes[2]})
                if [ $HOSTNAME == "micro" ];then
                    # ~122 Mh
                    profile "Extension Warm" "0" "90" "125" "-400" "2500"
                    profile "Extension Warm" "1" "90" "125" "-400" "2500"
                else
                    profile "Extension Hot" "0" "90" "230" "-400" "2300"
                done
                break
            ;;
            ${modes[3]})
                exit
            ;;
            *)
                echo -e "${RED}Invalid Option${NC}" | tee -a "/home/omen/mining-profiles-$(date +%d%m%Y).log"
                exit
            ;;
        esac
    done
}
mainMenu

echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${GREEN}Running Temp Control${NC}" | tee -a "/home/omen/mining-profiles-$(date +%d%m%Y).log"
while :
do
    tempControl
    # Interval
    sleep 20
done