#!/bin/bash
# Device/session verification tool
#clear
#set -x
filename=$(pwd)/aql-`hostname`"_"`date +%Y-%m-%d`".txt"
#filename=$HOME/MW/aql-`hostname`"_"`date +%Y-%m-%d`".txt"
#filename=$HOME/aql-`hostname`"_"`date +%Y-%d-%m_%H:%M:%S`".txt"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

#********************************************************************************************
# Function to provide input data
#********************************************************************************************
function input_data() {
echo "VERIFICATIN TOOL (Gx, Rx, PDU session only), ver 0.1 10.2023"
echo "Please find output at "$filename
COLUMNS=12
echo "*******************************************"
PS3='Please enter your choice: '
options1=("e164" "imsi" "IPv4" "IPv6" "SessionId" "DeviceId" "Quit")
select opt in "${options1[@]}"
do
	case $opt in
		"e164"|"imsi"|"IPv4"|"IPv6"|"SessionId"|"DeviceId")
			sub_type=$opt
			break
			;;
		"Quit")
			echo "Bye"
			exit	
			;;
		*) echo "invalid option $REPLY";;
	esac
done
echo "*******************************************"
unset COLUMNS
read -p "Enter value of $sub_type: " sub_value

case $sub_type in
	"e164")
		e164=$sub_value
		exist_sub=0
		echo "********** Input data: e164 - " $e164 " **********" >> $filename
		;;
	"imsi")
		imsi=$sub_value
		exist_sub=1
		echo "********** Input data: imsi - " $imsi " **********" >> $filename
		;;
	"IPv4")
		addr2hex_IPv4 $sub_value
		echo "********** Input data: IPv4 - " $sub_value " **********" >> $filename
		;;
	"IPv6")
		addr2hex_IPv6 $sub_value
		echo "********** Input data: IPv6 - " $sub_value " **********" >> $filename
		;;
	"SessionId")
		echo "********** Input data: SessionId - " $sub_value " **********" >> $filename
		;;
	"DeviceId")
		echo "********** Input data: DeviceId - " $sub_value " **********" >> $filename
		;;
	*)
		;;
esac
echo "*******************************************"
}

#********************************************************************************************
# Function to convert IPv6 value to DB format
#********************************************************************************************
function addr2hex_IPv6() {
userIPv6=`echo $1 |cut -d '/' -f1 | awk '{if(NF<8){inner = "0"; for(missing = (8 - NF);missing>0;--missing){inner = inner ":0"}; if($2 == ""){$2 = inner} else if($3 == ""){$3 = inner} else if($4 == ""){$4 = inner} else if($5 == ""){$5 = inner} else if($6 == ""){$6 = inner} else if($7 == ""){$7 = inner}}; print $0}' FS=":" OFS=":" | awk '{for(i=1;i<9;++i){len = length($(i)); if(len < 1){$(i) = "0000"} else if(len < 2){$(i) = "000" $(i)} else if(len < 3){$(i) = "00" $(i)} else if(len < 4){$(i) = "0" $(i)} }; print $0}' FS=":" OFS=":"`
userIPv6=`echo ${userIPv6^^} |tr -d ':'`
}

#********************************************************************************************
# Function to convert IPv6 value to addr format
#********************************************************************************************
function hex2addr_IPv6() {
ipv6=""
delim=""
tymIPv6=`echo ${1^^} |tr -d ' '`
myhexIP=`echo $tymIPv6 | sed 's/\(....\)/\1 /g'`
IFS=' ' read -ra my_array <<< "$myhexIP"
for i in "${my_array[@]}"
do
        x=0x$i
        octet=`printf '%01x' $x` 
        ipv6+=$delim$octet
        delim=":"
done
ipv6+="/"$2
#echo $ipv4
}

#********************************************************************************************
# Function to convert IPv4 value to db format
#********************************************************************************************
function addr2hex_IPv4() {
IP_ADDR=$1
userIPv4=`printf '%02X' ${IP_ADDR//./ }` #dec to hex
#echo $userIPv4
}

#********************************************************************************************
# Function to convert IPv4 value to addr format
#********************************************************************************************
function hex2addr_IPv4() {
# printf '%d.%d.%d.%d\n' $(echo 80D00297 | sed 's/../0x& /g')
delim=""
ipv4=""
myhexIP=`echo $1 | sed 's/\(..\)/\1 /g'`
IFS=' ' read -ra my_array <<< "$myhexIP"
for i in "${my_array[@]}"
do
        x=0x$i
        octet=`printf '%01u' $x` # hex to dec (01 means no zeros before number - minimum number of digits)
        ipv4+=$delim$octet
        delim="."
done
#echo $ipv4
}

