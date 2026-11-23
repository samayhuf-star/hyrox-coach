import Foundation

struct DemoPose {
    let title: String
    let cue: String
}

struct MovementDemo {
    let asset: String
    let poses: [DemoPose]
    var frames: [Int] = [0, 1, 2, 3]
    var interval: Double = 1.0
    var still = false
}

extension Exercise {
    var demo: MovementDemo {
        switch id {
        case "run":
            MovementDemo(asset: "DemoRun", poses: [
                DemoPose(title: "Land softly", cue: "Let your foot land close to underneath your hips."),
                DemoPose(title: "Push off", cue: "Use a relaxed stride. Keep your hands and shoulders loose."),
                DemoPose(title: "Switch sides", cue: "Keep your breathing steady as the other foot lands."),
                DemoPose(title: "Keep it easy", cue: "Stay at a comfortable pace. Walking is always an option.")
            ], interval: 0.8)
        case "march":
            MovementDemo(asset: "DemoMarch", poses: [
                DemoPose(title: "Stand tall", cue: "Place your feet under your hips. Keep a wall nearby if you need balance."),
                DemoPose(title: "Lift one knee", cue: "Lift only as high as feels comfortable. Swing the opposite arm."),
                DemoPose(title: "Set it down", cue: "Lower your foot gently and find your balance."),
                DemoPose(title: "Switch legs", cue: "Lift the other knee. Stay upright rather than leaning back.")
            ])
        case "squat":
            MovementDemo(asset: "DemoSquat", poses: [
                DemoPose(title: "Find your stance", cue: "Stand with feet comfortably apart and your whole foot grounded."),
                DemoPose(title: "Lower slowly", cue: "Bend your knees and hips together. Let your knees follow your toes."),
                DemoPose(title: "Comfortable depth", cue: "Keep your heels down and back neutral. You do not need to go this low."),
                DemoPose(title: "Stand back up", cue: "Push through your feet to stand tall. A stable chair can help.")
            ])
        case "goblet":
            MovementDemo(asset: "DemoGoblet", poses: [
                DemoPose(title: "Hold close", cue: "Hold one light kettlebell securely with both hands at your chest."),
                DemoPose(title: "Lower with control", cue: "Bend your hips and knees while keeping the weight close."),
                DemoPose(title: "Keep feet grounded", cue: "Choose a comfortable depth. Keep your knees tracking your toes."),
                DemoPose(title: "Stand tall", cue: "Push through your feet and rise without tipping the weight forward.")
            ])
        case "carry":
            MovementDemo(asset: "DemoCarry", poses: [
                DemoPose(title: "Set your posture", cue: "Stand tall with one light weight in each hand. The logged load is per hand."),
                DemoPose(title: "Take a small step", cue: "Walk steadily with your arms at your sides and shoulders relaxed."),
                DemoPose(title: "Stay balanced", cue: "Keep your torso upright. Avoid leaning to either side."),
                DemoPose(title: "Continue walking", cue: "Alternate comfortable steps along a clear, safe path.")
            ])
        case "lunge":
            MovementDemo(asset: "DemoLunge", poses: [
                DemoPose(title: "Stand ready", cue: "Start with feet hip-width apart. Use stable support if needed."),
                DemoPose(title: "Step backward", cue: "Move one foot back. Keep the front foot flat on the floor."),
                DemoPose(title: "Lower gently", cue: "Bend both knees within a comfortable range. The rear knee need not touch down."),
                DemoPose(title: "Return to standing", cue: "Push through the front foot. Alternate legs; each lunge is one rep.")
            ])
        case "sandbag":
            MovementDemo(asset: "DemoSandbag", poses: [
                DemoPose(title: "Secure the bag", cue: "Support a light bag across your upper shoulders with both hands. Keep pressure off your neck."),
                DemoPose(title: "Step forward", cue: "Take a comfortable forward step, keeping the bag stable."),
                DemoPose(title: "Lower with control", cue: "Bend both knees, keep your torso upright and use a comfortable depth."),
                DemoPose(title: "Rise and reset", cue: "Stand with control. Alternate legs without rushing.")
            ])
        case "row":
            MovementDemo(asset: "DemoRow", poses: [
                DemoPose(title: "Set up the catch", cue: "Secure your feet. Bend your knees, straighten your arms and keep your back neutral."),
                DemoPose(title: "Drive with legs", cue: "Push through your feet first. Keep your arms straight as your legs extend."),
                DemoPose(title: "Finish the pull", cue: "Lean back slightly, then draw the handle toward your lower ribs."),
                DemoPose(title: "Return smoothly", cue: "Hands away first, then hinge forward, then bend your knees.")
            ])
        case "ski":
            MovementDemo(asset: "DemoSki", poses: [
                DemoPose(title: "Start tall", cue: "Hold both handles above you with soft knees and elbows."),
                DemoPose(title: "Pull and hinge", cue: "Pull the handles down as you hinge at the hips. Keep your back neutral."),
                DemoPose(title: "Finish near thighs", cue: "Let your hands pass your hips. Avoid rounding your back or squatting deeply."),
                DemoPose(title: "Return upright", cue: "Stand smoothly as your arms return. Let the cords retract under control.")
            ])
        case "wallball":
            MovementDemo(asset: "DemoWallball", poses: [
                DemoPose(title: "Choose a safe target", cue: "Use a light medicine ball and a clear wall target. Hold the ball at your chest."),
                DemoPose(title: "Squat with control", cue: "Keep your heels grounded and choose a comfortable depth."),
                DemoPose(title: "Stand and throw", cue: "Drive upward and release the ball toward your target. Do not chase a missed catch."),
                DemoPose(title: "Catch softly", cue: "Receive the ball with both hands and soft knees. Reset before repeating.")
            ])
        case "sled":
            MovementDemo(asset: "DemoSled", poses: [
                DemoPose(title: "Set up safely", cue: "Choose a light sled and clear track. Grip both poles and keep your back neutral."),
                DemoPose(title: "Push with legs", cue: "Lean from your ankles and take a short step. Brace gently."),
                DemoPose(title: "Keep steps short", cue: "Keep your hands secure and avoid rounding your back."),
                DemoPose(title: "Alternate steadily", cue: "Continue short, controlled steps. Ask a coach to check your setup if this is new.")
            ])
        case "sledpull":
            // Uses the sled photo as a still until dedicated pull artwork is added.
            MovementDemo(asset: "DemoSled", poses: [
                DemoPose(title: "Set up safely", cue: "Choose a light sled and a clear lane. Lay the rope out straight so it can’t wrap around your feet."),
                DemoPose(title: "Sit back", cue: "Bend your knees, keep your back neutral and hold the rope with straight arms."),
                DemoPose(title: "Pull hand over hand", cue: "Lean back gently and draw the rope toward your hips with steady pulls."),
                DemoPose(title: "Reset and repeat", cue: "Let the rope fall behind or beside you, never under your feet. Rest whenever you need to.")
            ], frames: [0, 0, 0, 0], interval: 2.0, still: true)
        case "burpee":
            // Uses the squat photo as a still until dedicated burpee artwork is added.
            MovementDemo(asset: "DemoSquat", poses: [
                DemoPose(title: "Hands down", cue: "Place both hands on the floor in front of your feet."),
                DemoPose(title: "Chest to the floor", cue: "Step or hop your feet back and lower your chest. Stepping is always fine."),
                DemoPose(title: "Stand up", cue: "Step or hop your feet forward and stand tall."),
                DemoPose(title: "Jump forward", cue: "Take off and land on both feet together, softly. Keep jumps small and repeatable.")
            ], frames: [0, 0, 0, 0], interval: 2.0, still: true)
        case "rest":
            MovementDemo(asset: "DemoWalk", poses: [
                DemoPose(title: "Stand comfortably", cue: "Let your arms hang loosely. Sit or walk slowly if that feels better."),
                DemoPose(title: "Relax your shoulders", cue: "Release tension in your hands, jaw and shoulders."),
                DemoPose(title: "Breathe naturally", cue: "Let your breathing settle. There is no need to force a breath hold."),
                DemoPose(title: "Take the time you need", cue: "Pause the workout timer if you need more rest.")
            ], frames: [0, 0, 0, 0], interval: 2.0, still: true)
        default:
            MovementDemo(asset: "DemoWalk", poses: [
                DemoPose(title: "Stand comfortably", cue: "Keep your head up, shoulders relaxed and arms loose."),
                DemoPose(title: "Take an easy step", cue: "Use a comfortable stride, allowing your arms to swing naturally."),
                DemoPose(title: "Move with control", cue: "Keep your steps steady and your breathing natural."),
                DemoPose(title: "Alternate steps", cue: id == "cooldown" ? "Slow to an easy pace and finish feeling settled." : "Choose a pace where you can still talk comfortably.")
            ], interval: id == "cooldown" ? 1.4 : 1.0)
        }
    }
}
