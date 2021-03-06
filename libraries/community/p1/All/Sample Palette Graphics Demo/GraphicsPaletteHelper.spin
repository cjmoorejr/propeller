{{
┌──────────────────────────────────────────┐
│ Graphics Palette Helper                  │
│ Author: Jim Fouch                        │               
│ Copyright (c) 2010 Jim Fouch             │               
│ See end of file for terms of use.        │                
└──────────────────────────────────────────┘

This example show how you create a graphics display with the propeller.

It Uses a modified version of the standard Graphics.spin file

It uses Output pins 12..15 for the TV output. It's configured to work with NTSC, but could be modified to work with PAL.

A Button shound be wired to Pin 7 and pulled high. This button will allow you to see an overlayed grid showing the cells.



}}

CON  {<object declarations, code, and comments>}
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000
'  _stack = ($3000 + $3000 + 100) >> 2   'accomodate display memory and stack
  _stack = (200) >> 2   'accomodate display memory and stack
  ' One Screen Takes $3000 Bytes
  ' Two are used for double buffering
  x_tiles = 16 ' 256 Pixels
  y_tiles = 12 ' 192 Pixels

  paramcount = 14       
 
  thickness = 2

  TachSpacing = $137
  TachCenterX = 86
  TachCenterY = 88

  ' Colors
  CL_Black      = $02
  CL_Grey1      = $03
  CL_Grey2      = $04
  CL_Grey3      = $05
  CL_Grey4      = $06
  CL_White      = $07
  CL_Blue       = $0A
  CL_DarkBlue   = $3A
  CL_DarkGreen  = $4A
  CL_Red        = $48
  CL_Brown      = $28
  CL_Yellow     = $9E
  CL_Purple     = $88
  CL_DarkPurple = $EA
  CL_Green      = $F8

  ' Buttons
  ShowGrid = 7

  ' Signal Masks
  LeftTurnMask  = %0000_0001
  RightTurnMask = %0000_0010
  HighBeamMask  = %0000_0100
  LowFuelMask   = %0000_1000
  LowOilMask    = %0001_0000
  FIMask        = %0010_0000
  DistanceMask  = %0100_0000 ' 0=Miles , 1 = Kilometers
  HESCMask      = %1000_0000

  Gallon        = 49907
  FullTank      = 225081   ' 4.51 Gallon Allows for 1/4 Gallon Reserve (Not Counted) 


VAR

  Long bitmap_base  
  Long display_base 

  word  screen[x_tiles * y_tiles]
  
  long  tv_status     '0/1/2 = off/visible/invisible           read-only
  long  tv_enable     '0/? = off/on                            write-only
  long  tv_pins       '%ppmmm = pins                           write-only
  long  tv_mode       '%ccinp = chroma,interlace,ntsc/pal,swap write-only
  long  tv_screen     'pointer to screen (words)               write-only
  long  tv_colors     'pointer to colors (longs)               write-only               
  long  tv_hc         'horizontal cells                        write-only
  long  tv_vc         'vertical cells                          write-only
  long  tv_hx         'horizontal cell expansion               write-only
  long  tv_vx         'vertical cell expansion                 write-only
  long  tv_ho         'horizontal offset                       write-only
  long  tv_vo         'vertical offset                         write-only
  long  tv_broadcast  'broadcast frequency (Hz)                write-only
  long  tv_auralcog   'aural fm cog                            write-only
  Long colors[16]
  Long   Signals, Gear, Speed, TachValue, CoolantTemp, BatteryVoltage
  Long  _Signals,_Gear,_Speed,_TachValue,_CoolantTemp,_BatteryVoltage
  Long  AmbTemp, _AmbTemp  
  Long  V1Status, _V1Status
  Long   FICounter, Odometer, TripAOdometer, TripBOdometer
  Long  _FICounter,_Odometer,_TripAOdometer,_TripBOdometer
  Byte DisplayRam[12288+64] ' Display Ram. Allow enough extra to Align to a 64 Byte Boundry

  Long LastFuelModeChange
  Byte Hour, Minute, _Hour, _Minute
  Byte UserSettings1, TimeOut
  Byte Temp[12]


OBJ
  tv      : "tv"
  gr      : "graphics"

