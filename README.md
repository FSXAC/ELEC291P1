# ELEC291P1
Reflow Oven Controller - A.K.A Lit Solder Controller

## Resources

**GitHub Pages**: https://fsxac.github.io/ELEC291P1/

**Trelle Link**: https://trello.com/b/4QynfMXc/project-1-lit-solder-controller

**Google Drive**: https://drive.google.com/drive/folders/0B7_AKRr0ByjpWmxVZVN0MWlLRlU

## Hardware

AT89LP52 Microcontroller

- **Input**: ADC module, LM335, thermocouple, buttons
- **Output**: Serial to PC (via USB), PWM SSR control, speaker, LCD, LED

![](doc/Hardware.png "Hardware Layout")

### Task 1: Circuit and Hardware Assembly

- [x] Assemble OP AMP
- [x] Attach OP AMP to thermocouple
- [ ] Attach LM335 for temperature offset
- [ ] Attach sensors to ADC, attach ADC to microcontroller

## Software

### Task 1: Reflow FSM

- [ ] Program reflow FSM shown in diagram on lecture slides
- [ ] Test FSM
- [ ] Add required sound and LCD outputs during each transition

### Task 2: SSR Controller

### Task 3: Interface and Configuration (FSM)

*important*: `crtTemp` should be temperature input from sensors

- [ ] Wire up `crtTemp` to sensors

- [x] Update LCD Screen for each state
- [x] Make marcos for incrementing and decrementing temperature
- [ ] Program what happens when you press start while on the main screen
- [ ] Make macros for setting time
- [ ] Modify code for 3 digit temperature readings
- [ ] Unit Test FSM
- [ ] Integration to main program

## Extra Features

**Brainstorm**
