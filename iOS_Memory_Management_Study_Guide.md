# 🐾 iOS Memory Management Study Guide
### DesignerAna Codebase Edition — Wednesday Morning Session · June 17, 2026

Good morning, Birdie! This Wednesday is blocked for interview prep, and you've got a perfect real-world codebase to study from. Here's your guide covering every memory management topic worth knowing, anchored to actual code you've written.

---

## 1. ARC Basics — How Scenes Are Released

**The concept:** ARC (Automatic Reference Counting) deallocates an object when its retain count drops to zero — when nothing holds a strong reference to it.

**In DesignerAna:** `SKView` (inside `GameViewController`) holds the **only strong reference** to the currently-presented scene. When you call `skView.presentScene(nextScene)`, the view drops its reference to the old scene. If the old scene has no other strong references keeping it alive, ARC immediately deallocates it and all its children.

This is why there's no explicit cleanup code between scene transitions — ARC handles it. The implication: anything you allocate inside a scene (nodes, timers, closures) lives exactly as long as the scene itself, unless you create an accidental extra reference somewhere.

**Interview phrasing:** *"In SpriteKit, the SKView holds a single strong reference to the active scene. Calling presentScene() releases that reference, which triggers ARC deallocation of the old scene's entire object graph — no manual cleanup required."*

---

## 2. `[weak self]` in Closures — Why It Matters

**The problem:** A closure captures the objects it references, creating strong references. If a node (`self`) schedules an SKAction closure, and that closure strongly captures `self`, you have a cycle: the node holds the action, the action holds the closure, the closure holds the node. Neither can be freed.

**In DesignerAna:** Both `MinigameNode.swift` and `BossMinigameNode.swift` use `[weak self]` throughout their SKAction callbacks:

```swift
// MinigameNode.swift line 362
let charge = SKAction.run { [weak self] in
    self?.chargeMonster()
}

// BossMinigameNode.swift line 148
run(.wait(forDuration: 2.0)) { [weak self] in self?.runAttackLoop() }
```

The `[weak self]` capture list makes the closure's reference to `self` weak — it doesn't increment the retain count. If the node is removed from the scene while the action is pending, `self` becomes `nil` and the closure safely no-ops via optional chaining (`self?.method()`).

**Without `[weak self]`:** the node would stay in memory until the SKAction finished executing, even after it's been removed from the scene tree. In a boss fight with a long pending action sequence, that's a meaningful leak.

---

## 3. The One Real Bug — `BossMinigameNode.swift` Line 485

This is the most interview-worthy code in the project. Look at it carefully:

```swift
// BossMinigameNode.swift lines 484–487
self.openVulnerabilityWindow(duration: 3.0) { [weak self] in
    self?.boss.run(.move(to: self!.bossAnchor, duration: 0.4)) {  // ← LINE 485
        self?.scheduleNextAttack()
    }
}
```

**What's wrong:** The outer closure correctly captures `self` weakly. But on line 485, `self!` force-unwraps the optional — if `self` has been deallocated by the time this closure runs, this crashes with `Fatal error: Unexpectedly found nil while unwrapping an Optional value`.

The pattern `[weak self]` + `self!` is self-defeating. You opted into safety on the capture list, then threw it away with the force-unwrap.

**How to fix it:**

```swift
self.openVulnerabilityWindow(duration: 3.0) { [weak self] in
    guard let self = self else { return }
    self.boss.run(.move(to: self.bossAnchor, duration: 0.4)) { [weak self] in
        self?.scheduleNextAttack()
    }
}
```

The `guard let self = self` pattern (Swift 5.3+) re-binds `self` as a strong reference for the duration of that closure's execution only — so you get safety (no crash if `self` is nil) and convenience (no `?` on every property access).

**Why interviewers love this:** It tests whether you understand the whole picture — not just "use weak self" as a cargo-cult rule, but *why* it works and what breaks when you mix it with force-unwrapping.

---

## 4. `private weak var sceneRef: SKScene?`

Both minigame nodes declare this:

```swift
// MinigameNode.swift line 134
private weak var sceneRef: SKScene?

// BossMinigameNode.swift line 151  
private weak var sceneRef: SKScene?
```

**Why it must be weak:** `MinigameNode` is added as a child node of `BackRoomScene` (an `SKScene`). The scene already holds a strong reference to the node via the SpriteKit node tree. If the node also held a strong reference back to the scene, you'd have a reference cycle: scene → node → scene. Neither could be freed.