#********************************************************************************************
# Function to check dsc.SmDevice to receive home SPS
#********************************************************************************************
function check_device_home() {
printf "*** Check SmDevice for "$1" ("$2"):"
line0=`aql -h ${HOSTNAME/oame/db} -c "select * from dsc.SmDevice where $1='$2'" -o json |head -n -9 |sed -e '1,4d' |jq -r '.siteId'`
status0=`aql -h ${HOSTNAME/oame/db} -c "select * from dsc.SmDevice where $1='$2'" -o json |head -n -2 |sed -e '1,2d' |jq '.[1] | .[].Status' 2> /dev/null`
count0=`aql -h ${HOSTNAME/oame/db} -c "select * from dsc.SmDevice where $1='$2'" -o json |head -n -2 |sed -e '1,2d' |jq '.[0] | length' 2> /dev/null`
if [[ $status0 == "0" ]] && [[ $line3 != "" ]]
then
	if [[ $count0 == "1" ]]
	then
		homeSPS=$line0	
		printf " ${GREEN}[OK]${NC} *** (siteId="$homeSPS")\n"
		echo "Record at dsc.SmDevice for " $1 " = " $2 "exists"  >> $filename
		echo "siteId - " $homeSPS >> $filename
	else
		printf " ${YELLOW}[WARNING]${NC} *** (more than 1 record)\n"
		echo "More than 1 record at dsc.SmDevice for " $1 " = " $2 "exists"  >> $filename
	fi
else
	printf " ${RED}[FAIL]${NC} *** \n"
	echo "Lack of record at dsc.SmDevice for " $1 " = " $2  >> $filename
fi
}

#********************************************************************************************
# Function to check dscglobal.Device_e164 / dscglobal.Device_imsi set
#********************************************************************************************
function check_device_subscription() {
printf "*** Check Device_"$1" ("$2"):"
line1=`aql -h ${HOSTNAME/oame/db} -c "select * from dscglobal.Device_$1 where PK='$2'" |grep MAP 2> /dev/null`
status1=`aql -h ${HOSTNAME/oame/db} -c "select * from dscglobal.Device_$1 where PK='$2'" -o json |head -n -2 |sed -e '1,2d' |jq '.[1] | .[].Status' 2> /dev/null`
count1=`aql -h ${HOSTNAME/oame/db} -c "select * from dscglobal.Device_$1 where PK='$2'" -o json |head -n -2 |sed -e '1,2d' |jq '.[0] | length' 2> /dev/null`
if [[ $status1 == "0" ]] && [[ $line1 != "" ]]
then
	if [[ $count1 == "1" ]]
	then
		dev_name=`echo $line1 |awk -F "{" '{print $2}' |awk -F ":" '{print $1}' |awk -F "\"" '{print $2}'`
		pk_dec=`echo $line1 |awk -F "{" '{print $2}' |awk -F ":" '{print $2}' |awk -F "}" '{print $1}'`
		printf " ${GREEN}[OK]${NC} *** (club id="$pk_dec", device_name="$dev_name")\n"
		echo "Record at dscglobal.Device_" $1 " for " $2 "exists"  >> $filename
		echo "dev_name - " $dev_name >> $filename
		echo "pk_dec - " $pk_dec >> $filename
		sets_state[$exist_sub]=1
	else
		printf " ${YELLOW}[WARNING]${NC} *** (more than 1 record)\n"
		echo "More than 1 record at at dscglobal.Device_" $1 " for " $2  >> $filename
		sets_state[$exist_sub]=$count1
	fi
else 
	printf " ${RED}[FAIL]${NC} *** \n"
	echo "Lack of record at dscglobal.Device_" $1 " for " $2  >> $filename
	sets_state[$exist_sub]=0
fi 
}

#********************************************************************************************
# Function to check dscglobal.DevicePar_id set
#********************************************************************************************
function check_devicePair_id() {
printf "*** Check DevicePair_id ("$1"):"
line2=`aql -h ${HOSTNAME/oame/db} -c "select * from dscglobal.DevicePar_id where PK='$1'" |head -5 | tail -1 2> /dev/null`
status2=`aql -h ${HOSTNAME/oame/db} -c "select * from dscglobal.DevicePar_id where PK='$1'" -o json |head -n -2 |sed -e '1,2d' |jq '.[1] | .[].Status' 2> /dev/null`
count2=`aql -h ${HOSTNAME/oame/db} -c "select * from dscglobal.DevicePar_id where PK='$1'" -o json |head -n -2 |sed -e '1,2d' |jq '.[0] | length' 2> /dev/null`
if [[ $status2 == "0" ]] && [[ $line2 != "" ]]
then
	if [[ $count2 == "1" ]]
	then
		pk_dec2=`echo $line2 |tr -d '|' |tr -d ' '`
		printf " ${GREEN}[OK]${NC} *** (club_id="$pk_dec2")\n"
		echo "Record at dscglobal.DevicePar_id for " $1 "exists"  >> $filename
		echo "pk_dec - " $pk_dec2 >> $filename
		sets_state[2]=1
	else
		printf " ${YELLOW}[WARNING]${NC} *** (more than 1 record)\n"
		echo "More than 1 record at at dscglobal.DevicePar_id for " $1  >> $filename
		sets_state[2]=$count2
	fi
else
	printf " ${RED}[FAIL]${NC} *** \n"
	echo "Lack of record at dscglobal.DevicePar_id for " $1  >> $filename
	sets_state[2]=0
fi
}

