{{

By Don Starkey
Email: Don@StarkeyMail.com
Ver. 1.0,  11/26/2011

Floating Point math routines copied from Float32 as written by Cam Thompson
 

    My implementation of Bresenham's circle algorithm
    Ref. http://free.pages.at/easyfilter/bresenham.html


This code is the starting point for a circular interpolation motion profile for a home-brew CNC machine. (CNC Codes G02 & G03)

The Bresenham algorithm calculates X & Y steps of an approximate circle starting at a boundary between quadrants and calculates
up to a 45-degree point in the arc. You then mirror the X & Y coordinates to finish the arc within the quadrant. You also mirror
the first quadrant to form the 2nd, 3rd and 4th quadrants. My code starts at 0-degrees and depending on the direction of the arc,
draws a circle either CCW or CW. When the starting point of the desired points are are crossed (within 2 steps of the start/end points),
it starts to drive the actual stepper motors (or if you like, you can turn on pixels).
When the path crosses the endpoint, it stops stepping.

The PASM code actually draws a circle twice so that it can properly draw an arc that crosses between the 1st and 4th quadrants.
I haven't worked out the code to draw/step full circles since the code is constantly looking to see if it crosses the start/end points.
A full circle would have the same start & end points so it thinks it is done before it takes its first step.
This can be easily fixed but is lower on the to-do list.

Things to consider.
1. It is extremely accurate in its calculation. I have plotted its output against an AutoCAD circle and it is always within 1 step of perfect.
2. Its behavior when crossing the endpoint is dependant on the correct location of the endpoint. If the specified endpoint is wrong,
    it will miss it and complete the two turns around the circle. (You can trap for endpoint accuracy using  Pythagorean theorem and
    fault out if an improper endpoint is specified).
3. The center of the arc is specified using the I & J addresses standard to CNC programming.
    I=the distance from the starting point to the center of the arc along the X-Axis &
    J=the distance from the starting point to the center of the arc along the Y-Axis.
4. This code is strictly for 2-axis (X & Y). 
5. There is no code for controlling the step rate along the path. (Currently working on this).
6. I used some floating point math to begin the routine but it is only used to calculate the radius of the arc. 

 
I also have written a 3D Linear Interpolation again using the Bresenham algorithm calculates X,Y & Z steps of an approximate line.
 


   I/O P16 - X-Axis Step Pin    ' Should be a contiguous block of pins
   I/O P17 - X-Axis Directin Pin
   I/O P18 - Y-Axis Step Pin
   I/O P19 - Y-Axis Directin Pin
   I/O P20 - Z-Axis Directin Pin (Not used) 
   I/O P21 - Z-Axis Directin Pin (Not used)

   I/O P28 - SCL I2C
   I/O P39 - SDA I2C
   I/O P30 - Serial Communications
   I/O P31 - Serial Communications Also Bridge pin for timer operations.

}}

CON                  
    _CLKMODE    = XTAL1 + PLL16X                         
    _XINFREQ    = 5_000_000

    StepXPin    = 16+0 ' Must be a contiguous block of pins
    DirXPin     = 16+1
    StepYPin    = 16+2
    DirYPin     = 16+3
    StepZPin    = 16+4 '(Not used)
    DirZPin     = 16+5 '(Not used)

    CW          = 1     ' Counter-Clockwise rotation
    CCW         = -1    ' Clockwise rotation

' Floating Point Math Constants
    SignFlag    = $1
    ZeroFlag    = $2
    NaNFlag     = $8

VAR

' Dont rearrange the order of these variables as the PASM code need to know them in order
    long    s_Dir       ' +0 Circular Interpolation Direction & Status
                        ' State of 0 = idle, awaiting a value from Spin program
                        ' State of 1 = in PASM code, move in CW circular interpolation Direction
                        ' State of -1 = in PASM code, move in CCW circular interpolation Direction
                        
    long    s_FromX     ' +4  From X Coordinate
    long    s_FromY     ' +8  From Y Coordinate
    long    s_FromZ     ' +12 From Z Coordinate (Not implemented) 
    long    s_ToX       ' +16 To X Coordinate
    long    s_ToY       ' +20 To Y Coordinate
    long    s_ToZ       ' +24 To Z Coordinate   (Not implemented)
    long    s_I         ' +28 Distance from Starting X to Center of Radius along X-Axis
    long    s_J         ' +32 Distance from Starting Y to Center of Radius along Y-Axis
    long    s_Speed     ' +36 Speed of movement (Not implemented)
    long    s_XAt       ' +40 Current location of X Axis
    long    s_YAt       ' +44 Current location of Y Axis
    long    s_ZAt       ' +48 Current location of Z Axis (Not implemented)
    

