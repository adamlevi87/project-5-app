#!/bin/sh

CONFIG_FILENAME=config.js
CONFIG_PATH="/usr/share/nginx/html/${CONFIG_FILENAME}"
INDEX_HTML="/usr/share/nginx/html/index.html"

echo "Injecting runtime config into $CONFIG_PATH"
cat <<EOF > "$CONFIG_PATH"
window.RUNTIME_CONFIG = {
  BACKEND_URL: "${REACT_APP_BACKEND_URL}"
};
EOF

echo "Injecting <script> tag into $INDEX_HTML"
# Insert the <script> tag right before </head>
sed -i "/<\/head>/i <script src=\"/${CONFIG_FILENAME}\"></script>" "$INDEX_HTML"

exec nginx -g "daemon off;"