PUB Start|i,si, si2,gi, j, k, kk, x, y, TachAngle, TachChange, _Switch, Redraw, StartCNT, Diag, RedrawTrip, FuelMode,_FuelMode, MPG, FuelRange

  ' Establish Display Memory, Make sure it's on a 64 Byte Boundry
  display_base:= bitmap_base := (@DisplayRam + $3F ) & $7FC0  

  ' UserSettings1
  ' Bit 0 - 0=TripA   1=TripB
  '     1 - 0=MPH     1=KPH
  '    


  OdoMeter      := 5832834
  TripAOdometer := 36325
  TripBOdometer := 0
  FICounter     := 142344 
  UserSettings1 := 0
  CoolantTemp   := 192
  AmbTemp       := 74
  BatteryVoltage:= 1445
 
  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)
  

  SetColorPallet(0,CL_Black,CL_White,CL_Red,CL_Blue)
  SetColorPallet(1,CL_Black,$F8,CL_Red,CL_Blue)
  SetColorPallet(2,CL_Yellow,$F8,CL_Red,CL_Blue)          
  SetColorPallet(3,CL_Black,CL_White,$48,$AA) ' Valentine One          
  SetColorPallet(4,$4E,CL_White,$48,$AA)       ' Idiot Lights   
  SetColorPallet(5,$8B,CL_White,$8E,$AA)
  SetColorPallet(6,$6E,$F8,CL_Red,CL_Blue)
  SetColorPallet(7,CL_Black,$6D,CL_Red,CL_Blue)
  SetColorPallet(8,CL_Black,CL_White,CL_Red,$F8) ' Gear Indicator            

  'init tile screen
  SetAreaColor(0,0,TV_HC-1,TV_VC-1,0)
  SetAreaColor(0,8,2,3,8)    ' Gear 
  SetAreaColor(6,1,13,5,2)      ' Speed
  SetAreaColor(6,6,9,6,6)       ' Speed Tab
  SetAreaColor(0,0,1,1,1)       ' Left Turn Signal
  SetAreaColor(14,0,15,1,1)     ' Right Turn Signal
  SetAreaColor(6,7,11,9,3)      ' V1
  SetAreaColor(2,0,13,0,4)      ' Idiot Lights  
  SetAreaColor(6,10,11,11,5)    ' Odometers   
  SetAreaColor(14,9,15,9,7)    ' Ambient
  SetAreaColor(14,5,15,5,7)    ' Battery
      
      
  'start and setup graphics
  gr.start
  gr.setup(x_tiles, y_tiles, 0 , 0, bitmap_base)
  'mouse.start(24, 25) 'start mouse
  _Signals:=255
  _Speed:=-1
  _TachValue:=-10000
  _Gear:=-1
  _V1Status:=-1
  _AmbTemp:=-100
  _CoolantTemp:=-100
  _Odometer := -1
  _TripAOdometer := -100
  _TripBOdometer := -100
  _BatteryVoltage:=-10
  _Minute:=-1
  _FuelMode:=255
  FuelMode:=1
  Redraw:=1
  RedrawTrip:=1
  Diag:=0
  LastFuelModeChange:=CNT
  Gear:=1  
    Repeat
      TachValue+=5
      If TachValue>13000
        TachValue:=0
        Gear+=1
        If Gear>6
          Gear:=1
          Speed:=1
      si+=1
      if si>75
        si:=0
        Speed +=1
        If Speed>186
          Speed:=0
      si2+=1
      if Si2>100
        SI2:=0
        ?Signals

          
      'Draw Tach Numbers
      TachChange:=0
      If ||(TachValue-_TachValue) > 100 ' New Value or Higher
        gr.color(0)
        J:=0
        K:=0 ' Used to Store Bits for TileSections That need Cleared
        Repeat I from 1 to 2
          Case I
            1: J:=_TachValue
            2: J:= TachValue
          Case J
            0..1000:      K |=        %0001
            1001..2000:   K |=        %0010
            2001..3000:   K |=        %0100
            3001..4000:   K |=        %1000
            4001..5000:   K |=      %1_0000
            5001..7800:   K |=     %10_0000
            7801..8700:   K |=    %100_0000
            8701..11000:  K |=   %1000_0000
            11001..14000: K |= %1_0000_0000
          
        Repeat I from 0 to 8
          Case I
            0:
              If K & (1<<i)
                ClearTiles(4,0,2,6)
            1:
              If K & (1<<i)
                ClearTiles(3,0,1,4)
                ClearTiles(4,0,2,5)
                ClearTiles(4,3,2,3)
            2:
              If K & (1<<i)
                ClearTiles(2,1,2,3)
                ClearTiles(3,1,1,4)
                ClearTiles(4,2,2,4)
            3:
              If K & (1<<i)
                ClearTiles(3,3,3,3)                    
                ClearTiles(1,2,3,2)
                _Gear:=-1                                    
            4:
              If K & (1<<i)
                ClearTiles(1,2,1,1)                    
                ClearTiles(3,3,3,3)                    
                ClearTiles(0,3,3,2)
                _Gear:=-1                                    
            5:
              If K & (1<<i)
                ClearTiles(0,3,6,4)                    
            6:
              If K & (1<<i)
                ClearTiles(0,5,6,3)                    
            7:
              If K & (1<<i)
                ClearTiles(3,5,3,4)
                ClearTiles(1,6,3,4)                                      
            8:
              If K & (1<<i)
                ClearTiles(3,5,3,6)                    
                                    
           
        TachAngle := $1800
        Gr.TextMode(1,1,6,%0101) 
        Repeat I from 1 to 14
          Case I
            13..14: gr.Color(2) ' Red
            Other : gr.Color(1) ' White 
          gr.textarc(tachCenterX,TachCenterY,80,80,TachAngle,Lookup(I: @Tach0,@Tach1,@tach2,@Tach3,@Tach4,@Tach5,@Tach6,@Tach7,@Tach8,@Tach9,@Tach10,@Tach11,@Tach12,@Tach13))
          gr.color(1)
          Repeat J from 50 to 75 Step 15                     
            gr.Arc(tachCenterX,TachCenterY,J,J,TachAngle,0,1,0)
          TachAngle := TachAngle - TachSpacing
         
        gr.color(2)  
        gr.plot(tachCenterX,TachCenterY)
        TachAngle := Tachvalue * 313 
        TachAngle := TachAngle / 1000
        TachAngle := 6154 - TachAngle
        gr.vec(tachCenterX,TachCenterY,205,TachAngle,@Tach)
         
        gr.color(3)  
        gr.plot(tachCenterX,TachCenterY)
         
        gr.vec(tachCenterX,TachCenterY,205,TachAngle,@TachCtr)
        NormalText

        _TachValue:=TachValue   
   
      ' Display Gear
      If Gear <> _Gear
        Gr.color(0)
        Gr.FilledBox(0,0,22,38)
        gr.textmode(4,4,6,%0101)
        Case Gear
          0: Gr.ColorWidth(3,3)
          Other: gr.colorwidth(2,3)
        IF Gear==255 
          Gr.text(TachCenterX - 75,TachCenterY-70,string("?"))
        else
          gr.text(TachCenterX - 75,TachCenterY-70,Lookup(Gear+1 : string("N"),String("1"),String("2"),String("3"),String("4"),String("5"),String("6")))
        NormalText
        _Gear := Gear
      
   
      ' Display Speed
      If Speed<>_Speed
        gr.width(5)    
        gr.textmode(7,7,6,%0101)
        GR.Color(0)
        Gr.FilledBox(6*16,6*16,8*16-3,5*16-5)
        gr.color(2)
        DisplayDec(163,135,Speed)
        NormalText
        _Speed:=Speed
   
      ' Check for Left Turn Signal
      If Signals & LeftTurnMask <> _Signals & LeftTurnMask
        if Signals & LeftTurnMask
          gr.TextMode(6,6,6,%0101)
          gr.colorwidth(1,3)
          gr.Text(16,175,String("<"))
          NormalText
          _Signals:= _Signals + LeftTurnMask
        Else
          GR.Color(0)
          Gr.FilledBox(0,10*16,32,32)
          _Signals := _Signals - LeftTurnMask
          
      ' Check for Right Turn Signal
      If Signals & RightTurnMask <> _Signals & RightTurnMask      
        if Signals & RightTurnMask             
          GR.Color(1)
          gr.TextMode(6,6,6,%0101)
          gr.colorwidth(1,3)
          gr.Text(242,175,String(">"))
          NormalText
          _Signals := _Signals + RightTurnMask
        else
          GR.Color(0)
          Gr.FilledBox(14*16,10*16,32,32)
          _Signals := _Signals - RightTurnMask 
   
      ' High Beam Light
      If Signals & HighBeamMask <> _Signals & HighBeamMask    
        if Signals & HighBeamMask             
          Gr.ColorWidth(3,-18)
          _Signals := _Signals + HighBeamMask
        else        
          Gr.ColorWidth(0,-18)
          _Signals := _Signals - HighBeamMask
        Gr.Plot(248,152)
        gr.Width(0)
        Gr.Color(1)   
   
      ' Low Fuel
      If Signals & LowFuelMask <> _Signals & LowFuelMask
        if Signals & LowFuelMask             
          Gr.Color(2)
          Gr.FilledBox(9*16-4,177,5*16+2,14)             
          gr.Color(1)
          gr.TextMode(2,1,5,%0101)
          gr.text(180,183,String("LOW FUEL"))
          _Signals := _Signals + LowFuelMask
        Else
          Gr.Color(0)
          gr.filledbox(9*16-4,175,5*16+2,16)
          gr.color(1)
          _Signals := _Signals - LowFuelMask
   
      ' Oil        
      If Signals & LowOilMask <> _Signals & LowOilMask
        if Signals & LowOilMask             
          Gr.Color(2)
          Gr.FilledBox(2*16+2,177,33,14)             
          gr.Color(1)
          gr.TextMode(2,1,5,%0101)
          gr.text(50,183,String("OIL"))
          _Signals := _Signals + LowOilMask
        Else
          Gr.Color(0)
          gr.filledbox(2*16+2,175,33,16)
          gr.color(1)
          _Signals := _Signals - LowOilMask
   
      ' FI
      If Signals & FIMask <> _Signals & FIMask          
        if Signals & FIMask
          Gr.Color(2)
          Gr.FilledBox(6*16-3,177,26,14)             
          gr.Color(1)
          gr.TextMode(2,1,5,%0101)
          gr.text(105,183,String("FI"))
          _Signals := _Signals + FIMask
        Else                
          Gr.Color(0)
          gr.filledbox(6*16-3,177,26,14)
          gr.color(1)
          _Signals := _Signals - FIMask
   
      ' Now Check Miles or Kelometers 
      If Signals & DistanceMask <> _Signals & DistanceMask      
        if Signals & DistanceMask             
          Gr.Color(0)
          Gr.FilledBox(6*16,5*16,4*16,16)
          gr.TextMode(2,1,6,%0101)
          gr.colorwidth(3,1)
          gr.Text(8*16,5*16+7,String("Kl/H"))
          NormalText
          _Signals := _Signals + DistanceMask
        else
          Gr.Color(0)
          Gr.FilledBox(6*16,5*16,4*16,16)
          gr.TextMode(3,1,6,%0101)
          gr.colorwidth(3,1)
          gr.Text(8*16,5*16+7,String("MPH"))
          NormalText
          _Signals := _Signals - DistanceMask 
   
         
      ' Display Clock
      Minute:=15
      Hour:=7
      if Minute<>_Minute
        DisplayTime(207,-2,Hour,Minute)
        _Minute:=Minute
   
      if Redraw
        Gr.Color(1)      
        gr.TextMode(1,1,6,%0000)
        Gr.FilledBox(6*16,0,34,32)
        Gr.Color(0)
        gr.text(98,0,String("ODO"))
        if (UserSettings1 & %1)==0 
          gr.text(98,16,String("TRP-A"))
        else
          gr.text(98,16,String("TRP-B"))

      ' FI Level Counter
      If ||(FICounter-_FICounter)=>1 Or (FuelMode<>_FuelMode)
        MPG:=(TripAOdometer * 1000) / ((FICounter* 1000) / Gallon)

        ' Clear Box
        gr.color(3)
        gr.FilledBox(10*16,80,64,16)
        gr.color(1)
        Case FuelMode
          1 :            Gr.Textmode(1,1,6,%1000)
            Gr.Text(184,80,String("Fuel"))
            gr.Text(221,80,String("%"))
            Gr.Textmode(1,1,6,%1011)
            I:=((FullTank-FICounter)*1000)/FullTank
            if I==1000 
              Gr.Text(214,80,String("100"))
            else
              I:=I*100
              FixedDec(I)  
              Gr.Text(214,80,@Temp)
          2 :' MPG                           
            Gr.Textmode(1,1,8,%1000)
            Gr.Text(184,80,String("MPG"))
            Gr.Textmode(1,1,6,%1011)
            FixedDec(MPG)
            Gr.Text(218,80,@Temp)
          3 : ' Range
            Gr.Textmode(1,1,6,%1000)
            Gr.Text(192,80,String("Range"))
            Gr.Textmode(1,1,7,%1011)
            I:=MPG * (((FullTank-FICounter) * 1000) / Gallon)
            I/=1000000
            DisplayDec(218,80,I)
        _FuelMode:=FuelMode
        _FICounter:=FICounter
                
   
      ' Odometer
      if ||(Odometer-_Odometer)=>100 ' If there is abs(.1) Change in the Units
        gr.color(0)
        gr.FilledBox(130,0,62,16)
        gr.color(1)
        Gr.Textmode(1,1,7,%1000)
        FixedDec(Odometer)
        Gr.Text(130+58,0,@Temp)
        _Odometer:=Odometer
   
      ' Trip Odometer
      IF (||(Odometer-_Odometer)=>1) or RedrawTrip==1  ' If there is abs(.1) Change in the Units
        gr.color(0)
        gr.FilledBox(130,16,62,16)
        gr.color(1)
        Gr.Textmode(1,1,7,%1000)
        
        if (UserSettings1 & %1)==0
          FixedDec(TripAOdometer)
          'I:=TripAOdometer
        else
          FixedDec(TripBOdometer)
          'I:=TripBOdometer
        'DisplayDec(130+58,16,I)          
        Gr.Text(130+58,16,@Temp)
        _TripAOdometer:=TripAOdometer
        _TripBOdometer:=TripBOdometer
        RedrawTrip:=0

   
      ' Battery
      X:=224
      Y:=96
      If Redraw
        Gr.TextMode(1,1,6,%0101)
        Gr.Color(1)
        gr.text(X+16,Y+21,String("VOLTS"))
      
      If ||(BatteryVoltage-_BatteryVoltage)=>10
        Gr.Color(1)
        Gr.FilledBox(X,Y,32,15)
        Gr.Color(0)
        gr.TextMode(1,1,7,%0101)
  '      Gr.text(X+16,y+7,Num.DecF(BatteryVoltage,2))
        FixedDec(BatteryVoltage*10)  
        Gr.Text(X+16,Y+7,@Temp) 
        _BatteryVoltage:=BatteryVoltage
   
      ' Coolant
      X:=224
      Y:=64
      If Redraw
        Gr.TextMode(1,1,7,%0101)
        Gr.Color(1)
        gr.text(X+16,Y+21,String("WTR"))
      
      If CoolantTemp<>_CoolantTemp
        If CoolantTemp=<96
          GR.Color(3)
          Gr.FilledBox(X,Y,32,15)
          Gr.Color(1)
          gr.TextMode(1,1,7,%0101)
          Gr.Text(X+16,Y+7,String("---"))  
        else    
          If CoolantTemp=>230
            Gr.Color(2)
          else
            GR.Color(3)
          Gr.FilledBox(X,Y,32,15)
          Gr.Color(1)
          gr.TextMode(1,1,7,%0101)  
          DisplayDec(X+16,Y+7,CoolantTemp) 
        _CoolantTemp:=CoolantTemp
   
      ' Ambient
      X:=224
      Y:=32
      If Redraw
        Gr.TextMode(1,1,7,%0101)
        Gr.Color(1)
        gr.text(X+16,Y+21,String("AIR"))
      
      If AmbTemp<>_AmbTemp
        Gr.Color(1)
        Gr.FilledBox(X,Y,32,15)
        Gr.Color(0)
        gr.TextMode(1,1,7,%0101)  
        DisplayDec(X+16,Y+7,AmbTemp) 
        _AmbTemp:=AmbTemp

      Redraw:=0
   
      if INA[ShowGrid]==0
        ShowTiles
        If _Switch==0
          _Switch:=1 
      else
        If _Switch==1
          _Switch:=0
          _Speed:=-1
          _TachValue:=-1000
          _Gear:=-1
          _Signals:=_Signals ^ $FF
          _V1Status:=-1
          _AmbTemp:=-100
          _CoolantTemp:=-100
          _Odometer := -1
          _TripAOdometer := -1
          _TripBOdometer := -1
          _BatteryVoltage:=-10
          _Minute := -1
          Redraw:=1
          Gr.Clear


   
