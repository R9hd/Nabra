# NABRA - Arduino prototype

Bench model of the NABRA collar's deployment logic. A rising vital signal is
confirmed over a short window, then a servo deploys the head and neck airbag
while an LED and buzzer raise the alert.

This is a hackathon prototype for demonstration, not a certified medical device.

## What it does

1. Reads a vital signal continuously on `A0`.
2. When the signal crosses the threshold and holds past the confirmation
   window (about 80 ms), it fires: the servo deploys and the alert light and
   alarm turn on.
3. When the signal drops back down it auto-rearms and goes quiet, ready for the
   next event.

On the bench the live sensor is simulated with a potentiometer: turn the knob
up to trigger a deploy, down to reset.

## Wiring (Arduino UNO)

| Component | Arduino pin |
|-----------|-------------|
| Potentiometer wiper (signal) | A0 |
| Potentiometer outer legs | 5V and GND |
| LED (with 220 ohm resistor) | D8, other leg to GND |
| Active buzzer | D7 (+) and GND |
| SG90 servo signal | D9 |
| SG90 servo power and ground | 5V and GND |

## Settings

Edit these constants at the top of `NABRA.ino`:

- `THRESHOLD` - fire point (0-1023). Lower is more sensitive.
- `REARM_BELOW` - reset point. Keep below `THRESHOLD`.
- `CONFIRM_MS` - confirmation window in milliseconds.

## Run

Open `NABRA.ino` in the Arduino IDE, select your board and port, and upload.
Open the Serial Monitor at 4800 baud to watch the signal, the deploy latency,
and the rearm events.
