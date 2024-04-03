import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import sys, time, math
import serial
# configure the serial port
ser = serial.Serial(
  port='COM3',
  baudrate=115200,
  parity=serial.PARITY_NONE,
  stopbits=serial.STOPBITS_TWO,
  bytesize=serial.EIGHTBITS
)
ser.isOpen()
#strin = ser.readline()
#str_data = strin.decode('utf-8').strip()
  
  
xsize=100
   
#test cases
#print(int(str_data[1:len(str_data)-2]));
#print(float(str_data[:len(str_data)])/100);

for x in range(5):
    strin = ser.readline()
    yh = strin.decode('utf-8').strip()
    yh = int(yh[1:len(yh)-2])
    yf = strin.decode('utf-8').strip()
    yf = float(yf[:len(yf)])/100
    print(yh,'\t',yf)
##########################################    
    
def data_gen():
    t = data_gen.t
    while True:
       t+=1
       strin = ser.readline()
       strin = strin.decode('utf-8').strip()
       val = int(strin)/10000
       yield t, val

def run(data):
    # update the data
    t,y = data
    if t>-1:
        xdata.append(t)
        ydata.append(y)
        if t>xsize: # Scroll to the left.
            ax.set_xlim(t-xsize, t)
        line.set_data(xdata, ydata)
        
        #error = 0.1  # Adjust this with your actual error
        #ax.errorbar(t, y, yerr=error, fmt='ro', markersize=5)
        
        if hasattr(run, 'text_label'):
            run.text_label.set_text('')
        
        run.text_label = ax.text(t, ax.get_ylim()[1], f'{y:.2f}', fontsize=8, ha='left', va='bottom', color='black')
        #run.text_label.set_text(f'{y:.2f}')

    return line,

def on_close_figure(event):
    sys.exit(0)

data_gen.t = -1
fig = plt.figure()
fig.canvas.mpl_connect('close_event', on_close_figure)
ax = fig.add_subplot(111)
line, = ax.plot([], [], lw=2)
ax.set_ylim(20,30)
ax.set_xlim(0, xsize)
ax.grid()
xdata, ydata = [], []

ax.set_title('Temp vs time')
ax.set_xlabel('Time-axis ')
ax.set_ylabel('Temp-axis')
ax.grid(True)


ani = animation.FuncAnimation(fig, run, data_gen, blit=False, interval=100, repeat=False)
plt.show()

# Important: Although blit=True makes graphing faster, we need blit=False to prevent
# spurious lines to appear when resizing the stripchart.
