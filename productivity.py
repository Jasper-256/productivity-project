import pyautogui
from openai import OpenAI
import pytesseract
import time
import os
from datetime import datetime
import re
import subprocess
from collections import Counter
import random
import threading

def load_api_key():
    with open('openai_api_key.txt', 'r') as file:
        return file.read()

OPENAI_API_KEY = load_api_key()
TIME_BETWEEN_CHECKS_SECS = 10
BREAK_TIME_MINS = 5
PROD_MIN_TIME_TO_DISPLAY_MINS = 0.05 # 5
ROLLING_CHECK_NUM = 15
TITLE = "Productivity Monitor"
IGNORE_TEXT = "Ignore"
BREAK_TEXT = f"Take a {BREAK_TIME_MINS} minute break"
DISABLE_TEXT = "Turn off"
RUN = True
NO_BREAK = True
STAGE_3_NOTIFICATIONS = False

time_productive_today = 0.0
time_unproductive_today = 0.0
time_program_active_today = 0.0
productivity_history = []

client = OpenAI(api_key=OPENAI_API_KEY)

def load_prompt():
    with open('prompt.txt', 'r') as file:
        return file.read()

def log_run(start, middle, end, extracted_text, answer, is_prod):
    total_time = end - start
    screenshot_time = middle - start
    chatgpt_time = end - middle
    
    if not os.path.exists('log'):
        os.makedirs('log')
    
    timestamp = datetime.fromtimestamp(end).strftime('%Y-%m-%d_%H.%M.%S')
    filename = f"log/log_{timestamp}_{is_prod}.txt"
    
    log_content = (
        f"Time: {total_time:.2f} seconds\n"
        f"Screenshot time: {screenshot_time:.2f} seconds\n"
        f"ChatGPT time: {chatgpt_time:.2f} seconds\n"
        f"Conclusion: {print_prod(is_prod)}\n\n"
        f"Screenshot text:\n{extracted_text}\n\n"
        f"ChatGPT answer:\n{answer}"
    )
    
    with open(filename, 'w') as log_file:
        log_file.write(log_content)

def capture_screenshot():
    screenshot = pyautogui.screenshot()
    return screenshot

def image_to_text(image):
    text = pytesseract.image_to_string(image)
    return text

def print_prod(is_prod):
    if is_prod == 1:
        return "productive"
    elif is_prod == 0:
        return "unproductive"
    else:
        return "unknown"

def take_a_break():
    global NO_BREAK, STAGE_3_NOTIFICATIONS
    STAGE_3_NOTIFICATIONS = False
    NO_BREAK = False

def disable():
    global RUN
    RUN = False