#********************************************************************************************
# Function to check dscglobal.Device_deviceName set
#********************************************************************************************
function check_device_deviceName() {
printf "*** Check Device_deviceName ("$1"):"
line3=`aql -h ${HOSTNAME/oame/db} -c "select * from dscglobal.Device_deviceName where PK='$1'" |grep '||' 2> /dev/null`
status3=`aql -h ${HOSTNAME/oame/db} -c "select * from dscglobal.Device_deviceName where PK='$1'" -o json |head -n -2 |sed -e '1,2d' |jq '.[1] | .[].Status' 2> /dev/null`
count3=`aql -h ${HOSTNAME/oame/db} -c "select * from dscglobal.Device_deviceName where PK='$1'" -o json |head -n -2 |sed -e '1,2d' |jq '.[0] | length' 2> /dev/null`
if [[ $status3 == "0" ]] && [[ $line3 != "" ]]
then
	if [[ $count3 == "1" ]]
	then
		pk_hex=`echo $line3 |awk -F "\"" '{print $2}' |awk -F "|" '{print $3}'`
		printf " ${GREEN}[OK]${NC} *** (club_id_hex="$pk_hex")\n"
		echo "Record at dscglobal.DeviceName for " $1 "exists"  >> $filename
		echo "pk_hex - " $pk_hex >> $filename
		sets_state[3]=1
	else
		printf " ${YELLOW}[WARNING]${NC} *** (more than 1 record)\n"
		echo "More than 1 record at at dscglobal.Device_deviceName for " $1  >> $filename
		sets_state[3]=$count3
	fi
else
	printf " ${RED}[FAIL]${NC} *** \n"
	echo "Lack of record at dscglobal.Device_deviceName for " $1  >> $filename
	sets_state[3]=0
fi
}

#********************************************************************************************
# Function to check dscglobal.DeviceCustomDataPar_id set
#********************************************************************************************
function check_deviceCustomDataPar_id() {
printf "*** Check DeviceCustomDataPar_id ("$1"):"
line4=`aql -h ${HOSTNAME/oame/db} -c "select * from dscglobal.DeviceCustomDataPar_id where PK='$1'" |head -5 | tail -1 2> /dev/null`
status4=`aql -h ${HOSTNAME/oame/db} -c "select * from dscglobal.DeviceCustomDataPar_id where PK='$1'" -o json |head -n -2 |sed -e '1,2d' |jq '.[1] | .[].Status' 2> /dev/null`
count4=`aql -h ${HOSTNAME/oame/db} -c "select * from dscglobal.DeviceCustomDataPar_id where PK='$1'" -o json |head -n -2 |sed -e '1,2d' |jq '.[0] | length' 2> /dev/null`
if [[ $status4 == "0" ]] && [[ $line4 != "" ]]
then
	if [[ $count4 == "1" ]]
	then
		pk_dec4=`echo $line4 |tr -d '|' |tr -d ' '`
		printf " ${GREEN}[OK]${NC} *** (club_id="$pk_dec4")\n"
		echo "Record at dscglobal.DeviceCustomDataPar_id for " $1 "exists"  >> $filename
		echo "pk_dec - " $pk_dec4 >> $filename
		sets_state[4]=1
	else
		printf " ${YELLOW}[WARNING]${NC} *** (more than 1 record)\n"
		echo "More than 1 record at at dscglobal.DeviceCustomDataPar_id for " $1  >> $filename
		sets_state[4]=$count4
	fi
else
	printf " ${RED}[FAIL]${NC} *** \n"
	echo "Lack of record at dscglobal.DeviceCustomDataPar_id for " $1  >> $filename
	sets_state[4]=0
fi
}

#********************************************************************************************
# Function to check spspd<nr>.DeviceCustomData_device set
#********************************************************************************************
function check_deviceCustomData_device() {
printf "*** Check DeviceCustomData_device ("$1"):"
line5=`aql -h ${HOSTNAME/oame/db} -c "select * from $spsnr.DeviceCustomData_device where PK='$1'" |grep '||' 2> /dev/null`
status5=`aql -h ${HOSTNAME/oame/db} -c "select * from $spsnr.DeviceCustomData_device where PK='$1'" -o json |head -n -2 |sed -e '1,2d' |jq '.[1] | .[].Status' 2> /dev/null`
count5=`aql -h ${HOSTNAME/oame/db} -c "select * from $spsnr.DeviceCustomData_device where PK='$1'" -o json |head -n -2 |sed -e '1,2d' |jq '.[0] | length' 2> /dev/null`
if [[ $status5 == "0" ]] && [[ $line5 != "" ]]
then
	if [[ $count5 == "1" ]]
	then
		device_id5=`echo $line5 |sed -e '1,$s/| //' |sed -e '1,$s/ |//'`
		printf " ${GREEN}[OK]${NC} *** (device_id="$device_id5")\n"
		echo "Record at " $spsnr ".DeviceCustomData_device for " $1 "exists"  >> $filename
		echo "device_id - " $device_id5 >> $filename
		sets_state[5]=1
	else
		printf " ${YELLOW}[WARNING]${NC} *** (more than 1 record)\n"
		echo "More than 1 record at " $spsnr ".DeviceCustomData_device for " $1 >> $filename
		sets_state[5]=$count5
	fi
else
	printf " ${RED}[FAIL]${NC} *** \n"
	echo "Lack of record at " $spsnr ".DeviceCustomData_device for " $1  >> $filename
	sets_state[5]=0
fi
}

