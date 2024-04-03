#include <XC.h>
#include <stdio.h>
#include <stdlib.h>
#include "lcd.h"
 
// Configuration Bits (somehow XC32 takes care of this)
#pragma config FNOSC = FRCPLL       // Internal Fast RC oscillator (8 MHz) w/ PLL
#pragma config FPLLIDIV = DIV_2     // Divide FRC before PLL (now 4 MHz)
#pragma config FPLLMUL = MUL_20     // PLL Multiply (now 80 MHz)
#pragma config FPLLODIV = DIV_2     // Divide After PLL (now 40 MHz)
#pragma config FWDTEN = OFF         // Watchdog Timer Disabled
#pragma config FPBDIV = DIV_1       // PBCLK = SYCLK
#pragma config FSOSCEN = OFF        // Turn off secondary oscillator on A4 and B4

#define RA 1000
#define RB 2000
// Defines
#define SYSCLK 40000000L
#define Baud2BRG(desired_baud)( (SYSCLK / (16*desired_baud))-1)
 
void UART2Configure(int baud_rate)
{
    // Peripheral Pin Select
    U2RXRbits.U2RXR = 4;    //SET RX to RB8
    RPB9Rbits.RPB9R = 2;    //SET RB9 to TX

    U2MODE = 0;         // disable autobaud, TX and RX enabled only, 8N1, idle=HIGH
    U2STA = 0x1400;     // enable TX and RX
    U2BRG = Baud2BRG(baud_rate); // U2BRG = (FPb / (16*baud)) - 1
    
    U2MODESET = 0x8000;     // enable UART2
}

// Needed to by scanf() and gets()
int _mon_getc(int canblock)
{
	char c;
	
    if (canblock)
    {
	    while( !U2STAbits.URXDA); // wait (block) until data available in RX buffer
	    c=U2RXREG;
        while( U2STAbits.UTXBF);    // wait while TX buffer full
        U2TXREG = c;          // echo
	    if(c=='\r') c='\n'; // When using PUTTY, pressing <Enter> sends '\r'.  Ctrl-J sends '\n'
		return (int)c;
    }
    else
    {
        if (U2STAbits.URXDA) // if data available in RX buffer
        {
		    c=U2RXREG;
		    if(c=='\r') c='\n';
			return (int)c;
        }
        else
        {
            return -1; // no characters to return
        }
    }
}

#define PIN_PERIOD (PORTB&(1<<6))

// GetPeriod() seems to work fine for frequencies between 200Hz and 700kHz.
long int GetPeriod (int n)
{
	int i;
	unsigned int saved_TCNT1a, saved_TCNT1b;
	
    _CP0_SET_COUNT(0); // resets the core timer count
	while (PIN_PERIOD!=0) // Wait for square wave to be 0
	{
		if(_CP0_GET_COUNT() > (SYSCLK/4)) return 0;
	}

    _CP0_SET_COUNT(0); // resets the core timer count
	while (PIN_PERIOD==0) // Wait for square wave to be 1
	{
		if(_CP0_GET_COUNT() > (SYSCLK/4)) return 0;
	}
	
    _CP0_SET_COUNT(0); // resets the core timer count
	for(i=0; i<n; i++) // Measure the time of 'n' periods
	{
		while (PIN_PERIOD!=0) // Wait for square wave to be 0
		{
			if(_CP0_GET_COUNT() > (SYSCLK/4)) return 0;
		}
		while (PIN_PERIOD==0) // Wait for square wave to be 1
		{
			if(_CP0_GET_COUNT() > (SYSCLK/4)) return 0;
		}
	}

	return  _CP0_GET_COUNT();
}
void main(void)
{
    char buff[17];
    int j;
	long int count;
	float T, f,capacitance;
	
	char display_buffer_1[17];
	
	char display_buffer_2[17];
	
	DDPCON = 0;
	CFGCON = 0;

    UART2Configure(115200);  // Configure UART2 for a baud rate of 115200
	LCD_4BIT();
	
    ANSELB &= ~(1<<6); // Set RB6 as a digital I/O
   
    TRISB |= (1<<6);   // configure pin RB6 as input
   
    CNPUB |= (1<<6);   // Enable pull-up resistor for RB6

	waitms(500);	
	printf("4-bit mode LCD Test using the PIC32MX130.\r\n");
		
   	// Display something in the LCD
	LCDprint("Capacitance", 1, 1);
	//LCDprint("TEST", 2, 1);
	while(1)
	{
		//printf("Type what you want to display in line 2 (16 char max): ");
		count=GetPeriod(100);
		
		if(count>0)
		{
	
			T=(count*2.0)/(SYSCLK*100.0);
	
			capacitance = 1.44*T/(RA+2*RB);

			capacitance*=1000000;
			
			if(capacitance<0.01&&capacitance>0.001){
				capacitance*=1000;
				capacitance-=0.47;
				
				sprintf(display_buffer_1,"Capacitance");
			
				sprintf(display_buffer_2,"C= %.2fnF", capacitance);
			
				LCDprint(display_buffer_1,1,1);
				LCDprint(display_buffer_2,2,1);
			}else if(capacitance<0.02&&capacitance>0.091){
				capacitance*=1000;
				//capacitance-=0.63;
				
				sprintf(display_buffer_1,"Capacitance");
			
				sprintf(display_buffer_2,"C= %.2fnF", capacitance);
			
				LCDprint(display_buffer_1,1,1);
				LCDprint(display_buffer_2,2,1);
			}else if(capacitance<0.001){
				sprintf(display_buffer_1,"Capacitance");
			
				sprintf(display_buffer_2,"NO capacitor");
			
				LCDprint(display_buffer_1,1,1);
				LCDprint(display_buffer_2,2,1);
			}else{
				sprintf(display_buffer_1,"Capacitance");

				sprintf(display_buffer_2,"C= %.2fuF", capacitance);
			
				LCDprint(display_buffer_1,1,1);
				LCDprint(display_buffer_2,2,1);
			}
			printf("T: %f, C: %f\r",T,capacitance*1000000);
			
			//sprintf(display_buffer_1,"Capacitance");
			
			//sprintf(display_buffer_2,"C= %.4fF", capacitance*1000000);
			
			//LCDprint(display_buffer_1,1,1);
		
			//LCDprint(display_buffer_2,2,1);
		}
		
		fflush(stdout); // GCC peculiarities: need to flush stdout to get string out without a '\n'
		//fgets(buff, sizeof(buff)-1, stdin);	
		//printf("\r\n");
		//for(j=0; j<sizeof(buff); j++)
		//{
		//	if(buff[j]=='\r') buff[j]=0;
		//	if(buff[j]=='\n') buff[j]=0;
		//}

		//LCDprint(buff, 2, 1);
		waitms(200);
	}
}
