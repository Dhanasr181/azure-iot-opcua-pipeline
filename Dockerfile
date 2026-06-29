FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LD_LIBRARY_PATH=/usr/local/lib

RUN apt-get update && apt-get install -y \
    cmake \
    build-essential \
    git \
    python3 \
    libmbedtls-dev \
    libssl-dev \
    openssl \
    ca-certificates \
    libpaho-mqtt-dev \
    pkg-config \
    curl \
    stunnel4 \
    mosquitto-clients \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Copy your local repository folder cloned from Windows context directly into the image build environment
COPY ./open62541 /workspace/open62541

# 1. Build the foundational core static object library
WORKDIR /workspace/open62541
RUN mkdir -p build && cd build && \
    cmake \
    -DUA_ENABLE_PUBSUB=ON \
    -DUA_ENABLE_PUBSUB_MQTT=ON \
    -DUA_ENABLE_MQTT=ON \
    -DUA_ENABLE_JSON_ENCODING=ON \
    -DUA_ENABLE_ENCRYPTION=ON \
    -DUA_ENABLE_ENCRYPTION_OPENSSL=ON \
    -DUA_BUILD_EXAMPLES=OFF \
    -DUA_ENABLE_UNIT_TESTS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    .. && \
    make -j4 && \
    make install

# 2. Compile publisher binary with MQTT support
RUN gcc -v -O2 /workspace/open62541/examples/pubsub/tutorial_pubsub_mqtt_publish.c \
    -I/workspace/open62541/build/src_generated \
    -I/workspace/open62541/include -I/workspace/open62541/plugins/include \
    -I/workspace/open62541/build/include \
    -L/usr/local/lib -L/usr/lib/x86_64-linux-gnu \
    -lopen62541 -lssl -lcrypto -lpaho-mqtt3cs -lpthread \
    -o /usr/local/bin/tutorial_pubsub_mqtt_publish

# 3. Compile subscriber binary with MQTT support
RUN gcc -v -O2 /workspace/open62541/examples/pubsub/tutorial_pubsub_mqtt_subscribe.c \
    -I/workspace/open62541/build/src_generated \
    -I/workspace/open62541/include -I/workspace/open62541/plugins/include \
    -I/workspace/open62541/build/include \
    -L/usr/local/lib -L/usr/lib/x86_64-linux-gnu \
    -lopen62541 -lssl -lcrypto -lpaho-mqtt3cs -lpthread \
    -o /usr/local/bin/tutorial_pubsub_mqtt_subscribe

# Automated Certificate Engine generation block
RUN mkdir -p /root/scripts && printf '#!/bin/bash\nset -e\nif [ ! -f /certs/device.crt ]; then\n  echo "Generating X.509 certificates..."\n  mkdir -p /certs\n  openssl genrsa -out /certs/device.key 2048 2>/dev/null\n  DEVICE_NAME=${IOT_DEVICE_ID:-device2}\n  openssl req -new -key /certs/device.key -out /certs/device.csr -subj "/C=US/ST=State/L=City/O=Organization/CN=${DEVICE_NAME}" 2>/dev/null\n  openssl x509 -req -days 3650 -in /certs/device.csr -signkey /certs/device.key -out /certs/device.crt 2>/dev/null\n  rm -f /certs/device.csr\n  echo "✓ Certificates generated successfully in /certs"\nelse\n  echo "✓ Certificates already exist"\nfi\n\necho "Configuring stunnel for Azure IoT Hub..."\nHUB_NAME=${IOT_HUB_NAME:-$AZURE_IOT_HUB_NAME}\ncat <<EOF > /etc/stunnel/stunnel.conf\npid = /var/run/stunnel.pid\nforeground = yes\n\n[mqtts]\nclient = yes\naccept = 127.0.0.1:1883\nconnect = $HUB_NAME:8883\ncert = /certs/device.crt\nkey = /certs/device.key\nsni = $HUB_NAME\nEOF\nstunnel4 /etc/stunnel/stunnel.conf &\n' > /root/scripts/generate_certs.sh && chmod +x /root/scripts/generate_certs.sh

# Add thumbprint extraction script
RUN printf '#!/bin/bash\nif [ ! -f /certs/device.crt ]; then\n  echo "Error: /certs/device.crt not found"\n  exit 1\nfi\necho "Extracting certificate thumbprint..."\nTHUMBPRINT=$(openssl x509 -in /certs/device.crt -noout -fingerprint -sha1 | cut -d= -f2 | tr -d ":"\n)\necho "Certificate Thumbprint (SHA1):"\necho "$THUMBPRINT"\nTHUMBPRINT_SHA256=$(openssl x509 -in /certs/device.crt -noout -fingerprint -sha256 | cut -d= -f2 | tr -d ":"\n)\necho ""\necho "Certificate Thumbprint (SHA256):"\necho "$THUMBPRINT_SHA256"\necho "$THUMBPRINT" > /certs/thumbprint_sha1.txt\necho "$THUMBPRINT_SHA256" > /certs/thumbprint_sha256.txt\necho ""\necho "✓ Thumbprints saved to /certs/thumbprint_sha1.txt and /certs/thumbprint_sha256.txt"\n' > /root/scripts/extract_thumbprint.sh && chmod +x /root/scripts/extract_thumbprint.sh

WORKDIR /workspace
