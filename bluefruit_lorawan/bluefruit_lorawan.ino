#include <Arduino.h>
#include <SPI.h>

#include "Adafruit_BLE.h"
#include "Adafruit_BluefruitLE_SPI.h"
#include "Adafruit_BluefruitLE_UART.h"
#include "Adafruit_BLEGatt.h"

#include "BluefruitConfig.h"
#define FACTORYRESET_ENABLE         0
#define MINIMUM_FIRMWARE_VERSION    "0.7.0"
#define MODE_LED_BEHAVIOUR          "MODE"

#include <Sodaq_RN2483.h>
#define debugSerial Serial
#define loraSerial Serial1
#define loraResetPin 5

#ifndef CRLF
#define CRLF "\r\n"
#endif

#define HEX_CHAR_TO_NIBBLE(c) ((c >= 'A') ? (c - 'A' + 0x0A) : (c - '0'))
#define HEX_PAIR_TO_BYTE(h, l) ((HEX_CHAR_TO_NIBBLE(h) << 4) + HEX_CHAR_TO_NIBBLE(l))


/* ...hardware SPI, using SCK/MOSI/MISO hardware SPI pins and then user selected CS/IRQ/RST */
Adafruit_BluefruitLE_SPI ble(BLUEFRUIT_SPI_CS, BLUEFRUIT_SPI_IRQ, BLUEFRUIT_SPI_RST);
Adafruit_BLEGatt gatt(ble);


// Random Service UUID
const uint8_t LoRaWAN_Service_UUID[16] = {
  0x3A, 0x76, 0xBB, 0xF7, 0x35, 0x1A, 0x42, 0x76, 0xB4, 0xD6, 0xC3, 0x0F, 0x16, 0x94, 0x40, 0x84
};
// Characteristic IDs
const uint16_t LoRaWAN_HW_EUI = 0xFF01;
const uint16_t LoRaWAN_DEV_EUI = 0xFF02;
const uint16_t LoRaWAN_APP_EUI = 0xFF03;
const uint16_t LoRaWAN_APP_KEY = 0xFF04;
const uint16_t LoRaWAN_PORT = 0xFF05;
const uint16_t LoRaWAN_RETRIES = 0xFF06;
const uint16_t LoRaWAN_CMD = 0xFF00;
const uint16_t LoRaWAN_PKT = 0xFF10;
const uint16_t LoRaWAN_CON = 0xFF20;
const uint16_t LoRaWAN_STS = 0xFF21;
const uint16_t LoRaWAN_SNR = 0xFF22;
// Handles from GATT
static uint8_t _service_id = 0;
static uint8_t _hwEUI_id = 0;
static uint8_t _devEUI_id = 0;
static uint8_t _appEUI_id = 0;
static uint8_t _appKey_id = 0;
static uint8_t _port_id = 0;
static uint8_t _retries_id = 0;
static uint8_t _cmd_id = 0;
static uint8_t _pkt_id = 0;
static uint8_t _con_id = 0;
static uint8_t _sts_id = 0;
static uint8_t _snr_id = 0;
// NVM addresses
const uint16_t LoRaWAN_NVM_DEV_EUI = 0;
const uint16_t LoRaWAN_NVM_APP_EUI = 8;
const uint16_t LoRaWAN_NVM_APP_KEY = 16;

// Command constants
const uint8_t  LoRaWAN_CMD_None              = 0x00;
const uint8_t  LoRaWAN_CMD_Mask              = 0xf0;
const uint8_t  LoRaWAN_CMD_OTA               = 0x10;
const uint8_t  LoRaWAN_CMD_Send              = 0x20;
const uint8_t  LoRaWAN_CMD_SendAck           = 0x21;
const uint8_t  LoRaWAN_CMD_SendEmpty         = 0x22;
const uint8_t  LoRaWAN_CMD_SendEmptyAck      = 0x23;
const uint8_t  LoRaWAN_CMD_Reset             = 0x40;
const uint8_t  LoRaWAN_CMD_Save              = 0x50;
// Status constants
const uint8_t  LoRaWAN_STS_None              = 0;
const uint8_t  LoRaWAN_STS_OTASuccess        = 1;
const uint8_t  LoRaWAN_STS_OTAFailed         = 2;
const uint8_t  LoRaWAN_STS_NoError           = 3;
const uint8_t  LoRaWAN_STS_NoResponse        = 4;
const uint8_t  LoRaWAN_STS_Timeout           = 5;
const uint8_t  LoRaWAN_STS_PayloadSizeError  = 6;
const uint8_t  LoRaWAN_STS_InternalError     = 7;
const uint8_t  LoRaWAN_STS_Busy              = 8;
const uint8_t  LoRaWAN_STS_NetworkFatalError = 9;
const uint8_t  LoRaWAN_STS_NotConnected      = 10;
const uint8_t  LoRaWAN_STS_NoAcknowledgment  = 11;
const uint8_t  LoRaWAN_STS_Unknown           = 127;
const uint8_t  LoRaWAN_STS_OK                = LoRaWAN_STS_NoError;