long latch' +52 ' Debugging variables, can be deleted
    
OBJ

     ser        : "Parallax Serial Terminal"
     
PUB CircularInterpolation

    ser.start(115200)               ' Start the serial port driver

    StepPinX := StepXPin            ' Define the base pin for Step & Direction outputs
    
    cognew(@CircInt,@s_Dir)         ' Start the Circular Interpolation COG

' do some demo moves
    waitcnt(clkfreq*2+cnt)
    cir(100,2,100,-2,-100,-2,CW) ' Draw a CW arc from (100,2) to (100,-2) with the center at (0,0)
    waitcnt(clkfreq+cnt)
    cir(100,-2,100,2,-100,2,CW) ' Draw a CW arc from (100,-2) to (100,2) with the center at (0,0)
    waitcnt(clkfreq+cnt)
    cir(1000,20,1000,16,-100,-2,CCW) ' Draw a CCW arc from (1000,20) to (1000,16) with the center at (900,18)

PUB Cir (From_X,From_Y,To_X,To_Y,_I,_J,_Dir)

' Enter with From_X & From_Y = starting point (integers)
' Enter with To_X & To_Y ending point (integers)
' Enter with _I & _J = distance from starting point to center of arc (integers)
' Enter with _Dir = 1 for Clockwise or -1 for Counter-Clockwise, 0 for no move
                                        
    s_FromX := From_X
    s_FromY := From_Y                                  
    s_ToX   := To_X
    s_ToY   := To_Y
    s_I     := _I
    s_J     := _J

    ser.char(13)
    ser.char(13)
    ser.str(string("From "))
    ser.dec(From_X)                      
    ser.str(string(","))
    ser.dec(From_Y)
    if (_Dir==1)
        ser.str(string(" CW"))
    else
        ser.str(string(" CCW"))

    ser.str(string(" To "))
    ser.dec(To_X)                        
    ser.str(string(","))
    ser.dec(To_Y)
    ser.str(string(" Centered at "))
    ser.dec(From_X+_I)                    
    ser.str(string(","))
    ser.dec(From_Y+_J)
    ser.char(13)
    ser.char(13)
    

    s_Dir := _Dir ' Start moving by setting the direction status to either -1 / +1 signalling the start of a move.

    repeat while s_Dir          ' will be cleared (by the PASM COG) to 0 when the move is done.
         if latch
            ser.dec(s_XAt)
            ser.str(string(","))
            ser.dec(s_YAt)
            ser.char(13)
            latch:=0

    
dat

' My implementation of Bresenham's circle algorithm
' Ref. http://free.pages.at/easyfilter/bresenham.html

                        org     0
