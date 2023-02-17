# Week 0 — Billing and Architecture

## AWS CLI

### Installation
- When Gitpod environment launches, we'll install AWS CLI
- Setting AWS CLI to use partial autoprompt mode (easier to debugg CLI commands)
- We update `gitpod.yml` to include the following task:
```sh
tasks:
  - name: aws-cli
    env:
      AWS_CLI_AUTO_PROMPT: on-partial
    init: |
      cd /workspace
      curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
      unzip awscliv2.zip
      sudo ./aws/install
      cd $THEIA_WORKSPACE_ROOT
```
### Create a new user and generte AWS credentials
- Search IAM, go into User Console, create new user
- `Enable Console access` for the user
- Create `Admin` group with `AdministratorAccess`
- User -> Select user -> `Security credentials` -> `Create Access Key`
- Choose AWS CLI Access and download the CSV with credentials

![Alt text](../_docs/AWS%20Admin%20User.png)

### Set env variables
We will set these credentials for the current bash terminal
```
export AWS_ACCESS_KEY_ID=""
export AWS_SECRET_ACCESS_KEY=""
export AWS_DEFAULT_REGION=us-east-1
```

We'll tell Gitpod to remember these credentials if we relaunch our workspaces
```
gp env AWS_ACCESS_KEY_ID=""
gp env AWS_SECRET_ACCESS_KEY=""
gp env AWS_DEFAULT_REGION=us-east-1
```

### Check that the AWS CLI is working and you are the expected user

```sh
aws sts get-caller-identity
```

You should see something like this:
```json
{
    "UserId": "ABCDZRJIQN2ONP4ET4EK4",
    "Account": "0123456789101",
    "Arn": "arn:aws:iam::0123456789101:user/username"
}
```
![Alt text](../_docs/AWS%20CLI%20installed.png)

## Billing
- Enable billing: in root account go to [Billing Page](https://console.aws.amazon.com/billing/)
- Under `Billing Preferences` Choose `Receive Billing Alerts`
- Save Preferences
### Create SNS Topic (prereq for alarm)
- [aws sns create-topic](https://docs.aws.amazon.com/cli/latest/reference/sns/create-topic.html) this will deliver a message when we overspend

We'll create a SNS Topic which will return a TopicARN
```sh
aws sns create-topic --name billing-alarm
```

We'll create a subscription supply the TopicARN and our Email
```sh
aws sns subscribe \
    --topic-arn TopicARN \
    --protocol email \
    --notification-endpoint your@email.com
```
![Alt text](../_docs/AWS%20SNS.png)

Check your email and confirm the subscription

### Create Alarm

- [Create an Alarm via AWS CLI](https://aws.amazon.com/premiumsupport/knowledge-center/cloudwatch-estimatedcharges-alarm/)
- We need to update the configuration json script with the TopicARN we generated earlier
- We are just a json file because --metrics is required for expressions and so its easier to us a JSON file.

```sh
aws cloudwatch put-metric-alarm --cli-input-json file://aws/json/alarm-config.json
```
![Alt text](../_docs/AWS%20Alarm.png)


## Create an AWS Budget

[aws budgets create-budget](https://docs.aws.amazon.com/cli/latest/reference/budgets/create-budget.html)

Get your AWS Account ID
```sh
aws sts get-caller-identity --query Account --output text
```

- Supply your AWS Account ID
- Update the json files
- This is another case with AWS CLI its just much easier to json files due to lots of nested json

```sh
aws budgets create-budget \
    --account-id AccountID \
    --budget file://aws/json/budget.json \
    --notifications-with-subscribers file://aws/json/budget-notifications-with-subscribers.json
```
![Alt text](../_docs/AWS%20Budget.png)

## Recreate conceptual diagram in Lucidcharts/napkin
- Recreated the conceptual diagram, so a non-technical person can understand it: [diagram-1](https://lucid.app/lucidchart/0a2daf3d-aed6-435b-aa0b-cca75b872423/edit?viewport_loc=-163%2C102%2C2419%2C1164%2C0_0&invitationId=inv_9f2c2c1f-9d18-4b16-9237-9fa4b70ddf46)
- Recreated a conceptual diagram using AWS specific iconography: [diagram-2](https://lucid.app/lucidchart/b0bbca9f-6919-4d92-82f6-8d17f058c738/edit?viewport_loc=-185%2C111%2C2207%2C1062%2C0_0&invitationId=inv_52fc783a-555b-40ba-8c71-8a6d377925ec)
- Created a logical diagram for this project: [diagram-3](https://lucid.app/lucidchart/95db69db-35cb-4ee5-8f37-530b915f72a5/edit?viewport_loc=-68%2C18%2C2114%2C1017%2C0_0&invitationId=inv_4eb1eda1-985d-4932-bf28-df2dcbd847eb)