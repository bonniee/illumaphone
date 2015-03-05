// Authored by Bonnie Eisenman.
// blog.bonnieeisenman.com
// This code is provided as-is. It's not perfect and may require debugging!
SerialIO.list() @=> string list[];

for(int i; i < list.cap(); i++)
{
    chout <= i <= ": " <= list[i] <= IO.newline();
}

// parse first argument as device number
0 => int device;
if(me.args()) me.arg(0) => Std.atoi => device;

if(device >= list.cap())
{
    cherr <= "serial device #" <= device <= " not available\n";
    me.exit(); 
}

SerialIO cereal;
if(!cereal.open(device, SerialIO.B9600, SerialIO.ASCII))
{
    chout <= "unable to open serial device '" <= list[device] <= "'\n";
    me.exit();
}

6 => int numPins;
20 => int historyLength;
1.0 => float totalVolume;
4 => int oscsPerPin;

// MIDI values; these determine pitch of each cup.
// Feel free to experiment.
[72, 69, 67, 64, 62, 60] @=> int notes[];

int baseVals[numPins];
int pinHistory[numPins][historyLength];

float baseFreqs[numPins][oscsPerPin];

Gain gains[numPins];
Envelope envs[numPins];
TriOsc oscs[numPins][oscsPerPin];
SinOsc sinOscs[numPins][2];

40 => int triggerThresh;
300.0 => float range;

Gain g;
g.gain(0.3);
PRCRev rev;
rev.mix(0.5);

g => dac;

SinOsc vibs[numPins];
SinOsc vib;
vib => blackhole;
5 => vib.freq;
5 => float baseVibFreq;

// tok should already have params set
fun void calibrate() {

    20 => int numLaps;
    5 => int throwAways;

    for (0 => int i; i < throwAways; i++) {
        cereal.onLine() => now;
        cereal.getLine() => string line;
    }
    5::ms => now;

    for (0 => int lap; lap < numLaps; lap++) {
        cereal.onLine() => now;
        cereal.getLine() => string line;
        if(line$Object != null) {
            StringTokenizer tok;
            tok.set(line);

            for (0 => int i; i < numPins; i++) {
                // Fill history with default values
                Std.atoi(tok.next()) => int pinVal;

                for (0 => int j; j < historyLength; j++) {
                    pinVal => pinHistory[i][j];
                }
                // Store a 1D base vals array, too.
                pinVal + baseVals[i] => baseVals[i];

            }

        }
    }
    for (0 => int i; i < numPins; i++) {
        <<< baseVals[i] >>>;
        baseVals[i] / numLaps => baseVals[i];
        <<< baseVals[i] >>>;
        <<< "=======" >>>;
    }
    <<< "DONE CALIBRATING" >>>;

}

fun void setup() {
    // Setup stuff
    for (0 => int i; i < numPins; i++) {
        gains[i].gain(0.5);
        vibs[i] => blackhole;
        5 => vibs[i].freq;
        envs[i] => g;
        for (1 => int j; j <= oscsPerPin; j++) {
            Std.mtof(notes[i]) * (j) => oscs[i][j-1].freq;
            //(Std.mtof((36 + i) * 2)) * (j * 0.5) => oscs[i][j-1].freq;
            oscs[i][j-1].freq() => baseFreqs[i][j-1];
            oscs[i][j-1] => envs[i]; //=> g;
        }
        baseFreqs[i][0] => sinOscs[i][0].freq;
        sinOscs[i][0] => envs[i];
        Std.mtof(notes[i] - 24) => sinOscs[i][1].freq;
        sinOscs[i][1] => envs[i];
        0 => baseVals[i];

        dac.chan(i);
    }
}

0 => int bufferIndex;
fun void processLine(StringTokenizer tok) {
    for (0 => int i; i < numPins; i++) {
        Std.atoi(tok.next()) => int newVal;
        newVal => pinHistory[i][bufferIndex];
        
        int oldVal;
        if (bufferIndex == 0) {
            pinHistory[i][historyLength - 1] => oldVal;
        }
        else {
            pinHistory[i][bufferIndex - 1] => oldVal;
        }
        
        Std.abs(newVal - baseVals[i]) => int diff;


        if (diff >= triggerThresh) {
            // Is ON!
            (diff - triggerThresh) / range => float newGain;
            baseVibFreq + (newGain * 2) => vibs[i].freq;
            //<<< newGain >>>;
            //diff / range => float newGain;
            envs[i].target(newGain / 3.0);
            if (newGain / 3.0 > 1) {
                envs[i].target(1.0);
            }
            envs[i].duration(1::ms);
            envs[i].keyOn();
            1::ms => now;
        }
        else {
            // Is OFF! 
            
            // If we WERE on before, do an envelope’d end
            if (Std.abs(oldVal - baseVals[i]) >= triggerThresh) {
                envs[i].target(0);
                envs[i].keyOff();
            }
        }
        
    } // End looping over cups.
            
    // Advance buffer index
    bufferIndex + 1 => bufferIndex;
    if (bufferIndex >= historyLength) {
        0 => bufferIndex;
    }
    
}

fun void viber() {
    while (true) {
        for (0 => int i; i < numPins; i++) {
            for (0 => int j; j < oscsPerPin; j++) {
                (vibs[i].last() * 5) + baseFreqs[i][j] => oscs[i][j].freq;
            }
        }
        0.001::second => now;
    }
}


setup();
calibrate();

spork ~ viber();

while(true)
{
    cereal.onLine() => now;
    cereal.getLine() => string line;
    if(line$Object != null) {
        chout <= "raw: " <= line <= IO.newline();
        StringTokenizer tok;
        tok.set(line);
        processLine(tok);
    }
 
}