// Storage in memory
static uint8_t RN2483_connected = false;
static uint8_t RN2483_port = 1;
static uint8_t RN2483_retries = 3;
static uint8_t hwEUI[8] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
static uint8_t devEUI[8] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
static uint8_t appEUI[8] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
static uint8_t appKey[16] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };

// A small helper
void error(const __FlashStringHelper*err) {
  debugSerial.println(err);
  while (1);
}

void initBLE() {
  debugSerial.println("init Bluetooth");
  
  if (!ble.begin(VERBOSE_MODE)) {
    error(F("Couldn't find Bluefruit, make sure it's in CoMmanD mode & check wiring?"));
  }

  // load non-volatile memory before factory reset (if we do one)
  ble.echo(false);
  ble.readNVM(LoRaWAN_NVM_DEV_EUI, devEUI, sizeof(devEUI));
  ble.readNVM(LoRaWAN_NVM_APP_EUI, appEUI, sizeof(appEUI));
  ble.readNVM(LoRaWAN_NVM_APP_KEY, appKey, sizeof(appKey));

  if (FACTORYRESET_ENABLE) {
    if (!ble.factoryReset()) {
      error(F("Couldn't factory reset"));
    }
  }

  /* Disable command echo from Bluefruit */
  ble.echo(false);

  /* Print Bluefruit information */
  ble.info();
  ble.verbose(false);

  /* Wait for connection */
  //while (!ble.isConnected()) {
  //  delay(500);
  //}

  // Need version 0.7.0 for GATT stuffs
  if (!ble.isVersionAtLeast(MINIMUM_FIRMWARE_VERSION)) {
    error(F("Bluefruit bootloader must be at least version 0.7.0"));
  }

  // Change name
  ble.sendCommandCheckOK("AT+GAPDEVNAME=LoRaWAN-SigTest");

  // Set LED mode
  ble.sendCommandCheckOK("AT+HWModeLED=" MODE_LED_BEHAVIOUR);

  // Clear custom services
  ble.sendCommandCheckOK("AT+GATTCLEAR");

  // Setup custom service and characteristics
  _service_id = gatt.addService((uint8_t *)LoRaWAN_Service_UUID);
  _hwEUI_id = gatt.addCharacteristic(LoRaWAN_HW_EUI, GATT_CHARS_PROPERTIES_READ, sizeof(hwEUI), sizeof(hwEUI), BLE_DATATYPE_BYTEARRAY, "Hardware EUI");
  _devEUI_id = gatt.addCharacteristic(LoRaWAN_DEV_EUI, GATT_CHARS_PROPERTIES_READ | GATT_CHARS_PROPERTIES_WRITE, sizeof(devEUI), sizeof(devEUI), BLE_DATATYPE_BYTEARRAY);
  _appEUI_id = gatt.addCharacteristic(LoRaWAN_APP_EUI, GATT_CHARS_PROPERTIES_READ | GATT_CHARS_PROPERTIES_WRITE, sizeof(appEUI), sizeof(appEUI), BLE_DATATYPE_BYTEARRAY);
  _appKey_id = gatt.addCharacteristic(LoRaWAN_APP_KEY, GATT_CHARS_PROPERTIES_READ | GATT_CHARS_PROPERTIES_WRITE, sizeof(appKey), sizeof(appKey), BLE_DATATYPE_BYTEARRAY);
  _port_id = gatt.addCharacteristic(LoRaWAN_PORT, GATT_CHARS_PROPERTIES_READ | GATT_CHARS_PROPERTIES_WRITE, 1, 1, BLE_DATATYPE_BYTEARRAY);
  _retries_id = gatt.addCharacteristic(LoRaWAN_RETRIES, GATT_CHARS_PROPERTIES_READ | GATT_CHARS_PROPERTIES_WRITE, 1, 1, BLE_DATATYPE_BYTEARRAY);
  _cmd_id = gatt.addCharacteristic(LoRaWAN_CMD, GATT_CHARS_PROPERTIES_WRITE, 1, 1, BLE_DATATYPE_BYTEARRAY);
  _pkt_id = gatt.addCharacteristic(LoRaWAN_PKT, GATT_CHARS_PROPERTIES_WRITE, 1, 20, BLE_DATATYPE_BYTEARRAY);
  _con_id = gatt.addCharacteristic(LoRaWAN_CON, GATT_CHARS_PROPERTIES_READ, 1, 1, BLE_DATATYPE_BYTEARRAY);
  _sts_id = gatt.addCharacteristic(LoRaWAN_STS, GATT_CHARS_PROPERTIES_READ | GATT_CHARS_PROPERTIES_INDICATE, 1, 1, BLE_DATATYPE_BYTEARRAY);
  _snr_id = gatt.addCharacteristic(LoRaWAN_SNR, GATT_CHARS_PROPERTIES_READ, 1, 4, BLE_DATATYPE_BYTEARRAY);

  // set attribute values (pre-reset)
  gatt.setChar(_hwEUI_id, hwEUI, sizeof(hwEUI));
  gatt.setChar(_devEUI_id, devEUI, sizeof(devEUI));
  gatt.setChar(_appEUI_id, appEUI, sizeof(appEUI));
  gatt.setChar(_appKey_id, appKey, sizeof(appKey));
  gatt.setChar(_port_id, RN2483_port);
  gatt.setChar(_retries_id, RN2483_retries);

  uint8_t advdata[25]; // 3 + 4 + 18
  int p = 0;
  // General discoverability of BLE device
  advdata[p++] = 2; // 2 bytes to follow
  advdata[p++] = 0x01; // Flag type
  advdata[p++] = 0x06; // LE General | BR/EDR not supported
  // Incomplete list of Service 16-bit UUIDs
  advdata[p++] = 3; // 3 bytes to follow
  advdata[p++] = 0x02; // Incomplete List of 16-bit service UUIDs
  advdata[p++] = 0x0A; // 0x180A = Device Information Service
  advdata[p++] = 0x18;
  // Incomplete list of Service 128-bit UUIDs
  advdata[p++] = 17; // 1 + 16 bytes to follow
  advdata[p++] = 0x06; // Incomplete List of 128-bit service UUIDs
  for (int i = 0; i < 16; ++i)
    advdata[p++] = LoRaWAN_Service_UUID[15 - i];
  ble.setAdvData(advdata, sizeof(advdata));

  ble.reset();
  ble.waitForOK();
  delay(1000);

  // reset device name
  ble.sendCommandCheckOK("AT+GAPDEVNAME=LoRaWAN-SigTest");

  // set attribute values (post-reset)
  gatt.setChar(_hwEUI_id, hwEUI, sizeof(hwEUI));
  gatt.setChar(_devEUI_id, devEUI, sizeof(devEUI));
  gatt.setChar(_appEUI_id, appEUI, sizeof(appEUI));
  gatt.setChar(_appKey_id, appKey, sizeof(appKey));
  gatt.setChar(_port_id, RN2483_port);
  gatt.setChar(_retries_id, RN2483_retries);

  // set status
  gatt.setChar(_cmd_id, LoRaWAN_CMD_None);
  gatt.setChar(_con_id, RN2483_connected);
  gatt.setChar(_sts_id, LoRaWAN_STS_None);
  gatt.setChar(_snr_id, (uint8_t *)"unk", 3);

  // re-flash NVM (if required)
  updateNVM(LoRaWAN_NVM_DEV_EUI, devEUI, sizeof(devEUI));
  updateNVM(LoRaWAN_NVM_APP_EUI, appEUI, sizeof(appEUI));
  updateNVM(LoRaWAN_NVM_APP_KEY, appKey, sizeof(appKey));
}

