# 🫧 Bubble Quest Godot

<div align="center">

### A Modular, Physics-Driven 2D Bubble Shooter Built with Godot 4

[![Godot](https://img.shields.io/badge/Godot-4.5%2B-478CBF?style=for-the-badge\&logo=godotengine\&logoColor=white)](https://godotengine.org/)
[![GDScript](https://img.shields.io/badge/GDScript-2.0-478CBF?style=for-the-badge\&logo=godotengine\&logoColor=white)](https://docs.godotengine.org/)
[![Platform](https://img.shields.io/badge/Platform-Desktop%20%7C%20Mobile-blue?style=for-the-badge)]()
[![Resolution](https://img.shields.io/badge/Resolution-720×1280-purple?style=for-the-badge)]()
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

**Bubble Quest** is a physics-based Match-3 bubble shooter featuring a custom hexagonal grid, trajectory prediction, flood-fill cluster detection, and BFS-based floating-cluster removal.

</div>

---

## 🎮 Overview

**Bubble Quest** is an arcade-style 2D puzzle game developed with **Godot Engine 4** and **GDScript**.

The player launches colored bubbles toward an anchored hexagonal grid. When three or more bubbles of the same color become connected, they are removed. Any bubbles that are no longer connected to the ceiling subsequently fall, creating chain reactions and bonus scoring opportunities.

Rather than relying entirely on built-in game mechanics, the project implements several of its core systems from scratch, including:

* Hexagonal grid coordinate mapping
* Six-direction neighbor detection
* Real-time trajectory prediction
* Wall-bounce reflection
* Match-3 cluster detection
* Flood-fill graph traversal
* Ceiling-connectivity analysis
* Floating bubble detection
* Adaptive bubble spawning
* Game-state and scoring management

The project was designed with a **modular component-based architecture** so that gameplay systems can be extended independently.

---

## ✨ Features

### 🧩 Custom Hexagonal Grid

The game uses a staggered-row hexagonal grid rather than a conventional square grid.

Each bubble maintains a logical grid position while being rendered using world-space coordinates. Neighbor relationships are calculated dynamically based on row parity.

This allows the game to efficiently determine the six possible adjacent bubbles around any grid cell.

---

### 🎯 Physics-Based Aiming

The launcher provides a real-time trajectory preview before every shot.

The trajectory system supports:

* Adjustable aiming angles
* Angle restrictions
* Predictive trajectory rendering
* Side-wall collision detection
* Direction reflection after wall collisions
* Mouse and touch-based aiming

The preview is rendered using Godot's `Line2D` system.

---

### 💥 Match-3 Detection

After a bubble is attached to the grid, the game searches for connected bubbles of the same type.

A flood-fill traversal explores neighboring cells and collects all connected bubbles matching the launched bubble's color.

A cluster is removed when:

```text
Cluster Size >= 3
```

This keeps the matching logic independent from the visual bubble entities.

---

### 🫧 Floating Cluster Detection

After a successful match, the game checks whether remaining bubbles are still connected to the ceiling.

The algorithm:

1. Finds bubbles occupying the ceiling row.
2. Adds them to a BFS queue.
3. Traverses all connected bubbles.
4. Marks every reachable bubble as anchored.
5. Searches for bubbles that were not reached.
6. Removes those disconnected bubbles.

This produces the classic **floating-island drop mechanic** found in bubble shooter games.

---

### 🎨 Adaptive Bubble Spawner

The next bubble is generated from colors that are currently present on the board.

Instead of randomly selecting from every possible bubble type, the spawner dynamically considers the active colors remaining in the grid.

This reduces situations where the player receives bubbles that cannot meaningfully interact with the current board.

---

### 📱 Portrait Mobile Layout

The game is designed around a native:

```text
720 × 1280
```

portrait viewport.

Godot's stretch configuration allows the same gameplay scene to adapt to different desktop and mobile display sizes.

---

## 🕹️ Controls

| Action  | Desktop           | Mobile         |
| ------- | ----------------- | -------------- |
| Aim     | Move mouse        | Drag finger    |
| Shoot   | Left mouse button | Release touch  |
| Restart | `R`               | Restart button |

---

# 🧠 Technical Implementation

## 1. Hexagonal Grid Mathematics

The game uses a staggered-row coordinate system.

The vertical distance between rows is calculated using the geometry of an equilateral triangle:

$$
\Delta y = spacing \times \frac{\sqrt{3}}{2}
$$

Therefore:

$$
\frac{\sqrt{3}}{2} \approx 0.866
$$

Horizontal neighbor offsets change depending on whether the current row is even or odd.

Conceptually:

```text
        ●   ●   ●
      ●   ●   ●
        ●   ●   ●
      ●   ●   ●
```

This allows each bubble to have up to six logical neighbors.

---

## 2. Flood-Fill Match Detection

When a bubble becomes attached to the grid, the grid manager performs a flood-fill traversal.

### Process

```text
New Bubble
    │
    ▼
Find Grid Cell
    │
    ▼
Check 6 Neighbors
    │
    ▼
Same Color?
   / \
 Yes  No
  │
  ▼
Continue Search
  │
  ▼
Cluster Size >= 3?
  │
 ┌┴───────┐
Yes       No
 │         │
 ▼         ▼
Pop      Nothing
```

The traversal prevents duplicate visits by maintaining a collection of already-visited cells.

---

## 3. Ceiling Connectivity — BFS

Once matching bubbles are removed, the remaining grid must be evaluated for disconnected clusters.

The ceiling acts as the graph's root.

```text
Ceiling
════════════════════
 ●   ●   ●   ●   ●
   ●   ●   ●
 ●   ●   ●
          ●   ●
```

The algorithm starts from occupied cells in the top row and performs **Breadth-First Search (BFS)**.

Any bubble reachable from the ceiling remains attached.

Any bubble that cannot be reached becomes a floating cluster and is removed.

### Complexity

For `N` occupied grid cells:

```text
Time:  O(N)
Space: O(N)
```

This makes the approach suitable for the relatively small game board while keeping the logic straightforward and deterministic.

---

# 🏗️ Architecture

The project separates gameplay responsibilities across several components.

```text
                    ┌──────────────────┐
                    │   Game Manager   │
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
        ┌──────────┐   ┌───────────┐   ┌──────────┐
        │ Launcher │   │ Bubble    │   │   Grid   │
        │          │   │           │   │ Manager  │
        └────┬─────┘   └───────────┘   └────┬─────┘
             │                              │
             ▼                              ▼
       Trajectory                    Match Detection
       Calculation                         │
             │                             ▼
             ▼                      Flood Fill / BFS
       Bubble Firing                       │
                                           ▼
                                    Cluster Removal
```

### `GameManager`

Responsible for high-level gameplay orchestration:

* Game state
* Shooting flow
* Scoring
* Restarting
* Gameplay transitions

### `BubbleGrid`

Responsible for the logical game board:

* Grid coordinates
* Bubble placement
* Neighbor detection
* Match detection
* Flood-fill traversal
* Ceiling connectivity
* Floating cluster removal

### `Launcher`

Responsible for player interaction:

* Aiming
* Angle restrictions
* Trajectory prediction
* Wall reflections
* Bubble launching

### `Bubble`

Represents an individual bubble entity and handles its movement and collision behavior.

### `BubbleTypes`

Contains shared bubble metadata and type definitions.

---

# 📁 Project Structure

```text
bubble-quest-godot/
│
├── data/
│   └── BubbleTypes.gd
│       └── Bubble colors, types and metadata
│
├── scenes/
│   ├── bubbles/
│   │   └── Bubble.tscn
│   │       └── Reusable bubble scene
│   │
│   └── gameplay/
│       └── Scene_Gameplay.tscn
│           └── Main gameplay scene
│
├── scripts/
│   ├── bubble.gd
│   │   └── Bubble movement and collision
│   │
│   ├── bubble_grid.gd
│   │   └── Grid logic and cluster algorithms
│   │
│   ├── game_manager.gd
│   │   └── Game state and scoring
│   │
│   └── launcher.gd
│       └── Aiming and firing system
│
├── project.godot
└── README.md
```

---

# 🔄 Gameplay Flow

A typical shot follows this pipeline:

```text
Player Aims
     │
     ▼
Trajectory Calculated
     │
     ▼
Bubble Fired
     │
     ▼
Collision With Board
     │
     ▼
Bubble Snapped To Grid
     │
     ▼
Match Detection
     │
     ├───────────────┐
     │               │
   Match           No Match
     │               │
     ▼               ▼
Remove Cluster    Continue
     │
     ▼
Check Ceiling Connectivity
     │
     ▼
Remove Floating Bubbles
     │
     ▼
Update Score
     │
     ▼
Generate Next Bubble
```

---

# 🛠️ Built With

| Technology              | Purpose                       |
| ----------------------- | ----------------------------- |
| **Godot Engine 4.5+**   | Game engine                   |
| **GDScript 2.0**        | Gameplay programming          |
| **Line2D**              | Trajectory visualization      |
| **Area2D / Physics**    | Bubble collision and movement |
| **Hexagonal Grid Math** | Board representation          |
| **Flood Fill**          | Match-3 detection             |
| **BFS**                 | Floating cluster detection    |

---

# 🚀 Getting Started

## Prerequisites

Install:

* **Godot Engine 4.5 or newer**
* Git

The project can run using Godot's standard rendering configurations, including **Compatibility** and **Forward+**, depending on the target environment.

## Installation

Clone the repository:

```bash
git clone https://github.com/mhishaambinsaghir-tech/bubble_quest_godot.git
```

Navigate into the project:

```bash
cd bubble_quest_godot
```

Open the project in Godot:

1. Launch Godot.
2. Select **Import**.
3. Choose `project.godot`.
4. Click **Import & Edit**.
5. Press `F6` or `F5` to run the project.

---

# 📈 Roadmap

The current version focuses primarily on the core gameplay and algorithmic systems.

Future improvements include:

* [ ] Particle-based bubble pop effects
* [ ] Improved visual feedback and animations
* [ ] Sound effects
* [ ] Dynamic background music
* [ ] Level progression system
* [ ] JSON/Resource-based level definitions
* [ ] Next-bubble preview queue
* [ ] Bubble swapping mechanic
* [ ] Combo and chain scoring
* [ ] Game Over state
* [ ] Victory state
* [ ] Persistent high scores
* [ ] Additional bubble types and special abilities
* [ ] Mobile UI refinement

---

# 🎯 What This Project Demonstrates

Bubble Quest is more than a simple game prototype. It demonstrates practical implementation of several computer science and game-development concepts:

**Game Development**

* Scene-based architecture
* Component-oriented design
* Physics and collision handling
* Input management
* Responsive game UI

**Algorithms & Data Structures**

* Graph traversal
* Flood-fill algorithms
* Breadth-First Search
* Coordinate transformations
* Spatial adjacency
* Deterministic state processing

**Software Engineering**

* Modular scripts
* Separation of responsibilities
* Reusable scenes
* Centralized game-state management
* Extensible gameplay systems

---

# 📜 License

This project is licensed under the **MIT License**.

See the [`LICENSE`](LICENSE) file for details.

---

<div align="center">

### 🫧 Built with Godot 4 and GDScript

**Bubble Quest** — Physics, algorithms, and game mechanics working together.

</div>