#********************************************************************************************
# Function to check spspd<nr>.DynamicData set
#********************************************************************************************
function check_dynamicData() {
printf "*** Check DynamicData ("$1"):"
line6=`aql -h ${HOSTNAME/oame/db} -c "select * from $spsnr.DynamicData where PK=$1" |grep '||' 2> /dev/null`
status6=`aql -h ${HOSTNAME/oame/db} -c "select * from $spsnr.DynamicData where PK=$1" -o json |head -n -2 |sed -e '1,2d' |jq '.[1] | .[].Status' 2> /dev/null`
count6=`aql -h ${HOSTNAME/oame/db} -c "select * from $spsnr.DynamicData where PK=$1" -o json |head -n -2 |sed -e '1,2d' |jq '.[0] | length' 2> /dev/null`
if [[ $status6 == "0" ]] && [[ $line6 != "" ]]
then
	if [[ $count6 == "1" ]]
	then
		printf " ${GREEN}[OK]${NC} ***\n"
		echo "Record at " $spsnr ".DynamicData for " $1 "exists"  >> $filename
		echo "dynamicdata - " $line6 >> $filename
		sets_state[6]=1
	else
		printf " ${YELLOW}[WARNING]${NC} *** (more than 1 record)\n"
		echo "More than 1 record at " $spsnr ".DynamicData for " $1 >> $filename
		sets_state[6]=$count6
	fi
else
	printf " ${RED}[FAIL]${NC} *** \n"
	echo "Lack of record at " $spsnr ".DynamicData for " $1  >> $filename
	sets_state[6]=0
fi
}

#********************************************************************************************
# Function to check spspd<nr>.ICD set
#********************************************************************************************
function check_sps_InfrequentlyChangingData() {
printf "*** Check InfrequentlyChangingData ("$1"):"
line7=`aql -h ${HOSTNAME/oame/db} -c "select * from $spsnr.InfrequentlyChangingData where PK=$1" |grep MAP`
json7=`aql -h ${HOSTNAME/oame/db} -c "select * from $spsnr.InfrequentlyChangingData where PK=$1" -o json |head -n -2 |sed -e '1,2d' 2> /dev/null`
#status7=`aql -h ${HOSTNAME/oame/db} -c "select * from $spsnr.InfrequentlyChangingData where PK=$1" -o json |head -n -2 |sed -e '1,2d' |jq '.[1] | .[].Status' 2> /dev/null`
#count7=`aql -h ${HOSTNAME/oame/db} -c "select * from $spsnr.InfrequentlyChangingData where PK=$1" -o json |head -n -2 |sed -e '1,2d' |jq '.[0] | length' 2> /dev/null`
status7=`echo $json7 |jq '.[1] | .[].Status' 2> /dev/null`
count7=`echo $json7 |jq '.[0] | length' 2> /dev/null`
if [[ $status7 == "0" ]] && [[ $line7 != "" ]]
then
	if [[ $count7 == "1" ]]
	then
		icd_imsi=`echo $json7 |jq '.[0] | .[].devices | to_entries | .[].value.imsi[0]' |tr -d '\"' |tr -d ' '`
		icd_e164=`echo $json7 |jq '.[0] | .[].devices | to_entries | .[].value."e164"[0]' |tr -d '\"' |tr -d ' '`
		printf " ${GREEN}[OK]${NC} ***\n"
		echo "Record at " $spsnr ".InfrequentlyChangingData for " $1 "exists"  >> $filename
		echo "imsi - "$icd_imsi >> $filename
		echo "e164 - "$icd_e164 >> $filename
		echo "icd - "$line7 >> $filename
		sets_state[7]=1
	else
		printf " ${YELLOW}[WARNING]${NC} *** (more than 1 record)\n"
		echo "More than 1 record at " $spsnr ".InfrequentlyChangingData for " $1 >> $filename
		sets_state[7]=$count7
	fi
else
	printf " ${RED}[FAIL]${NC} *** \n"
	echo "Lack of record at " $spsnr ".InfrequentlyChangingData for " $1  >> $filename
	sets_state[7]=0
fi
}

