; ISR_example.asm: a) Increments/decrements a BCD variable every half second using
; an ISR for timer 2; b) Generates a 2kHz square wave at pin P1.7 using
; an ISR for timer 0; and c) in the 'main' loop it displays the variable
; incremented/decremented using the ISR for timer 2 on the LCD.  Also resets it to 
; zero if the 'CLEAR' push button connected to P1.5 is pressed.
$NOLIST
$MODN76E003
$LIST

;  N76E003 pinout:
;                               -------
;       PWM2/IC6/T0/AIN4/P0.5 -|1    20|- P0.4/AIN5/STADC/PWM3/IC3
;               TXD/AIN3/P0.6 -|2    19|- P0.3/PWM5/IC5/AIN6
;               RXD/AIN2/P0.7 -|3    18|- P0.2/ICPCK/OCDCK/RXD_1/[SCL]
;                    RST/P2.0 -|4    17|- P0.1/PWM4/IC4/MISO
;        INT0/OSCIN/AIN1/P3.0 -|5    16|- P0.0/PWM3/IC3/MOSI/T1
;              INT1/AIN0/P1.7 -|6    15|- P1.0/PWM2/IC2/SPCLK
;                         GND -|7    14|- P1.1/PWM1/IC1/AIN7/CLO
;[SDA]/TXD_1/ICPDA/OCDDA/P1.6 -|8    13|- P1.2/PWM0/IC0
;                         VDD -|9    12|- P1.3/SCL/[STADC]
;            PWM5/IC7/SS/P1.5 -|10   11|- P1.4/SDA/FB/PWM1
;                               -------
;

CLK           EQU 16600000 ; Microcontroller system frequency in Hz
TIMER0_RATE   EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))
TIMER2_RATE   EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD EQU ((65536-(CLK/TIMER2_RATE)))

;SETUP THE PUSH button
;-----------------------------------------------------------------------------------------------
Time_Hour_Button equ P3.0  
Time_Min_Button equ P1.6  
Time_Sec_Button equ P1.5  

Set_Hour_Button equ P1.2
Set_Min_Button equ P1.1
Set_Sec_Button equ P1.0

SOUND_OUT equ P1.7
;-----------------------------------------------------------------------------------------------


; Reset vector
org 0x0000
    ljmp main

; External interrupt 0 vector (not used in this code)
org 0x0003
	reti

; Timer/Counter 0 overflow interrupt vector
org 0x000B
	ljmp Timer0_ISR

; External interrupt 1 vector (not used in this code)
org 0x0013
	reti

; Timer/Counter 1 overflow interrupt vector (not used in this code)
org 0x001B
	reti

; Serial port receive/transmit interrupt vector (not used in this code)
org 0x0023 
	reti
	
; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR

; In the 8051 we can define direct access variables starting at location 0x30 up to location 0x7F
dseg at 0x30
Count1ms:     ds 2 ; Used to determine when half second has passed


;Define variable: ds=(data space) 1
;-----------------------------------------------------------------------------------------------
time_sec_counter:  ds 1 
time_min_counter:  ds 1 
time_hour_counter: ds 1 

set_sec_counter:  ds 1 
set_min_counter:  ds 1 
set_hour_counter: ds 1 

Time_AP:       ds 1 ; AMPM
Set_AP: ds 1 ; AMPM_alarm

AM: db 'AM', 0
PM: db 'PM', 0

;-----------------------------------------------------------------------------------------------


; In the 8051 we have variables that are 1-bit in size.  We can use the setb, clr, jb, and jnb
; instructions with these variables.  This is how you define a 1-bit variable:
bseg
half_seconds_flag: dbit 1 ; Set to one in the ISR every time 500 ms had passed

;Define variable: dbit=( declare a single bit variable) 1
;bseg, refers to a bit segment, a way to organize or group bit variables
;cseg, refers to code segment,  region of memory that stores the executable code of a program
;-----------------------------------------------------------------------------------------------

AP_time_var: dbit 1 
bseg
AP_set_var: dbit 1 
bseg
sec: dbit 1
bseg
min: dbit 1
bseg
hour: dbit 1
bseg
set_sec_var: dbit 1
bseg
set_min_var: dbit 1
bseg
set_hour_var: dbit 1
bseg
set_AP_var: dbit 1
cseg

;-----------------------------------------------------------------------------------------------

; These 'equ' must match the hardware wiring
LCD_RS equ P1.3
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E  equ P1.4
LCD_D4 equ P0.0
LCD_D5 equ P0.1
LCD_D6 equ P0.2
LCD_D7 equ P0.3

$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

