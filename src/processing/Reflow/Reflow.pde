import processing.serial.*;

// Serial
Serial      mySerial;
int         temperature;
final int   BAUD_RATE = 115200;

void setup() {
    size(1000, 500);
    printArray(Serial.list());

    // initialize SPI
    mySerial = new Serial(this, Serial.list()[0], BAUD_RATE);

    // setup canvas
    background(255);
}

void draw() {
    if (mySerial.available() > 0) {
        // do something here
    }
}