CircInt
                        sub     StepPinX,#1
                        mov     tmp1,StepPinX
                        mov     StepPinX,#1                 ' Make bitmask for Output Pins
                        shl     StepPinX,tmp1
                        
                        mov     DirPinX,StepPinX
                        shl     DirPinX,#1
                        
                        mov     StepPinY,StepPinX
                        shl     StepPinY,#2
                        
                        mov     DirPinY,StepPinX
                        shl     DirPinY,#3
                        
                        ' Set bitmask for X-Axis Step & Direction Pins
                        mov     tmp2,StepPinX                        
                        or      tmp2,DirPinX
                        or      tmp2,StepPinY
                        or      tmp2,DirPinY  
                        mov     outa,#0
                        mov     tmp2,#$f
                        shl     tmp2,tmp1
                        mov     dira,tmp2                   ' Set output pins for OUTPUT
                        mov     Sign,#0

                        ' Save addresses of pass-through variables
                        mov     tmp1,par
                        mov     DirAt,tmp1                  ' +0      Circular Interpolation Direction / Status 
                        add     tmp1,#4                     '         Direction of rotation, -1 for CCW, 1 for CW, 0 for not moving.                 

                        mov     FromXAt,tmp1                ' +4      From X Coordinate
                        add     tmp1,#4
                        mov     FromYAt,tmp1                ' +8      From Y Coordinate
                                                            ' +12     From Z Coordinate
                        add     tmp1,#8
                        mov     ToXAt,tmp1                  ' +16     To X Coordinate
                        add     tmp1,#4
                        mov     ToYAt,tmp1                  ' +20     To Y Coordinate
                                                            ' +24     To Z Coordinate (not implemented)                 
                                                            
                        add     tmp1,#8
                        mov     IAt,tmp1                    ' +28     I = Distance from Starting X to Center of Radius along X-Axis
                        add     tmp1,#4
                        mov     JAt,tmp1                    ' +32     J = Distance from Starting Y to Center of Radius along Y-Axis
                                                            ' +36     Speed of Movement (not implemented)
                        add     tmp1,#8                     
                        mov     XCurAt,tmp1                 ' +40     X Current Location in counts     
                        add     tmp1,#4                       
                        mov     YCurAt,tmp1                 ' +44     Y Current Location in counts
                        add     tmp1,#4                       
                        mov     ZCurAt,tmp1                 ' +48     Z Current Location in counts (not used)
                        

add tmp1,#4 ' Debugging Variables, can be removed
mov latchat,tmp1 '+52' Debugging Variables, can be removed


Disable
                        rdlong  tmp1, DirAt wz              ' Status of 0 = idle, awaiting SPIN
            if_z        jmp     #Disable                    ' SPIN sets to a Status of 1 to command moving in Circ. Int. Mode

                                                            
                        ' Read Pass-Through Variables
                        rdlong  p_Dir,DirAt                 ' Load the values from shared memory
                        rdlong  p_FromX,FromXAt
                        rdlong  p_FromY,FromYAt
                        rdlong  p_ToX,ToXAt   
                        rdlong  p_ToY,ToYAt   
                        rdlong  p_I,IAt
                        rdlong  p_J,JAt

                        ' Calculate Radius from I & J
                        mov     fnumA,p_I
                        call    #_FFloat
                        mov     fnumB,fnumA
                        call    #_FMul                      
                        mov     tmp1,fnumA                  ' I^2

                        mov     fnumA,p_J
                        call    #_FFloat
                        mov     fnumB,fnumA
                        call    #_FMul                      ' J^2
                        mov     fnumB,tmp1                  ' I^2
                        call    #_FAdd                      
                        call    #_FSqr                      ' Get radius
                        call    #_FRound          
                        mov     Radius,fnumA

                        
                        mov     CircleBiasX, p_FromX
                        adds    CircleBiasX, p_I           
                        mov     CircleBiasY, p_FromY
                        adds    CircleBiasY, p_J
                        subs    p_FromX, CircleBiasX
                        subs    p_FromY, CircleBiasY
                        subs    p_ToX, CircleBiasX
                        subs    p_ToY, CircleBiasY

                        mov     p_XCur, Radius              ' Starting point for Bresenham's circle algorithm 
                        mov     p_YCur, #0
                        
                        mov     PrevX,Radius                ' Seed start of circle
                        mov     PrevY,#0
                        
                        mov     DisplayOn,#0                ' Flag that we are not moving yet
                        mov     Quadrant,#0                 ' Always begin at 0-degrees

                        
MainLoop                ' Beginning of loop
                        mov     tmp1,Quadrant
                        and     tmp1,#3 wz                  ' First Quadrant? 

            if_z        mov     DX,#1
            if_z        mov     DY,#1
            if_z        mov     RXY,#0
            if_z        jmp     #DoIt
                
                        cmp     tmp1,#1 wz                  ' Second Quadrant
            if_z        mov     DX,#1
            if_z        mov     DY,NegOne
            if_z        mov     RXY,#1
            if_z        jmp     #DoIt
                
                        cmp     tmp1,#2 wz                  ' Third Quadrant
            if_z        mov     DX,NegOne
            if_z        mov     DY,NegOne
            if_z        mov     RXY,#0
            if_z        jmp     #DoIt
                                                            
                        mov     DX,NegOne                   ' Fourth Quadrant
                        mov     DY,#1
                        mov     RXY,#1