Pri FixedDec(Value)|i,k, V
  V:=Value/1000 ' First Calc Whole Miles  
  Repeat K From 0 to 11
    Temp[K]:=0
  
  k:=0
'' Print a decimal number
  if V < 0
    -V
    Temp[K++]:="-"

  i := 1_000_000_000

  repeat 10
    if V => i
      Temp[k++]:= Lookup(V / i: 49,50,51,52,53,54,55,56,57)
      V //= i
      Result~~
    elseif Result or i == 1
      Temp[k++]:="0"
    i /= 10

  Temp[k++]:="."
  ' Now Calc Fractions
  V:= (Value / 1000)
  V:= V * 1000
  V:= Value - V   
  Case V
    0..99:    Temp[K++]:="0"
    100..199: Temp[K++]:="1"
    200..299: Temp[K++]:="2"
    300..399: Temp[K++]:="3"
    400..499: Temp[K++]:="4"
    500..599: Temp[K++]:="5"
    600..699: Temp[K++]:="6"
    700..799: Temp[K++]:="7"
    800..899: Temp[K++]:="8"
    900..999: Temp[K++]:="9"

Pri NormalText
  Gr.TextMode(1,1,6,%0101)
  Gr.ColorWidth(1,0)

Pri ClearTiles(X,Y,W,H)
  gr.Color(0)
  Gr.FilledBox(X*16,Y*16,W*16,H*16)
  
