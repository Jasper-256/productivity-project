import pyautogui
from openai import OpenAI
import pytesseract
import time
import os
from datetime import datetime
import re
import subprocess
from collections import Counter

def load_api_key():
    with open('openai_api_key.txt', 'r') as file:
        return file.read()

OPENAI_API_KEY = load_api_key()
TIME_ALLOWED = 10
TITLE = "Productivity Monitor"

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

def notify_user(is_prod):
    if is_prod != 0: return
    
    text = "ChatGPT failed to determine whether you are productive or not"
    if is_prod == 1:
        text = "Good job being productive"
    elif is_prod == 0:
        text = "GET BACK ON TASK!"
    
    script = f"""
    display dialog "{text}" ¬
    with title "{TITLE}" ¬
    with icon caution ¬""" + """
    buttons {"OK", "Ignore"}
    """
    subprocess.Popen(["osascript", "-e", script], shell=False)

def very_unproductive_notification():
    script = f"""
    display dialog "THIS IS YOUR FINAL WARNING, GET BACK ON TASK!!!!!!!!" ¬
    with title "{TITLE}" ¬
    with icon caution ¬""" + """
    buttons {"OK"}
    """
    subprocess.Popen(["osascript", "-e", script], shell=False)

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
        "Productivity Monitor",
        "Good job being productive",
        "GET BACK ON TASK!",
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

def main():
    global time_program_active_today, time_productive_today, time_unproductive_today, productivity_history
    time.sleep(0.1)
    
    for _ in range(100):
        start_time = time.time()
        
        is_prod = productivity_check()

        productivity_history.append(is_prod)
        last_min_history_unproductive_cnt = -1
        if len(productivity_history) >= 6:
            last_min_history = productivity_history[-6:]
            last_min_history_counter = Counter(last_min_history)
            last_min_history_unproductive_cnt = last_min_history_counter[0]
        
        print(print_prod(is_prod))
        print(f"last min\t{last_min_history_unproductive_cnt} / 6")

        notify_user(is_prod)
        if last_min_history_unproductive_cnt > 3 and is_prod == 0:
            very_unproductive_notification()
        
        elapsed_time = time.time() - start_time
        if elapsed_time < TIME_ALLOWED:
            time.sleep(TIME_ALLOWED - elapsed_time)
        
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
