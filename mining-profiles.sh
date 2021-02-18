#!/bin/bash

POWER_CAP=210

LOG_PATH = "/home/omen/mining-profiles-$(date +%Y%m%d).log"

#Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BYELLOW='\033[0;93m'
NC='\033[0m' # No Color

# startMiner() {
#     echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${BYELLOW}Starting Miner${NC}" | tee -a "/home/omen/mining-profiles-$(date +%Y%m%d).log"
#     eval "/home/omen/Downloads/technopremium/build/ethminer/ethminer -P stratum1+ssl://0xD352C913a0692688F23045De56EAa3ABac486842.Glassy@eth-de.flexpool.io:5555 --report-hr --verbosity 2 --HWMON 2" | tee -a "/home/omen/ethminer-$(date +%Y%m%d).log"
# }

declare -i fanControlState

fanAuto() {
        fanControlState=$(nvidia-settings -q [gpu:0]/GPUFanControlState | grep '^  Attribute' | grep "gpu:0" | perl -pe 's/^.*?(\d)\.*$/\1/;')
        if [ $fanControlState -ne 0 ]; then
                eval "nvidia-settings -a [gpu:0]/GPUFanControlState=0" > /dev/null
                echo -e "$(date +'%d-%m-%Y %H:%M:%S') Current Fan Speed: ${GREEN}$fanSpeed %${NC}, Setting Fan Speed to ${BYELLOW}Auto${NC}" | tee -a "/home/omen/mining-profiles-$(date +%Y%m%d).log"
        fi
}

declare -i powerLimit
powerCap() {
    powerLimit=$(nvidia-smi --query-gpu=power.limit --format=csv,noheader,nounits | cut -d'.' -f1)

    if [ $powerLimit != $1 ]; then
        echo -e "$(date +'%d-%m-%Y %H:%M:%S') Setting power cap to ${BYELLOW}$1W${NC}" | tee -a "/home/omen/mining-profiles-$(date +%Y%m%d).log"
        eval "sudo nvidia-smi --id=0 --power-limit=$1" > /dev/null
        
    else
        echo -e "$(date +'%d-%m-%Y %H:%M:%S') Power cap already at ${GREEN}$1 W${NC}" | tee -a "/home/omen/mining-profiles-$(date +%Y%m%d).log"
    fi
}

# Emergency cleanup
cleanup() {
        echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}Executing Trap${NC}" | tee -a "/home/omen/mining-profiles-$(date +%Y%m%d).log"

        eval "nvidia-settings --assign [gpu:0]/GPUFanControlState=0" > /dev/null
        echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}Setting Fan Speed to Auto${NC}" | tee -a "/home/omen/mining-profiles-$(date +%Y%m%d).log"
    
        # GPUPowerMizerMode=0 is Adaptive Mode
        echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}Setting automatic P-State control${NC}" | tee -a "/home/omen/mining-profiles-$(date +%Y%m%d).log"
        eval "nvidia-settings --assign [gpu:0]/GPUPowerMizerMode=0" > /dev/null
        

        echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}Setting GPU clock offset to 0MHz${NC}" | tee -a "/home/omen/mining-profiles-$(date +%Y%m%d).log"
        eval "nvidia-settings --assign [gpu:0]/GPUMemoryTransferRateOffset[4]=0" > /dev/null

        echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}Setting GPU memory offset to 0MHz${NC}" | tee -a "/home/omen/mining-profiles-$(date +%Y%m%d).log"
        eval "nvidia-settings --assign [gpu:0]/GPUMemoryTransferRateOffset[4]=0" > /dev/null

        echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}Exit${NC}" | tee -a "/home/omen/mining-profiles-$(date +%Y%m%d).log"
        exit
}

# Set cleanup function (clean up and exit when interrupted)
trap cleanup 1 2 3 15 20

declare -i fanSpeed

#Get fan speed
getFanSpeed() {
        fanSpeed=$(nvidia-smi --query-gpu=fan.speed --format=csv,noheader,nounits)
}

#Control fan
setFanSpeed() {
    getFanSpeed

    if [ $fanSpeed -ne $1 ]; then
        eval "nvidia-settings --assign [gpu:0]/GPUFanControlState=1 --assign [fan:0]/GPUTargetFanSpeed=$1 --assign [fan:1]/GPUTargetFanSpeed=$1" > /dev/null
        echo -e "$(date +'%d-%m-%Y %H:%M:%S') Current Fan Speed: ${GREEN}$fanSpeed%${NC}, Setting Fan Speed to ${BYELLOW}$1%${NC}" | tee -a "/home/omen/mining-profiles-$(date +%Y%m%d).log"
    else
        echo -e "$(date +'%d-%m-%Y %H:%M:%S') Fan Speed already at: ${GREEN}$fanSpeed%${NC}" | tee -a "/home/omen/mining-profiles-$(date +%Y%m%d).log"
    fi
}