Pub ShowTiles| x, y
  ' This Sub Will Draw a Grid Outlining each Tile
  gr.color(1)
  Repeat X From 0 to X_tiles-1
    gr.Plot(X * 16,0)
    gr.line(X * 16,y_Tiles * 16)  
  Repeat Y From 0 to y_Tiles-1
    gr.Plot(0,Y*16)
    gr.line(X_Tiles * 16,Y * 16)

Pri PlaceChar(x,y,Char)|i,j,k,S,w
  S := Display_Base+(64*Y)+(768*x) 
  k := S - 64 * 2
  Repeat i from 0 to 64
    'Word[S][i] := Word[$9000][i] Or %11111111_11111111
    ' WordMove(S+I*2,$9000+i*2,1)
    Word[S][i] := (Word[$9000+I*2] & %10101010_10101010)
    'Word[S][i] := (Word[$9000+I*2] & %01010101_01010101)

Pub DisplayTime(X,Y,H,M)

  ' Display time
  gr.color(3)
  gr.FilledBox(X-6,Y+2,4*16,20)
  gr.color(1)    
   
  If H==0
    H:=12 ' 12 AM
  IF H>12 ' ?? PM
    H:=H-12
  Gr.Width(0)
  Gr.TextMode(2,2,6,%0101)
  If H<10 
    DisplayDec(X+12,Y+11,H)
  Else
    DisplayDec(X+6,Y+11,H)  
  gr.Text(X+20,Y+10,String(":"))
  If M<10
    Gr.text(X+28,Y+11,string("0"))
    DisplayDec(X+39,y+11,M)
  Else
    DisplayDec(X+34,y+11,M)

