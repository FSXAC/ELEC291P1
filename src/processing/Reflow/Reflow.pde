import processing.serial.*;

// Serial
Serial      port;
String      readString = null;
final int   BAUD_RATE = 115200;
final int   ASCII_LINEFEED = 10;
final int   ASCII_CARRIAGE_RETURN = 13;

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
float[] hex_x = new float[6];
float[] hex_y = new float[6];

void setup() {
    fullScreen();

    // initialize SPI
    printArray(Serial.list());
    while (Serial.list().length < 1) {
        delay(1000);
    }
    port = new Serial(this, Serial.list()[0], BAUD_RATE);

    // throw out garbage values
    delay(1000);
    readString = port.readStringUntil(ASCII_LINEFEED);
    readString = null;

    // setup canvas
    background(50);

    // setup drawing
    textAlign(CENTER, CENTER);
    noFill();

    // setup hexagon
    generateHexagon(width/2, height/2, height/3, 6);
}

int state = 0;
int signal;
int power;
String[] components = {"0", "0", "0"};

void draw() {
    background(50);
    displayState(state);

    // read data from serial
    if (port.available() > 0) {
        readString = readSerial();

        // parse data into variables
        components = readString.split(",");
    }

    // draw onto the screen
    if (readString != null) {
        // println(readString);
        textSize(50);
        stroke(240);
        text(components[0] + " : " + components[1] + " : "  + components[2], width/2, height/2);
    }
}


// read from serial
String readSerial() {
    String buffer = port.readStringUntil(ASCII_LINEFEED);
    if (buffer.charAt(buffer.length()-1)=='\r') {
        buffer = buffer.substring(0, buffer.length()-1);
    }
    return buffer;
}

float theta = 0;
void drawSignal(float angle, float value) {

}

void generateHexagon(float x, float y, float radius, int nstates) {
    float angle = TWO_PI / nstates;
    for (int i = 0; i < nstates; i++) {
        hex_x[i] = x + cos(i * angle) * radius;
        hex_y[i] = y + sin(i * angle) * radius;
    }
}

void displayState(int activeState) {
    for (int i = 0; i < STATES.length; i++) {
        if (i == activeState) {
            stroke(0, 255, 0);
            strokeWeight(5);
        } else {
            stroke(240);
            strokeWeight(1);
        }

        polygon(hex_x[i], hex_y[i], SMALL_HEX, 6);
        textSize(20);
        text(STATES[i], hex_x[i], hex_y[i]);
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