void loRaBeeSerialInit() {
  loraSerial.begin(LoRaBee.getDefaultBaudRate());
  loraSerial.flush();
  loraSerial.end();
  
  loraSerial.begin(300);
  loraSerial.write((uint8_t)0x00);
  loraSerial.flush();
  loraSerial.end();
  
  loraSerial.begin(LoRaBee.getDefaultBaudRate());
  loraSerial.write((uint8_t)0x55);
  loraSerial.flush();
}

void resetLoRa() {
  debugSerial.println("Reset RN2483");
  pinMode(loraResetPin, INPUT);
  delay(500);
  digitalWrite(loraResetPin, HIGH);
  pinMode(loraResetPin, OUTPUT);
  delay(500);
  
  loRaBeeSerialInit();
  delay(2000);
}

void initLoRa() {
  // Reset and Initialise RN2483
  resetLoRa();

  int cycles = 0;
  bool ready = false;
  do {
    if (cycles > 10) {
      resetLoRa();
      cycles = 0;
    }
    debugSerial.println("query RN2483");
    
    uint8_t buffer[64];
    queryLoRaBee("sys get hweui", buffer, sizeof(buffer));
    debugSerial.print("hweui: ");
    debugSerial.println((char *)buffer);
    if (strlen((char *)buffer) == 16) {
        int i;
        for (i = 0; i < 8; ++i) {
           hwEUI[i] = HEX_PAIR_TO_BYTE(buffer[(i * 2)], buffer[(i * 2) + 1]);
        }
        ready = true;
    } else if (strcmp((char *)buffer, "invalid_param") == 0) {
      
    }
    
    queryLoRaBee("sys get ver", buffer, sizeof(buffer));
    debugSerial.print("hwver: ");
    debugSerial.println((char *)buffer);
    
    cycles++;
  } while (!ready);

  LoRaBee.setDiag(debugSerial);
}

