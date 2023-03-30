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
- we'll need also a script to run this health check, so inside `bin/flask/health-check` we will write the following (make it executable: ```chmod u+x bin/flask/health-check```):
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