#********************************************************************************************
# Function to check dscglobal.PolicySessionMap set
#********************************************************************************************
function check_sps_PolicySessionMap() {
map_key=$1
echo -n "*** Check PolicySessionMap ("$1"):"
#printf "*** Check PolicySessionMap ("$map_key"):"
#status8=`aql -h ${HOSTNAME/oame/db} -c "select * from dscglobal.PolicySessionMap where PK='$map_key'" -o json |grep Status |cut -d ':' -f2 |tr -d  ' \t\r'`
line8=`aql -h ${HOSTNAME/oame/db} -c "select * from dscglobal.PolicySessionMap where PK='$1'" -o json |head -n -2 |sed -e '1,2d'`
status8=`aql -h ${HOSTNAME/oame/db} -c "select * from dscglobal.PolicySessionMap where PK='$1'" -o json |head -n -2 |sed -e '1,2d' |jq '.[1] | .[].Status' 2> /dev/null`
count8=`aql -h ${HOSTNAME/oame/db} -c "select * from dscglobal.PolicySessionMap where PK='$1'" -o json |head -n -2 |sed -e '1,2d' |jq '.[0] | length' 2> /dev/null`
if [[ $status8 == "0" ]] && [[ $line8 != "" ]]
then
	if [[ $count8 == "1" ]]
	then
		printf " ${GREEN}[OK]${NC} ***\n"
		echo "Record at dscglobal.PolicySessionMap for " $1 "exists"  >> $filename
		echo "PSM - " $line8 >> $filename
		sets_state[8]=1
	else
		printf " ${YELLOW}[WARNING]${NC} *** (more than 1 record)\n"
		echo "More than 1 record at dscglobal.PolicySessionMap for " $1 >> $filename
		sets_state[8]=$count8
	fi
else
	printf " ${RED}[FAIL]${NC} *** \n"
	echo "Lack of record at at dscglobal.PolicySessionMap for " $1  >> $filename
	sets_state[8]=0
fi
}

#********************************************************************************************
# Function to check spspd<nr>.SessionContainer set
#********************************************************************************************
function check_sps_SessionContainer() {
printf "*** Check SessionContainer ("$1"):"
#device_key=$1
#device_key=$1'||'$2
#status9=`aql -h ${HOSTNAME/oame/db} -c "select * from $spsnr.SessionContainer where PK='$device_key'" -o json |grep '"Status"' |cut -d ':' -f2 |tr -d  ' \t\r'`
line9=`aql -h ${HOSTNAME/oame/db} -c "select * from $spsnr.SessionContainer where PK='$1'" -o json |head -n -9 |sed -e '1,4d'`
status9=`aql -h ${HOSTNAME/oame/db} -c "select * from $spsnr.SessionContainer where PK='$1'" -o json |head -n -2 |sed -e '1,2d' |jq '.[1] | .[].Status' 2> /dev/null`
count9=`aql -h ${HOSTNAME/oame/db} -c "select * from $spsnr.SessionContainer where PK='$1'" -o json |head -n -2 |sed -e '1,2d' |jq '.[0] | length' 2> /dev/null`
if [[ $status9 == "0" ]] && [[ $line9 != "" ]]
then
	printf " ${GREEN}[OK]${NC} *** ("$count9")\n"
	echo "Record at " $spsnr ".SessionContainer for " $1 "exists"  >> $filename
	echo "SC - " $line9 >> $filename
	sets_state[9]=1
else
	printf " ${RED}[FAIL]${NC} *** \n"
	echo "Lack of record at " $spsnr ".SessionContainer for " $1  >> $filename
	sets_state[9]=0
fi
}

#********************************************************************************************
# Function to check spspd<nr>.TEMEntity set
#********************************************************************************************
function check_sps_Tementity() {
printf "*** Check TEMEntity ("$1"):"
#device_key=$1
line10=`aql -h ${HOSTNAME/oame/db} -c "select * from $spsnr.TEMEntity where PK='$1'" -o json |head -n -9 |sed -e '1,4d'`
#status10=`aql -h ${HOSTNAME/oame/db} -c "select * from $spsnr.TEMEntity where PK='$device_key'" -o json |grep '"Status"' |cut -d ':' -f2 |tr -d  ' \t\r'`
status10=`aql -h ${HOSTNAME/oame/db} -c "select * from $spsnr.TEMEntity where PK='$1'" -o json |head -n -2 |sed -e '1,2d' |jq '.[1] | .[].Status' 2> /dev/null`
count10=`aql -h ${HOSTNAME/oame/db} -c "select * from $spsnr.TEMEntity where PK='$1'" -o json |head -n -2 |sed -e '1,2d' |jq '.[0] | length' 2> /dev/null`
if [[ $status10 == "0" ]] && [[ $line10 != "" ]]
then
	if [[ $count10 == "1" ]]
	then
		printf " ${GREEN}[OK]${NC} ***\n"
		echo "Record at " $spsnr ".TEMENtity for " $1 "exists"  >> $filename
		echo "TEMEntity - " $line10 >> $filename
		sets_state[10]=1
	else
		printf " ${YELLOW}[WARNING]${NC} *** (more than 1 record)\n"
		echo "More than 1 record at " $spsnr ".TEMEntity for " $1 >> $filename
		sets_state[10]=$count10
	fi
else
	printf " ${RED}[FAIL]${NC} *** \n"
	echo "Lack of record at " $spsnr ".TEMEntity for " $1  >> $filename
	sets_state[10]=0
fi
}

