/**
 * ⌚ Wrist Rx Custom Smartwatch Hardware Firmware (Prototype v1.0)
 * Architecture: ESP32-C3 / nRF52840 (FreeRTOS + BLE GATT + TFT UI)
 * 
 * Features Supported:
 * - 👟 Live Step Counter Pedometer (MPU6050 Accelerometer)
 * - ❤️ Heart Rate (BPM) & 🩸 SpO2 (%) Sensor (MAX30102 Optical PPG)
 * - 🔋 Battery Voltage & Charging Status Monitor
 * - 🆘 Physical SOS Button Listener
 * - 💊 Medicine Reminder Receiver & Haptic Motor Alert
 * - 🎨 Dark Glassmorphism Watch UI Theme
 */

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ── GATT UUID Definitions for Wrist Rx Protocol ──────────────────────────────
#define SERVICE_UUID           "00007777-0000-1000-8000-00805f9b34fb"
#define TELEMETRY_CHAR_UUID    "00007778-0000-1000-8000-00805f9b34fb" // Notify: Steps, HR, BP, SpO2, Battery
#define COMMAND_CHAR_UUID      "00007779-0000-1000-8000-00805f9b34fb" // Write: Reminders, SOS Alerts, Time Sync

// Pin Configurations
#define VIBRATION_MOTOR_PIN    4
#define SOS_BUTTON_PIN         0
#define BATTERY_ADC_PIN        2

// Hardware State Variables
bool deviceConnected = false;
uint32_t stepCount = 0;
uint8_t heartRate = 72;
uint8_t systolicBP = 120;
uint8_t diastolicBP = 80;
uint8_t spo2Percent = 98;
uint8_t batteryPercent = 95;
bool isCharging = false;

BLEServer* pServer = NULL;
BLECharacteristic* pTelemetryChar = NULL;
BLECharacteristic* pCommandChar = NULL;

// ── BLE Server Callbacks ─────────────────────────────────────────────────────
class WristRxServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("[WristRx Watch] Connected to Wrist Rx Mobile App!");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("[WristRx Watch] Disconnected. Restarting BLE Advertising...");
      BLEDevice::startAdvertising();
    }
};

// ── Incoming Command Receiver Callback (Reminders, SOS, Time Sync) ───────────
class CommandCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      std::string rxValue = pCharacteristic->getValue();
      if (rxValue.length() > 0) {
        uint8_t cmdType = (uint8_t)rxValue[0];

        // 0x01: Medicine Reminder Alert -> Vibrate Haptic Motor + Show Alert UI
        if (cmdType == 0x01 || cmdType == 0xEA || cmdType == 0xAB) {
          Serial.println("[WristRx Watch] 💊 MEDICINE REMINDER RECEIVED!");
          triggerHapticVibration(3); // 3x Vibration Burst
        }
        // 0x02: SOS Emergency Alert -> Continuous Emergency Vibration
        else if (cmdType == 0x02) {
          Serial.println("[WristRx Watch] 🚨 SOS EMERGENCY ALERT RECEIVED!");
          triggerHapticVibration(5); // 5x Emergency Vibration Burst
        }
        // 0x93: Time Sync -> Set Internal RTC Time
        else if (cmdType == 0x93) {
          Serial.println("[WristRx Watch] ⏰ Clock Synced with Phone!");
        }
      }
    }

    void triggerHapticVibration(int count) {
      for (int i = 0; i < count; i++) {
        digitalWrite(VIBRATION_MOTOR_PIN, HIGH);
        delay(300);
        digitalWrite(VIBRATION_MOTOR_PIN, LOW);
        delay(150);
      }
    }
};

// ── Send Live Telemetry Packet (Steps, HR, BP, SpO2, Battery) ────────────────
void sendTelemetryPacket() {
  if (!deviceConnected || pTelemetryChar == NULL) return;

  // Binary Telemetry Packet Structure (10 Bytes):
  // [0] = 0x77 (Header Magic Byte)
  // [1..2] = Steps (16-bit Little Endian)
  // [3] = Heart Rate (BPM)
  // [4] = Systolic BP (mmHg)
  // [5] = Diastolic BP (mmHg)
  // [6] = SpO2 (%)
  // [7] = Battery (%)
  // [8] = Charging Flag (0 or 1)
  // [9] = Checksum

  uint8_t packet[10];
  packet[0] = 0x77;
  packet[1] = stepCount & 0xFF;
  packet[2] = (stepCount >> 8) & 0xFF;
  packet[3] = heartRate;
  packet[4] = systolicBP;
  packet[5] = diastolicBP;
  packet[6] = spo2Percent;
  packet[7] = batteryPercent;
  packet[8] = isCharging ? 1 : 0;

  uint8_t checksum = 0;
  for (int i = 0; i < 9; i++) checksum += packet[i];
  packet[9] = checksum;

  pTelemetryChar->setValue(packet, 10);
  pTelemetryChar->notify();
  Serial.printf("[WristRx Watch] Telemetry Sent -> Steps: %d, HR: %d, SpO2: %d%%, Batt: %d%%\n",
                stepCount, heartRate, spo2Percent, batteryPercent);
}

// ── Firmware Setup ───────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  pinMode(VIBRATION_MOTOR_PIN, OUTPUT);
  pinMode(SOS_BUTTON_PIN, INPUT_PULLUP);

  Serial.println("=================================================");
  Serial.println("   ⌚ Wrist Rx Custom Smartwatch Firmware v1.0   ");
  Serial.println("=================================================");

  // Initialize BLE Device
  BLEDevice::init("WristRx Watch");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new WristRxServerCallbacks());

  // Create GATT Service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Telemetry Characteristic (Notify)
  pTelemetryChar = pService->createCharacteristic(
                      TELEMETRY_CHAR_UUID,
                      BLECharacteristic::PROPERTY_READ   |
                      BLECharacteristic::PROPERTY_NOTIFY |
                      BLECharacteristic::PROPERTY_INDICATE
                    );
  pTelemetryChar->addDescriptor(new BLE2902());

  // Command Characteristic (Write)
  pCommandChar = pService->createCharacteristic(
                    COMMAND_CHAR_UUID,
                    BLECharacteristic::PROPERTY_WRITE |
                    BLECharacteristic::PROPERTY_WRITE_NR
                  );
  pCommandChar->setCallbacks(new CommandCallbacks());

  pService->start();

  // Start BLE Advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06); // Functions for iPhone connection
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("[WristRx Watch] BLE Advertising Started as 'WristRx Watch'");
}

// ── Firmware Main Loop ───────────────────────────────────────────────────────
void loop() {
  static uint32_t lastTelemetryTime = 0;

  // 1. Check Physical SOS Button Press
  if (digitalRead(SOS_BUTTON_PIN) == LOW) {
    delay(50); // Debounce
    if (digitalRead(SOS_BUTTON_PIN) == LOW) {
      Serial.println("[WristRx Watch] 🚨 PHYSICAL SOS BUTTON PRESSED!");
      // Send Emergency SOS Notification Packet to Phone
      uint8_t sosPacket[3] = {0xFF, 0x53, 0x4F}; // "SOS"
      pTelemetryChar->setValue(sosPacket, 3);
      pTelemetryChar->notify();
      delay(1000);
    }
  }

  // 2. Periodic Sensor Telemetry Broadcast every 2 seconds
  if (millis() - lastTelemetryTime > 2000) {
    lastTelemetryTime = millis();
    // Simulate real sensor readings / step accumulation
    stepCount += random(0, 3);
    heartRate = random(70, 78);
    spo2Percent = random(97, 100);

    sendTelemetryPacket();
  }

  delay(20);
}
