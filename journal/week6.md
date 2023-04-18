# Week 6 — Deploying Containers

- health checks are very usefull, we can see the state of containers, we can use them for load ballancing, RDS instances, debugging, etc.
- we'll create a script in `backend-flask/bin/db/test` to verify our RDS connection (make it executable: ```chmod u+x bin/db/test```):
```bash
#!/usr/bin/env python3

import psycopg
import os
import sys

connection_url = os.getenv("CONNECTION_URL")

conn = None
try:
  print('attempting connection')
  conn = psycopg.connect(connection_url)
  print("Connection successful!")
except psycopg.Error as e:
  print("Unable to connect to the database:", e)
finally:
  conn.close()
```
- next we're going to setup a health check for our flask, so we update `app.py` with the following:
```py
@app.route('/api/health-check')
def health_check():
  return {'success': True}, 200
```
- we'll need also a script to run this health check, so inside `backend-flask/bin/health-check` we will write the following (make it executable: ```chmod u+x bin/flask/health-check```):
```py
#!/usr/bin/env python3

import urllib.request

try:
  response = urllib.request.urlopen('http://localhost:4567/api/health-check')
  if response.getcode() == 200:
    print("[OK] Flask server is running")
    exit(0) # success
  else:
    print("[BAD] Flask server is not running")
    exit(1) # false
# This for some reason is not capturing the error....
#except ConnectionRefusedError as e:
# so we'll just catch on all even though this is a bad practice
except Exception as e:
  print(e)
  exit(1) # false
```
- we're going to need a CloudWatch log group:
```
aws logs create-log-group --log-group-name "/cruddur/fargate-cluster"
aws logs put-retention-policy --log-group-name "/cruddur/fargate-cluster" --retention-in-days 1
```
- next we'll create an ECS Cluster:
```bash
aws ecs create-cluster \
--cluster-name cruddur \
--service-connect-defaults namespace=cruddur
```
## Gaining Access to ECS Fargate Container
### Create ECR repo and push image:
- we'll create some repositories, to store our images;
- first for base-image python:
```
aws ecr create-repository \
  --repository-name cruddur-python \
  --image-tag-mutability MUTABLE
```
- before pushing the ECR we always have to take the action `Retrieve an authentication token and authenticate your Docker client to your registry.` We'll be doing this with the following command:
```
aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com"
```
- we will put in a local variable the url for our python repo:
```
export ECR_PYTHON_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/cruddur-python"
```
- we'll pull the python image (v. 3.10 slim-buster) into our container:
```
docker pull python:3.10-slim-buster
```
- we'll tag the image:
```
docker tag python:3.10-slim-buster $ECR_PYTHON_URL:3.10-slim-buster
```
- next we will push the images:
```
docker push $ECR_PYTHON_URL:3.10-slim-buster
```
- after that inside our `backend-flask/Dockerfile` we will change the location from where we pull the image:
```bash
FROM 853114967029.dkr.ecr.us-east-1.amazonaws.com/cruddur-python:3.10-slim-buster
```
- now we'll create a repo for Flask:
```
aws ecr create-repository \
  --repository-name backend-flask \
  --image-tag-mutability MUTABLE
```
- and we set the URL:
```bash
export ECR_BACKEND_FLASK_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/backend-flask"
```
- now we have to build the image:
```bash
docker build -t backend-flask .
```
- than tag it:
```bash
docker tag backend-flask:latest $ECR_BACKEND_FLASK_URL:latest
```
- and push it:
```bash
docker push $ECR_BACKEND_FLASK_URL:latest
```
- inside `frontend-react-js/Dockerfile.prod` we create a new dockerfile for production:
```sh
# Base Image ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
FROM node:16.18 AS build

ARG REACT_APP_BACKEND_URL
ARG REACT_APP_AWS_PROJECT_REGION
ARG REACT_APP_AWS_COGNITO_REGION
ARG REACT_APP_AWS_USER_POOLS_ID
ARG REACT_APP_CLIENT_ID

ENV REACT_APP_BACKEND_URL=$REACT_APP_BACKEND_URL
ENV REACT_APP_AWS_PROJECT_REGION=$REACT_APP_AWS_PROJECT_REGION
ENV REACT_APP_AWS_COGNITO_REGION=$REACT_APP_AWS_COGNITO_REGION
ENV REACT_APP_AWS_USER_POOLS_ID=$REACT_APP_AWS_USER_POOLS_ID
ENV REACT_APP_CLIENT_ID=$REACT_APP_CLIENT_ID

COPY . ./frontend-react-js
WORKDIR /frontend-react-js
RUN npm install
RUN npm run build

# New Base Image ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
FROM nginx:1.23.3-alpine

# --from build is coming from the Base Image
COPY --from=build /frontend-react-js/build /usr/share/nginx/html
COPY --from=build /frontend-react-js/nginx.conf /etc/nginx/nginx.conf

EXPOSE 3000
```
- now we'll create the repo for the frontend images:
```bash
aws ecr create-repository \
  --repository-name frontend-react-js \
  --image-tag-mutability MUTABLE
```
- we will build the container:
```bash
docker build \
--build-arg REACT_APP_BACKEND_URL="http://api.crazyfroggg-project.com" \
--build-arg REACT_APP_AWS_PROJECT_REGION="$AWS_DEFAULT_REGION" \
--build-arg REACT_APP_AWS_COGNITO_REGION="$AWS_DEFAULT_REGION" \
--build-arg REACT_APP_AWS_USER_POOLS_ID="us-east-1_Am8nwhFg4" \
--build-arg REACT_APP_CLIENT_ID="583cb447cq53g992niajhp7v0n" \
-t frontend-react-js \
-f Dockerfile.prod \
.
```
- we set the URL:
```sh
export ECR_FRONTEND_REACT_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/frontend-react-js"
```
- next we will tag the image and push it:
```sh
docker tag frontend-react-js:latest $ECR_FRONTEND_REACT_URL:latest
```
```sh
docker push $ECR_FRONTEND_REACT_URL:latest
```
## Register Task Definition:
- we will pass in sensitive data to task definition; we can check them after in `AWS System Manager-> Parameter Store`:
```
aws ssm put-parameter --type "SecureString" --name "/cruddur/backend-flask/AWS_ACCESS_KEY_ID" --value $AWS_ACCESS_KEY_ID
aws ssm put-parameter --type "SecureString" --name "/cruddur/backend-flask/AWS_SECRET_ACCESS_KEY" --value $AWS_SECRET_ACCESS_KEY
aws ssm put-parameter --type "SecureString" --name "/cruddur/backend-flask/CONNECTION_URL" --value $PROD_CONNECTION_URL
aws ssm put-parameter --type "SecureString" --name "/cruddur/backend-flask/ROLLBAR_ACCESS_TOKEN" --value $ROLLBAR_ACCESS_TOKEN
aws ssm put-parameter --type "SecureString" --name "/cruddur/backend-flask/OTEL_EXPORTER_OTLP_HEADERS" --value "x-honeycomb-team=$HONEYCOMB_API_KEY"
```

