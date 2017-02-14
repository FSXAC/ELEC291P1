import processing.serial.*;

// Serial
Serial      port;
String      readString = null;
final int   BAUD_RATE = 115200;
final int   LINEFEED = 10;

// screen grid setup

void setup() {
    fullScreen();

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
    displayState(width / 2, height / 2, 400, 6)
    if (port.available() > 0) {
        readString = port.readStringUntil(LINEFEED);
        if (readString != null) {
            text(readString, width/2, height/2);
        }
    }
}

void displayState(float x, float y, float radius, int nstates) {
    float angle = TWO_PI / nstates;
    for (float a = 0; a < TWO_PI; a += angle) {
        float sx = x + cos(a) * radius;
        float sy = y + sin(a) * radius;
        polygon(sx, sy, 100, 6);
    }
}

void polygon(float x, float y, float radius, int npoints) {
    float angle = TWO_PI / npoints;
    beginShape();
    for (float a = 0; a < TWO_PI; a += angle) {
        float sx = x + cos(a) * radius;
        float sy = y + sin(a) * radius;
        vertex(sx, sy);
    }
    endShape(CLOSE);
}
