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
        fill(power == 1 ? 0: 50);
        noStroke();
        rect(width/2, height/2, width/4, 70);
        rectMode(CORNER);
        fill(255);
        text(components[0] + " : " + components[1] + " : "  + components[2], width/2, height/2);
    }
}

void drawSignal(float value) {
    theta = (theta >= TWO_PI) ? 0 : theta + 0.01;
    float r = map(value, 10, 260, 0, 400);
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
