const int   MIC_PIN      = A0;
const int   SERVO_PIN    = 9;
const int   TRIG_PIN     = 5;
const int   ECHO_PIN     = 6;
const int   LED_GREEN    = 4;
const int   LED_RED      = 3;
const int   BUZZER_PIN   = 7;

const int   SERVO_CLOSED = 1000;
const int   SERVO_OPEN   = 1500;
const unsigned long SAMPLE_US = 700;
const int   N = 512;
const int   PROX_THRESHOLD_CM = 20;

unsigned long lastSampleTime = 0;

float measureDistance() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  long duration = pulseIn(ECHO_PIN, HIGH, 25000);
  return duration * 0.034 / 2.0;
}

void servoMove(int pulseUs, int durationMs) {
  unsigned long endTime = millis() + durationMs;
  while (millis() < endTime) {
    digitalWrite(SERVO_PIN, HIGH);
    delayMicroseconds(pulseUs);
    digitalWrite(SERVO_PIN, LOW);
    delay(19);
  }
}

void blinkRed(int nrBlinks) {
  for (int i = 0; i < nrBlinks; i++) {
    digitalWrite(LED_RED, HIGH);
    delay(150);
    digitalWrite(LED_RED, LOW);
    delay(150);
  }
}

void beep(int durationMs) {
  digitalWrite(BUZZER_PIN, HIGH);
  delay(durationMs);
  digitalWrite(BUZZER_PIN, LOW);
}

void setup() {
  Serial.begin(115200);
  pinMode(SERVO_PIN, OUTPUT);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(LED_GREEN, OUTPUT);
  pinMode(LED_RED, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(LED_GREEN, LOW);
  digitalWrite(LED_RED, LOW);
  digitalWrite(BUZZER_PIN, LOW);
  for (int i = 0; i < 20; i++) {
    digitalWrite(SERVO_PIN, HIGH);
    delayMicroseconds(SERVO_CLOSED);
    digitalWrite(SERVO_PIN, LOW);
    delay(19);
  }
}

void loop() {
  if (Serial.available() > 0) {
    char cmd = Serial.read();

    if (cmd == 'G') {
      digitalWrite(LED_GREEN, HIGH);
      servoMove(SERVO_OPEN, 1000);

      unsigned long lastBeep = 0;
      while (true) {
        delay(50);
        float dist = measureDistance();
        if (dist == 0) {
          digitalWrite(SERVO_PIN, HIGH);
          delayMicroseconds(SERVO_OPEN);
          digitalWrite(SERVO_PIN, LOW);
          delay(18);
        } else if (dist > 2 && dist < PROX_THRESHOLD_CM) {
          digitalWrite(SERVO_PIN, HIGH);
          delayMicroseconds(SERVO_OPEN);
          digitalWrite(SERVO_PIN, LOW);
          delay(18);
          if (millis() - lastBeep > 500) { beep(80); lastBeep = millis(); }
        } else {
          break;
        }
      }

      servoMove(SERVO_CLOSED, 600);
      digitalWrite(LED_GREEN, LOW);
      digitalWrite(BUZZER_PIN, LOW);
    }

    if (cmd == 'T') {
      blinkRed(4);
    }
  }

  int samples[N];
  lastSampleTime = micros();
  for (int i = 0; i < N; i++) {
    while (micros() - lastSampleTime < (unsigned long)i * SAMPLE_US);
    samples[i] = analogRead(MIC_PIN);
  }

  Serial.write(0xFF);
  Serial.write(0xFF);
  for (int i = 0; i < N; i++) {
    Serial.write((samples[i] >> 8) & 0xFF);
    Serial.write(samples[i] & 0xFF);
  }
}