DoIt
                        neg     Error,Radius
                        mov     X,Radius
                        mov     Y,#0
                        
Loop1                   ' test for 0 - 45 degrees in this quadrant
                        cmps    X,Y wc                      ' C Set if SValue1 < SValue2
            if_c        jmp     #Loop1End                   ' Jump out of loop if X < Y               

                        mov     PError,Error
                        call    #SwapXY    
                        call    #Move

                        cmp     p_Dir,#0 wz
            if_z        jmp     #SetDisable

                        adds    Error,Y
                        adds    Y,#1
                        adds    Error,Y

                        cmps    Error,#0 wc
            if_nc       subs    X,#1
            if_nc       subs    Error,X
            if_nc       subs    Error,X
                        jmp     #Loop1
Loop1End

                        mov     Error,PError
                        call    #Move
                        cmp     p_Dir,#0 wz
            if_z        jmp     #SetDisable                 ' Done with arc

Loop2                   ' Up to axis crossing
                        cmps    X,#0 wc                                             
            if_c        jmp     #Loop2End
                        call    #SwapXY
                        call    #Move

                        cmp     p_Dir,#0 wz
            if_z        jmp     #SetDisable

                        mov     tmp1,Error
                        subs    tmp1,X
                        subs    tmp1,X
                        adds    tmp1,#1
                        
                        neg     tmp2,Y
                        adds    tmp2,tmp2
                        cmps    tmp1,tmp2 wc
            if_c        adds    Error,Y
            if_c        adds    Error,Y
            if_c        adds    Y,#1                
                        subs    Error,X
                        subs    X,#1
                        subs    Error,X
                        jmp     #Loop2
Loop2End

                        ' Go around circle twice to allow crossing 0-degrees                        
                        add     Quadrant,#1                        
                        cmp     Quadrant,#8 wz               
            if_nz       jmp     #MainLoop                        

SetDisable                                                  ' Done with arc, clear status flag
                        mov     p_Dir,#0
                        wrlong  p_Dir,DirAt
                        jmp     #Disable

Move                    ' Move a step
                        cmp     DisplayOn,#1 wz
                        neg     tmp1,p_FromX                   
            if_z        neg     tmp1,p_ToX
                        adds    tmp1,PrevX
                        abs     tmp1,tmp1

                        neg     tmp2,p_FromY
            if_z        neg     tmp2,p_ToY              

                        adds    tmp2,PrevY
                        abs     tmp2,tmp2
                        add     tmp1,tmp2
                        cmp     tmp1,#2 wc                  ' C Set if SValue1 < SValue2
            if_c_and_nz mov     DisplayOn,#1

            if_c_and_z  mov     DispX,p_ToX                 ' Done with arc move
            if_c_and_z  mov     DispY,p_ToY

            if_c_and_z  mov     p_Dir,#0                    ' Signal end of move

                        ' Do the move now
                        mov     StepPins,#0
                        mov     OutX,DispX
                        subs    OutX,PrevX wz
            if_z        jmp     #NoXMove

                        mov     tmp1,OutX
                        rol     tmp1,#1 wc
                        muxc    Sign,DirPinX
                        mov     StepPins,StepPinX           ' Set Step bit
                        
NoXMove
                        mov     OutY,DispY                  ' CCW movement
                        subs    OutY,PrevY wz
            if_z        jmp     #NoYMove

                        mov     tmp1,OutY
                        rol     tmp1,#1 wc
                        muxc    Sign,DirPinY
                        or      StepPins,StepPinY 
            
NoYMove
                        adds    p_XCur,OutX
                        adds    p_YCur,OutY
                        cmp     DisplayOn,#1 wz   
            if_nz       jmp     #MoveDone        
                        mov     tmp1,OutX                   ' Skip if neither X or Y change
                        or      tmp1,OutY wz
            if_z        jmp     #MoveDone
                       
                        mov     tmp1, p_XCur
                        adds    tmp1, CircleBiasX
                        wrlong  tmp1, XCurAt
                        mov     tmp1, p_YCur
                        adds    tmp1, CircleBiasY
                        wrlong  tmp1, YCurAt


