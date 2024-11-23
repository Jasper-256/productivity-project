import pystray
from pystray import MenuItem as item
from PIL import Image, ImageDraw
import subprocess
import sqlite3
import matplotlib.pyplot as plt

# Variable to store the process
process = None

# Function to start the script
def start_script(icon, item):
    global process
    if process is None:
        process = subprocess.Popen(["python", "productivity.py"])
        update_menu(icon)

# Function to stop the script
def stop_script(icon, item):
    global process
    if process:
        process.terminate()
        process = None
        update_menu(icon)

# Function to quit the app
def quit_app(icon, item):
    if process:
        process.terminate()
    icon.stop()

# Function to generate and display a productivity report
def generate_report(icon, item):
    conn = sqlite3.connect('productivity.db')
    cursor = conn.cursor()
    
    cursor.execute("SELECT timestamp, productivity_status FROM productivity_log")
    data = cursor.fetchall()
    conn.close()

    timestamps = [record[0] for record in data]
    statuses = [record[1] for record in data]
    
    productive_count = statuses.count('productive')
    unproductive_count = statuses.count('unproductive')

    plt.figure(figsize=(6, 4))
    plt.bar(['Productive', 'Unproductive'], [productive_count, unproductive_count], color=['green', 'red'])
    plt.title("Productivity Report")
    plt.xlabel("Status")
    plt.ylabel("Frequency")
    plt.show()

# Function to update the icon menu dynamically
def update_menu(icon):
    if process is None:
        icon.menu = pystray.Menu(
            item('Start', start_script),
            item('Quit', quit_app)
        )
    else:
        icon.menu = pystray.Menu(
            item('Stop', stop_script),
            item('Quit', quit_app)
        )

# Create an icon image (or load your custom icon)
def create_image():
    image = Image.new('RGB', (64, 64), (0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((16, 16, 48, 48), fill="blue")
    return image

# Create the tray icon
icon = pystray.Icon("productivity_control")
icon.icon = create_image()
icon.title = "Productivity Script Control"
update_menu(icon)  # Set initial menu based on process state

# Run the icon in the system tray
icon.run()