#********************************************************************************************
# Function SC
#********************************************************************************************
function sc_extract() {
s_type_array=()	# number of device sessions by type
s_type=`echo $line9 |jq -r '.sessionCounts' |tr -d '[ ' |tr -d ' ]' |tr -d ' '`
IFS="," read -a s_type_array <<< $s_type
echo "Sessions by type: "${s_type_array[*]}
# 0 - Gx, 2 - Rx, 8 - PDU
for i in 0 2 8 
do
	max_ses=${s_type_array[$i]}
	if [[ $max_ses -gt 0 ]]
	then
#	for ((j=1;$j<=$max_ses;j++))
#	do
		case $i in
			"0") # Gx sessions
				s_e164=`echo $line9 |jq -r '.ipCanSessions[].sbi.subscriId | .[] | select(.type==0) | .data'`
				s_imsi=`echo $line9 |jq -r '.ipCanSessions[].sbi.subscriId | .[] | select(.type==1) | .data'`
				s_nai=`echo $line9 |jq -r '.ipCanSessions[].sbi.subscriId | .[] | select(.type==2) | .data'`
				s_ses=`echo $line9 |jq -r '.ipCanSessions | keys' |tr -d '[ ' |tr -d ' ]' |tr -d ' ' |tr -d '\"'`
				ipv6_gx=`echo $line9 |jq -r '.ipCanSessions[].sbi.ipv6Prefix.ipv6Prefix' |tr -d ' '`
				ipv6_gx_length=`echo $line9 |jq -r '.ipCanSessions[].sbi.ipv6Prefix.prefixLength' |tr -d ' '`
				s_devId=`echo $line9 |jq -r '.ipCanSessions[].deviceId'`
				ipv4_gx=`echo $line9 |jq -r '.ipCanSessions[].sbi.ipAddress' |tr -d ' '`
				#sbi_gx=`echo $line9 |jq -r '.ipCanSessions[].sbi.subscriId' |tr -d '[ ' |tr -d ' ]' |tr -d '{' |tr -d '}'`
				#IFS="," read -a gx_array <<< $sbi_gx
				#array=(${dupa/{/})
				#echo "SBI "${gx_array[@]}
				sessions_list+=($s_ses)
				echo -n "Gx session "$s_ses" (device_id="$s_devId
				if [[ ! -z $s_e164 ]] && [[ $s_e164 != "" ]]
				then
					echo -n ", e164="$s_e164
				fi
				if [[ ! -z $s_imsi ]] && [[ $s_imsi != "" ]]
				then
					echo -n ", imsi="$s_imsi
				fi
				if [[ ! -z $ipv4_gx ]] && [[ $ipv4_gx != "" ]] && [[ $ipv4_gx != null ]]
				then
					hex2addr_IPv4 $ipv4_gx
					echo -n ", ip="$ipv4
				fi
				if [[ ! -z $ipv6_gx ]] && [[ $ipv6_gx != "" ]] && [[ $ipv6_gx != null ]]
				then
					hex2addr_IPv6 $ipv6_gx $ipv6_gx_length
					echo -n ", ip="$ipv6
				fi
				echo ")"
				case $sub_type in
					"e164")
						imsi=$s_imsi
						;;
					"imsi")
						e164=$s_e164
						;;
					*)
						imsi=$s_imsi
						e164=$s_e164
						;;
				esac
				;;
			"2") # Rx sessions
				s_ses=`echo $line9 |jq -r '.afSessions | keys' |tr -d '[ ' |tr -d ' ]' |tr -d ', ' |tr -d ' ' |tr -d '\"'`
				if [[ $max_ses == 1 ]]
				then
					s_devId=`echo $line9 |jq -r '.afSessions[].deviceId'`
				else
					s_temp=`echo $line9 |jq -r '.afSessions[].deviceId'`
					s_devId=`echo $s_temp |cut -d " " -f 1`
				fi
				sessions_list+=($s_ses)
				echo "Rx session(s) "$s_ses" (device_id="$s_devId")"
				;;
			"8") # PDU sessions
				s_e164=`echo $line9 |jq -r '.pduSessions[].sbi.subscriId | .[] | select(.type==0) | .data'`
				s_imsi=`echo $line9 |jq -r '.pduSessions[].sbi.subscriId | .[] | select(.type==1) | .data'`
				s_nai=`echo $line9 |jq -r '.pduSessions[].sbi.subscriId | .[] | select(.type==2) | .data'`
				ipv6_gx=`echo $line9 |jq -r '.pduSessions[].sbi.ipv6Prefix.ipv6Prefix' |tr -d ' '`
				ipv6_gx_length=`echo $line9 |jq -r '.pduSessions[].sbi.ipv6Prefix.prefixLength' |tr -d ' '`
				ipv4_gx=`echo $line9 |jq -r '.pduSessions[].sbi.ipAddress' |tr -d ' '`
				s_ses=`echo $line9 |jq -r '.pduSessions | keys' |tr -d '[ ' |tr -d ' ]' |tr -d ' ' |tr -d '\"'`
				s_devId=`echo $line9 |jq -r '.pduSessions[].deviceId'`
				sessions_list+=($s_ses)
				echo -n "PDU session "$s_ses" (device_id="$s_devId
				if [[ ! -z $s_e164 ]] && [[ $s_e164 != "" ]]
				then
					echo -n ", e164="$s_e164
				fi
				if [[ ! -z $s_imsi ]] && [[ $s_imsi != "" ]]
				then
					echo -n ", imsi="$s_imsi
				fi
				if [[ ! -z $ipv4_gx ]] && [[ $ipv4_gx != "" ]] && [[ $ipv4_gx != null ]]
				then
					hex2addr_IPv4 $ipv4_gx
					echo -n ", ip="$ipv4
				fi
				if [[ ! -z $ipv6_gx ]] && [[ $ipv6_gx != "" ]] && [[ $ipv6_gx != null ]]
				then
					hex2addr_IPv6 $ipv6_gx $ipv6_gx_length
					echo -n ", ip="$ipv6
				fi
				echo ")"
				case $sub_type in
					"e164")
						imsi=$s_imsi
						;;
					"imsi")
						e164=$s_e164
						;;
					*)
						imsi=$s_imsi
						e164=$s_e164
						;;
				esac
				;;
			*)
				;;
		esac
