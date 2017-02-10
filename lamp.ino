#include<ESP8266WiFi.h>

#include<FastLED.h>

#include<DNSServer.h>
#include<ESP8266WebServer.h>
#include<WiFiManager.h>

#include<ESP8266mDNS.h>

#include <WiFiUdp.h>
#include <ArtnetWifi.h>

#define DATA_PIN 7
#define CLOCK_PIN 5

#define NUM_LEDS 300
#define LEADER_SIZE 22
#define USABLE_LEDS (NUM_LEDS - LEADER_SIZE)
#define NUM_CHANNELS (USABLE_LEDS * 3)

#define ROWS 10
#define COLS 30

#define FIRST_UNIVERSE 0
#define NECESSARY_UNIVERSES ((NUM_CHANNELS / 512) + ((NUM_CHANNELS % 512) ? 1 : 0))
#define PIXELS_PER_UNIVERSE 170

CRGBArray<NUM_LEDS> leds;

ArtnetWifi artnet;
bool artnetReceived = false;

void allOff() { 
  leds.fill_solid(CHSV(0,0,0));
  FastLED.show(); 
}

uint8_t baseHue = 0;

void rainbowCycle() {
  static uint8_t hue;
  fill_rainbow( &(leds[LEADER_SIZE-1]), NUM_LEDS - LEADER_SIZE, baseHue, 1);
  leds.fadeToBlackBy(200);
  FastLED.show(); 
  baseHue++;
  FastLED.delay(33);
}

void printFrameInfo(uint8_t universe, uint8_t sequence, uint16_t length) {
  Serial.print("[#");
  Serial.print((int) sequence);
  Serial.print(" ");
  Serial.print((int) universe);
  Serial.print("/");
  Serial.print((int) length);
  Serial.print("]");
}

void printFrameData(uint8_t* data) {
  int dataLength = 512;
  for (int i = 0; i < dataLength; i++) {
    Serial.print(i);
    Serial.print(": ");
    Serial.println((int) data[i]);
    delay(0);
  }
}

bool universesReceived[NECESSARY_UNIVERSES];
bool framesSinceLastPaint = 0;

void onDmxFrame(uint16_t universe, uint16_t length, uint8_t sequence, uint8_t* data) {
  bool bufferedControl = true;
  bool haveAllUniverses = true;
  uint8_t universeIndex = universe - FIRST_UNIVERSE;

  // Allow unbuffered control on universe i + 10
  if (universeIndex >= 10) {
    bufferedControl = false;
    universeIndex -= 10;
  }

  // Stop the idle loop on first ArtNet frame
  artnetReceived = true;

  // printFrameInfo(universe, sequence, length);
  // printFrameData(data);

  for (int i = 0; i < PIXELS_PER_UNIVERSE; i++) {
    int ledIndex = i + (universeIndex * PIXELS_PER_UNIVERSE) + (LEADER_SIZE - 1);

    if (ledIndex >= NUM_LEDS)
      break;

    leds[ledIndex] = CRGB(data[i * 3], data[i * 3 + 1], data[i * 3 + 2]);
  }

  if (universeIndex == FIRST_UNIVERSE) { memset(universesReceived, 0, NECESSARY_UNIVERSES); }
  if (universeIndex < NECESSARY_UNIVERSES) { universesReceived[universeIndex] = true; }

  haveAllUniverses = true;
  for (int i = 0; i < NECESSARY_UNIVERSES; i++) {
    if (universesReceived[i] == false) {
      haveAllUniverses = false;
      break;
    }
  }

  if (haveAllUniverses || !bufferedControl) {
    // Serial.print('.');
    FastLED.show();
    memset(universesReceived, 0, NECESSARY_UNIVERSES);
  }
}

void setupMDNS() {
  if (!MDNS.begin("blinky")) {
    Serial.println("*mDNS: Error setting up MDNS responder!");
  } else {
    Serial.println("*mDNS: responder started");

    MDNS.addService("artnet", "udp", 6454);
    Serial.println("*mDNS: registered artnet(UDP) on port 6454");
  }
}

void setup() {
  Serial.begin(9600);

  FastLED.addLeds<APA102, DATA_PIN, CLOCK_PIN, BGR>(leds, NUM_LEDS);
  allOff();

  WiFiManager wifiManager;
  wifiManager.autoConnect();

  artnet.begin();
  artnet.setArtDmxCallback(onDmxFrame);

  setupMDNS();
}

void loop(){ 
  artnet.read();

  // Idle rainbow
  if (!artnetReceived) { rainbowCycle(); }
}
