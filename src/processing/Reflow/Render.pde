void mode1() {
    drawSignal(signal);
}

void mode2() {
    drawSignal(signal);
    displayState(state);

    // draw onto the screen
    if (readString != null) {
        // println(readString);
        textSize(50);
        stroke(240);
        rectMode(CENTER);
        fill(power == 1 ? 50: 0, 100);
        noStroke();
        rect(width/2, height/2, width/4, 100);
        rectMode(CORNER);
        fill(255);
        // text(components[0] + " : " + components[1] + " : "  + components[2], width/2, height/2);
        textAlign(CENTER, CENTER);
        text(str(signal) + " deg C", width/2, height/2);
    }
}

void mode3() {
    float strip_y = map(signal, 0, 260, height - 50, 50);
    fill(
        map(strip_y, 0.3 * (height - 50), 0.7 * (height - 50), 255, 0),
        (1 - sq(map(strip_y, 0, height, -1, 1))) * 255,
        map(strip_y, 0.3 * (height - 50), 0.7 * (height - 50), 0, 255)
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

void drawSignal(float value) {
    theta = (theta >= TWO_PI) ? 0 : theta + 0.01;
    float r = map(value, 0, 260, 30, 400);
    float sx = width/2 + r * cos(theta);
    float sy = height/2 + r * sin(theta);
    stroke(0, 255, 255);
    strokeWeight(10);
    line(width/2, height/2, sx, sy);
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