# ⌚ Wrist Rx Custom Smartwatch Hardware Prototype (v1.0)

Welcome to the **Wrist Rx Custom Smartwatch Prototype Project**!
This repository contains the complete open-source firmware, BLE GATT communication protocol, and hardware wiring schematics to build your own custom smartwatch tailored 100% to **Wrist Rx**.

---

## 🛠️ Required Hardware Components:

1. **Microcontroller Board:** ESP32-C3 / ESP32 Pico D4 / nRF52840 (BLE 5.0 + FreeRTOS)
2. **Display:** 1.3" ST7789 240x240 IPS Color Display Screen
3. **Heart Rate & SpO2 Sensor:** MAX30102 Optical Heart Rate & Oxygen Sensor
4. **Pedometer Motion Sensor:** MPU6050 6-Axis Gyro/Accelerometer
5. **Haptic Feedback:** 3V Coin Vibration Motor Driver
6. **Emergency Button:** Physical Tactile Push Button (SOS Trigger)
7. **Power:** 3.7V 300mAh LiPo Battery + TP4056 USB-C Charger Chip

---

## 🔌 Hardware Pinout Wiring Diagram:

| Component | Component Pin | ESP32-C3 Pin | Function |
|---|---|---|---|
| **ST7789 Display** | SCL / SDA / CS | GPIO 6, 7, 10 | SPI Display Communication |
| **MAX30102 Sensor** | SDA / SCL | GPIO 4, 5 | I2C Heart Rate & SpO2 Sensor |
| **MPU6050 Sensor** | SDA / SCL | GPIO 4, 5 | I2C Pedometer Accelerometer |
| **Vibration Motor** | VCC / NPN Base | GPIO 4 | Haptic Reminder Alert Pulse |
| **SOS Push Button** | SW | GPIO 0 | Physical SOS Emergency Trigger |
| **Battery Voltage** | ADC | GPIO 2 | Battery Percentage Reading |

---

## 🚀 How to Flash Firmware to Watch:

1. Open `firmware.cpp` in **Arduino IDE** or **PlatformIO**.
2. Select Board: `ESP32C3 Dev Module`.
3. Install Libraries: `ESP32 BLE Arduino`, `Adafruit_ST7789`, `MAX30105`.
4. Click **Upload** to flash the smartwatch.
5. Turn on Bluetooth on your phone and open **Wrist Rx** — your custom watch will advertise as **`WristRx Watch`**!

---

## 🛰️ Custom BLE GATT Protocol Specification:

- **GATT Service UUID:** `00007777-0000-1000-8000-00805f9b34fb`
- **Telemetry Characteristic (Notify):** `00007778-0000-1000-8000-00805f9b34fb`
  - *Packet Format (10 Bytes):* `[0x77, Steps_L, Steps_H, HR, SysBP, DiaBP, SpO2%, Battery%, ChargingFlag, Checksum]`
- **Command Characteristic (Write):** `00007779-0000-1000-8000-00805f9b34fb`
  - `0x01 + Name`: Medicine Reminder Haptic Alert
  - `0x02 + SOS`: Emergency SOS Vibration Alert
  - `0x93 + Time`: RTC Clock Synchronization
