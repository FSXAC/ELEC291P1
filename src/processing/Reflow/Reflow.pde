import processing.serial.*;

// Serial
Serial      port;
String      readString = null;
final int   BAUD_RATE = 115200;
final int   LINEFEED = 10;

// state diagram setup
final int   SMALL_HEX = 100;

// states
final String[] STATES = {
    "Main Menu",
    "Ramp To Soak",
    "Preehat Soak",
    "Ramp to Peak",
    "Reflow",
    "Cooling"
};

int state = 0;

void setup() {
    fullScreen();
    //size(500, 500);

    // initialize SPI
    printArray(Serial.list());
    port = new Serial(this, Serial.list()[0], BAUD_RATE);

    // throw out garbage values
    readString = port.readStringUntil(LINEFEED);
    readString = null;

    // setup canvas
    background(50);

    // setup drawing
    textAlign(CENTER, CENTER);
    noFill();
}

void draw() {
    background(50);
    displayState(width / 2, height / 2, height / 3 - SMALL_HEX - 20, 6, state);
    if (port.available() > 0) {
        readString = port.readStringUntil(LINEFEED);
        if (readString != null) {
            textSize(50);
            stroke(240);
            text(readString, width/2, height/2);
        }
    }
    if (millis() % 1000 <= 10) {
        println("hello");
        if (state == 5) {
            state = 0;
        } else {
            state++;
        }
    }
}

void displayState(float x, float y, float radius, int nstates, int activeState) {
    float angle = TWO_PI / nstates;
    for (int i = 0; i < nstates; i++) {
        if (i == activeState) {
            stroke(0, 255, 0); 
            strokeWeight(5);
        } else {
            stroke(240);
            strokeWeight(1);
        }
        
        float a = i * angle;
        float sx = x + cos(a) * radius;
        float sy = y + sin(a) * radius;

        polygon(sx, sy, SMALL_HEX, 6);
        textSize(20);
        text(STATES[i], sx, sy);
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