void updateNVM(uint16_t offset, uint8_t data[], uint16_t size) {
  uint8_t buffer[32];
  ble.readNVM(offset, buffer, size);
  if (memcmp(buffer, data, size) != 0) {
    ble.writeNVM(offset, data, size);
  }
}

void updateKeys() {
  gatt.getChar(_devEUI_id, devEUI, sizeof(devEUI));
  gatt.getChar(_appEUI_id, appEUI, sizeof(appEUI));
  gatt.getChar(_appKey_id, appKey, sizeof(appKey));
  updateNVM(LoRaWAN_NVM_DEV_EUI, devEUI, sizeof(devEUI));
  updateNVM(LoRaWAN_NVM_APP_EUI, appEUI, sizeof(appEUI));
  updateNVM(LoRaWAN_NVM_APP_KEY, appKey, sizeof(appKey));
}

void led_on() {
  digitalWrite(13, 1);
}

void led_off() {
  digitalWrite(13, 0);
}

void setup() {
  pinMode(13, OUTPUT); // setup led
  debugSerial.begin(57600);
  
  initLoRa();
  initBLE();
}

void loop() {
  uint8_t cmd = gatt.getCharInt8(_cmd_id);
  if (cmd) {
    int8_t sts = LoRaWAN_STS_None;
    
    debugSerial.print("cmd: ");
    debugSerial.println(cmd);
    
    gatt.setChar(_cmd_id, (uint8_t)LoRaWAN_CMD_None);
    
    if (cmd == LoRaWAN_CMD_OTA) {
      updateKeys();
      debugSerial.println("initiate OTA");
      if (LoRaBee.initOTA(loraSerial, devEUI, appEUI, appKey, true)) {
        debugSerial.println("OTA success");
        led_on();
        RN2483_connected = 1;
        sts = LoRaWAN_STS_OTASuccess;
      } else {
        debugSerial.println("OTA failure");
        led_off();
        RN2483_connected = 0;
        sts = LoRaWAN_STS_OTAFailed;
      }
      updateSNR();
      gatt.setChar(_con_id, RN2483_connected);
    } else if (cmd == LoRaWAN_CMD_Reset) {
      resetLoRa();
      led_off();
      RN2483_connected = 0;
      gatt.setChar(_con_id, RN2483_connected);
      sts = LoRaWAN_STS_OK;
    } else if (cmd == LoRaWAN_CMD_Save) {
      updateKeys();
      sts = LoRaWAN_STS_OK;
    } else if ((cmd & LoRaWAN_CMD_Mask) == LoRaWAN_CMD_Send) {
      if (RN2483_connected) {
        uint8_t pkt[32];
        uint8_t ret, len;

        // load parameters
        RN2483_port = gatt.getCharInt8(_port_id);
        RN2483_retries = gatt.getCharInt8(_retries_id);

        // load packet
        if ((cmd & LoRaWAN_CMD_SendEmpty) == LoRaWAN_CMD_SendEmpty) {
          memset(pkt, 0, sizeof(pkt));
          len = 0;
        } else {
          len = gatt.getChar(_pkt_id, pkt, sizeof(pkt));
        }
        
        // initiate send
        if ((cmd & LoRaWAN_CMD_SendAck) == LoRaWAN_CMD_SendAck) {
          debugSerial.println("sendReqAck");
          ret = LoRaBee.sendReqAck(RN2483_port, pkt, len, RN2483_retries);
        } else {
          debugSerial.println("send");
          ret = LoRaBee.send(RN2483_port, pkt, len); 
        }

        debugSerial.print("got: ");
        debugSerial.println(ret);

        // decode result
        switch (ret) {
          case NoError:           sts = LoRaWAN_STS_NoError; break;
          case NoResponse:        sts = LoRaWAN_STS_NoResponse; break;
          case Timeout:           sts = LoRaWAN_STS_Timeout; break;
          case PayloadSizeError:  sts = LoRaWAN_STS_PayloadSizeError; break;
          case InternalError:     sts = LoRaWAN_STS_InternalError; break;
          case Busy:              sts = LoRaWAN_STS_Busy; break;
          case NetworkFatalError: sts = LoRaWAN_STS_NetworkFatalError; break;
          case NotConnected:      sts = LoRaWAN_STS_NotConnected; break;
          case NoAcknowledgment:  sts = LoRaWAN_STS_NoAcknowledgment; break;
          default:
            sts = LoRaWAN_STS_Unknown;
            break;
        }

        // update snr
        if ((cmd & LoRaWAN_CMD_SendAck) == LoRaWAN_CMD_SendAck) {
          updateSNR();
        }
      } else {
        sts = LoRaWAN_STS_NotConnected;
      }
    }

    debugSerial.print("sts: ");
    debugSerial.println(sts);
    gatt.setChar(_sts_id, sts);
  }
  delay(100);
}

