/*
  NABRA - seizure-onset head/neck protection collar (prototype)

  Bench model of the deployment logic: a rising vital signal crosses a
  threshold, is confirmed over a short window, then the airbag servo deploys
  with an alert light and an alarm. When the signal drops back down the model
  auto-rearms and goes quiet, ready for the next event.

  This is a hackathon prototype for demonstration, not a certified medical device.

  Hardware (Arduino UNO):
    A0  potentiometer wiper   - stands in for the live vital signal
    D8  LED (+ 220 ohm)       - alert indicator
    D7  active buzzer         - alarm
    D9  SG90 servo signal     - airbag deploy

  On the bench, turn the knob up to fire and down to reset.
*/

#include <Servo.h>

const int PIN_SIGNAL = A0;   // vital signal (potentiometer on the bench model)
const int PIN_LED    = 8;    // alert indicator
const int PIN_BUZZER = 7;    // alarm (active buzzer)
const int PIN_SERVO  = 9;    // airbag servo

const int THRESHOLD   = 700;          // fire point, 0-1023 (lower = more sensitive)
const int REARM_BELOW = 400;          // reset point (keep below THRESHOLD)
const unsigned long CONFIRM_MS = 80;  // confirmation window ~= detection latency (ms)

const int SERVO_ARMED    = 0;         // resting position
const int SERVO_DEPLOYED = 90;        // deployed position

Servo airbag;
bool deployed = false;
bool rising   = false;
unsigned long riseStart = 0;

void deploy(long latency) {
  digitalWrite(PIN_LED, HIGH);
  digitalWrite(PIN_BUZZER, HIGH);
  deployed = true;

  Serial.print("DEPLOYED  latency(ms)=");
  Serial.println(latency);

  // Rapid sweep so the deployment reads clearly on camera.
  for (int i = 0; i < 8; i++) {
    airbag.write(0);
    delay(110);
    airbag.write(180);
    delay(110);
  }
  airbag.write(SERVO_DEPLOYED);
}

void rearm() {
  airbag.write(SERVO_ARMED);
  digitalWrite(PIN_LED, LOW);
  digitalWrite(PIN_BUZZER, LOW);
  deployed = false;
  rising   = false;
  Serial.println("REARMED");
}

void setup() {
  Serial.begin(4800);
  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_BUZZER, OUTPUT);
  airbag.attach(PIN_SERVO);
  airbag.write(SERVO_ARMED);
  Serial.println("NABRA ready. Knob up to fire, down to reset.");
}

void loop() {
  int signal = analogRead(PIN_SIGNAL);

  if (!deployed) {
    if (signal >= THRESHOLD) {
      if (!rising) {
        rising = true;
        riseStart = millis();
      } else if (millis() - riseStart >= CONFIRM_MS) {
        deploy(millis() - riseStart);
      }
    } else {
      rising = false;
    }
  } else {
    if (signal < REARM_BELOW) {
      rearm();
    }
  }

  // Heartbeat: print the current signal once a second.
  static unsigned long lastPrint = 0;
  if (millis() - lastPrint >= 1000) {
    lastPrint = millis();
    Serial.print("signal=");
    Serial.println(signal);
  }
}
