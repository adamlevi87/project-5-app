#!/bin/bash
# Load the base .env
set -a
source .env.base
set +a

# Compose combined variables
echo "Generating .env.generated..."

cat > .env.generated <<EOF
# Composed variables
REACT_APP_BACKEND_URL=http://${BACKEND_HOST}:${BACKEND_PORT}
SQS_QUEUE_URL=http://localstack:${LOCALSTACK_PORT}/000000000000/${QUEUE_NAME}
AWS_ENDPOINT=http://${LOCALSTACK_HOST}:${LOCALSTACK_PORT}
EOF

# Append all base vars
cat .env >> .env.generated
