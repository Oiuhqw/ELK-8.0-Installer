#!/bin/bash
# Ensure the script is run as sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# Function to wait for the dpkg lock
wait_for_dpkg_lock() {
    while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
        echo "Waiting for other package manager to finish..."
        sleep 10
    done
}

# Stop unattended-upgrades service to prevent automatic updates
stop_unattended_upgrades() {
    sudo systemctl stop unattended-upgrades
    sudo systemctl disable unattended-upgrades
}

# Start unattended-upgrades service after script completion
start_unattended_upgrades() {
    sudo systemctl enable unattended-upgrades
    sudo systemctl start unattended-upgrades
}

# Stop unattended-upgrades at the beginning of the script
stop_unattended_upgrades

# Get the original user's home directory
USER_HOME=$(eval echo ~$SUDO_USER)
mkdir $USER_HOME/elk-configs

# Install necessary packages
wait_for_dpkg_lock
sudo apt update
wait_for_dpkg_lock
sudo apt install -y curl jq

# Add Elasticsearch GPG key and repository
curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elastic.gpg
echo "deb [signed-by=/usr/share/keyrings/elastic.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list

# Update package list and install Elasticsearch
wait_for_dpkg_lock
sudo apt update
wait_for_dpkg_lock

# Temporary file to capture the Elasticsearch installation output
TEMP_FILE=$(mktemp)
sudo apt install -y elasticsearch | tee $TEMP_FILE

# Extract the generated password from the temporary file
PASSWORD=$(grep -oP '(?<=The generated password for the elastic built-in superuser is : ).*' $TEMP_FILE | tr -d '\r\n')

# Clean up the temporary file
rm -f $TEMP_FILE

# Write the password to a file in the original user's home directory
echo $PASSWORD > "$USER_HOME/elk-configs/elastic-password"
chown $SUDO_USER:$SUDO_USER "$USER_HOME/elk-configs/elastic-password"

# Start and enable Elasticsearch service
sudo systemctl start elasticsearch
sudo systemctl enable elasticsearch

# Install Kibana
wait_for_dpkg_lock
sudo apt install -y kibana

# Generate Kibana enrollment token
KIBANA_TOKEN=$(sudo /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana)

# Setup Kibana with the enrollment token
echo $KIBANA_TOKEN | sudo /usr/share/kibana/bin/kibana-setup

# Generate the encryption keys and capture the output
OUTPUT=$(sudo /usr/share/kibana/bin/kibana-encryption-keys generate)

# Extract the last three lines containing the keys
ENCRYPTION_KEYS=$(echo "$OUTPUT" | tail -n 3)

# Append the keys to the Kibana configuration file
echo "$ENCRYPTION_KEYS" | sudo tee -a /etc/kibana/kibana.yml


# Start and enable Kibana service
sudo systemctl start kibana
sudo systemctl enable kibana

# Install Nginx
wait_for_dpkg_lock
sudo apt install -y nginx

# Update Nginx configuration
NGINX_CONFIG="/etc/nginx/sites-enabled/default"
if ! grep -q "^[[:space:]]*location / {[[:space:]]*proxy_pass http://127.0.0.1:5601;" $NGINX_CONFIG; then
  sudo sed -i '/^[[:space:]]*location \/ {$/,/^[[:space:]]*}$/ {
      /^[[:space:]]*try_files \$uri \$uri\/ =404;/ s/^/# /
      /^[[:space:]]*location \/ {$/ a\
          proxy_pass http:\/\/127.0.0.1:5601;
  }' $NGINX_CONFIG
fi

# Restart and enable Nginx service
sudo systemctl restart nginx
sudo systemctl enable nginx

echo "wait for kibana service to start"
sleep 100

# Encode the elastic user credentials
AUTHORIZATION=$(echo -n "elastic:$PASSWORD" | base64)
echo -n "elastic:$PASSWORD"
echo "$AUTHORIZATION"

