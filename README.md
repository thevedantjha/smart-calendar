# Smart Calendar
AI Assisted Calendar Manager App for iPhone

## Project Overview
**SmartCalendar** is an intelligent, privacy-first iOS assistant that reimagines schedule management by bringing the power of Large Language Models (LLMs) directly to the edge. Rather than relying on cloud servers, SmartCalendar runs the **Google Gemma** model locally on the device, allowing users to interact with their schedule using natural language and manage events through advanced computer vision.

#### The app allows users to:
- **Chat with their Calendar:** Ask natural language questions like *"What am I doing next Friday?"* or *"Create an event for a game night tomorrow 9pm."*
- **Scan Physical Flyers:** Use the camera to snap a photo of an event flyer. The app extracts the text, interprets the details (Title, Date, Location) using AI, and creates a calendar event automatically.

## Functionality
SmartCalendar combines a user-friendly SwiftUI interface with a sophisticated backend logic layer that orchestrates the interaction between the iOS ecosystem and the local AI model.

### Key Features
- **Chat with Your Calendar:** Users can query their schedule naturally (e.g., *"What am I doing tomorrow?"*) or issue commands (e.g., *"Clear Thursday's schedule"*). The app understands context and intent without rigid command structures.

- **Physical Flyer Scanner:** Users can snap a photo of a physical event flyer. The app uses Optical Character Recognition (OCR) to read the text and the LLM to intelligently parse messy details, extracting the Title, Date, and Location to create a calendar event automatically.

- **Offline Capability:** Thanks to the local model, the app remains fully functional even in "Airplane Mode."

## Installation
Follow these steps to set up the environment, configure the model, and run the application on your iOS device or simulator.

### Phase 1: Environment Setup
Before interacting with the project files, ensure your development environment is ready.

1. **Install CocoaPods** CocoaPods is a dependency manager required for this project.

 - Open your **Terminal**.

 - Run the following command:

    - ```sudo gem install cocoapods```

> Note: You may be asked to enter your system password. Characters will not appear on the screen as you type them; simply type the password and press `Enter`.

### Phase 2: Project Initialization
2. **Download the Repository**

Clone the repository using `git` or download the ZIP file and unzip it to your desired location.

3. **Install Dependencies**

In your Terminal, navigate to the project folder you just downloaded:

```cd path/to/downloaded-repo```

Run the installer:

`pod install`

4. **Open the Project**

- Once the installation is complete, open the project folder in Finder.

    - **Crucial**: Locate the file ending in `.xcworkspace` (white icon) and open it.

>⚠️ Do not open the `.xcodeproj` (blue icon) file, or the dependencies will not load correctly.

### Phase 3: Model Configuration
The app requires the Gemma-3n model file to function.

5. **Prepare the Model**

- **Download:** Download the gemma 3n model from the provided source link. (https://huggingface.co/google/gemma-3n-E2B-it-litert-preview/tree/main)

- **Rename:** Rename the downloaded file strictly to:
    - `gemma-3n.task`

- **Import to Xcode:**

    - In Xcode, locate the `SmartCalendar/` folder in the project navigator (left sidebar).

    - Drag and drop the `gemma-3n.task` file directly into this folder.

- **Set Target Membership:**

    - When the file options pop-up appears, look for the **"Add to targets"** section.

    - Ensure the checkbox next to the **SmartCalendar** app target is **checked**.

    - Click **Finish**.

### Phase 4: Build and Run
6. **Configure Signing**

- Click on the project name (the very top item) in the left sidebar.

- Select the main **Target** in the center editor.

- Go to the **"Signing & Capabilities"** tab.

- Under the **Team** dropdown, select your personal team (usually your Apple ID).

7. **Run the Application**

- Connect your iPhone via cable or select a Simulator. (May need additional installation, do as system message says if so.)

- Click the **Play** button (▶️) in the top-left corner of Xcode to build and run.

8. **Trust Developer (Physical Device Only)**

- If you are running on a physical iPhone and see a popup regarding an "Untrusted Developer":

    - On your iPhone, go to **Settings** > **General**.

    - Scroll down to **VPN & Device Management** (or "Profiles & Device Management").

    - Tap the Developer App profile associated with your email.

    - Tap **Trust**.

### Phase 5: Using the App
9. **Grant Permissions**

- When the app opens, a prompt will appear asking for access to your Calendar. Tap **Allow Full Access**.

10. **Wait for Initialization**

 - Look at the **top right corner** of the app screen.

- You will see a loading indicator. Wait for this to turn **Green**.

    > This may take a few seconds as the Gemma model loads into memory.

- Once green, the app is ready to use!

### Troubleshooting
If something goes wrong that's not covered in these instructions, please ask a large language model such as ChatGPT, Gemini, Claude, Grok, etc.
