# ELK 8.0 Installer

This script automates the installation and configuration of Elasticsearch, Kibana, and Nginx on your system. It also captures and saves the generated password for the Elasticsearch built-in superuser and sets up a Fleet server. 

Additionally, there is a client script to install and enroll the Elastic Agent into the Fleet server.

## Usage

### ELK Stack and Fleet Server Installation

Run the following command to download and execute the installer script:

```sh
wget -qO- https://raw.githubusercontent.com/Oiuhqw/ELK-8.0-Installer/main/installer.sh | sudo bash
```

### Elastic Agent Installation and Enrollment

Run the following command to download and execute the client script on the intended monitoring system after the ELK stack and Fleet server have been successfully installed:

```sh
wget https://raw.githubusercontent.com/Oiuhqw/ELK-8.0-Installer/main/client.sh -qO client.sh; sudo bash client.sh
```

## What the Scripts Do

### Installer Script (`installer.sh`)

1. Installs curl and jq: Ensures these tools are installed on your system.
2. Adds Elasticsearch GPG Key and Repository: Adds the necessary GPG key and repository for Elasticsearch.
3. Installs Elasticsearch: Downloads and installs Elasticsearch. The generated password for the built-in superuser is captured and saved to a file.
4. Starts and Enables Elasticsearch: Configures Elasticsearch to start on boot.
5. Installs Kibana: Downloads and installs Kibana.
6. Generates Kibana Enrollment Token: Creates an enrollment token for Kibana.
7. Sets Up Kibana: Configures Kibana using the enrollment token and adds encryption keys.
8. Starts and Enables Kibana: Configures Kibana to start on boot.
9. Installs Nginx: Downloads and installs Nginx.
10. Configures Nginx: Modifies the Nginx configuration to proxy requests to Kibana.
11. Restarts and Enables Nginx: Configures Nginx to start on boot.
12. Sets Up Fleet Server: Configures Fleet server and saves the service token.

### Client Script (`client.sh`)

1. Installs necessary packages: Ensures curl, auditd, and jq are installed on your system.
2. Prompts for Elasticsearch credentials and IP address.
3. Creates a Client Policy in Kibana: Configures a policy for the Elastic Agent.
4. Downloads and Installs Elastic Agent: Sets up the Elastic Agent and enrolls it with the Fleet server.
5. Configures Audit Rules: Adds and applies audit rules for monitoring.

## Important Information

- Password: The password for the Elasticsearch built-in superuser will be printed to the console at the end of the script and saved to a file named `elastic-password` in the `elk-configs` directory of the user who ran the script.
- Fleet Service Token: The service token for the Fleet server will be saved to a file named `fleet-service-token` in the `elk-configs` directory of the user who ran the script.

## Accessing the Elasticsearch Panel

Navigate to `<your-host-ip-address>` to access the Elasticsearch panel.

## How to use the Indiviual Scripts

### Downloading Example

```sh
wget -qO- https://raw.githubusercontent.com/Oiuhqw/ELK-8.0-Installer/main/installer.sh | sudo bash
```

After the script completes, you should see a message similar to, it will also include the command to be used on the client system:

```
Navigate to http://<your-host-ip-address> to access the Elasticsearch Interface
Login to the interface with the following credentials: 
Username: elastic
Password: <generated-password>
```

Replace `<your-host-ip-address>` with the actual IP address of your host to access the Elasticsearch panel.

### Client Enrollment Example

```sh
wget https://raw.githubusercontent.com/Oiuhqw/ELK-8.0-Installer/main/client.sh -qO client.sh; sudo bash client.sh
```

After the client script completes, you should see a message indicating that the installation and enrollment were successful.

Navigating back to the main server webpage should show that a new agent and policy have been created.
