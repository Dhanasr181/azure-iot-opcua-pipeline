import ssl
import paho.mqtt.client as mqtt
import time
import json

payload_str = '{"MessageId":null,"MessageType":"ua-data","PublisherId":"\"device2\"","Messages":[{"DataSetWriterId":62541,"SequenceNumber":51,"MetaDataVersion":{"MajorVersion":3079857672,"MinorVersion":3079856868},"Timestamp":"2026-06-26T20:48:13.1655581Z","Status":0,"MessageType":"ua-keyframe","Payload":{"Server localtime":{"UaType":13,"Value":"2026-06-26T20:48:13.1655746Z"}}}]}'

def on_connect(client, userdata, flags, rc):
    print('CONNACK received with code %d.' % (rc))
    if rc == 0:
        print('Publishing OPC UA message...')
        client.publish('devices/device2/messages/events/', payload=payload_str, qos=0)

def on_publish(client, userdata, mid):
    print('Message %d published.' % mid)

def on_disconnect(client, userdata, rc):
    print('Disconnected with result code: %s' % str(rc))

client = mqtt.Client(client_id='device2', protocol=mqtt.MQTTv311)
client.on_connect = on_connect
client.on_publish = on_publish
client.on_disconnect = on_disconnect
client.username_pw_set('iot63018734.azure-devices.net/device2/?api-version=2021-04-12')
client.tls_set(ca_certs='/etc/ssl/certs/ca-certificates.crt', certfile='/certs/device.crt', keyfile='/certs/device.key', tls_version=ssl.PROTOCOL_TLSv1_2)
client.connect('iot63018734.azure-devices.net', 8883, 60)
client.loop_start()
time.sleep(5)