;                     1234567890123456    <- This helps determine the location of the counter
;-----------------------------------------------------------------------------------------------
Initial_Message:  db 'Time:  :  :', 0
Alarm_Message:    db 'Set :  :  :', 0

;-----------------------------------------------------------------------------------------------

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 0                     ;
;---------------------------------;
Timer0_Init:
	orl CKCON, #0b00001000 ; Input for timer 0 is sysclk/1
	mov a, TMOD
	anl a, #0xf0 ; 11110000 Clear the bits for timer 0
	orl a, #0x01 ; 00000001 Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0
	ret

;---------------------------------;
; ISR for timer 0.  Set to execute;
; every 1/4096Hz to generate a    ;
; 2048 Hz wave at pin SOUND_OUT   ;
;---------------------------------;
Timer0_ISR:
	;clr TF0  ; According to the data sheet this is done for us already.
	; Timer 0 doesn't have 16-bit auto-reload, so
	clr TR0
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	setb TR0

    ;jnb - Jump if Bit Not Set:
	;reti - Return from Interrupt:
	;-----------------------------------------------------------------------------------------------
	
	jnb set_AP_var, reset_var
	jnb set_sec_var, reset_var
	jnb set_min_var, reset_var
	jnb set_hour_var, reset_var
    cpl SOUND_OUT
	 ; Connect speaker the pin assigned to 'SOUND_OUT'!
	reti

reset_var:
	clr set_AP_var
	clr set_sec_var
	clr set_min_var
	clr set_hour_var		
	reti


;-----------------------------------------------------------------------------------------------

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 2                     ;
;---------------------------------;
Timer2_Init:
	mov T2CON, #0 ; Stop timer/counter.  Autoreload mode.
	mov TH2, #high(TIMER2_RELOAD)
	mov TL2, #low(TIMER2_RELOAD)
	; Set the reload value
	orl T2MOD, #0x80 ; Enable timer 2 autoreload
	mov RCMP2H, #high(TIMER2_RELOAD)
	mov RCMP2L, #low(TIMER2_RELOAD)
	; Init One millisecond interrupt counter.  It is a 16-bit variable made with two 8-bit parts
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Enable the timer and interrupts
	orl EIE, #0x80 ; Enable timer 2 interrupt ET2=1
    setb TR2  ; Enable timer 2
	ret

;---------------------------------;
; ISR for timer 2                 ;
;---------------------------------;

	
Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in the ISR.  It is bit addressable.
	cpl P0.4 ; To check the interrupt rate with oscilloscope. It must be precisely a 1 ms pulse.
	
	; The two registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	; Increment the 16-bit one mili second counter
	inc Count1ms+0    ; Increment the low 8-bits first
	mov a, Count1ms+0 ; If the low 8-bits overflow, then increment high 8-bits
	jnz Inc_Done
	inc Count1ms+1

Inc_Done:
	; Check if half second has passed
	mov a, Count1ms+0
	cjne a, #low(200), Timer2_ISR_done ; Warning: this instruction changes the carry flag!
	mov a, Count1ms+1
	cjne a, #high(200), Timer2_ISR_done
	
	; 500 milliseconds have passed.  Set a flag so the main program knows
	setb half_seconds_flag ; Let the main program know half second had passed
	cpl TR0 ; Enable/disable timer/counter 0. This line creates a beep-silence-beep-silence sound.
	; Reset to zero the milli-seconds counter, it is a 16-bit variable
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a


  ;-----------------------------------------------------------------------------------------------
	jnb Time_Sec_Button, time_sec_pressed
	jnb Time_Min_Button, time_min_pressed
	jnb Time_Hour_Button, time_hour_pressed

    jnb Set_Sec_Button, set_sec_pressed
	jnb Set_Min_Button, set_min_pressed
	jnb Set_Hour_Button,set_pre_hour_pressed              

	; Increment the BCD counter
	mov a, time_sec_counter
	add a, #0x01
	sjmp Timer2_ISR_da_sec
	;-----------------------------------------------------------------------------------------------
time_sec_pressed:
	mov a, time_sec_counter
	add a, #1
	sjmp Timer2_ISR_da_sec
	
time_min_pressed:
	mov a, time_min_counter
	add a, #1
	sjmp Timer2_ISR_da_min
	

time_hour_pressed:
	mov a, time_hour_counter
    add a, #1
	sjmp Timer2_ISR_da_hour

Timer2_ISR_da_sec:
	da a 
	mov time_sec_counter, a
	mov a, time_sec_counter
	cjne a, #0x60, Timer2_ISR_done
	clr a 
	mov time_sec_counter, a
	mov a, time_min_counter
	add a, #1
	mov time_min_counter, a