Pub DisplayDec(X,Y,V)|i,k
  K:=0
  i:=0
  
  Repeat K From 0 to 11
    Temp[K]:=0
  
  k:=0
'' Print a decimal number
  if V < 0
    -V
    Temp[K++]:="-"

  i := 1_000_000_000

  repeat 10
    if V => i
      'Temp[k++]:= Lookup(V / i: "1","2","3","4","5","6","7","8","9")
      Temp[k++]:= Lookup(V / i: 49,50,51,52,53,54,55,56,57)
      V //= i
      Result~~
    elseif Result or i == 1
      Temp[k++]:="0"
    i /= 10

  GR.text(x,y,@Temp)





Pub SetAreaColor(X1,Y1,X2,Y2,ColorIndex)|DX,DY
  Repeat DX from X1 to X2
    Repeat DY from Y1 to Y2
      SetTileColor(DX,DY,ColorIndex)    

Pub SetTileColor( x, y, ColorIndex)
   screen[y * tv_hc + x] := display_base >> 6 + y + x * tv_vc + ((ColorIndex & $3F) << 10)

Pub SetColorPallet(ColorIndex,Color1,Color2,Color3,Color4)
  colors[ColorIndex] := (Color1) + (Color2 << 8) +  (Color3 << 16) + (Color4 << 24)       