#	done
	fi
done
}

#********************************************************************************************
# Function PSM
#********************************************************************************************
function psm_extract_by_IP() {
case $1 in
	"search") 
		bind_Type=`echo $line8 |jq '.[0] | .[] | .label' |tr -d '\"' 2> /dev/null`
		bind_Value=`echo $line8 |jq '.[0] | .[] | .value' |tr -d '\"' 2> /dev/null`
		if [[ $sub_type == "SessionId" ]]
		then
			bind_deviceId=`echo $line8 |jq '.[0] | .[] | .sessContKeys[]' |tr -d '\"' 2> /dev/null`
			bind_sessionId=`echo $line8 |jq '.[0] | .[] | .value' |tr -d '\"' 2> /dev/null`
		else
			bind_sessionId=`echo $line8 |jq '.[0] | .[].bindingInfo | .[].sessionId' |tr -d '\"' 2> /dev/null`
			bind_deviceId=`echo $line8 |jq '.[0] | .[].bindingInfo | .[].deviceId' |tr -d '\"' 2> /dev/null`
		fi
		echo "(bind type="$bind_Type", bind value= "$bind_Value", session="$bind_sessionId", device="$bind_deviceId")"
		;;
	"bind")
		#bindingId=`echo $line8 |jq '.[0] | .[] | .id' 2> /dev/null`
		bindingType=`echo $line8 |jq '.[0] | .[] | .label' |tr -d '\"' 2> /dev/null`
		bindingValue=`echo $line8 |jq '.[0] | .[] | .value' |tr -d '\"' 2> /dev/null`
		sessionId=`echo $line8 |jq '.[0] | .[].bindingInfo | .[].sessionId' |tr -d '\"' 2> /dev/null`
		deviceId=`echo $line8 |jq '.[0] | .[].bindingInfo | .[].deviceId' |tr -d '\"' 2> /dev/null`
		echo "(bind type="$bindingType", bind value="$bindingValue", session="$sessionId", device="$deviceId")"
		;;
	"session")
		sessionId=`echo $line8 |jq '.[0] | .[] | .value' |tr -d '\"' 2> /dev/null`
		deviceId=`echo $line8 |jq '.[0] | .[] | .sessContKeys[]' |tr -d '\"' 2> /dev/null`
		echo "(session="$sessionId", device="$deviceId")"
		;;
esac
}

#********************************************************************************************
# Main part
#********************************************************************************************
while :
do

clear
echo "*******************************************"
homeSPS=""
e164=""
imsi=""
pk_dec=""
pk_hex=""
dev_name=""
ipv6=""
ipv4=""
ipv6_gx=""
ipv4_gx=""
sessions_list=()
exist_sub=99 # provided subsription type: e164 (0) or imsi (1)
sets="Device_e164 Device_imsi DevicePar_id Device_deviceName DeviceCustomDataPar_id DeviceCustomData_device DynamicData InfrequentlyChangingData PolicySessionMap SessionContainer TEMEntity"
sets_state=(99 99 99 99 99 99 99 99 99 99 99)
input_data
spsnr=`aql -h ${HOSTNAME/oame/db} -c "show sets" | grep -i "SessionContainer" | head -1 | egrep -wo 'spspd.[0-9]*'`

case $sub_type in
	"e164"|"imsi")
		# query by provided subscription: e164 or imsi - as result we should have dec_club_id and device_name
		echo "******************** Start : " `date +%H:%M:%S` " ********************" >> $filename
		echo "*******************************************" >> $filename
		check_device_subscription $sub_type $sub_value
		check_devicePair_id $dev_name
		check_sps_InfrequentlyChangingData $pk_dec
		check_device_deviceName $dev_name
		check_device_home $sub_type $sub_value
		;;
	"IPv4"|"IPv6"|"SessionId")
		# query by provided IP or Session Id at PSM records - as result device_id
		echo "******************** Start : " `date +%H:%M:%S` " ********************" >> $filename
		echo "*******************************************" >> $filename
		if [[ $sub_type == "IPv6" ]]
		then
			check_sps_PolicySessionMap 'Framed-IPv6-Prefix '$sub_value
		elif [[ $sub_type == "IPv4" ]]
		then
			check_sps_PolicySessionMap 'IPv4-Address '$sub_value
		else
			check_sps_PolicySessionMap 'Session-Id '$sub_value
		fi
		psm_extract_by_IP "search" 
		# query by device_id at SC - as result imsi and/or e164
		check_sps_SessionContainer $bind_deviceId
		if [[ ${sets_state[9]}>0 ]]
		then
			sc_extract
		fi