' Debugging variable, can be removed
wrlong negone,latchat ' set a "latch" flag so that the SPIN code can hold up processing until it is written to the serial port then cleared to release the hold.

'============================================================
                        mov     outa,Sign                   ' Set the DIRECTION bit pattern
                        or      outa,StepPins               ' Strobe the STEP pins
                        call    #Pulse
                        mov     outa,sign                   ' Clear the STEP pins
'============================================================

MoveDone                        
                        mov     PrevX,DispX
                        mov     PrevY,DispY
Move_ret                ret

SwapXY                  ' Swap X & Y based on the quadrant an above/below 45-degrees
                        neg     DispX,X                                            
                        cmp     DX,#1 wz
            if_z        mov     DispX,X    

                        neg     DispY,Y
                        cmp     DY,#1 wz
            if_z        mov     DispY,Y                                                    

                        cmp     RXY,#1 wz                   ' swap X & Y ?
            if_z        mov     tmp1,DispX
            if_z        mov     DispX,DispY                 ' DispX & DispY are X & Y Coordinates for CCW circle starting at 0-degrees
            if_z        mov     DispY,tmp1

                        cmps    p_Dir,#1 wz                 ' Reverse direction for CW movement
            if_z        neg     DispY,DispY

SwapXY_ret              ret

Pulse 
                        mov     tmp1,PulseTime
Pulse1                  djnz    tmp1,#Pulse1

pulse2
                        rdlong  tmp1,latchat wz
            if_nz jmp   #pulse2
Pulse_ret               ret


'=============== Floating Point Math Routines from Float32 Library ========================
'------------------------------------------------------------------------------
' _FFloat  fnumA = float(fnumA)
' changes: fnumA, flagA, expA, manA
'------------------------------------------------------------------------------
         
_FFloat                 mov     flagA, fnumA            ' get integer value
                        mov     fnumA, #0               ' set initial result to zero
                        abs     manA, flagA wz          ' get absolute value of integer
          if_z          jmp     #_FFloat_ret            ' if zero, exit
                        shr     flagA, #31              ' set sign flag
                        mov     expA, #31               ' set initial value for exponent
:normalize              shl     manA, #1 wc             ' normalize the mantissa 
          if_nc         sub     expA, #1                ' adjust exponent
          if_nc         jmp     #:normalize
                        rcr     manA, #1                ' justify mantissa
                        shr     manA, #2
                        call    #_Pack                  ' pack and exit
_FFloat_ret             ret

'------------------------------------------------------------------------------
' _FTrunc  fnumA = fix(fnumA)
' _FRound  fnumA = fix(round(fnumA))
' changes: fnumA, flagA, expA, manA, t1 
'------------------------------------------------------------------------------

_FTrunc                 mov     t1, #0                  ' set for no rounding
                        jmp     #fix

_FRound                 mov     t1, #1                  ' set for rounding

fix                     call    #_Unpack                ' unpack floating point value
          if_c          jmp     #_FRound_ret            ' check for NaN
                        shl     manA, #2                ' left justify mantissa 
                        mov     fnumA, #0               ' initialize result to zero
                        neg     expA, expA              ' adjust for exponent value
                        add     expA, #30 wz
                        cmps    expA, #32 wc
          if_nc_or_z    jmp     #_FRound_ret
                        shr     manA, expA
                                                       
                        add     manA, t1                ' round up 1/2 lsb   
                        shr     manA, #1
                        
                        test    flagA, #signFlag wz     ' check sign and exit
                        sumnz   fnumA, manA
_FTrunc_ret
_FRound_ret             ret
'------------------------------------------------------------------------------
' _FAdd    fnumA = fnumA + fNumB
' _FAddI   fnumA = fnumA + {Float immediate}
' _FSub    fnumA = fnumA - fNumB
' _FSubI   fnumA = fnumA - {Float immediate}
' changes: fnumA, flagA, expA, manA, fnumB, flagB, expB, manB, t1
'------------------------------------------------------------------------------

_FSubI                  movs    :getB, _FSubI_ret       ' get immediate value
                        add     _FSubI_ret, #1
:getB                   mov     fnumB, 0

