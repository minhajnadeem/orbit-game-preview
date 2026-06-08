# Project Requirements Document (PRD)

## Real-Time Trivia Buzzer Game (Web-Only & Firestore Sourced)

This document outlines the requirements, specifications, and architecture for the Trivia Buzzer game. The project is designed as a single web application supporting four key routes/views:
1. **Landing Page** (`/`): The root route of the application. Allows users to choose their role (Admin, Host, or Player).
2. **Web Host Screen** (`/host`): Displayed on the Host's screen or tablet. It manages the active questions, leaderboard, and is used to register player names and control the game.
3. **Player Web App** (`/player` or `/player?slot=1|2|3|4`): Pre-loaded on player tablets. If accessed without a slot parameter, players can register their name or select an active slot. If accessed with a slot, it connects directly.
4. **Question Management Panel** (`/admin`): Used by the Host to manage the question pool (add, edit, list, and delete questions stored in Firestore).

---

## 1. Product Overview

The Trivia Buzzer Game is a real-time web-based multiplayer trivia application designed for a game-show format.

- **Pre-Configured Player Devices**: Player tablets are pre-loaded with URL links corresponding to their slots (1, 2, 3, or 4).
- **Lobby Setup by Host**: The host registers the players' names directly on the Host device. Players do not need to sign up or select slots on their own devices.
- **Firestore Synchronization**: Firestore acts as the real-time coordinator, propagating questions, buzzer locks, scores, and active states between all devices.

---

## 2. Core Game Loop & User Flow

```mermaid
sequenceDiagram
    autonumber
    participant Admin as Admin Panel (/admin)
    participant Host as Web Host (/host)
    participant Firestore as Firestore Database
    participant Players as Player Tablets (/player?slot=X)

    Note over Admin, Firestore: Question Prep (Prior to Game)
    Admin->>Firestore: Add/Update Questions & Options

    Note over Host, Players: Game Setup / Lobby
    Players->>Firestore: Listen to Room State (Assigned Slot X)
    Host->>Host: Enter names for Players 1-4
    Host->>Firestore: Write Player Names & Init Game
    Firestore->>Players: Display names (e.g. "Alice (Player 1)") & Show Waiting State

    Note over Host, Players: The Buzz Phase
    Host->>Firestore: Load Question & Enable Buzzer
    Firestore->>Players: Enable buzzer buttons on all tablets
    Players->>Firestore: Player X taps Buzzer (First)
    Firestore->>Host: Lock Buzzer / Set Active Player = Player X
    Firestore->>Players: Lock buzzers; Show options *only* to Player X
    Host->>Firestore: Reveal Answer Options on Host Screen

    Note over Host, Players: The Answer Phase
    Players->>Firestore: Player X selects option
    Firestore->>Host: Submit Answer
    alt Answer is Correct
        Host->>Host: Play Success SFX / Confetti / Player X Score +10
    else Answer is Incorrect
        Host->>Host: Play Failure SFX / Red Flash / Player X Score -10
    end
    Firestore->>Players: Show feedback / waiting screen
    Note over Host, Players: Host can Reset Buzz to let players try again, or click "Next Question" to proceed
    Host->>Firestore: Reset Buzz (Optional) or Load Next Question
```

---

## 3. Feature Requirements

### 3.1 Question Management Panel (`/admin`)
An administrative interface to manage the database of trivia questions.
- **Add/Edit Question Form**:
  - Input field for the question text.
  - 4 text inputs for options (Option A, Option B, Option C, Option D).
  - Radio button selector to specify the Correct Option.
- **Questions Directory**:
  - A scrollable list of all questions in Firestore.
  - **Edit/Delete Controls**: Tap to load a question's data back into the form or delete it from Firestore.

### 3.2 Web Host Application (The Game Board `/host`)
The main dashboard for running the game, typically displayed on the Host's screen or tablet.
- **Player Registry (Lobby)**:
  - Form to enter the names of up to 4 players corresponding to Slot 1, Slot 2, Slot 3, and Slot 4.
  - Button to initialize/start the game session.
- **Question Board**:
  - Automatically fetches the active question list from Firestore.
  - Displays the active question.
  - Hides options until a player buzzes in to focus attention on the question itself.
- **Option Reveal & Results**:
  - Reveals the options (A, B, C, D) once a player successfully buzzes in.
  - Visually indicates the answer selected by the active player.
  - Highlights the correct answer and updates player scores.
- **Host Controls**:
  - Navigation buttons (`Next Question`, `Previous Question`).
  - Session control (`Reset Scores`, `Clear Room`).
- **Leaderboard**:
  - Displays players and their cumulative scores. Updates instantly upon answer validation.

