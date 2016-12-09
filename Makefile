SKETCH = lamp.ino

UPLOAD_SPEED = 921600
UPLOAD_PORT = /dev/tty.wchusbserial1410
BOARD = d1_mini
LIBS =	$(ESP_LIBS)/ESP8266WiFi \
				$(ESP_LIBS)/DNSServer \
				$(ESP_LIBS)/ESP8266WebServer \
				$(ESP_LIBS)/ESP8266mDNS \
				../libraries/FastLED \
				../libraries/WiFiManager \
				../libraries/ArtnetWifi \

include ../makeEspArduino/makeEspArduino.mk
