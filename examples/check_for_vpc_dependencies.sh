#!/bin/bash

VPC_ID=$1

if [ -z "$AWS_REGION" ]; then echo "no region set"; exit 1; fi
if [ -z "$VPC_ID" ]; then echo "no vpc id set"; exit 1; fi

aws ec2 describe-internet-gateways --region "$AWS_REGION" --filters 'Name=attachment.vpc-id,Values='"$VPC_ID" | grep InternetGatewayId
aws ec2 describe-subnets --region "$AWS_REGION" --filters 'Name=vpc-id,Values='"$VPC_ID" | grep SubnetId
aws ec2 describe-route-tables --region "$AWS_REGION" --filters 'Name=vpc-id,Values='"$VPC_ID" | grep RouteTableId
aws ec2 describe-network-acls --region "$AWS_REGION" --filters 'Name=vpc-id,Values='"$VPC_ID" | grep NetworkAclId
aws ec2 describe-vpc-peering-connections --region "$AWS_REGION" --filters 'Name=requester-vpc-info.vpc-id,Values='"$VPC_ID" | grep VpcPeeringConnectionId
aws ec2 describe-vpc-endpoints --region "$AWS_REGION" --filters 'Name=vpc-id,Values='"$VPC_ID" | grep VpcEndpointId
aws ec2 describe-nat-gateways --region "$AWS_REGION" --filter 'Name=vpc-id,Values='"$VPC_ID" | grep NatGatewayId
aws ec2 describe-security-groups --region "$AWS_REGION" --filters 'Name=vpc-id,Values='"$VPC_ID" | grep GroupId
aws ec2 describe-instances --region "$AWS_REGION" --filters 'Name=vpc-id,Values='"$VPC_ID" | grep InstanceId
aws ec2 describe-vpn-gateways --region "$AWS_REGION" --filters 'Name=attachment.vpc-id,Values='"$VPC_ID" | grep VpnGatewayId
aws ec2 describe-network-interfaces --region "$AWS_REGION" --filters 'Name=vpc-id,Values='"$VPC_ID" | grep NetworkInterfaceId
aws ec2 describe-carrier-gateways --region "$AWS_REGION" --filters Name=vpc-id,Values="$VPC_ID" | grep CarrierGatewayId
aws ec2 describe-local-gateway-route-table-vpc-associations --region "$AWS_REGION" --filters Name=vpc-id,Values="$VPC_ID" | grep LocalGatewayRouteTableVpcAssociationId