- we will create a policy, in `aws/policies/service-assume-role-execution-policy.json`:
```json
{
    "Version":"2012-10-17",
    "Statement":[{
    "Action":["sts:AssumeRole"],
    "Effect":"Allow",
    "Principal":{
    "Service":["ecs-tasks.amazonaws.com"]
    }
  }]
}

```
- after that we will create a task role from our AWS CLI, using that policy:
```
aws iam create-role --role-name CruddurServiceExecutionPolicy --assume-role-policy-document "file://aws/policies/service-assume-role-execution-policy.json"
```
- we'll create a policy for the AWS System Management Agent:
```bash
aws iam put-role-policy \
  --policy-name SSMAccessPolicy \
  --role-name CruddurTaskRole \
  --policy-document "{
  \"Version\":\"2012-10-17\",
  \"Statement\":[{
    \"Action\":[
      \"ssmmessages:CreateControlChannel\",
      \"ssmmessages:CreateDataChannel\",
      \"ssmmessages:OpenControlChannel\",
      \"ssmmessages:OpenDataChannel\"
    ],
    \"Effect\":\"Allow\",
    \"Resource\":\"*\"
  }]
}
"
```
- and we will attach the following policies to this role:
```bash
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess --role-name CruddurTaskRole
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/CloudWatchFullAccess --role-name CruddurTaskRole
```
- inside `aws/task-definitions/backend-flask.json` we'll put the following:
```json
"family": "backend-flask",
    "executionRoleArn": "arn:aws:iam::853114967029:role/CruddurServiceExecutionRole",
    "taskRoleArn": "arn:aws:iam::853114967029:role/CruddurTaskRole",
    "networkMode": "awsvpc",
    "cpu": "256",
    "memory": "512",
    "requiresCompatibilities": [ 
      "FARGATE" 
    ],
    "containerDefinitions": [
      {
        "name": "backend-flask",
        "image": "853114967029.dkr.ecr.us-east-1.amazonaws.com/backend-flask",
        "essential": true,
        "healthCheck": {
          "command": [
            "CMD-SHELL",
            "python /backend-flask/bin/flask/health-check"
          ],
          "interval": 30,
          "timeout": 5,
          "retries": 3,
          "startPeriod": 60
        },
        "portMappings": [
          {
            "name": "backend-flask",
            "containerPort": 4567,
            "protocol": "tcp", 
            "appProtocol": "http"
          }
        ],
        "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
              "awslogs-group": "cruddur",
              "awslogs-region": "us-east-1",
              "awslogs-stream-prefix": "backend-flask"
          }
        },
        "environment": [
          {"name": "OTEL_SERVICE_NAME", "value": "backend-flask"},
          {"name": "OTEL_EXPORTER_OTLP_ENDPOINT", "value": "https://api.honeycomb.io"},
          {"name": "AWS_COGNITO_USER_POOL_ID", "value": "us-east-1_Am8nwhFg4"},
          {"name": "AWS_COGNITO_USER_POOL_CLIENT_ID", "value": "583cb447cq53g992niajhp7v0n"},
          {"name": "FRONTEND_URL", "value": "*"},
          {"name": "BACKEND_URL", "value": "*"},
          {"name": "AWS_DEFAULT_REGION", "value": "us-east-1"}
        ],
        "secrets": [
          {"name": "AWS_ACCESS_KEY_ID"    , "valueFrom": "arn:aws:ssm:us-east-1:853114967029:parameter/cruddur/backend-flask/AWS_ACCESS_KEY_ID"},
          {"name": "AWS_SECRET_ACCESS_KEY", "valueFrom": "arn:aws:ssm:us-east-1:853114967029:parameter/cruddur/backend-flask/AWS_SECRET_ACCESS_KEY"},
          {"name": "CONNECTION_URL"       , "valueFrom": "arn:aws:ssm:us-east-1:853114967029:parameter/cruddur/backend-flask/CONNECTION_URL" },
          {"name": "ROLLBAR_ACCESS_TOKEN" , "valueFrom": "arn:aws:ssm:us-east-1:853114967029:parameter/cruddur/backend-flask/ROLLBAR_ACCESS_TOKEN" },
          {"name": "OTEL_EXPORTER_OTLP_HEADERS" , "valueFrom": "arn:aws:ssm:us-east-1:853114967029:parameter/cruddur/backend-flask/OTEL_EXPORTER_OTLP_HEADERS" }
        ]
      }
    ]
  }
```
- we'll register a task definition:
```sh
aws ecs register-task-definition --cli-input-json file://aws/task-definitions/backend-flask.json
```
- we will create the service:
```sh
aws ecs create-service --cli-input-json file://aws/service-backend-flask.json
```
- we'll create in `aws/task-definitions/frontend-react-js.json` the task for the frontend:
```json
{
    "family": "frontend-react-js",
    "executionRoleArn": "arn:aws:iam::853114967029:role/CruddurServiceExecutionRole",
    "taskRoleArn": "arn:aws:iam::853114967029:role/CruddurTaskRole",
    "networkMode": "awsvpc",
    "cpu": "256",
    "memory": "512",
    "requiresCompatibilities": [ 
      "FARGATE" 
    ],
    "containerDefinitions": [
      {
        "name": "frontend-react-js",
        "image": "853114967029.dkr.ecr.us-east-1.amazonaws.com/backend-flask",
        "essential": true,
        "portMappings": [
          {
            "name": "frontend-react-js",
            "containerPort": 3000,
            "protocol": "tcp", 
            "appProtocol": "http"
          }
        ],
  
        "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
              "awslogs-group": "cruddur",
              "awslogs-region": "us-east-1",
              "awslogs-stream-prefix": "frontend-react-js"
          }
        }
      }
    ]
  }
```
- we will build the task definition for the frontend:
```sh
aws ecs register-task-definition --cli-input-json file://aws/task-definitions/frontend-react-js.json
```
- and we create the service:
```sh
aws ecs create-service --cli-input-json file://aws/service-frontend-react-js.json
```

