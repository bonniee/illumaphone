float analogPins[] = {0, 1, 2, 3, 4, 5};

void setup() 
{ 
  Serial.begin(9600);
} 
 
 
void loop() 
{ 
  for (int i = 0; i < 6; i++)
  {
    int val = analogRead(analogPins[i]);
    Serial.print(val);
    Serial.print(" ");
  }
  Serial.println();
}
