import processing.serial.*;

// Serial
Serial      port;
String      readString = null;
final int   BAUD_RATE = 115200;
final int   LINEFEED = 10;

void setup() {
    size(1000, 500);

    // initialize SPI
    printArray(Serial.list());
    port = new Serial(this, Serial.list()[0], BAUD_RATE);

    // throw out garbage values
    readString = port.readStringUntil(LINEFEED);
    readString = null;

    // setup canvas
    background(255);

    // setup drawing
    textAlign(CENTER, CENTER);
    textSize(50);
    fill(0);
}

void draw() {
    background(255);
    if (port.available() > 0) {
        readString = port.readStringUntil(LINEFEED);
        if (readString != null) {
            text(readString, width/2, height/2);
        }
    }
}
