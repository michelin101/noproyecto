import mqtt from 'mqtt';

const BROKER_URL = 'ws://broker.emqx.io:8083/mqtt';
const PREFIX = 'grupo19/invernadero/';

let client = null;

export const connectMQTT = (onMessageCallback) => {
    if (!client) {
        client = mqtt.connect(BROKER_URL);
        client.on('connect', () => {
            console.log('Conectado al Broker MQTT');
            client.subscribe(`${PREFIX}#`);
        });
        client.on('message', (topic, message) => {
            onMessageCallback(topic, message.toString());
        });
    }
};

export const publishCommand = (subtopic, payload) => {
    if (client && client.connected) {
        client.publish(`${PREFIX}${subtopic}`, payload);
        console.log(`Comando enviado a ${PREFIX}${subtopic}: ${payload}`);
    } else {
        console.warn("No se pudo enviar el comando. MQTT no está conectado.");
    }
};