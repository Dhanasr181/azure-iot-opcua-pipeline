# OPC UA to Azure IoT Hub Pipeline

This project implements an Industrial Internet of Things (IIoT) pipeline that simulates generating OPC UA telemetry data and publishing it securely to Azure IoT Hub over MQTT with mutual TLS (mTLS) authentication.

## Architecture Overview

The pipeline follows this industrial flow:
**PLC (Simulated)** ➔ **OPC UA Publisher** ➔ **MQTT + TLS (`stunnel`)** ➔ **Azure IoT Hub**

1. **OPC UA Publisher**: Built using the open-source `open62541` C library. It packages data into standardized OPC UA JSON payloads.
2. **TLS Proxy (`stunnel`)**: Azure IoT Hub requires strict TLS encryption. Because the underlying MQTT C-client used by `open62541` does not natively support TLS, we use `stunnel` as a secure local proxy. The publisher sends unencrypted MQTT data locally to `stunnel`, which wraps it in military-grade TLS encryption using X.509 certificates and forwards it to Azure IoT Hub.

## What Codes Were Developed & Why?

* **`Dockerfile`**: 
  * **Why:** To create a reproducible, isolated Linux environment.
  * **What it does:** Installs all necessary dependencies (Cmake, OpenSSL, stunnel, etc.), builds the `open62541` library from source with PubSub/MQTT enabled, compiles the publisher/subscriber C applications, and injects our custom certificate generation and thumbprint extraction scripts.
* **`docker-compose.yml`**:
  * **Why:** To easily manage and orchestrate the multiple services (Publisher, Subscriber, and Thumbprint Extractors) without typing long Docker commands.
  * **What it does:** Defines the containers, mounts the `./certs` volumes so certificates are saved to your local machine, and passes the environment variables (Device ID and Hub Name) into the containers.
* **`generate_certs.sh` (Inside Dockerfile)**:
  * **Why:** Azure requires devices to authenticate. We chose X.509 self-signed certificates.
  * **What it does:** Automatically generates a 2048-bit RSA key and an X.509 certificate tailored specifically to your Device ID. It also automatically configures `stunnel` to route traffic to your specific Azure IoT Hub.
* **`extract_thumbprint.sh` (Inside Dockerfile)**:
  * **Why:** Azure IoT Hub requires you to input the SHA-256 "Thumbprint" of your certificate when registering the device in the portal.
  * **What it does:** Extracts the exact thumbprint hash from the generated certificate and prints it to the logs so you can easily copy and paste it into Azure.

---

## How to Change IoT Hub or Device Details in the Future

If you create a new IoT Hub, or want to deploy a new device (e.g., `device3`), you must follow these exact steps to ensure the security certificates are generated correctly:

### Step 1: Update the configuration
1. Open the `.env` file (or `docker-compose.yml` if you hardcoded them there).
2. Change `IOT_HUB_NAME` to your new Azure IoT Hub URL (e.g., `new-hub.azure-devices.net`).
3. Change `IOT_DEVICE_ID` to your new device name (e.g., `device3`).

### Step 2: Delete old certificates (CRITICAL)
**Yes, you MUST create new certificates!** X.509 certificates are hardcoded with the specific Device ID. If you change the Device ID, the old certificate is invalid.
To force the system to generate new certificates:
1. Delete all files inside the `./certs` folder on your host machine.
2. Delete all files inside the `./certs-sub` folder (if using the subscriber).

### Step 3: Restart Docker to generate new certificates
Run the following commands in your terminal:
```bash
docker-compose down
docker-compose up -d
```
When the containers start, the `generate_certs.sh` script will notice the `./certs` folder is empty and will automatically generate brand-new certificates using your new Device ID.

### Step 4: Get the new Thumbprints
Run the following command to get the new SHA-256 thumbprint:
```bash
docker logs cert-thumbprint-extractor
```

### Step 5: Register the device in Azure IoT Hub
Go to the Azure Portal ➔ Your IoT Hub ➔ Devices ➔ **+ Add Device**.
* **Device ID:** (Must exactly match what you put in the `.env` file)
* **Authentication type:** Self-signed X509 Certificate
* **Thumbprints:** Paste the SHA-256 thumbprint you copied in Step 4 into both the Primary and Secondary boxes.

Once saved, your containers will immediately connect and begin transmitting telemetry to the new hub!

---

## Developer Guide for OT Specialists (Azure IoT Integration)

If you are writing the core OPC UA PubSub logic (reading from PLCs, formatting data, etc.) in the future, you do **not** need to worry about complex TLS encryption or Azure authentication tokens! The networking foundation has been abstracted for you. 

Here is the "Common Code" integration knowledge you need to integrate your future C applications into this Azure IoT Hub pipeline:

### 1. Azure Authentication (Already Handled)
We modified the core networking layer in open62541/arch/common/eventloop_mqtt.c. It automatically pulls the IOT_DEVICE_ID and IOT_HUB_NAME environment variables and formats them into the strict MQTT Username that Azure IoT Hub demands:
[HubName]/[DeviceId]/?api-version=2021-04-12

Because of this, your C code simply connects to 127.0.0.1:1883 (which is routed through our stunnel TLS proxy) without needing any passwords or SAS tokens in your C code!

### 2. The Publisher Topic (Telemetry)
When writing your publisher code (like 	utorial_pubsub_mqtt_publish.c), Azure strictly mandates what MQTT topic you publish to. 
Your publishing topic **must** be formatted like this:
`c
// Replace device2 with your actual device ID (or read it dynamically)
UA_String topic = UA_String("devices/device2/messages/events/");
`

### 3. The Subscriber Topic (Cloud-to-Device Commands)
If you are writing logic to listen for commands *from* the Azure cloud to control local PLCs (like 	utorial_pubsub_mqtt_subscribe.c), you must subscribe to this specific wildcard topic:
`c
// Replace device2-sub with your actual device ID
UA_String topic = UA_String("devices/device2-sub/messages/devicebound/#");
`

### 4. Payload Format
Azure IoT Hub expects the payload to be a valid JSON string. As long as you use the UA_ENABLE_JSON_ENCODING flag when building the open62541 PubSub dataset writer, the telemetry will be natively parsed by Azure IoT Hub, IoT Explorer, and Azure Stream Analytics.
