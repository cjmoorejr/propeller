''******************************************
''*  Title: DHT21_Demo for DHT21_Object    *
''*  Author: Gregg Erickson  2012          *
''*  See MIT License for Related Copyright *
''*  See end of file and objects for .     *
''*  related copyrights and terms of use   *
''*  This object draws upon code from other*
''*  OBEX objects such as servoinput.spin  *
''*  and DHT C++  from Adafruit Industries *
''*                                        *
''*  The object reads the temperature and *
''*  humidity from an AM3201/DHT21 Sensor  *
''*  using a unique 1-wire serial protocol *
''*  with 5 byte packets where 0s are 26uS *
''*  long and 1s are 70uS.                 *
''*                                        *
''*  The object automatically returns the  *
''*  temperature and humidiy to variables  *
''*  memory every few seconds as Deg F and *
''*  relative percent respectively. It also*
''*  return an error byte where true means *
''*  the data received had correct parity  *
''*                                        *
''******************************************



CON

  _clkmode = xtal1 + pll16x   'Set clock speed and mode
  _xinfreq = 5_000_000
  stack=30                    'Set aside stack space to launch the object in other Cog

VAR

long ReadOK          ' Boolean for Parity
byte ByteCount1      ' Count of Bytes Received
long Temperature     ' Calculated temperature in degrees fahrenheit
long Humidity        ' Calculated humidity in % relative humidity


OBJ

serial[2]: "FullDuplexSerial" 'Call two copies of object to handle serial communications
DHT21    : "DHT21_Object"

Pub Main | n


serial[0].start(2, 2, 0, 38_400)      ' Initialize Serial Communication to VFD Display
serial[1].start(31,30, 0, 38_400)     ' Initialize Serial Communication to Serial Terminal

DHT21.Start(10,@Temperature,@Humidity,@ReadOK) ' Automatically read DHT every 3-4 seconds

repeat


  repeat n from 1 to 3            'Pause 3 to allow DHT time to read
    Waitcnt(clkfreq+cnt)

 ' Ouput temperature and humidity to serial VFD display and Terminal


  serial[0].tx($1B)              ' Clear screen
  serial[0].tx($40)

  serial[0].dec(Temperature)     ' Print temperature to VFD
  serial[0].str(@fahr)
  serial[0].str(@space)
  serial[0].str(@space)
  Serial[0].dec(Humidity)        ' Print Humidity to VFD
  serial[0].str(@percent)

  Serial[1].dec(Temperature)     ' Print temperature to Terminal
  serial[1].str(@fahr)
  serial[1].str(@space)
  Serial[1].dec(Humidity)        ' Print humidity to Terminal
  serial[1].str(@percent)

  if ReadOK==true                ' Print Read Status, error or not
      serial[1].str(@valid)
  else
      serial[1].str(@invalid)
  serial[1].tx($0A)
  serial[1].tx($0D)



Dat

Space    byte " ",0           ' Strings for use in printing
Percent  byte " %",0
Fahr     byte " F",0
Valid    byte " Read OK",0
Invalid  byte " Read Error",0

{{

┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}
