# Productivity Monitor

## About

**Productivity Monitor** is a macOS productivity companion that automatically checks what you're working on and helps keep you on task. Every few seconds it:

1. **Captures your screen** with PyAutoGUI  
2. **Extracts visible text** using Tesseract OCR  
3. **Classifies your activity** via the OpenAI API as "productive" or "unproductive"  
4. **Logs your time** and maintains daily productivity stats  
5. **Notifies you or pops up reminders** when you've spent too long off-task  
6. **Suggests distracting browser tabs** to close  
7. **Provides a Swift-based UI** to show your current status and break prompts  

Built with Python (PyAutoGUI, pytesseract, OpenAI SDK) and a lightweight Swift frontend, this tool helps you stay focused and take breaks at the right time.

## Setup Instructions

1. Create the file `openai_api_key.txt` and put your OpenAI key there.
2. Install the required python packages by running these commands. You might need to use `pip3`, check your python versions or install python 3 if you don't have it.
```
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```
3. For macOS, use homebrew to install tesseract `brew install tesseract` (install homebrew if you do not have it). For windows, look up tesseract ocr and install it.
4. Run the python file by typing `python3 productivity.py` into your terminal.