def display_popup(message):
    script = f"""
    display dialog "{message}" ¬
    with title "{TITLE}" ¬
    with icon caution ¬
    buttons {{"{DISABLE_TEXT}", "{BREAK_TEXT}", "{IGNORE_TEXT}"}} ¬
    default button "{IGNORE_TEXT}"
    """
    
    def run_script():
        proc = subprocess.Popen(
            ["osascript", "-e", script],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        stdout, stderr = proc.communicate()
        if stdout:
            if BREAK_TEXT in stdout:
                take_a_break()
            elif DISABLE_TEXT in stdout:
                disable()

    threading.Thread(target=run_script).start()

def display_os_notification(notification):
    command = f'''
    osascript -e 'display notification "{notification}" with title "{TITLE}"'
    '''
    os.system(command)

def stage_1():
    global STAGE_3_NOTIFICATIONS
    message = "Are you sure you want to doing this right now?"
    if (time_productive_today / 60) >= PROD_MIN_TIME_TO_DISPLAY_MINS:
        message += f" You have already been productive for {time_productive_today / 60:.0f} minutes today!"
    display_os_notification(message)
    STAGE_3_NOTIFICATIONS = False

def stage_2():
    global STAGE_3_NOTIFICATIONS
    message = "Please get back on task."
    if (time_unproductive_today / 60) >= PROD_MIN_TIME_TO_DISPLAY_MINS:
        message += f" You've wasted {time_unproductive_today / 60:.0f} minutes today :("
    display_popup(message)
    STAGE_3_NOTIFICATIONS = False

def stage_3():
    global STAGE_3_NOTIFICATIONS
    if STAGE_3_NOTIFICATIONS:
        display_popup("!!! GET BACK ON TASK !!!")
        screen_nuke()
    else:
        display_popup("Get back on task right now, this is your LAST WARNING!")
    STAGE_3_NOTIFICATIONS = True

def screen_nuke():
    # Hardcoded screen dimensions (update these if needed)
    screen_width = 1440  # Replace with your screen width
    screen_height = 900  # Replace with your screen height
    for _ in range(10):
        xPos = random.randint(0, screen_width - 300)  # Assume window width is ~300 pixels
        yPos = random.randint(0, screen_height - 100)  # Assume window height is ~100 pixels

        dialog_text = "!!! GET BACK ON TASK !!!"
        script = f'''
        tell application "TextEdit"
            activate
            make new document with properties {{text:"{dialog_text}"}}
            set the bounds of the front window to {{{xPos}, {yPos}, {xPos + 400}, {yPos + 150}}}
            set the name of the front window to "{TITLE}"
        end tell
        '''
        process = subprocess.Popen(['osascript'], stdin=subprocess.PIPE)
        process.communicate(script.encode('utf-8'))

def ask_chatgpt(prompt):
    response = client.chat.completions.create(
        messages=[
            {
                "role": "user",
                "content": prompt,
            }
        ],
        model="gpt-4o-mini",
    )
    return response.choices[0].message.content

def remove_phrases(text):
    phrases_to_remove = [
        TITLE,
        IGNORE_TEXT,
        BREAK_TEXT,
        DISABLE_TEXT,
        "Are you sure you want to doing this right now?",
        "You have already been productive for",
        "You've wasted",
        "minutes today",
        "Please get back on task.",
        "Get back on task right now, this is your LAST WARNING!",
        "GET BACK ON TASK",
        "!!!",
        "Run Program",
        "Stop Program"
    ]
    for phrase in phrases_to_remove:
        pattern = re.compile(re.escape(phrase), re.IGNORECASE)
        text = pattern.sub('', text)
    return text

def productivity_check():
    start = time.time()
    
    screenshot = capture_screenshot()
    extracted_text = image_to_text(screenshot)
    extracted_text = remove_phrases(extracted_text)
    
    middle = time.time()
    replace_keyword = '" + extracted_text + "'
    
    with open('gpt_judge_prompt_01.txt') as file:
        prompt_template = file.read()
    prompt = prompt_template.replace(replace_keyword, extracted_text, 1)
    
    answer = ask_chatgpt(prompt)
    last_word = answer.split()[-1].lower()
    is_prod = -1
    
    if "productive" in last_word and "un" not in last_word:
        is_prod = 1
    elif "unproductive" in last_word:
        is_prod = 0
    
    # Suggest tabs to close based on extracted text
    suggest_tabs_to_close(extracted_text)

    # Outline Green for productive and Red for unproductive
    update_status_file(is_prod)
    
    end = time.time()
    log_run(start, middle, end, extracted_text, answer, is_prod)
    
    return is_prod

    

def suggest_tabs_to_close(extracted_text):
    # Simulate tab suggestions based on keywords
    tabs = [
        "Facebook", "Twitter", "Reddit", "YouTube", "Netflix", "Shopping sites"
    ]
    suggested_tabs = [tab for tab in tabs if tab.lower() in extracted_text.lower()]
    
    if not suggested_tabs:
        suggested_tabs = ["No distracting tabs found."]
    
    # Write suggestions to a file for the Swift app to read
    with open("suggested_tabs.txt", "w") as file:
        file.write("\n".join(suggested_tabs))
    
    return suggested_tabs

def update_status_file(is_prod):
    status = "productive" if is_prod == 1 else "unproductive"
    with open("productivity_status.txt", "w") as file:
        file.write(status)


def main():
    global RUN, NO_BREAK, time_program_active_today, time_productive_today, time_unproductive_today, productivity_history
    time.sleep(0.1)
    
    for _ in range(100):
        if RUN == False:
            print("user exit")
            exit()
        
        if NO_BREAK == False:
            print(f"{BREAK_TIME_MINS} min break starts now")
            time.sleep(BREAK_TIME_MINS * 60)
            productivity_history = []
            NO_BREAK = True
        
        start_time = time.time()
        
        is_prod = productivity_check()

        productivity_history.append(is_prod)
        last_min_history = productivity_history[-min(ROLLING_CHECK_NUM, len(productivity_history)):]
        last_min_history_unproductive_cnt = Counter(last_min_history)[0]
        
        print(print_prod(is_prod))
        print(f"last min\t{last_min_history_unproductive_cnt} / {ROLLING_CHECK_NUM}")

        if is_prod == 0 and RUN == True and NO_BREAK == True:
            if last_min_history_unproductive_cnt >= 12:
                stage_3()
            elif last_min_history_unproductive_cnt >= 6:
                stage_2()
            else:
                stage_1()
        
        elapsed_time = time.time() - start_time
        if elapsed_time < TIME_BETWEEN_CHECKS_SECS:
            time.sleep(TIME_BETWEEN_CHECKS_SECS - elapsed_time)
        
        total_time = time.time() - start_time
        time_program_active_today += total_time
        if is_prod == 1:
            time_productive_today += total_time
        elif is_prod == 0:
            time_unproductive_today += total_time

        print(f"total\t\t{time_program_active_today}")
        print(f"prod\t\t{time_productive_today}")
        print(f"un\t\t{time_unproductive_today}")
        print(f"history\t\t{productivity_history}")
        print()

if __name__ == "__main__":
    main()