#!/bin/bash

# Ensure the script is run as sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# Install curl
sudo apt update
sudo apt install -y curl

# Add Elasticsearch GPG key and repository
curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elastic.gpg
echo "deb [signed-by=/usr/share/keyrings/elastic.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list

# Update package list and install Elasticsearch
sudo apt update

# Temporary file to capture the Elasticsearch installation output
TEMP_FILE=$(mktemp)
sudo apt install -y elasticsearch | tee $TEMP_FILE

# Extract the generated password from the temporary file
PASSWORD=$(grep -oP '(?<=The generated password for the elastic built-in superuser is : ).*' $TEMP_FILE)

# Clean up the temporary file
rm -f $TEMP_FILE

# Start and enable Elasticsearch service
sudo systemctl start elasticsearch
sudo systemctl enable elasticsearch

# Install Kibana
sudo apt install -y kibana

# Generate Kibana enrollment token
KIBANA_TOKEN=$(sudo /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana)

# Setup Kibana with the enrollment token
echo $KIBANA_TOKEN | sudo /usr/share/kibana/bin/kibana-setup

# Start and enable Kibana service
sudo systemctl start kibana
sudo systemctl enable kibana

# Install Nginx
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

# Output the Elasticsearch password
echo "Elasticsearch built-in superuser password: $PASSWORD"