_FSub                   xor     fnumB, Bit31            ' negate B
                        jmp     #_FAdd                  ' add values                                               

_FAddI                  movs    :getB, _FAddI_ret       ' get immediate value
                        add     _FAddI_ret, #1
:getB                   mov     fnumB, 0

_FAdd                   call    #_Unpack2               ' unpack two variables                    
          if_c_or_z     jmp     #_FAdd_ret              ' check for NaN or B = 0

                        test    flagA, #SignFlag wz     ' negate A mantissa if negative
          if_nz         neg     manA, manA
                        test    flagB, #SignFlag wz     ' negate B mantissa if negative
          if_nz         neg     manB, manB

                        mov     t1, expA                ' align mantissas
                        sub     t1, expB
                        abs     t1, t1
                        max     t1, #31
                        cmps    expA, expB wz,wc
          if_nz_and_nc  sar     manB, t1
          if_nz_and_c   sar     manA, t1
          if_nz_and_c   mov     expA, expB        

                        add     manA, manB              ' add the two mantissas
                        cmps    manA, #0 wc, nr         ' set sign of result
          if_c          or      flagA, #SignFlag
          if_nc         andn    flagA, #SignFlag
                        abs     manA, manA              ' pack result and exit
                        call    #_Pack  
_FSubI_ret
_FSub_ret 
_FAddI_ret
_FAdd_ret               ret      


'------------------------------------------------------------------------------
' _FMul    fnumA = fnumA * fNumB
' _FMulI   fnumA = fnumA * {Float immediate}
' changes: fnumA, flagA, expA, manA, fnumB, flagB, expB, manB, t1, t2
'------------------------------------------------------------------------------

_FMulI                  movs    :getB, _FMulI_ret       ' get immediate value
                        add     _FMulI_ret, #1
:getB                   mov     fnumB, 0

_FMul                   call    #_Unpack2               ' unpack two variables
          if_c          jmp     #_FMul_ret              ' check for NaN

                        xor     flagA, flagB            ' get sign of result
                        add     expA, expB              ' add exponents
                        mov     t1, #0                  ' t2 = upper 32 bits of manB
                        mov     t2, #32                 ' loop counter for multiply
                        shr     manB, #1 wc             ' get initial multiplier bit 
                                    
:multiply if_c          add     t1, manA wc             ' 32x32 bit multiply
                        rcr     t1, #1 wc
                        rcr     manB, #1 wc
                        djnz    t2, #:multiply

                        shl     t1, #3                  ' justify result and exit
                        mov     manA, t1                        
                        call    #_Pack 
_FMulI_ret
_FMul_ret               ret


'------------------------------------------------------------------------------
' _FSqr    fnumA = sqrt(fnumA)
' changes: fnumA, flagA, expA, manA, t1, t2, t3, t4, t5 
'------------------------------------------------------------------------------

_FSqr                   call    #_Unpack                 ' unpack floating point value
          if_nc         mov     fnumA, #0                ' set initial result to zero
          if_c_or_z     jmp     #_FSqr_ret               ' check for NaN or zero
                        test    flagA, #signFlag wz      ' check for negative
          if_nz         mov     fnumA, NaN               ' yes, then return NaN                       
          if_nz         jmp     #_FSqr_ret
          
                        test    expA, #1 wz             ' if even exponent, shift mantissa 
          if_z          shr     manA, #1
                        sar     expA, #1                ' get exponent of root
                        mov     t1, Bit30               ' set root value to $4000_0000                ' 
                        mov     t2, #31                 ' get loop counter

:sqrt                   or      fnumA, t1               ' blend partial root into result
                        mov     t3, #32                 ' loop counter for multiply
                        mov     t4, #0
                        mov     t5, fnumA
                        shr     t5, #1 wc               ' get initial multiplier bit
                        
:multiply if_c          add     t4, fnumA wc            ' 32x32 bit multiply
                        rcr     t4, #1 wc
                        rcr     t5, #1 wc
                        djnz    t3, #:multiply

                        cmps    manA, t4 wc             ' if too large remove partial root
          if_c          xor     fnumA, t1
                        shr     t1, #1                  ' shift partial root
                        djnz    t2, #:sqrt              ' continue for all bits
                        
                        mov     manA, fnumA             ' store new mantissa value and exit
                        shr     manA, #1
                        call    #_Pack
