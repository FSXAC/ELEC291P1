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
final int   LINEFEED = 10;

public void setup() {
    

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

public void draw() {
    background(255);
    if (port.available() > 0) {
        readString = port.readStringUntil(LINEFEED);
        if (readString != null) {
            text(readString, width/2, height/2);
        }
    }
}
  public void settings() {  size(1000, 500); }
  static public void main(String[] passedArgs) {
    String[] appletArgs = new String[] { "--present", "--window-color=#272727", "--stop-color=#cccccc", "Reflow" };
    if (passedArgs != null) {
      PApplet.main(concat(appletArgs, passedArgs));
    } else {
      PApplet.main(appletArgs);
    }
  }
}
