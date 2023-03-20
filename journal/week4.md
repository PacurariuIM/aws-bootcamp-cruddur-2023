# Week 4 — Postgres and RDS

## PostgreSQL
- To connect to psql via the psql client cli tool remember to use the host flag to specific localhost:
```
psql -Upostgres --host localhost
```
- inside `backend-flask/db` we create a `schema.sql` file and we import the scripts with this command:
```
psql cruddur < db/schema.sql -h localhost -U postgres
```
- we create the tables with the following commands, making sure we drop the tables if they already exist:
```
DROP TABLE IF EXISTS public.users;
DROP TABLE IF EXISTS public.activities;

CREATE TABLE public.users (
  uuid UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  display_name text,
  handle text,
  cognito_user_id text,
  created_at TIMESTAMP default current_timestamp NOT NULL
);

CREATE TABLE public.activities (
  uuid UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_uuid UUID NOT NULL,
  message text NOT NULL,
  replies_count integer DEFAULT 0,
  reposts_count integer DEFAULT 0,
  likes_count integer DEFAULT 0,
  reply_to_activity_uuid integer,
  expires_at TIMESTAMP,
  created_at TIMESTAMP default current_timestamp NOT NULL
);
```
- inside `backend-flask/bin` we'll put our bash scripts; we also store localy our connection url into a variable:
```
export CONNECTION_URL="postgresql://postgres:password@localhost:5432/cruddur"
gp env CONNECTION_URL="postgresql://postgres:password@localhost:5432/cruddur"

export PROD_CONNECTION_URL="postgresql://cruddurroot:bestAWScourse1@cruddur-db-instance-second.cke83t8x6lvl.us-east-1.rds.amazonaws.com:5432/cruddur"
gp env PROD_CONNECTION_URL="postgresql://cruddurroot:bestAWScourse1@cruddur-db-instance-second.cke83t8x6lvl.us-east-1.rds.amazonaws.com:5432/cruddur"
```
- we create a bash script `bin/db-connect`:
```bash
#! /usr/bin/bash

psql $CONNECTION_URL
```
- we'll make it executable:
```bash
chmod u+x bin/db-connect
```
- and to execute it we use the following command:
```bash
./bin/db-connect
```
- to drop the database we make the following script `bin/db-drop`:
```bash
#! /usr/bin/bash

NO_DB_CONNECTION_URL=$(sed 's/\/cruddur//g' <<< "$CONNECTION_URL")
psql $NO_DB_CONNECTION_URL -c "drop database cruddur;"
```
- we write the following script to create a database `bin/db-create`:
```bash
#! /usr/bin/bash

NO_DB_CONNECTION_URL=$(sed 's/\/cruddur//g' <<< "$CONNECTION_URL")
psql $NO_DB_CONNECTION_URL -c "create database cruddur;"
```
- we write the following script to load the schema `bin/db-schema-load`:
```bash
#! /usr/bin/bash

echo "db-schema-load"
schema_path="$(realpath .)/db/schema.sql"
echo $schema_path

if [ "$1" = "prod" ]; then
  CON_URL=$PROD_CONNECTION_URL
else
  CON_URL=$CONNECTION_URL
fi

psql $CONNECTION_URL cruddur < $schema_path
```
- we write the following script to load the seed data `bin/db-seed`:
```bash
#! /usr/bin/bash

echo "db-seed"
seed_path="$(realpath .)/db/seed.sql"
echo $seed_path

if [ "$1" = "prod" ]; then
  CON_URL=$PROD_CONNECTION_URL
else
  CON_URL=$CONNECTION_URL
fi

psql $CONNECTION_URL cruddur < $seed_path
```

- inside `backend-flask/db` we create a new file named `seed.sql`, to seed some data into our tables:
```bash
INSERT INTO public.users (display_name, handle, cognito_user_id, email)
VALUES
  ('Ionel Pacurariu', 'ionelp' ,'e2d787ae-5a98-4d02-890e-7231a9a06d2d', 'jonny_boy90609@yahoo.com');

INSERT INTO public.activities (user_uuid, message, expires_at)
VALUES
  (
    (SELECT uuid from public.users WHERE users.handle = 'ionelp' LIMIT 1),
    'This was imported as seed data!',
    current_timestamp + interval '10 day'
  )
  ```
- to see what connections we are using we'll create `bin/db-sessions`:
```bash
#! /usr/bin/bash

if [ "$1" = "prod" ]; then
  CON_URL=$PROD_CONNECTION_URL
else
  CON_URL=$CONNECTION_URL
fi

NO_DB_CONNECTION_URL=$(sed 's/\/cruddur//g' <<<"$CONNECTION_URL")
psql $NO_DB_CONNECTION_URL -c "select pid as process_id, \
       usename as user,  \
       datname as db, \
       client_addr, \
       application_name as app,\
       state \
from pg_stat_activity;"
```
- to make things easier to setup, we'll create a `bin/db-setup` script:
```bash
#! /usr/bin/bash
-e # stop if it fails at any point

CYAN='\033[1;36m'
NO_COLOR='\033[0m'
LABEL="db-setup"
printf "${CYAN}==== ${LABEL}${NO_COLOR}\n"

bin_path="$(realpath .)/bin"

source "$bin_path/db-drop"
source "$bin_path/db-create"
source "$bin_path/db-schema-load"
source "$bin_path/db-seed"
```
![Alt text](../_docs/w04/db-setup.png)

