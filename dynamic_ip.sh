#!/bin/bash
echo "HOSTED_ZONE_ID:$1"
echo "NAME:$2"
echo "TYPE:$3"
echo "TTL:$4"
echo "LOGFILE:$5"

HOSTED_ZONE_ID=$1
NAME=$2
TYPE=$3
TTL=$4
LOGFILE="$NAME.log"

echo "Getting Ip address for $NAME " >> $LOGFILE
#get current IP address
IP=$(curl http://checkip.amazonaws.com/)
echo "IP address is $IP " >> $LOGFILE

#validate IP address (makes sure Route 53 doesn't get updated with a malformed payload)
if [[ ! $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
	exit 1
fi
echo 'IP appears to be valid... proceeding with update'

#get current
echo 'retrieving the current record set from AWS'
aws route53 list-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID | \
jq -r '.ResourceRecordSets[] | select (.Name == "'"$NAME"'") | select (.Type == "'"$TYPE"'") | .ResourceRecords[0].Value' > /tmp/"$NAME"current_route53_value

cat '/tmp/'$NAME'current_route53_value'
echo 'checking if existing IP address matches actual' >> $LOGFILE
#check if IP is different from Route 53
STOREDIP=$(grep -Fxq "$IP" /tmp/"$NAME"current_route53_value)
echo "Stored ip:"
echo $STOREDIP

echo $STOREDIP >> $LOGFILE

if grep -Fxq "$IP" /tmp/"$NAME"current_route53_value; then
	echo "IP Has Not Changed, Exiting" >> $LOGFILE
	exit 1
fi


echo "IP Changed, Updating Records" >> $LOGFILE

#prepare route 53 payload
cat > /tmp/"$NAME"route53_changes.json << EOF
    {
      "Comment":"Updated From DDNS Shell Script",
      "Changes":[
        {
          "Action":"UPSERT",
          "ResourceRecordSet":{
            "ResourceRecords":[
              {
                "Value":"$IP"
              }
            ],
            "Name":"$NAME",
            "Type":"$TYPE",
            "TTL":$TTL
          }
        }
      ]
    }
EOF

#update records
aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch file:///tmp/"$NAME"route53_changes.json >> $LOGFILE
