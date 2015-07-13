#!/usr/bin/ksh
#Name:EMC_Disk_Info_Collector.sh   Date:10/12/2014 
#Description: Prints information of EMC Powerpath disks inside a VIOS Server, relating to the lpar using it.
#Author: Wellington Silva wellsilva.email@gmail.com
HMC='HMC_ADDRESS'		#DNS Name or ip of the HMC
HMC_MANAG_SYS="Managed sys name"  	# Name of the VIOS's Managed System 
BASE_DIR='/home/suporte/DISK'		# Put a dir where the script can use to output and write some temporary data
LSMAP="$BASE_DIR/tmp/lsmap_tmp.txt"
IDS_LPARES_HMC="$BASE_DIR/tmp/ids_lpares_hmc.txt"
IDS_LPARES_LSMAP="$BASE_DIR/tmp/ids_lpares.txt"
#Output csv file
OUT_CSV="$BASE_DIR/log/lev_disks.csv"

#aliases used by the script
alias lsmap='/usr/ios/cli/ioscli lsmap'

get_vadapters ()
{
	VADAPTERS=$(lsmap -all -field svsa clientid -fmt ";" | sed 's/\\//g')
}

print_vhost_disks()
{
	get_vadapters
	echo "$VADAPTERS" | cut -d \; -f1 | while read VHOST
			do
					DISKS=$(lsmap -fmt ";" -field backing -type disk -vadapter $VHOST | sed 's/\\//g')
					echo "$(echo "$VADAPTERS"| grep $VHOST):$DISKS"
			done
}

lpar_id_to_dec()
{
    ID=$(echo $1 | cut -d \x -f2 | awk '{print toupper($0)}')
    echo "ibase=16; $ID" | bc
}


print_lparname_ids()
{
	echo "$VHOSTS_DISKS" |grep -w $1 | cut -d \: -f1 | sed 's/;/ /g' | read VHOST LPAR_ID
	LPAR_ID_DEC=$(lpar_id_to_dec $LPAR_ID)
	CHARS=$(echo $LPAR_ID_DEC | wc -c )
	if [ $CHARS -lt 2 ]
			then
					LPAR_ID_DEC='NO_LPAR_NAME'
					LPAR_NAME='NO_LPAR_ID'
			else
					LPAR_NAME=$(grep -w ^$LPAR_ID_DEC $IDS_LPARES_HMC | cut -d \: -f2)
	fi
}

main()
{
        #Create a temporary file with the lsmap output.
        lsmap -all > $LSMAP

        #Get ids from HMC
        ssh hscroot@"$HMC" "lssyscfg -m $HMC_MANAG_SYS -r lpar -F 'lpar_id:name'"  | sort -n > $IDS_LPARES_HMC

        #Create a lpar list
        grep -i vhost $LSMAP | awk '{print $3}' | cut -d \x -f2|tr [a-z] [A-Z] > $IDS_LPARES_LSMAP

        #Get the list of luns allocated to the hmc from powerpath
        DISK_LIST=$(powermt display dev=all | grep hdiskpower | cut -d \= -f2)

        #Creates a list of the virtual scsi adapters on VIOS
        VHOSTS_DISKS=$(print_vhost_disks)

        #Prints the information to a csv file
        for DSK in $(echo $DISK_LIST)
        do
                LOG_ID=$(powermt display dev=$DSK |grep Log | awk -F= '{print $2}')
                FPATHS=$(powermt display dev=$DSK |grep fsc| wc -l)
                IDSTORAGE=$(powermt display dev=$DSK | grep Symme | awk '{ print $2 }' | cut -d \= -f2 | cut -c 9-12)
                DVTD=$(grep -wp $DSK $LSMAP | grep VTD | awk  '{ print $2}')
                powermt display dev=$DSK |grep fsc | awk '{ print $2,$3,$5}' | while read PPATH PHDISK PPORT
                do
                        FCS=$(echo $PPATH | awk '{print $1}' | sed 's/fscsi/fcs/g')
                        PWWN=$(lscfg -vl $FCS | grep Net | awk -F1 '{print 1$2}')
                        STGPORT=$(echo $PPORT)
                        CHARS=$(echo $DVTD | wc -c)
                        if [ $CHARS -lt 2 ]
                                then
                                        DVTD='NOT_ALLOCATED'
                        fi
                        print_lparname_ids "$DSK"
                        echo "$LPAR_NAME $LPAR_ID_DEC $DSK $LOG_ID $FPATHS $DVTD $FCS $PWWN $STGPORT $IDSTORAGE" | sed 's/  */;/g'
                done
        done > $OUT_CSV
        rm -f $LSMAP
}
main && exit 0
