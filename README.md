# ELK 8.0 Installer

This script automates the installation and configuration of Elasticsearch, Kibana, and Nginx on your system. It also captures and saves the generated password for the Elasticsearch built-in superuser.

## Usage

Run the following command to download and execute the installer script:

```sh
wget -qO- https://raw.githubusercontent.com/Oiuhqw/ELK-8.0-Installer/main/installer.sh | sudo bash
```

## What the Script Does
  1. Installs curl: Ensures curl is installed on your system.
  2. Adds Elasticsearch GPG Key and Repository: Adds the necessary GPG key and repository for Elasticsearch.
  3. Installs Elasticsearch: Downloads and installs Elasticsearch. The generated password for the built-in superuser is captured and saved to a file.
  4. Starts and Enables Elasticsearch: Configures Elasticsearch to start on boot.
  5. Installs Kibana: Downloads and installs Kibana.
  6. Generates Kibana Enrollment Token: Creates an enrollment token for Kibana.
  7. Sets Up Kibana: Configures Kibana using the enrollment token.
  8. Starts and Enables Kibana: Configures Kibana to start on boot.
  9. Installs Nginx: Downloads and installs Nginx.
  10. Configures Nginx: Modifies the Nginx configuration to proxy requests to Kibana.
  11. Restarts and Enables Nginx: Configures Nginx to start on boot.

## Important Information
- Password: The password for the Elasticsearch built-in superuser will be printed to the console at the end of the script and saved to a file named elastic-password in the home directory of the user who ran the script.
  
- Accessing the Elasticsearch Panel: Navigate to http://<your-host-ip-address> to access the Elasticsearch panel.

## Example
```
wget -qO- https://raw.githubusercontent.com/Oiuhqw/ELK-8.0-Installer/main/installer.sh | sudo bash
```
After the script completes, you should see a message similar to:
```
Elasticsearch built-in superuser password: <your-password>
The password has also been saved to /home/<your-user>/elastic-password
```
Replace <your-host-ip-address> with the actual IP address of your host to access the Elasticsearch panel.

## License
This project is licensed under the MIT License. See the LICENSE file for details.

## Contributing
If you find any issues or have suggestions for improvements, feel free to open an issue or submit a pull request.

## Disclaimer
This script is provided as-is without any warranty. Use at your own risk.