PRI private_code
DAT
tvparams                long    0               'status
                        long    1               'enable
                        long    %001_0101       'pins
                        long    %0000           'mode
                        long    0               'screen
                        long    0               'colors
                        long    x_tiles         'hc
                        long    y_tiles         'vc
                        long    10              'hx
                        long    1               'vx
                        long    0               'ho
                        long    0              'vo
                        long    1               'broadcast
                        long    0               'auralcog


Tach                    word    $8000+$500 ' Position First Point                              
                        word    8               
                        word    $8000+0 ' Draw to next line
                        word    100               
                        word    $8000+$2000-$500 ' Draw to next line
                        word    8               
                        word    $8000+$2000-$500 ' Draw to next line
                        word    0               
                        word    0                

TachCtr                 word    $8000+$2000 ' Position First Point                              
                        word    100               
                        word    0                


{LeftTurnBitMap          Word
                        Byte    4,32,0,0
                                 '             1111111    11122222    22222333
                                 '12345678    90123456    78901234    56789012
                        Word    %%00000000, %%00000000, %%00000000, %%00000011 ' 1                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00001111 ' 2
                        Word    %%00000000, %%00000000, %%00000000, %%00111111 ' 3                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%11111111 ' 4                                                              
                        Word    %%00000000, %%00000000, %%00000011, %%11111111 ' 5                                                              
                        Word    %%00000000, %%00000000, %%00001111, %%11111111 ' 6                                                              
                        Word    %%00000000, %%00000000, %%00111111, %%11111111 ' 7                                                              
                        Word    %%00000000, %%00000000, %%11111111, %%11111111 ' 8                                                              
                        Word    %%00000000, %%00000011, %%11111111, %%11111111 ' 9                                                              
                        Word    %%00000000, %%00001111, %%11111111, %%11111111 ' 10                                                              
                        Word    %%00000000, %%00111111, %%11111111, %%11111111 ' 11                                                              
                        Word    %%00000000, %%11111111, %%11111111, %%11111111 ' 12                                                              
                        Word    %%00000011, %%11111111, %%11111111, %%11111111 ' 13                                                              
                        Word    %%00001111, %%11111111, %%11111111, %%11111111 ' 14                                                              
                        Word    %%00111111, %%11111111, %%11111111, %%11111111 ' 15                                                              
                        Word    %%11111111, %%11111111, %%11111111, %%11111111 ' 16                                                              
                        Word    %%11111111, %%11111111, %%11111111, %%11111111 ' 17                                                            
                        Word    %%00111111, %%11111111, %%11111111, %%11111111 ' 18                                                             
                        Word    %%00001111, %%11111111, %%11111111, %%11111111 ' 19                                                              
                        Word    %%00000011, %%11111111, %%11111111, %%11111111 ' 20                                                              
                        Word    %%00000000, %%11111111, %%11111111, %%11111111 ' 21                                                              
                        Word    %%00000000, %%00111111, %%11111111, %%11111111 ' 22                                                              
                        Word    %%00000000, %%00001111, %%11111111, %%11111111 ' 23                                                              
                        Word    %%00000000, %%00000011, %%11111111, %%11111111 ' 24                                                              
                        Word    %%00000000, %%00000000, %%11111111, %%11111111 ' 25                                                              
                        Word    %%00000000, %%00000000, %%00111111, %%11111111 ' 26                                                              
                        Word    %%00000000, %%00000000, %%00001111, %%11111111 ' 27                                                              
                        Word    %%00000000, %%00000000, %%00000011, %%11111111 ' 28                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%11111111 ' 29                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00111111 ' 30                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00001111 ' 31                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000011 ' 32                                                              
}                                                             
{
LeftTurnBitMap          Word
                        Byte    2,8,0,0
                                 '             1111111    11122222    22222333
                                 '12345678    90123456    78901234    56789012
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 1                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 2
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 3                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 4                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 5                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 6                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 7                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 8                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 9                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 10                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 11                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 12                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 13                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 14                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 15                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 16                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 17                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 18                                                             
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 19                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 20                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 21                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 22                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 23                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 24                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 25                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 26                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 27                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 28                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 29                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 30                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 31                                                              
                        Word    %%00000000, %%00000000, %%00000000, %%00000000 ' 32                                                              
}

Tach0                   Byte "0",0        
Tach1                   Byte "1",0
Tach2                   Byte "2",0
Tach3                   Byte "3",0
Tach4                   Byte "4",0
Tach5                   Byte "5",0
Tach6                   Byte "6",0
Tach7                   Byte "7",0
Tach8                   Byte "8",0
Tach9                   Byte "9",0
Tach10                  Byte "10",0
Tach11                  Byte "11",0
Tach12                  Byte "12",0
Tach13                  Byte "13",0
Tach14                  Byte "14",0
     
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