### 3.3 Player Web App (Player Tablets `/player` or `/player?slot=1|2|3|4`)
A highly responsive, mobile-friendly interface preloaded on player tablets or accessed via the Landing Page.
- **Onboarding & Slot Association**:
  - **Direct URL (Pre-Configured)**: Opening `/player?slot=1|2|3|4` directly bypasses setup and binds the device to that slot.
  - **Dynamic Tablet Onboarding**: Navigating to `/player` (without a slot parameter) allows the device to be configured dynamically:
    - *Dashboard Players Menu*: If the Host has already registered player names, they are displayed as a menu of slots. An available player slot can be tapped to claim it.
    - *One-by-One Name Entry*: If no players are configured yet (or if there are empty slots), players can type in their name. The first player to register is assigned Slot 1 (Player 1), the second Slot 2 (Player 2), etc.
    - *URL Synchronization*: Once a slot is selected/assigned, the browser URL is dynamically updated to `/player?slot=X` to persist connection across refreshes.
- **Buzzer Screen**:
  - A giant, responsive, circular buzzer button.
  - **Dynamic States**:
    - *Waiting (Grey)*: Before the question is ready, or after another player has buzzed. Displays player name: "Waiting... (Player name)"
    - *Ready to Buzz (Pulsing Amber/Red)*: Activated as soon as the Host shows a question.
    - *Buzzed Success (Glowing Green)*: Confirms this player was the quickest.
    - *Buzzed Locked Out (Dimmed Red)*: Notifies the player they missed the buzz.
- **Answering Interface**:
  - Displayed only on the device of the player who successfully buzzed in.
  - Displays 4 large tap target buttons corresponding to options A, B, C, and D.
  - Tapping submits the option to Firestore.
  - Displays result feedback ("Correct!" or "Incorrect!").
- **Web Polish**:
  - HTML5 Vibration API for buzzer feedback.
  - Gestures and double-tap zoom disabled.

---

## 4. Scoring Mechanics

- **Capacity**: Up to 4 players.
- **Buzzer Rule**: Only the first player's buzz registered in the database is granted the answering window.
- **Scoring Scale**:
  - **Correct Answer**: `+10 points`
  - **Incorrect Answer**: `-10 points`
- **Session Persistence**: Scores are stored in the database for the duration of the lobby session.

---

## 5. Technical Architecture & Database Schemas

Both state management and the question pool will be housed in **Google Cloud Firestore**, keeping database dependencies unified.

```
+-------------------------------------------------------------------------------+
|                             Single Web Application                            |
|                                                                               |
|  +--------------------+    +-----------------------------+    +-------------+  |
|  |   /host Route      |    |  /player Route              |    | /admin Route|  |
|  |  (Web Host Screen) |    |  (Slot Param: 1, 2, 3, or 4)|    | (Admin Panel)|  |
|  +--------------------+    +-----------------------------+    +-------------+  |
+-------------------------------------------------------------------------------+
           ^                               ^                           ^
           |                               |                           |
           v                               v                           v
+-------------------------------------------------------------------------------+
|                            Google Cloud Firestore                             |
+-------------------------------------------------------------------------------+
```

### 5.1 Firestore Collection: `questions`
Contains the list of questions entered by the admin.
```json
// Collection: /questions/{documentId}
{
  "question": "Which programming language is Flutter built upon?",
  "options": [
    "Java",
    "Kotlin",
    "Dart",
    "Swift"
  ],
  "correctAnswerIndex": 2,
  "createdAt": "Timestamp"
}
```

### 5.2 Firestore Collection: `sessions`
Synchronizes the active game state, buzzer events, and player scores in real-time.
```json
// Document: /sessions/active_game
{
  "room_state": {
    "status": "lobby|question_displayed|player_buzzed|answered",
    "currentQuestionIndex": 0,
    "activePlayerSlot": 2, // 1-4
    "buzzLocked": true,
    "timestamp": "Timestamp"
  },
  "players": {
    "player_1": { "name": "Alice", "score": 20, "connected": true },
    "player_2": { "name": "Bob", "score": -10, "connected": true },
    "player_3": { "name": "Charlie", "score": 0, "connected": false },
    "player_4": { "name": "David", "score": 10, "connected": true }
  }
}
```

---

## 6. UI/UX Design & Aesthetics

The design uses a dark-mode cyberpunk theme with sharp, glow-accented layouts.

### 6.1 Theme Variables
- **Backgrounds**: Slate Dark (`#0A0E17` / `#161B22`)
- **Containers**: Translucent Card (`#1E2530` with `backdrop-filter: blur(10px)`)
- **Buzzer Accent**: Neon Amber/Yellow (`#FF9F0A`)
- **Correct State**: Neon Emerald (`#30D158`)
- **Incorrect/Lockout State**: Coral Red (`#FF453A`)

### 6.2 View Layouts
- **Host View**: Optimized for 16:9 large displays or Host tablets. Features player name text input forms during lobby setup.
- **Player View**: Vertical, single-screen layout with large tap buttons (minimum `60px` height) optimized for tablets/phones. Reads the slot index from the query parameter.
- **Admin View**: Clean dashboard showing the Form on one side and the list of existing questions in a scrollable list.