By marking `sceneRef` as `weak`, the node can reach back up to the scene (e.g., to call scene-level methods in `MinigameNode.swift` line 559: `guard let scene = sceneRef else { return }`) without creating a cycle.

**The pattern name:** This is the classic **delegate/parent back-reference pattern** — child holds a weak reference to its parent/owner.

---

## 5. `SoundManager` AVAudioPlayer Pool

```swift
// SoundManager.swift
private var players: [String: [AVAudioPlayer]] = [:]

func play(_ filename: String) {
    // ...
    // Prune any instances that have finished playing so the pool
    // doesn't grow unbounded over a long session.
    var list = (players[filename] ?? []).filter { $0.isPlaying }
    list.append(player)
    players[filename] = list
}
```

**The problem it solves:** `AVAudioPlayer` instances must stay alive while playing — if you let ARC deallocate a player mid-playback, it stops. So the dictionary holds strong references to keep players alive. But if you only ever append and never remove, the dictionary grows forever over a long session.

**The solution:** Every time a new sound plays, the existing list is filtered to `isPlaying == true` — finished players are silently pruned. You never have more live entries than currently-playing sounds for that filename.

**The stop path:**
```swift
func stop(_ filename: String) {
    list.forEach { $0.stop() }
    players[filename] = nil   // ← drops all strong refs; ARC deallocates
}
```

Setting the dictionary entry to `nil` drops the array, which drops all the `AVAudioPlayer` strong references, which triggers ARC deallocation. Clean.

**Interview angle:** This is a real-world example of a manually managed object pool where you have to balance "keep alive while needed" against "release when done" — a common pattern in audio, networking, and animation engines.

---

## 6. Interview Talking Points

### strong / weak / unowned

| | strong | weak | unowned |
|---|---|---|---|
| Retain count | +1 | 0 | 0 |
| Value when referent is deallocated | still valid | becomes `nil` | crash (dangling pointer) |
| Optional? | no | yes (`T?`) | no |
| Use when | default ownership | back-references, delegates, closure captures where object may be gone | guaranteed same lifetime (e.g. closure in a view that owns the view controller) |

**When to use `unowned` vs `weak`:** If you're *certain* the captured object will outlive the closure, `unowned` avoids the optional unwrapping overhead. But `weak` is the safer default — it fails gracefully while `unowned` crashes.

### What a retain cycle looks like

```
Object A  --strong-->  Object B
Object B  --strong-->  Object A
```
Neither reaches zero retain count; neither is freed. In iOS, common sources: delegate properties (should be `weak var`), closures in long-lived objects, `NotificationCenter` observers not unregistered.

### Instruments Leaks Tool

- Open Instruments → choose **Leaks** template
- Run your app, exercise the suspected leak path
- Look for red "L" markers in the timeline — each marks a leaked allocation
- The **Call Tree** panel shows what allocated the leaked object
- **Useful companion:** Memory Graph Debugger in Xcode (Debug → Memory Graph) — shows the live object graph with reference annotations, making cycles visible as loops in the graph

---

## ⏰ Suggested 2-Hour Study Plan

**:00–:20** — Read through this guide once, with the actual Swift files open in Xcode side-by-side. Find each code snippet in context.

**:20–:40** — `BossMinigameNode.swift` deep dive. Read the full `executeDropAttack()` function (around line 465) and trace the closure chain. Draw the retain graph on paper: what captures what, where `weak` breaks potential cycles.

**:40–:60** — `SoundManager.swift` end-to-end. Read `play()`, `stop()`, `stopAll()`. Think about what happens to the `AVAudioPlayer` instances at each step.

**:60–:75** — Say your answers out loud. Pick two topics from section 6 and explain them as if to an interviewer. Hearing yourself say it is different from reading it.

**:75–:90** — Write the fix for line 485 from scratch, without looking at the guide. Then check your answer above.

**:90–:110** — Run the app in Xcode with the Memory Graph Debugger (Debug → Memory Graph while running). Poke around a minigame, then examine the live object graph. Getting hands-on with the tool is worth more than 20 more minutes of reading.

**:110–:120** — Rest. You've got this. 🐱

---

*You built a SpriteKit game with proper weak references, a pruning audio pool, and a mostly-correct memory model. That's real iOS engineering experience — way more interesting to talk about in an interview than textbook examples.*
