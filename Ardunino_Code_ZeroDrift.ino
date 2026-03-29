#include <LiquidCrystal.h>
LiquidCrystal lcd(9, 8, 4, 5, 6, 7);

const int buzzerPin = 3;

// timing
unsigned long lastBlink = 0;
bool blinking = false;

unsigned long lastSwitch = 0;
bool motivateMode = true;

// animation
int eyeOffset = 0;

// current state
int currentFace = 0;
String currentMessage = "";

// ---------------- CUSTOM CHARS ----------------

// eyes
byte eyeOpen[8] = {
  B00000,B01010,B00000,B00000,B00000,B00000,B00000,B00000
};

byte eyeClosed[8] = {
  B00000,B00000,B11111,B00000,B00000,B00000,B00000,B00000
};

// mouths
byte happy[8] = {
  B00000,B00000,B00000,B00000,B10001,B01110,B00000,B00000
};

byte neutral[8] = {
  B00000,B00000,B00000,B00000,B11111,B00000,B00000,B00000
};

byte sad[8] = {
  B00000,B00000,B01110,B10001,B00000,B00000,B00000,B00000
};

byte determined[8] = {
  B00000,B00000,B11111,B00000,B11111,B00000,B00000,B00000
};

byte sleepy[8] = {
  B00000,B00000,B00000,B00100,B01010,B00000,B00000,B00000
};

// ---------------- SETUP ----------------
void setup() {
  lcd.begin(16, 2);
  pinMode(buzzerPin, OUTPUT);

  lcd.createChar(0, eyeOpen);
  lcd.createChar(1, eyeClosed);
  lcd.createChar(2, happy);
  lcd.createChar(3, neutral);
  lcd.createChar(4, sad);
  lcd.createChar(5, determined);
  lcd.createChar(6, sleepy);

  randomSeed(analogRead(A0));

  pickNewState();
}

// ---------------- LOOP ----------------
void loop() {
  handleSwitch();
  handleBlink();
  animateEyes();
  drawDisplay();
}

// ---------------- STATE SWITCH ----------------
void handleSwitch() {
  if (millis() - lastSwitch > 5000) {
    motivateMode = !motivateMode;
    lastSwitch = millis();

    pickNewState();

    tone(buzzerPin, 1200, 100);
  }
}

// ---------------- PICK RANDOM ----------------
void pickNewState() {
  // random face
  currentFace = random(0, 5);

  // random message
  int m = random(0, 4);
  if (m == 0) currentMessage = "you can do it!";
  if (m == 1) currentMessage = "stay focused!";
  if (m == 2) currentMessage = "keep going!";
  if (m == 3) currentMessage = "almost there!";
}

// ---------------- BLINK ----------------
void handleBlink() {
  if (millis() - lastBlink > 2000) {
    blinking = true;
    lastBlink = millis();
  }

  if (blinking && millis() - lastBlink > 200) {
    blinking = false;
  }
}

// ---------------- SUBTLE ANIMATION ----------------
void animateEyes() {
  // randomly shift eyes slightly every ~1 sec
  static unsigned long lastMove = 0;

  if (millis() - lastMove > 10000) {
    eyeOffset = random(-1, 2); // -1, 0, or 1
    lastMove = millis();
  }
}

// ---------------- DRAW ----------------
void drawDisplay() {
  byte eyeChar = blinking ? 1 : 0;

  // -------- TOP ROW --------
  lcd.setCursor(0, 0);

  if (motivateMode) {
    lcd.print(currentMessage);
  } else {
    lcd.print("                ");
  }

  // -------- BOTTOM ROW --------
  lcd.setCursor(0, 1);
  lcd.print("                ");

  int leftEye = 5 + eyeOffset;
  int rightEye = 10 + eyeOffset;

  // eyes
  lcd.setCursor(leftEye, 1);
  lcd.write(byte(eyeChar));

  lcd.setCursor(rightEye, 1);
  lcd.write(byte(eyeChar));

  // mouth
  lcd.setCursor(7 + eyeOffset, 1);

  if (currentFace == 0) lcd.write(byte(2)); // happy
  if (currentFace == 1) lcd.write(byte(3)); // neutral
  if (currentFace == 2) lcd.write(byte(4)); // sad
  if (currentFace == 3) lcd.write(byte(5)); // determined
  if (currentFace == 4) lcd.write(byte(6)); // sleepy
}