Timer2_ISR_da_min:
	da a
	mov time_min_counter, a 
	mov a, time_min_counter
	cjne a, #0x60, Timer2_ISR_done
	clr a 
	mov time_min_counter, a
	mov a, time_hour_counter
	add a, #1
	mov time_hour_counter, a 

Timer2_ISR_da_hour:
	da a
	mov time_hour_counter, a 
	mov a, time_hour_counter
	cjne a, #0x12, Timer2_ISR_done
	clr a 
	mov time_hour_counter, a 
	cpl AP_time_var

Timer2_ISR_done:
	mov a, time_sec_counter
	cjne a, set_sec_counter, sec_not_same
	setb set_sec_var

sec_not_same:
	mov a, time_min_counter
	cjne a, set_min_counter, min_not_same
	setb set_min_var

min_not_same:
	mov a, time_hour_counter
	cjne a, set_hour_counter, hour_not_same
	setb set_hour_var

hour_not_same:
	mov a, Time_AP
	cjne a, Set_AP, done
	setb set_AP_var

done:
	pop psw
	pop acc
	reti

set_pre_hour_pressed:
	sjmp alarm_hour_set

set_sec_pressed:
	mov a, set_sec_counter
	add a, #1
	da a 
	mov set_sec_counter, a 
    mov a, set_sec_counter
	cjne a, #0x60, Timer2_ISR_done
	clr a 
	mov set_sec_counter, a 
	sjmp Timer2_ISR_done

set_min_pressed:
	mov a, set_min_counter
	add a, #1
	da a 
	mov set_min_counter, a 
    mov a, set_min_counter
	cjne a, #0x60, Timer2_ISR_done
	clr a 
	mov set_min_counter, a 
	sjmp Timer2_ISR_done

alarm_hour_set:
	mov a, set_hour_counter
	add a, #0x01
	da a 
	mov set_hour_counter, a 
    mov a, set_hour_counter
	cjne a, #0x12, Timer2_ISR_done
	clr a
	mov set_hour_counter, a 
	cpl AP_set_var
	sjmp Timer2_ISR_done

;---------------------------------;
; Main program. Includes hardware ;
; initialization and 'forever'    ;
; loop.                           ;
;---------------------------------;
main:
	; Initialization
    mov SP,   #0x7F
    mov P0M1, #0x00
    mov P0M2, #0x00
    mov P1M1, #0x00
    mov P1M2, #0x00
    mov P3M2, #0x00
    mov P3M2, #0x00
          
    lcall Timer0_Init
    lcall Timer2_Init
    setb EA   ; Enable Global interrupts
    lcall LCD_4BIT
    ; For convenience a few handy macros are included in 'LCD_4bit.inc':


		;---------------------------------------------------------------------
	Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message)
	Set_Cursor(2,1)
	Send_Constant_String(#Alarm_Message)
		;---------------------------------------------------------------------


    setb half_seconds_flag
	mov time_sec_counter,  #0x00
	mov time_min_counter,  #0x00		
	mov time_hour_counter, #0x00

	mov set_sec_counter,  #0x00
	mov set_min_counter,  #0x10
	mov set_hour_counter, #0x00

	mov Time_AP, #0x00
	mov Set_AP, #0x00

	clr AP_time_var
	clr AP_set_var
	clr set_sec_var
	clr set_min_var
	clr set_hour_var
	
	; After initialization the program stays in this 'forever' loop
PM_timecheck:
  	clr half_seconds_flag ; We clear this flag in the main loop, but it is - in the ISR for timer 2
	Set_Cursor(1, 15)     ; the place in the LCD where we want the BCD counter value
	jb AP_time_var, PM_time
	Send_Constant_String(#AM)
	mov Time_AP, #0x00

PM_setcheck:
	Set_Cursor(2,15)
	jb AP_set_var, PM_set
	Send_Constant_String(#AM)
	mov Set_AP, #0x00
	sjmp main_repeat

PM_time:
	Send_Constant_String(#PM)
	mov Time_AP, #0x01
	sjmp PM_setcheck

PM_set:
	Send_Constant_String(#PM)
	mov Set_AP, #0x01

main_repeat:
	Set_Cursor(1,12)
	display_BCD(time_sec_counter)
	Set_Cursor(1,9)
	display_BCD(time_min_counter)
	Set_Cursor(1,6)
	display_BCD(time_hour_counter)

    Set_Cursor(2,12)
	display_BCD(set_sec_counter)
	Set_Cursor(2,9)
	display_BCD(set_min_counter)
	Set_Cursor(2,6)
	display_BCD(set_hour_counter)

  ljmp PM_timecheck
	
END