#		imsi=$s_imsi
#		e164=$s_e164
		# query by provided subscription: e164 or imsi - as result we should have dec_club_id and device_name
		exist_sub=1
		check_device_subscription 'imsi' $s_imsi
		exist_sub=0
		check_device_subscription 'e164' $s_e164
		check_devicePair_id $dev_name
		check_sps_InfrequentlyChangingData $pk_dec
		check_device_deviceName $dev_name
		if [[ ! -z $s_e164 ]] && [[ $s_e164 != "" ]]
		then
			check_device_home "e164" $s_e164
		else
			check_device_home "imsi" $s_imsi
		fi
		;;
	"DeviceId")
		# query by provided subscription: deviceId - as result we should have device_name and hex_club_id
		echo "******************** Start : " `date +%H:%M:%S` " ********************" >> $filename
		echo "*******************************************" >> $filename
		check_devicePair_id $sub_value
		pk_dec=$pk_dec2
		check_sps_InfrequentlyChangingData $pk_dec
		check_device_deviceName $sub_value
		device_name_key=$sub_value"||"$pk_hex
		check_sps_SessionContainer $device_name_key
		if [[ ${sets_state[9]}>0 ]]
		then
			sc_extract
		fi
		# query by provided subscription: e164 or imsi - as result we should have dec_club_id and device_name
		exist_sub=1
		check_device_subscription 'imsi' $icd_imsi
		exist_sub=0
		check_device_subscription 'e164' $icd_e164
		dev_name=$sub_value
		if [[ ! -z $icd_e164 ]] && [[ $icd_e164 != "" ]]
		then
			check_device_home "e164" $icd_e164
		else
			check_device_home "imsi" $icd_imsi
		fi
		;;
	*)
		;;
esac

# rest of basic queries
check_deviceCustomDataPar_id $dev_name
check_deviceCustomData_device $dev_name
check_dynamicData $pk_dec
invalue=$dev_name'||'$pk_hex
case $sub_type in
	"e164")
		check_sps_SessionContainer $invalue
		if [[ ${sets_state[9]}>0 ]]
		then
			sc_extract
		fi
		if [[ $imsi != "" ]]
		then
			exist_sub=1
			check_device_subscription 'imsi' $imsi
		fi
		;;
	"imsi")
		check_sps_SessionContainer $invalue
		if [[ ${sets_state[9]}>0 ]]
		then
			sc_extract
		fi
		if [[ $e164 != "" ]]
		then
			exist_sub=0
			check_device_subscription 'e164' $e164
		fi
		;;
	*)
		;;
esac

for i in "${sessions_list[@]}"
do
	check_sps_PolicySessionMap 'Session-Id '$i
	psm_extract_by_IP "session"
done
if [[ ! -z $ipv6_gx ]] && [[ $ipv6_gx != "" ]] && [[ $ipv6_gx != null ]]
then
	hex2addr_IPv6 $ipv6_gx $ipv6_gx_length
	check_sps_PolicySessionMap 'Framed-IPv6-Prefix '$ipv6
	psm_extract_by_IP "bind"
fi
if [[ ! -z $ipv4_gx ]] && [[ $ipv4_gx != "" ]] && [[ $ipv4_gx != null ]]
then
	hex2addr_IPv4 $ipv4_gx
	check_sps_PolicySessionMap 'IPv4-Address '$ipv4
	psm_extract_by_IP "bind"
fi
check_sps_Tementity "1-$homeSPS-DpeDeviceAudit:"$invalue
for i in "${sessions_list[@]}"
do
	check_sps_Tementity "1-$homeSPS-DpeSessionAudit:"$i
done

#addr2hex_IPv6 'fdde:0:123f:a001:0:0:0:0/64'
#hex2addr_IPv6 'FD DE 00 00 12 3F A0 01 00 00 00 00 00 00 00 00' 64
#addr2hex_IPv4 '10.20.30.100'
#echo "@@@@@@@@@@@@@@@@@@"
#echo "IPv6 "$userIPv6
#echo "IPv4 "$userIPv4
#echo "IP " ${userIPv6^^}
echo "******************** End : " `date +%H:%M:%S` " ********************" >> $filename
echo >> $filename
#echo "e164 - " $e164
#echo "imsi - " $imsi
#echo "pk_dec - " $pk_dec
#echo "pk_hex - " $pk_hex
#echo "dev_name - " $dev_name
#echo ${sessions_list[*]}
#echo ${sets[*]}
echo "CONTROLS: "${sets_state[*]}
 
#echo "Finished"

echo "*******************************************"
read -n 1 -s -r -p "Press any key to continue"
done