- we set the following local variables:
```sh
export DEFAULT_VPC_ID=$(aws ec2 describe-vpcs \
--filters "Name=isDefault, Values=true" \
--query "Vpcs[0].VpcId" \
--output text)
echo $DEFAULT_VPC_ID
```
- now we create a security group:
```sh
export CRUD_SERVICE_SG=$(aws ec2 create-security-group \
  --group-name "crud-srv-sg" \
  --description "Security group for Cruddur services on ECS" \
  --vpc-id $DEFAULT_VPC_ID \
  --query "GroupId" --output text)
echo $CRUD_SERVICE_SG
```
- and we'll authorize port 80 to open our service:
```sh
aws ec2 authorize-security-group-ingress \
  --group-id $CRUD_SERVICE_SG \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0
```
- we need to update our `CruddurServiceExecutionPolicy` with the following permissions:
```sh
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameters",
                "ssm:GetParameter"
            ],
            "Resource": "arn:aws:ssm:us-east-1:853114967029:parameter/cruddur/backend-flask/*"
        }
    ]
}
```
- we need to install Session Manager in order to connect via Fargate (we can also add them into our `gitpod.yml` file, to run every time we spin a new gitpod instance):
```
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
```
```sh
sudo dpkg -i session-manager-plugin.deb
```
- check if installed:
```
session-manager-plugin
```
- we'll create `aws/service-backend-flask.json`:
```json
{
    "cluster": "cruddur",
    "launchType": "FARGATE",
    "desiredCount": 1,
    "enableECSManagedTags": true,
    "enableExecuteCommand": true,
    "networkConfiguration": {
      "awsvpcConfiguration": {
        "assignPublicIp": "ENABLED",
        "securityGroups": [
          "sg-00b6f710c0febf59d"
        ],
        "subnets": [
          "subnet-0e4b13b35eb9d697a",
          "subnet-016348564b4662f39",
          "subnet-0a97a8914a82c3bdd",
          "subnet-091f2ab8e06215a7c",
          "subnet-0e1115887c40320e3",
          "subnet-08c5803340f59fa7e"
        ]
      }
    },
    "propagateTags": "SERVICE",
    "serviceName": "backend-flask",
    "taskDefinition": "backend-flask",
    "serviceConnectConfiguration": {
      "enabled": true,
      "namespace": "cruddur",
      "services": [
        {
          "portName": "backend-flask",
          "discoveryName": "backend-flask",
          "clientAliases": [{"port": 4567}]
        }
      ]
    }
  }
  ```