_FSqr_ret               ret
'------------------------------------------------------------------------------
' input:   flagA        fnumA flag bits (Nan, Infinity, Zero, Sign)
'          expA         fnumA exponent (no bias)
'          manA         fnumA mantissa (aligned to bit 29)
' output:  fnumA        32-bit floating point value
' changes: fnumA, flagA, expA, manA 
'------------------------------------------------------------------------------

_Pack                   cmp     manA, #0 wz             ' check for zero                                        
          if_z          mov     expA, #0
          if_z          jmp     #:exit1

:normalize              shl     manA, #1 wc             ' normalize the mantissa 
          if_nc         sub     expA, #1                ' adjust exponent
          if_nc         jmp     #:normalize
                      
                        add     expA, #2                ' adjust exponent
                        add     manA, #$100 wc          ' round up by 1/2 lsb
          if_c          add     expA, #1

                        add     expA, #127              ' add bias to exponent
                        mins    expA, Minus23
                        maxs    expA, #255
 
                        cmps    expA, #1 wc             ' check for subnormals
          if_nc         jmp     #:exit1

:subnormal              or      manA, #1                ' adjust mantissa
                        ror     manA, #1

                        neg     expA, expA
                        shr     manA, expA
                        mov     expA, #0                ' biased exponent = 0

:exit1                  mov     fnumA, manA             ' bits 22:0 mantissa
                        shr     fnumA, #9
                        movi    fnumA, expA             ' bits 23:30 exponent
                        shl     flagA, #31
                        or      fnumA, flagA            ' bit 31 sign            
_Pack_ret               ret

'------------------------------------------------------------------------------
' input:   fnumA        32-bit floating point value
'          fnumB        32-bit floating point value 
' output:  flagA        fnumA flag bits (Nan, Infinity, Zero, Sign)
'          expA         fnumA exponent (no bias)
'          manA         fnumA mantissa (aligned to bit 29)
'          flagB        fnumB flag bits (Nan, Infinity, Zero, Sign)
'          expB         fnumB exponent (no bias)
'          manB         fnumB mantissa (aligned to bit 29)
'          C flag       set if fnumA or fnumB is NaN
'          Z flag       set if fnumB is zero
' changes: fnumA, flagA, expA, manA, fnumB, flagB, expB, manB, t1
'------------------------------------------------------------------------------

_Unpack2                mov     t1, fnumA               ' save A
                        mov     fnumA, fnumB            ' unpack B to A
                        call    #_Unpack
          if_c          jmp     #_Unpack2_ret           ' check for NaN

                        mov     fnumB, fnumA            ' save B variables
                        mov     flagB, flagA
                        mov     expB, expA
                        mov     manB, manA

                        mov     fnumA, t1               ' unpack A
                        call    #_Unpack
                        cmp     manB, #0 wz             ' set Z flag                      
_Unpack2_ret            ret


'------------------------------------------------------------------------------
' input:   fnumA        32-bit floating point value 
' output:  flagA        fnumA flag bits (Nan, Infinity, Zero, Sign)
'          expA         fnumA exponent (no bias)
'          manA         fnumA mantissa (aligned to bit 29)
'          C flag       set if fnumA is NaN
'          Z flag       set if fnumA is zero
' changes: fnumA, flagA, expA, manA
'------------------------------------------------------------------------------

_Unpack                 mov     flagA, fnumA            ' get sign
                        shr     flagA, #31
                        mov     manA, fnumA             ' get mantissa
                        and     manA, Mask23
                        mov     expA, fnumA             ' get exponent
                        shl     expA, #1
                        shr     expA, #24 wz
          if_z          jmp     #:zeroSubnormal         ' check for zero or subnormal
                        cmp     expA, #255 wz           ' check if finite
          if_nz         jmp     #:finite
                        mov     fnumA, NaN              ' no, then return NaN
                        mov     flagA, #NaNFlag
                        jmp     #:exit2        

:zeroSubnormal          or      manA, expA wz,nr        ' check for zero
          if_nz         jmp     #:subnorm
                        or      flagA, #ZeroFlag        ' yes, then set zero flag
                        neg     expA, #150              ' set exponent and exit
                        jmp     #:exit2
                                 