IP=$(ip a | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
echo $IP

curl --location 'http://localhost/api/fleet/fleet_server_hosts' \
    --header 'Accept: */*' \
    --header 'Content-Type: application/json' \
    --header 'Cache-Control: no-cache' \
    --header 'kbn-xsrf: xxx' \
    --header 'Connection: keep-alive' \
    --header 'Authorization: Basic '$AUTHORIZATION'' \
    --data '{"name":"fleetserver","host_urls":["https://'$IP':8220"],"is_default":true}'

sleep 10

# Create the service token
SERVICE_TOKEN=$(curl --location --request POST 'http://localhost/api/fleet/service_tokens' \
    --header 'Accept: */*' \
    --header 'Content-Type: application/json' \
    --header 'Cache-Control: no-cache' \
    --header 'kbn-xsrf: xxx' \
    --header 'Connection: keep-alive' \
    --header 'Authorization: Basic '$AUTHORIZATION'' | jq -r '.value')

sleep 10

# Write the Fleet service token to a file in the original user's home directory
echo $SERVICE_TOKEN > "$USER_HOME/elk-configs/fleet-service-token"
chown $SUDO_USER:$SUDO_USER "$USER_HOME/elk-configs/fleet-service-token"

# Create Fleet Server policy using the provided curl command
#curl --location 'http://localhost/api/fleet/agent_policies?sys_monitoring=true' \
curl --location 'http://localhost/api/fleet/agent_policies' \
    --header 'Accept: */*' \
    --header 'Content-Type: application/json' \
    --header 'Cache-Control: no-cache' \
    --header 'kbn-xsrf: xxx' \
    --header 'Connection: keep-alive' \
    --header 'Authorization: Basic '$AUTHORIZATION'' \
    --data '{"id":"fleet-server-policy","name":"Fleet Server Policy","description":"Fleet Server policy generated by Kibana","namespace":"default","has_fleet_server":true,"monitoring_enabled":["logs","metrics"],"is_default_fleet_server":true}'

sleep 30

# Define the configuration file path
KIBANA_CONFIG_FILE="/etc/kibana/kibana.yml"

# Extract the file path from the uncommented line using grep and sed
CERT_PATH=$(grep -oP '^\s*elasticsearch.ssl.certificateAuthorities: \[\K[^\]]+' "$KIBANA_CONFIG_FILE")

# Get the fingerprint of the certificate and remove colons
FINGERPRINT=$(sudo openssl x509 -noout -fingerprint -sha256 -in "$CERT_PATH" | awk -F'=' '{print $2}' | tr -d ':' | tr '[:upper:]' '[:lower:]')


# Download and install Elastic Agent
cd /tmp
curl -L -O https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-8.14.3-linux-x86_64.tar.gz
tar xzvf elastic-agent-8.14.3-linux-x86_64.tar.gz
cd elastic-agent-8.14.3-linux-x86_64

# Install and configure Fleet server
sudo yes | sudo ./elastic-agent install \
  --fleet-server-es=https://$IP:9200 \
  --fleet-server-service-token=$SERVICE_TOKEN \
  --fleet-server-policy=fleet-server-policy \
  --fleet-server-es-ca-trusted-fingerprint=$FINGERPRINT \
  --fleet-server-port=8220

start_unattended_upgrades

# Output the Elasticsearch password and Fleet service token
#echo "Elasticsearch built-in superuser password: $PASSWORD"
echo "The password has also been saved to $USER_HOME/elastic-password"
#echo "Fleet service token: $SERVICE_TOKEN"
echo "The Fleet service token has also been saved to $USER_HOME/fleet-service-token"
echo
echo " ===== Installation Completed ===== "
echo "Navigate to http://$IP to access the Elasticsearch Interface"
echo "Login to the interface with the following credentials: "
echo "Username: elastic"
echo "Password: $PASSWORD"
