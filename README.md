# ELEC291P1
Reflow Oven Controller - A.K.A Lit Solder Controller

## Trello

**Trelle Link**: https://trello.com/b/4QynfMXc/project-1-lit-solder-controller

## Hardware

AT89LP52 Microcontroller

- **Input**: ADC module, LM335, and thermocouple
- **Output**: Serial to PC (via USB), PWM SSR control, speaker, LCD, LED

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

- [x] Update LCD Screen for each state
- [x] Make marcos for incrementing and decrementing temperature
- [ ] Program what happens when you press start while on the main screen
- [ ] Make macros for setting time
- [ ] Modify code for 3 digit temperature readings
- [ ] Unit Test FSM
- [ ] Integration to main program

## Extra Features

**Brainstorm**