:subnorm                shl     manA, #7                ' fix justification for subnormals  
:subnorm2               test    manA, Bit29 wz
          if_nz         jmp     #:exit1
                        shl     manA, #1
                        sub     expA, #1
                        jmp     #:subnorm2

:finite                 shl     manA, #6                ' justify mantissa to bit 29
                        or      manA, Bit29             ' add leading one bit
                        
:exit1                  sub     expA, #127              ' remove bias from exponent
:exit2                  test    flagA, #NaNFlag wc      ' set C flag
                        cmp     manA, #0 wz             ' set Z flag
_Unpack_ret             ret       







'------------------------------------------------------------------------------
PulseTime       long        $2ff       ' How long to pulse the STEP pin, change as you like.
ZeroMask        long        $0000_0000
NegOne          long        $FFFF_FFFF

StepPinX        long    1   ' X-Axis Stepper Motor Step Pin
DirPinX         long    1   ' X-Axis Stepper Motor Direction Pin
StepPinY        long    1   ' Y-Axis Stepper Motor Step Pin
DirPinY         long    1   ' Y-Axis Stepper Motor Direction Pin

' Floating Point Math Constants
NaN            long     $7FFF_FFFF
Bit29          long     $2000_0000
Bit30          long    $4000_0000
Bit31          long    $8000_0000
Mask23         long    $007F_FFFF
Minus23        long    -23

' Addresses of Pass-Through Variables
DirAt           res     1   '+0  Address of Rotational Direction (1 for CCW, -1 For CW or 0 for stop) long
FromXAt         res     1   '+4  Address of From X Coordinate Long
FromYAt         res     1   '+8  Address of From Y Coordinate Long
ToXAt           res     1   '+16 Address of To X Coordinate Long
ToYAt           res     1   '+20 Address of To Y Coordinate Long
IAt             res     1   '+28 Address of I = Distance from Starting X to Center of Radius along X-Axis
JAt             res     1   '+32 Address of J = Distance from Starting Y to Center of Radius along J-Axis
XCurAt          res     1   '+40 Address of current X Position
YCurAt          res     1   '+44 Address of current Y Position
ZCurAt          res     1   '+48 Address of current Z Position

' Values read from Pass-Through Variables
p_Dir           res     1   ' Direction fo rotation, 1 for CW, -1 For CCW or 0 for stop
p_FromX         res     1   ' Value of From X Coordinate
p_FromY         res     1   ' Value of From Y Coordinate
p_ToX           res     1   ' Value of To X Coordinate 
p_ToY           res     1   ' Value of To Y Coordinate 
p_I             res     1   ' Distance from starting X to Center of Circle along X axis
p_J             res     1   ' Distance from starting Y to Center of Circle along Y axis
p_XCur          res     1   ' Current X Position
p_YCur          res     1   ' Current Y Position

'Calculated Variables
Radius          res     1   ' Calculated Radius of move
PrevX           res     1   ' Previous X
PrevY           res     1   ' Previous Y
Quadrant        res     1   ' Quadrant Counter 0-7
DX              res     1
DY              res     1
RXY             res     1   ' Reverse XY
Error           res     1   ' Error Amount
PError          res     1   ' Previous Error
X               res     1
Y               res     1
DispX           res     1
DispY           res     1
OutX            res     1   ' Step amount for X-Axis
OutY            res     1   ' Step amount for Y-Axis
DisplayOn       res     1
CircleBiasX     res     1   ' How much the center of the circle is shifted along X-Axis
CircleBiasY     res     1   ' How much the center of the circle is shifted along Y-Axis

StepPins        res     1   
Sign            res     1   
tmp1            res     1   ' Temporary Variable
tmp2            res     1   ' Temporary Variable

' Floating Point Math Variables
t1              res     1                       ' temporary values
t2              res     1
t3              res     1
t4              res     1
t5              res     1

fnumA           res     1                       ' floating point A value
flagA           res     1
expA            res     1
manA            res     1

fnumB           res     1                       ' floating point B value
flagB           res     1
expB            res     1
manB            res     1

' debugging variables
latchat res 1



                fit     496


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