- and for the frontend, we will create `aws/service-frontend-react-js.json`:
```json
{
  "cluster": "cruddur",
  "launchType": "FARGATE",
  "desiredCount": 1,
  "enableECSManagedTags": true,
  "enableExecuteCommand": true,

      ],
  "networkConfiguration": {
    "awsvpcConfiguration": {
      "assignPublicIp": "ENABLED",
      "securityGroups": [
        "sg-00b6f710c0febf59d"
      ],
      "subnets": [
          "subnet-0e4b13b35eb9d697a",
          "subnet-016348564b4662f39",
          "subnet-0a97a8914a82c3bdd",
          "subnet-091f2ab8e06215a7c",
          "subnet-0e1115887c40320e3",
          "subnet-08c5803340f59fa7e"
      ]
    }
  },
  "propagateTags": "SERVICE",
  "serviceName": "frontend-react-js",
  "taskDefinition": "frontend-react-js",
  "serviceConnectConfiguration": {
    "enabled": true,
    "namespace": "cruddur",
    "services": [
      {
        "portName": "frontend-react-js",
        "discoveryName": "frontend-react-js",
        "clientAliases": [{"port": 3000}]
      }
    ]
  }
}
```
- to find out our subnets we can use the following commands:
```sh
export DEFAULT_VPC_ID=$(aws ec2 describe-vpcs \
--filters "Name=isDefault, Values=true" \
--query "Vpcs[0].VpcId" \
--output text)
echo $DEFAULT_VPC_ID
```
```sh
export DEFAULT_SUBNET_IDS=$(aws ec2 describe-subnets  \
 --filters Name=vpc-id,Values=$DEFAULT_VPC_ID \
 --query 'Subnets[*].SubnetId' \
 --output json | jq -r 'join(",")')
echo $DEFAULT_SUBNET_IDS
```

- to get into our container via shell, we use the following command (where `task` is the ARN of our task):
```sh
aws ecs execute-command  \
--region $AWS_DEFAULT_REGION \
--cluster cruddur \
--task 26fdae11ff2d4c008ffcda2e7abe5e64 \
--container backend-flask \
--command "/bin/bash" \
--interactive
```

## Create a load balancer
- in our AWS account -> EC2 -> Load Balancers -> Application Load Balancer;
- for this load balancer we create a new security group and a target group;
- inside `aws/service-backend-flask.json` we add the following code, for our load ballancer:
```json
"loadBalancers": [
      {
          "targetGroupArn": "arn:aws:elasticloadbalancing:us-east-1:853114967029:targetgroup/cruddur-backend-flask-tg/858cd90dd2c24231",
          "loadBalancerName": "arn:aws:elasticloadbalancing:us-east-1:853114967029:loadbalancer/app/cruddur-alb/e78d454b3b4fb3cc",
          "containerName": "backend-flask",
          "containerPort": 4567
      }
    ]
```
- and inside `aws/service-frontend-react-js.json` for our load balancer we will put:
```json
  "loadBalancers": [
        {
            "targetGroupArn": "arn:aws:elasticloadbalancing:us-east-1:853114967029:targetgroup/cruddur-frontend-react-js/f644bdcffa6b8169",
            "containerName": "frontend-react-js",
            "containerPort": 3000
        }
```
