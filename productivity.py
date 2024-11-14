import pyautogui
from openai import OpenAI
import pytesseract
pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'
import time
import os
from datetime import datetime
import re
import subprocess


def load_api_key():
    with open('openai_api_key.txt', 'r') as file:
        return file.read()

OPENAI_API_KEY = load_api_key()
TIME_ALLOWED = 15

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

from plyer import notification

def notify_user(is_prod):
    if is_prod == 1:
        text = "Good job being productive"
    elif is_prod == 0:
        text = "GET BACK ON TASK!"
    else:
        text = "ChatGPT failed to determine productivity"

    notification.notify(
        title="Productivity Monitor",
        message=text,
        timeout=5  # Time in seconds for the notification to display
    )

def ask_chatgpt(question):
    response = client.chat.completions.create(
        messages=[
            {
                "role": "user",
                "content": question,
            }
        ],
        model="gpt-4o-mini",
    )
    return response.choices[0].message.content

def remove_phrases(text):
    phrases_to_remove = [
        "Productivity Monitor",
        "ChatGPT failed to determine whether you are productive or not",
        "Good job being productive",
        "GET BACK ON TASK!"
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
    
    question = "This is a screenshot of a user's computer with the following text <start text>" + extracted_text + "<end text> Is the user being productive? Think through this step by step and identify key words that might mean the user is being productive or not. Consider that unintelligible text could be due to errors in recognising text on the users screen so try to ignore it. Your response is being used in an automated script. In order to make the script run properly, the last thing you say must be either 'In conclusion, the user is being productive.' or 'In conclusion the user is being unproductive.'"
    answer = ask_chatgpt(question)
    last_word = answer.split()[-1].lower()
    is_prod = -1
    
    if "productive" in last_word and "un" not in last_word:
        is_prod = 1
    elif "unproductive" in last_word:
        is_prod = 0
    
    end = time.time()
    log_run(start, middle, end, extracted_text, answer, is_prod)
    
    return is_prod
    

def main():
    time.sleep(1)
    
    for _ in range(100):
        start_time = time.time()
        
        is_prod = productivity_check()
        print(print_prod(is_prod))
        notify_user(is_prod)
        
        elapsed_time = time.time() - start_time
        if elapsed_time < TIME_ALLOWED:
            time.sleep(TIME_ALLOWED - elapsed_time)

if __name__ == "__main__":
    main()