void updateSNR() {
  uint8_t buf[8];
  bool ok = queryLoRaBee("radio get snr", buf, sizeof(buf));
  if (ok) {
    int snrlen = strlen((char *)buf);
    if (snrlen > 4) {
      snrlen = 4;
    }
    debugSerial.print("snr: ");
    debugSerial.println((char *)buf);
    gatt.setChar(_snr_id, buf, snrlen);
  } else {
    gatt.setChar(_snr_id, (uint8_t *)"unk", 3);
  }
}

bool queryLoRaBee(char *cmd, uint8_t* buffer, uint16_t size) {
  buffer[0] = '\0';
  
  loraSerial.print(cmd);
  loraSerial.print(CRLF);
  
  unsigned long start = millis();
  int ret = 0;
  while (millis() < (start + DEFAULT_TIMEOUT)) {
    ret = readLn(loraSerial, buffer, size, 0);
    if (ret > 0)
      break;
  }
  return ret > 0;
}

uint16_t readLn(Stream& stream, uint8_t* buffer, uint16_t size, uint16_t start) {
  int len = stream.readBytesUntil('\n', buffer + start, size - 1);
  if (len > 0) {
      if (buffer[start + len - 1] == '\n') {
        buffer[start + len - 1] = '\0';
        len -= 1;
      }
      if (buffer[start + len - 1] == '\r') {
        buffer[start + len - 1] = '\0';
        len -= 1;
      }
  }
  return len;
}
