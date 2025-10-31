# App Overview

Medley is a Hims-branded hair loss consultation chat demo built with the Foundation Models framework and SwiftUI to provide an on-device, interactive user experience.

[![Medley app demo](https://img.youtube.com/vi/R9mtnyPthR8/0.jpg)](https://www.youtube.com/watch?v=R9mtnyPthR8)

## Core Architecture

### Data Schema (DataSchema.swift)
* Customizable JSON question structure to easily control the AI consultation flow.
* Each question contains: prompt, question type (single/multiple choice, free text), predefined response buttons, additional info, and next-question rules
* Schema is loaded and indexed in the Foundation Model session.

### Conversation Model (ConversationModel.swift)
* Protocol-based design; currently powered by Foundation Models (Apple's on-device LLM)
* Other implementations (ChatGPT, Claude, etc.) that conform to the protocol can be swapped in
* Streams text responses, handles answer mapping, and determines flow progression
* Generates context-aware responses using the schema and conversation history
* Uses the LLM to map the user's open-ended response with a predefined option from the schema

### Chat ViewModel (ChatViewModel.swift)
* Orchestrates conversation flow: loads schema, manages messages array, tracks currentQuestion, and holds collected data
* For each turn in the conversation: streams the model's response, maps user input to structured data, advances to next question
* Handles three types of streamed messages: opening, acknowledgment + next question, or info summary + question
* Answer Mapping: auto-detects exact matches or uses LLM to categorize open-ended responses into schema options

## UI Flow

### Chat Screen
* Title + Reset button (clears chat and resets data)
* Scrollable message thread (auto-scrolls to newest message)
* Predefined response chips (contextual buttons from current question)
* Text input bar for open-ended responses from the user

### Message Rendering (ChatView.swift)
* User messages are right-aligned with a dark bubble
* Model messages are left-aligned with a light bubble with streaming animation
* Messages auto-scroll to bottom as new content arrives

### Data Collection
* Each user response is validated/mapped to the schema's structured data (StructuredConsult.swift)
* Multiple-choice questions append to arrays; single-choice replace values

### Completion Flow
* When final question is answered, isComplete flag triggers a "Next" button
* Tapping "Next" shows ResultsView with the collected data as pretty-printed JSON

### Key Design Patterns
* Observation: ViewModel uses @Observable for reactive updates
* Fallbacks: If LLM call fails, app falls back to schema text gracefully
* User answers are simple string IDs but the model can return more complex structured data using the Generable protocol