gpuClockOffset() {
    echo -e "$(date +'%d-%m-%Y %H:%M:%S') Setting GPU clock offset to ${BYELLOW}$1MHz${NC}" | tee -a "/home/omen/mining-profiles-$(date +%Y%m%d).log"
    eval "nvidia-settings --assign [gpu:0]/GPUGraphicsClockOffset[4]=$1" > /dev/null
}

memRateOffset() {
    echo -e "$(date +'%d-%m-%Y %H:%M:%S') Setting GPU memory offset to ${BYELLOW}$1MHz${NC}" | tee -a "/home/omen/mining-profiles-$(date +%Y%m%d).log"
    eval "nvidia-settings --assign [gpu:0]/GPUMemoryTransferRateOffset[4]=$1" > /dev/null
}

thermThrottleCheck() {
    thermThrottle=$(nvidia-smi --query-gpu=clocks_throttle_reasons.sw_thermal_slowdown --format=csv,noheader,nounits)

    if [[ "$thermThrottle" == "Active" ]]; then
        echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}Thermal Throttle Active, Executing Auto Fans${NC}" | tee -a "/home/omen/mining-profiles-$(date +%Y%m%d).log"
        fanAuto
        sleep 90
    fi
}

tempControl() {
    # Checking fan speed
    getFanSpeed

    # Checking GPU temp
    gpuTemp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)

    # Get Thermal Throttle status
    thermThrottleCheck

    # Set GPU fan speed
    if   [ $gpuTemp -ge 60 ] && [ $fanSpeed -lt 90 ]; then
            echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}GPU Temp >= 60 C, Executing Auto Fans${NC}"  2>&1 | tee -a "/home/omen/mining-profiles-$(date +%Y%m%d).log"
            fanAuto
            # We want to run the fan for some time before moving on
            sleep 30
    elif [ $gpuTemp -ge 52 ] && [ $fanSpeed -lt 90 ]; then
            echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${RED}GPU Temp >= 52 C, Setting Fans to 90%${NC}" 2>&1 | tee -a "/home/omen/mining-profiles-$(date +%Y%m%d).log"
            setFanSpeed "90"
            # We want to run the fan for some time before moving on
            sleep 30
    else
            setFanSpeed $1
    fi
}


#Set profile settings
profile() {
    echo -e "$(date +'%d-%m-%Y %H:%M:%S') Enabling mode: ${GREEN}$1${NC}" | tee -a "/home/omen/mining-profiles-$(date +%Y%m%d).log"
    setFanSpeed $2
    powerCap $3

    # GPUPowerMizerMode=1 is Max Performance mode [level5]
    # echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${BYELLOW}Setting GPU to highest P-State${NC}" | tee -a "/home/omen/mining-profiles-$(date +%Y%m%d).log"
    # eval "nvidia-settings --assign [gpu:0]/GPUPowerMizerMode=1" > /dev/null

    gpuClockOffset $4
    memRateOffset $5
    echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${BYELLOW}$1 mode enabled${NC}" | tee -a "/home/omen/mining-profiles-$(date +%Y%m%d).log"

    echo -e "$(date +'%d-%m-%Y %H:%M:%S') ${GREEN}Running Temp Control${NC}" | tee -a "/home/omen/mining-profiles-$(date +%Y%m%d).log"

    # startMiner
    while :
    do
        tempControl $2
        # Interval
        sleep 10
    done

}

#Menu
mainMenu() {
    modes=(
        "Morning"
        "Office"
        "Lunch"
        "Night"
	"Extension Cold"
	"Extension Warm"
	"Extension Hot"
        "Exit"
    )
    select mode in "${modes[@]}"; do
        case $mode in
            ${modes[0]})
		# ~96 Mh Cold
                profile "Morning" "85" "225" "-400" "2000"
                break
            ;;
            ${modes[1]})
		# ~ 89 Mh
                profile "Office" "65" "215" "-400" "750"
                break
            ;;
            ${modes[2]})
                #pravie to samo co morning ale jest troche szybszy wiatrak
                profile "Lunch" "90" "235" "-400" "2000" 
                break
            ;;
            ${modes[3]})
                # ~89Mh
                profile "Night" "70" "215" "-400" "750"
                break
            ;;
            ${modes[4]})
		profile "Extension Cold" "75" "230" "-400" "2300"
                break
            ;;
	    ${modes[5]})
                profile "Extension Warm" "85" "230" "-400" "2300"
                break
            ;;
	    ${modes[6]})
                profile "Extension Hot" "90" "230" "-400" "2300"
                break
            ;;
	    ${modes[7]})
                exit
            ;;
            *)
                echo -e "${RED}Invalid Option${NC}" | tee -a "/home/omen/mining-profiles-$(date +%Y%m%d).log"
                exit
            ;;
        esac
    done
}
mainMenu
