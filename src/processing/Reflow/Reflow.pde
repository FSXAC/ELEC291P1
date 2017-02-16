import processing.serial.*;

// Serial
Serial      port;
String      readString = null;
final int   BAUD_RATE = 115200;
final int   ASCII_LINEFEED = 10;
final int   ASCII_CARRIAGE_RETURN = 13;

int[] data = new int[100];
int count = 0;
void add(int value) {
  if (count == data.length) {
    data = expand(data);
    if (mode == 1) {
      background(50);
    }
  }
  data[count++] = value;
}

// state diagram numbers
final int   SMALL_HEX = 100;
final String[] STATES = {
    "Main Menu",
    "Ramp To Soak",
    "Preheat Soak",
    "Ramp to Peak",
    "Reflow",
    "Cooling"
};
float[] hex_x = new float[6];
float[] hex_y = new float[6];

// readings from serial
int state = 0;
int signal = 0;
int signal_prev = 0;
int power = 0;
String[] components = {"0", "0", "0"};

// drawing mode
int mode = 1;

// radial graph
float theta = 0;

// strip chart
float strip_x = 0;

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

void draw() {
    // background(50);
    // read data from serial
    if (port.available() > 0) {
        readString = readSerial(readString);

        // parse data into variables
        components = readString.split(",");
        state = Integer.parseInt(components[0]);
        signal = Integer.parseInt(components[1]);
        add(signal);
        power = Integer.parseInt(components[2]);
    }

    switch(mode) {
        case 1: mode1();
            break;
        case 2: mode2();
            break;
        case 3: mode3();
    }
}

// read from serial
String readSerial(String previousBuffer) {
    String buffer = port.readStringUntil(ASCII_LINEFEED);

    // remove the last "\r\n" characters
    if (buffer != null && buffer.charAt(buffer.length()-1)=='\n') {
        buffer = buffer.substring(0, buffer.length()-2);
        return buffer;
    } else {
        return previousBuffer;
    }
}

int[] temp_img;
void mousePressed() {
  mode = (mode == 3 ? 1 : mode + 1);
  if (mode == 1) {
    background(50);
  }
}