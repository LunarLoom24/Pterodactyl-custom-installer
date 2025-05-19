---

# Pterodactyl-custom-installer

A fully automated bash script for deploying the [Pterodactyl](https://pterodactyl.io) panel and Wings daemon, with optional LiveNode integration and HTTPS setup using Let's Encrypt.

This script is ideal for server admins who want a fast, repeatable deployment method for game hosting infrastructure.

---

## 🚀 Features

* ✅ Full system update & required package installation
* 🔐 Configures UFW firewall with common ports
* 🌍 Timezone auto-setup (defaults to Europe/Helsinki)
* 🛠️ Installs Pterodactyl Panel & Wings using the installer
* 🔧 Prompts user for custom domain and configuration
* 🔑 Automatically generates Let's Encrypt SSL certificate
* ⚙️ Optionally configures and starts LiveNode
* 🧩 Clean separation of logic for extensibility

---

## 📥 Quick Install

Run the following command on a fresh Ubuntu-based server:

```bash
sudo apt update && apt install curl && bash <(curl -s https://raw.githubusercontent.com/LunarLoom24/Pterodactyl-custom-installer/refs/heads/main/pterodactyl_setup.sh)
```
```bash-BETA
sudo apt update && apt install curl && bash <(curl -s https://static.lunarhome.eu/pterodactyl_setup.sh)
```

> ⚠️ **Disclaimer:** Always review scripts before executing them on production environments.

---

## 📝 What the Script Does

1. **System Preparation**

   * Updates packages
   * Installs Apache, Curl, Certbot, Smartmontools
   * Sets timezone and localtime

2. **Firewall Configuration**

   * Opens ports: 22 (SSH), 80 (HTTP), 443 (HTTPS), 3306, 8080, 2022, 5555, 123/udp
   * Enables and reloads UFW

3. **Monitoring Script**

   * Optionally installs monitoring from `linux123123.com`

4. **Pterodactyl Installation**

   * Runs the panel & Wings installer from `pterodactyl-installer.se`

5. **Interactive Setup**

   * Prompts for domain (e.g., `node1.yourdomain.com`)
   * Prompts for Wings and LiveNode config commands

6. **SSL Setup**

   * Uses Certbot with Apache to issue a certificate for your domain

7. **Wings and LiveNode**

   * Runs the user-provided configuration commands
   * Starts and enables services

---

## 💡 Example Inputs

### Domain

```
node1.yourdomain.com
```

### Wings Command

```bash
sudo wings configure --panel-url https://panel.yourdomain.com --token YOUR_TOKEN --node NODE_ID
```

### LiveNode Command (Optional)

```bash
livenode --config YOUR_TOKEN YOUR_IP:3001
```

---

## 🛡️ Requirements

* Ubuntu 20.04 or later
* Root privileges or `sudo` access
* A domain name pointed to your server IP
* Ports 80 and 443 open to the public internet

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
You are free to use, modify, and distribute this software.

---

## 🤝 Contributing

Pull requests, issues, and forks are welcome.
Feel free to open suggestions or feature requests to make the script better!

---

## 🌐 Resources

* [Pterodactyl Documentation](https://pterodactyl.io)
* [Certbot](https://certbot.eff.org/)
* [UFW Manual](https://help.ubuntu.com/community/UFW)

---

## 🧠 Developer / Coder

**LunarLoom24**
GitHub: [@LunarLoom24](https://github.com/LunarLoom24)

---
