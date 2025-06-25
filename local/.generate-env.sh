#!/bin/bash
# Load the base .env
set -a
source .env.base
set +a

# Compose combined variables
echo "Generating .env.generated..."

cat > .env <<EOF
# Composed variables
REACT_APP_BACKEND_URL=http://${BACKEND_HOST}:${BACKEND_PORT}
SQS_QUEUE_URL=http://${LOCALSTACK_HOST}:${LOCALSTACK_PORT}/000000000000/${QUEUE_NAME}
AWS_ENDPOINT=http://${LOCALSTACK_HOST}:${LOCALSTACK_PORT}
EOF

envsubst < postgres/init-db.template.sql > postgres/init-db.sql

# Append all base vars
cat .env.base >> .env