### Install Posgtres client
- We need to set the env var for our backend-flask application. We put this into our `docker-compose.yml` file:
```bash
backend-flask:
    environment:
      CONNECTION_URL: "postgresql://postgres:password@db:5432/cruddur"
```
- We'll add the following to our requirments.txt and install using pip:
```
psycopg[binary]
psycopg[pool]
```
```
pip install -r requirements.txt
```
- To setup DB Object and Connection Pool we create the folder `/lib/db.py`:
```bash
from psycopg_pool import ConnectionPool
import os

def query_wrap_object(template):
  sql = f"""
  (SELECT COALESCE(row_to_json(object_row),'{{}}'::json) FROM (
  {template}
  ) object_row);
  """
  return sql

def query_wrap_array(template):
  sql = f"""
  (SELECT COALESCE(array_to_json(array_agg(row_to_json(array_row))),'[]'::json) FROM (
  {template}
  ) array_row);
  """
  return sql

connection_url = os.getenv("CONNECTION_URL")
pool = ConnectionPool(connection_url)
```
- in `home_activities.py` we replace the mock endpoint with real API call:
```bash
from lib.db import pool, query_wrap_array

sql = query_wrap_array("""
    SELECT
      activities.uuid,
      users.display_name,
      users.handle,
      activities.message,
      activities.replies_count,
      activities.reposts_count,
      activities.likes_count,
      activities.reply_to_activity_uuid,
      activities.expires_at,
      activities.created_at
    FROM public.activities
    LEFT JOIN public.users ON users.uuid = activities.user_uuid
    ORDER BY activities.created_at DESC
    """)
    with pool.connection() as conn:
      with conn.cursor() as cur:
        cur.execute(sql)
        # this will return a tuple
        # the first field being the data
        json = cur.fetchone()
    return json[0]
```
- We'll provision a RDS instance using the following command:
```bash
aws rds create-db-instance \
  --db-instance-identifier cruddur-db-instance-second \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version  14.6 \
  --master-username cruddurroot \
  --master-user-password bestAWScourse1 \
  --allocated-storage 20 \
  --availability-zone us-east-1a \
  --backup-retention-period 0 \
  --port 5432 \
  --no-multi-az \
  --db-name cruddur \
  --storage-type gp2 \
  --publicly-accessible \
  --storage-encrypted \
  --enable-performance-insights \
  --performance-insights-retention-period 7 \
  --no-deletion-protection
```
![Alt text](../_docs/w04/RDS%20instance.png)
- In order to connect to the RDS instance we need to provide our Gitpod IP and whitelist for inbound traffic on port 5432, and we'll create a script for this:
```bash
#! /usr/bin/bash

CYAN='\033[1;36m'
NO_COLOR='\033[0m'
LABEL="rds-update-sg-rule"
printf "${CYAN}== ${LABEL}${NO_COLOR}\n"

aws ec2 modify-security-group-rules \
    --group-id $DB_SG_ID \
    --security-group-rules "SecurityGroupRuleId=$DB_SG_RULE_ID,SecurityGroupRule={Description=GITPOD,IpProtocol=tcp,FromPort=5432,ToPort=5432,CidrIpv4=$GITPOD_IP/32}"
```

- Inside `gitpod.yml` we'll specify what command to run each time we spin a new environment, so that it provides the IP to our user group:
```bash
command: |
      export GITPOD_IP=$(curl ifconfig.me)
      source  "$THEIA_WORKSPACE_ROOT/backend-flask/bin/rds-update-sg-rule"
```
- We set the group rule ID and the group ID as local variables, for future use:
```bash
export DB_SG_ID="sg-*************"
gp env DB_SG_ID="sg-*************"
export DB_SG_RULE_ID="sgr--*************"
gp env DB_SG_RULE_ID="sgr--*************"
```
## Setup Cognito post confirmation lambda

- Create lambda in same vpc as rds instance Python 3.8;
- Put the following code into the Lambda function:
```py
import json
import psycopg2
import os

def lambda_handler(event, context):
    user = event['request']['userAttributes']
    print('userAttributes')
    print(user)

    user_display_name  = user['name']
    user_email         = user['email']
    user_handle        = user['preferred_username']
    user_cognito_id    = user['sub']
    try:
      print('entered-try')
      sql = f"""
         INSERT INTO public.users (
          display_name, 
          email,
          handle, 
          cognito_user_id
          ) 
        VALUES(
          '{user_display_name}', 
          '{user_email}', 
          '{user_handle}', 
          '{user_cognito_id}'
        )
      """
      print('SQL Statement ----')
      print(sql)
      conn = psycopg2.connect(os.getenv('CONNECTION_URL'))
      cur = conn.cursor()
      cur.execute(sql)
      conn.commit() 

    except (Exception, psycopg2.DatabaseError) as error:
      print(error)
    finally:
      if conn is not None:
          cur.close()
          conn.close()
          print('Database connection closed.')
    return event
```

![Alt text](../_docs/w04/Cloudwatch%20db%20log.png)
![Alt text](../_docs/w04/Cruddur.png)
![Alt text](../_docs/w04/prod%20table.png)