#!/bin/bash

#Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
#SPDX-License-Identifier: Apache-2.0

#DESCRIPTION: AWS Launch Wizard for SAP - PostConfiguration script to register HDB with SSM for SAP 
#https://docs.aws.amazon.com/ssm-sap/latest/userguide/what-is-ssm-for-sap.html
#EXECUTE: Can be run only via AWS Launch Wizard for SAP
#AUTHOR: mtoerpe@

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "$DIR/../utils/lw_bootstrap.sh"

#RUN ONLY IN CASE OF HANA DB
MYPID=$(pidof hdbindexserver)

if [[ $MYPID ]]
then

#Fix for ImportError: cannot import name 'SCHEME_KEYS'
sudo zypper -n rm python3-pip
sudo rm -fr /usr/lib/python3.6/site-packages/pip*
sudo zypper -n in python3-pip

#ADD TAG SSMForSAPManaged=True
echo "Tagging EC2 instance!"
aws ec2 create-tags --resources $ec2_instance_id --tags Key=SSMForSAPManaged,Value=True

#CREATE NEW SECRET IF NOT EXISTS
echo "Create a new secret for SSM for SAP!"
aws secretsmanager create-secret \
    --name $HANA_SECRET_ID-SSM \
    --description "Use with SSM for SAP" \
    --secret-string "{\"user\":\"ADMIN\",\"password\":\"$MASTER_PASSWORD\"}"

#REGISTER APPLICATION
echo "Registering Application..."
aws ssm-sap register-application \
--application-id $SAP_SID \
--application-type HANA \
--instances $ec2_instance_id \
--sap-instance-number $SAP_HANA_INSTANCE_NR \
--sid $SAP_HANA_SID \
--credentials '[{"DatabaseName":"'$SAP_HANA_SID'/'$SAP_HANA_SID'","CredentialType":"ADMIN","SecretId":"'$SAPHANASECRET'"},{"DatabaseName":"'$SAP_HANA_SID'/SYSTEMDB","CredentialType":"ADMIN","SecretId":"'$SAPHANASECRET'"}]'

sleep 120

aws ssm-sap get-application --application-id $SAP_SID
MYSTATUS=$(aws ssm-sap get-application --application-id $SAP_SID --query "*.Status" --output text)

if [[ $MYSTATUS = "ACTIVATED" ]]
then
echo "Registration successful!"
else
echo "Registration failed!"
exit 1
fi

fi