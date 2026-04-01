#define ENABLE_USER_AUTH
#define ENABLE_DATABASE

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <FirebaseClient.h>

#define WIFI_SSID        "BGSCET"
#define WIFI_PASSWORD    "BGSit@2022"

#define DATABASE_URL     "https://jal-rakshak-5ddf2-default-rtdb.firebaseio.com"
#define Web_API_KEY      "AIzaSyDhqRxDeagN8SSW_E6Y9zjkJxchLpKVxuk"
#define USER_EMAIL       "user1@gmail.com"
#define USER_PASS        "12345678"

#define RXD2 16
#define TXD2 17
HardwareSerial RS485Serial(2);

WiFiClientSecure ssl_client;
using AsyncClient = AsyncClientClass;
AsyncClient aClient(ssl_client);

FirebaseApp app;
UserAuth user_auth(Web_API_KEY, USER_EMAIL, USER_PASS);
RealtimeDatabase Database;

unsigned long lastSendTime = 0;
const unsigned long sendInterval = 30000;

// Modbus commands
uint8_t npkQuery[]             = {0x01, 0x03, 0x00, 0x1E, 0x00, 0x03, 0x65, 0xCD};
uint8_t phQuery[]              = {0x01, 0x03, 0x00, 0x06, 0x00, 0x01, 0x64, 0x0B};
uint8_t soilMoistureQuery[]    = {0x01, 0x03, 0x00, 0x12, 0x00, 0x01, 0x24, 0x0F};
uint8_t soilTemperatureQuery[] = {0x01, 0x03, 0x00, 0x13, 0x00, 0x01, 0x75, 0xCF};

void processData(AsyncResult &aResult) {
  if (aResult.isError()) {
    Serial.printf("Firebase Error: %s (code %d)\n",
                  aResult.error().message().c_str(),
                  aResult.error().code());
  }
}

void sendRS485Command(const uint8_t *cmd, size_t len) {
  while (RS485Serial.available()) RS485Serial.read();
  RS485Serial.write(cmd, len);
  RS485Serial.flush();
}

bool readRS485Response(uint8_t* buffer, size_t expected, uint32_t timeout = 500) {
  uint32_t start = millis();
  size_t idx = 0;

  while (millis() - start < timeout && idx < expected) {
    if (RS485Serial.available()) {
      buffer[idx++] = RS485Serial.read();
    }
  }
  return idx == expected;
}

void clearOldData() {
  HTTPClient http;
  String url = String(DATABASE_URL) + "/sensor_data.json";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.sendRequest("DELETE");
  http.end();
}

// DO calculation
float calculateDO(float N, float P, float temperature) {
  float pollutionIndex = (N + P) / 2.0;
  float DO = 14.0 - (pollutionIndex * 0.1) - (temperature * 0.05);

  if (DO < 0) DO = 0;
  if (DO > 14) DO = 14;

  return DO;
}

void setup() {
  Serial.begin(115200);
  RS485Serial.begin(9600, SERIAL_8N1, RXD2, TXD2);

  Serial.print("Connecting to WiFi...");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  while (WiFi.status() != WL_CONNECTED) {
    delay(300);
    Serial.print(".");
  }

  Serial.println("\nWiFi connected!");

  ssl_client.setInsecure();
  ssl_client.setConnectionTimeout(1000);
  ssl_client.setHandshakeTimeout(5);

  initializeApp(aClient, app, getAuth(user_auth), processData, "authTask");
  app.getApp<RealtimeDatabase>(Database);
  Database.url(DATABASE_URL);

  clearOldData();
}

void loop() {
  app.loop();
  if (!app.ready()) return;

  if (millis() - lastSendTime >= sendInterval) {
    lastSendTime = millis();

    float N = 0, P = 0, ph = 0, humidity = 0, temperature = 0, DO = 0;

    // ---- NPK ----
    sendRS485Command(npkQuery, sizeof(npkQuery));
    uint8_t npkResp[11];

    if (readRS485Response(npkResp, sizeof(npkResp))) {
      N = (npkResp[3] << 8 | npkResp[4]);
      P = (npkResp[5] << 8 | npkResp[6]);
      Serial.printf("N=%.1f P=%.1f\n", N, P);
    } else {
      Serial.println("NPK read failed (continuing...)");
    }

    delay(100);

    // ---- pH ----
    sendRS485Command(phQuery, sizeof(phQuery));
    uint8_t phResp[7];

    if (readRS485Response(phResp, sizeof(phResp))) {
      ph = ((phResp[3] << 8 | phResp[4]) / 100.0);
    }

    delay(100);

    // ---- Humidity ----
    sendRS485Command(soilMoistureQuery, sizeof(soilMoistureQuery));
    uint8_t moResp[7];

    if (readRS485Response(moResp, sizeof(moResp))) {
      humidity = ((moResp[3] << 8 | moResp[4]) / 10.0);
    }

    delay(100);

    // ---- Temperature ----
    sendRS485Command(soilTemperatureQuery, sizeof(soilTemperatureQuery));
    uint8_t tempResp[7];

    if (readRS485Response(tempResp, sizeof(tempResp))) {
      temperature = ((tempResp[3] << 8 | tempResp[4]) / 10.0);
    }

    delay(100);

    // ---- DO ----
    DO = calculateDO(N, P, temperature);

    Serial.printf("pH=%.2f Hum=%.1f Temp=%.1f DO=%.2f\n",
                  ph, humidity, temperature, DO);

    // ---- Firebase Upload ----
    String path = "/sensor_data/" + String(millis());

    Database.set<float>(aClient, path + "/N", N, processData, "N");
    Database.set<float>(aClient, path + "/P", P, processData, "P");
    Database.set<float>(aClient, path + "/ph", ph, processData, "ph");
    Database.set<float>(aClient, path + "/humidity", humidity, processData, "humidity");
    Database.set<float>(aClient, path + "/temperature", temperature, processData, "temperature");
    Database.set<float>(aClient, path + "/DO", DO, processData, "DO");

    Serial.println("Uploaded\n");
  }
}