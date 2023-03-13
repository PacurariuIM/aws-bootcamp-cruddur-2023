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

export PROD_CONNECTION_URL="postgresql://cruddurroot:bestAWScourse1@cruddur-db-instance.cke83t8x6lvl.us-east-1.rds.amazonaws.com"
gp env PROD_CONNECTION_URL="postgresql://cruddurroot:bestAWScourse1@cruddur-db-instance.cke83t8x6lvl.us-east-1.rds.amazonaws.com"
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
INSERT INTO public.users (display_name, handle, cognito_user_id)
VALUES
  ('Andrew Brown', 'andrewbrown' ,'MOCK'),
  ('Andrew Bayko', 'bayko' ,'MOCK');

INSERT INTO public.activities (user_uuid, message, expires_at)
VALUES
  (
    (SELECT uuid from public.users WHERE users.handle = 'andrewbrown' LIMIT 1),
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
