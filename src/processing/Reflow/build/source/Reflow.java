import processing.core.*; 
import processing.data.*; 
import processing.event.*; 
import processing.opengl.*; 

import processing.serial.*; 

import java.util.HashMap; 
import java.util.ArrayList; 
import java.io.File; 
import java.io.BufferedReader; 
import java.io.PrintWriter; 
import java.io.InputStream; 
import java.io.OutputStream; 
import java.io.IOException; 

public class Reflow extends PApplet {



// Serial
Serial      port;
String      readString = null;
final int   BAUD_RATE = 115200;
final int   ASCII_LINEFEED = 10;
final int   ASCII_CARRIAGE_RETURN = 13;

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
int power = 0;
String[] components = {"0", "0", "0"};

// drawing mode
int mode = 1;

// radial graph
float theta = 0;

// strip chart
float strip_x = 0;

public void setup() {
    

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

public void draw() {
    // background(50);
    fill(0, 25);
    noStroke();
    rect(0, 0, width, height);
    fill(255);

    // read data from serial
    if (port.available() > 0) {
        readString = readSerial(readString);

        // parse data into variables
        components = readString.split(",");
        state = Integer.parseInt(components[0]);
        signal = Integer.parseInt(components[1]);
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
public String readSerial(String previousBuffer) {
    String buffer = port.readStringUntil(ASCII_LINEFEED);

    // remove the last "\r\n" characters
    if (buffer != null && buffer.charAt(buffer.length()-1)=='\n') {
        buffer = buffer.substring(0, buffer.length()-2);
        return buffer;
    } else {
        return previousBuffer;
    }
}

// keyboard events
public void keyPressed() {
    // background(0);
    mode = (mode == 3 ? 1 : mode + 1);
}
public void mode1() {
    drawSignal(signal);
}

public void mode2() {
    drawSignal(signal);
    displayState(state);

    // draw onto the screen
    if (readString != null) {
        // println(readString);
        textSize(50);
        stroke(240);
        rectMode(CENTER);
        fill(power == 1 ? 0: 50, 100);
        noStroke();
        rect(width/2, height/2, width/4, 100);
        rectMode(CORNER);
        fill(255);
        // text(components[0] + " : " + components[1] + " : "  + components[2], width/2, height/2);
        textAlign(CENTER, CENTER);
        text(str(signal) + " deg C", width/2, height/2);
    }
}

public void mode3() {
    float strip_y = map(signal, 0, 260, height - 50, 50);
    fill(
        map(strip_y, 0.3f * (height - 50), 0.7f * (height - 50), 255, 0),
        (1 - sq(map(strip_y, 0, height, -1, 1))) * 255,
        map(strip_y, 0.3f * (height - 50), 0.7f * (height - 50), 0, 255)
        );
    rect(strip_x, strip_y, 5, height-50-strip_y);

    // display x-axis label
    fill(0);
    rect(0, height-50, width, height);
    textSize(20);
    fill(255);
    text(str(millis() / 1000) + 's', strip_x, height - 25);

    // display temperature
    text(str(signal) + " deg C", strip_x, strip_y);

    // increment horizontal
    strip_x = (strip_x >= width) ? 0 : strip_x + 5;
}

public void drawSignal(float value) {
    theta = (theta >= TWO_PI) ? 0 : theta + 0.01f;
    float r = map(value, 0, 260, 30, 400);
    float sx = width/2 + r * cos(theta);
    float sy = height/2 + r * sin(theta);
    stroke(0, 255, 255);
    strokeWeight(10);
    line(width/2, height/2, sx, sy);
}

public void generateHexagon(float x, float y, float radius, int nstates) {
    float angle = TWO_PI / nstates;
    for (int i = 0; i < nstates; i++) {
        hex_x[i] = x + cos(i * angle) * radius;
        hex_y[i] = y + sin(i * angle) * radius;
    }
}

public void displayState(int activeState) {
    for (int i = 0; i < STATES.length; i++) {
        if (i == activeState) {
            stroke(0, 255, 255);
            strokeWeight(20);
        } else {
            stroke(240);
            strokeWeight(1);
        }
        noFill();
        polygon(hex_x[i], hex_y[i], SMALL_HEX, 6);
        textSize(20);
        text(STATES[i], hex_x[i], hex_y[i]);
    }
}

public void polygon(float x, float y, float radius, int npoints) {
    float angle = TWO_PI / npoints;
    beginShape();
    for (float a = 0; a < TWO_PI; a += angle) {
        float sx = x + cos(a) * radius;
        float sy = y + sin(a) * radius;
        vertex(sx, sy);
    }
    endShape(CLOSE);
}
  public void settings() {  fullScreen(); }
  static public void main(String[] passedArgs) {
    String[] appletArgs = new String[] { "--present", "--window-color=#272727", "--stop-color=#cccccc", "Reflow" };
    if (passedArgs != null) {
      PApplet.main(concat(appletArgs, passedArgs));
    } else {
      PApplet.main(appletArgs);
    }
  }
}
