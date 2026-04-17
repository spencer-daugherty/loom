import Foundation

let LocalDiagnosticInsightsDatabaseJSON = """
{
  "coreCandidates": [
    {
      "id": "RC001",
      "layer": "core",
      "archetype": "Flooded Juggler",
      "subarchetype": "Stalled Under Spread",
      "intensity": "high",
      "tags": ["overload", "start-friction", "goal-diffusion", "low-structure", "control-seeking"],
      "triggerConditions": {
        "stressIn": ["competing_priorities"],
        "breaksFirstIn": ["dont_start"],
        "planningStyleIn": ["react_urgent", "simple_todo", "depends_day"],
        "areasCountMin": 4,
        "firstChangeIn": ["feel_control", "know_what_matters"]
      },
      "disqualifiers": {
        "planningStyleIn": ["plan_follow_through"]
      },
      "rootCause": "Your attention splits before you even start. Nothing feels clearly first, so starting one thing can feel like ignoring other important things.",
      "nextDirection": "Loom will narrow your day to one main result first. That gives you a short order to follow, so starting does not feel like giving up everything else.",
      "rationale": "Fits overload-driven start friction where breadth and weak ordering make starting feel costly."
    },
    {
      "id": "RC002",
      "layer": "core",
      "archetype": "Flooded Juggler",
      "subarchetype": "Fading Handoff",
      "intensity": "high",
      "tags": ["overload", "momentum-loss", "reset-cost", "attention-switching"],
      "triggerConditions": {
        "stressIn": ["competing_priorities"],
        "breaksFirstIn": ["lose_momentum"]
      },
      "disqualifiers": null,
      "rootCause": "Every new demand pulls you away from the task you are doing. Early progress keeps getting reset before it can build.",
      "nextDirection": "Loom will tie the day to one main result and a short order under it. That makes it easier to come back without restarting the whole plan.",
      "rationale": "Fits overload patterns where momentum dies because other demands keep taking the lead."
    },
    {
      "id": "RC003",
      "layer": "core",
      "archetype": "Flooded Juggler",
      "subarchetype": "Pulled Sideways",
      "intensity": "high",
      "tags": ["overload", "distraction", "fragmentation", "weak-priority-center"],
      "triggerConditions": {
        "stressIn": ["competing_priorities"],
        "breaksFirstIn": ["get_distracted"]
      },
      "disqualifiers": null,
      "rootCause": "No clear order holds your day in place. Things around you keep taking over before the work gets real focus.",
      "nextDirection": "Loom will put one result at the center and filter what belongs today. That cuts down distractions in the moment.",
      "rationale": "Fits overload plus distraction where attention gets captured because nothing is clearly central."
    },
    {
      "id": "RC004",
      "layer": "core",
      "archetype": "Flooded Juggler",
      "subarchetype": "Looping Chooser",
      "intensity": "high",
      "tags": ["overload", "overthinking", "comparison-loop", "priority-conflict"],
      "triggerConditions": {
        "stressIn": ["competing_priorities"],
        "breaksFirstIn": ["overthink"]
      },
      "disqualifiers": null,
      "rootCause": "Because many things feel important, you keep comparing instead of acting. The choice itself starts to feel like the work.",
      "nextDirection": "Loom will set one clear result before the day fills up. That gives you a simple path instead of making the same decision over and over.",
      "rationale": "Fits overload plus cognitive looping where competing importance blocks action."
    },
    {
      "id": "RC005",
      "layer": "core",
      "archetype": "Flooded Juggler",
      "subarchetype": "Open-Loop Finisher",
      "intensity": "high",
      "tags": ["overload", "finish-weakness", "open-loops", "spread-progress"],
      "triggerConditions": {
        "stressIn": ["competing_priorities"],
        "breaksFirstIn": ["dont_finish"]
      },
      "disqualifiers": null,
      "rootCause": "You keep starting new things before earlier ones are finished. Progress spreads out, but very little gets completed.",
      "nextDirection": "Loom will shorten your active list to one result and a few ordered actions. That gives your day a clear finish line.",
      "rationale": "Fits overload plus weak closure where the user touches many things but lands few."
    },
    {
      "id": "RC006",
      "layer": "core",
      "archetype": "Backlog Carrier",
      "subarchetype": "Frozen by Mess",
      "intensity": "high",
      "tags": ["behind", "disorganization", "start-friction", "shape-confusion"],
      "triggerConditions": {
        "stressIn": ["behind_disorganized"],
        "breaksFirstIn": ["dont_start"]
      },
      "disqualifiers": null,
      "rootCause": "The pile feels bigger than the next step. When everything is messy, starting feels like guessing.",
      "nextDirection": "Loom will turn the mess into one clear result and a short order under it. That makes the first step obvious.",
      "rationale": "Fits backlog stress where the user freezes because the work has no clear shape."
    },
    {
      "id": "RC007",
      "layer": "core",
      "archetype": "Backlog Carrier",
      "subarchetype": "Messy Restart",
      "intensity": "high",
      "tags": ["behind", "momentum-loss", "re-entry-cost", "disorganization"],
      "triggerConditions": {
        "stressIn": ["behind_disorganized"],
        "breaksFirstIn": ["lose_momentum"]
      },
      "disqualifiers": null,
      "rootCause": "Once you stop, the work has no clear place to pick back up. You waste energy trying to find your place again.",
      "nextDirection": "Loom will give each day one main result and a short sequence. That makes it easier and faster to restart.",
      "rationale": "Fits disorganized users who can begin but lose traction because there is no clear way back in."
    },
    {
      "id": "RC008",
      "layer": "core",
      "archetype": "Backlog Carrier",
      "subarchetype": "Chasing Noise",
      "intensity": "high",
      "tags": ["behind", "distraction", "loose-ends", "exposure-reactivity"],
      "triggerConditions": {
        "stressIn": ["behind_disorganized"],
        "breaksFirstIn": ["get_distracted"]
      },
      "disqualifiers": null,
      "rootCause": "Because things feel unfinished everywhere, the loudest loose end keeps winning. Your attention jumps to whatever feels most urgent or exposed.",
      "nextDirection": "Loom will organize today around one result and a few linked actions. That gives loose ends less power.",
      "rationale": "Fits disorganized users whose attention gets hijacked by visible unfinished items."
    },
    {
      "id": "RC009",
      "layer": "core",
      "archetype": "Backlog Carrier",
      "subarchetype": "Sorting Loop",
      "intensity": "high",
      "tags": ["behind", "overthinking", "sort-before-move", "perfection-order"],
      "triggerConditions": {
        "stressIn": ["behind_disorganized"],
        "breaksFirstIn": ["overthink"]
      },
      "disqualifiers": null,
      "rootCause": "You keep trying to organize everything before you act. Trying to create order becomes the new delay.",
      "nextDirection": "Loom will reduce the day to one result and a simple path. That lets action create order instead of waiting for perfect order.",
      "rationale": "Fits users who respond to mess by over-sorting instead of acting."
    },
    {
      "id": "RC010",
      "layer": "core",
      "archetype": "Backlog Carrier",
      "subarchetype": "Pile of Half-Done",
      "intensity": "high",
      "tags": ["behind", "finish-weakness", "circling", "non-closure"],
      "triggerConditions": {
        "stressIn": ["behind_disorganized"],
        "breaksFirstIn": ["dont_finish"]
      },
      "disqualifiers": null,
      "rootCause": "You keep rearranging the work without finishing it. The pile changes shape, but it does not get much smaller.",
      "nextDirection": "Loom will define a short finish path for one result at a time. That makes finishing work more likely than circling around it.",
      "rationale": "Fits backlog users who stay busy but do not create real closure."
    },
    {
      "id": "RC011",
      "layer": "core",
      "archetype": "Pulled Away",
      "subarchetype": "Pre-Start Drift",
      "intensity": "high",
      "tags": ["distraction", "start-friction", "weak-anchor", "attention-capture"],
      "triggerConditions": {
        "stressIn": ["distractions"],
        "breaksFirstIn": ["dont_start"]
      },
      "disqualifiers": null,
      "rootCause": "Your attention gets pulled away before the day has a center. Without a clear first target, anything can take over.",
      "nextDirection": "Loom will anchor the day to one result before other things pile on. That gives your attention a home base.",
      "rationale": "Fits users whose day never fully starts because attention is captured too early."
    },
    {
      "id": "RC012",
      "layer": "core",
      "archetype": "Pulled Away",
      "subarchetype": "Midstream Drift",
      "intensity": "high",
      "tags": ["distraction", "momentum-loss", "return-friction", "weak-hold"],
      "triggerConditions": {
        "stressIn": ["distractions"],
        "breaksFirstIn": ["lose_momentum"]
      },
      "disqualifiers": null,
      "rootCause": "Once the first push fades, things around you pull you somewhere else. The work keeps losing its hold.",
      "nextDirection": "Loom will keep one result and a short action order in view. That makes it easier to return before drifting turns into fully switching tasks.",
      "rationale": "Fits users who can begin but cannot keep the task holding attention."
    },
    {
      "id": "RC013",
      "layer": "core",
      "archetype": "Pulled Away",
      "subarchetype": "Reactive Switcher",
      "intensity": "high",
      "tags": ["distraction", "reactivity", "attention-fragmentation", "busy-not-directed"],
      "triggerConditions": {
        "stressIn": ["distractions"],
        "breaksFirstIn": ["get_distracted"]
      },
      "disqualifiers": null,
      "rootCause": "Your day keeps reacting to whatever is newest or closest. That keeps you busy, but not focused.",
      "nextDirection": "Loom will filter the day through one result first. That gives you a simple rule for what matters right now.",
      "rationale": "Fits direct distraction patterns where nearby inputs keep replacing intention."
    },
    {
      "id": "RC014",
      "layer": "core",
      "archetype": "Pulled Away",
      "subarchetype": "Thought-Hook Drift",
      "intensity": "medium",
      "tags": ["distraction", "overthinking", "side-questions", "attention-slip"],
      "triggerConditions": {
        "stressIn": ["distractions"],
        "breaksFirstIn": ["overthink"]
      },
      "disqualifiers": null,
      "rootCause": "Your mind keeps opening side questions while you work. Those side thoughts keep pulling you away from the main task.",
      "nextDirection": "Loom will narrow the work to one result and a smaller action block. That leaves less room for side thoughts to take over.",
      "rationale": "Fits mixed distraction/overthinking profiles where internal side-thoughts derail focus."
    },
    {
      "id": "RC015",
      "layer": "core",
      "archetype": "Pulled Away",
      "subarchetype": "Interrupted Finish",
      "intensity": "medium",
      "tags": ["distraction", "finish-weakness", "repeated-switching", "weak-closure"],
      "triggerConditions": {
        "stressIn": ["distractions"],
        "breaksFirstIn": ["dont_finish"]
      },
      "disqualifiers": null,
      "rootCause": "Each break in focus weakens the final stretch. You come back to the work many times, but finishing keeps slipping away.",
      "nextDirection": "Loom will reduce active work to a short ordered block tied to one result. That makes finishing easier before your attention breaks again.",
      "rationale": "Fits users whose finish behavior fails after repeated attention breaks."
    },
    {
      "id": "RC016",
      "layer": "core",
      "archetype": "Pressed Worker",
      "subarchetype": "Compressed Starter",
      "intensity": "high",
      "tags": ["work-pressure", "start-friction", "risk-load", "compressed-choice"],
      "triggerConditions": {
        "stressIn": ["work_pressure"],
        "breaksFirstIn": ["dont_start"]
      },
      "disqualifiers": null,
      "rootCause": "The pressure makes every move feel high-stakes. Starting feels risky instead of simple.",
      "nextDirection": "Loom will reduce the day to one clear work result and a short order. That makes it easier to begin.",
      "rationale": "Fits work-pressure users whose start point feels heavy because stakes feel high."
    },
    {
      "id": "RC017",
      "layer": "core",
      "archetype": "Pressed Worker",
      "subarchetype": "Squeezed Momentum",
      "intensity": "high",
      "tags": ["work-pressure", "momentum-loss", "rewritten-day", "crowding"],
      "triggerConditions": {
        "stressIn": ["work_pressure"],
        "breaksFirstIn": ["lose_momentum"]
      },
      "disqualifiers": null,
      "rootCause": "Work keeps filling up with new requests and leftover tasks. The day gets rewritten before progress can build.",
      "nextDirection": "Loom will hold one main result steady and organize the rest around it. That gives the day a stronger structure.",
      "rationale": "Fits work overload where momentum dies because the day keeps being redefined."
    },
    {
      "id": "RC018",
      "layer": "core",
      "archetype": "Pressed Worker",
      "subarchetype": "Fire-Fighting Attention",
      "intensity": "high",
      "tags": ["work-pressure", "distraction", "urgency-reactivity", "nearest-flame"],
      "triggerConditions": {
        "stressIn": ["work_pressure"],
        "breaksFirstIn": ["get_distracted"]
      },
      "disqualifiers": null,
      "rootCause": "Urgent work keeps pulling you to the nearest problem. That makes the day reactive instead of directed.",
      "nextDirection": "Loom will set one result as the anchor for the day. That helps you tell true priority from new pressure.",
      "rationale": "Fits work stress plus distraction where urgency repeatedly hijacks focus."
    },
    {
      "id": "RC019",
      "layer": "core",
      "archetype": "Pressed Worker",
      "subarchetype": "Risk Loop",
      "intensity": "high",
      "tags": ["work-pressure", "overthinking", "caution-loop", "stakes-sensitivity"],
      "triggerConditions": {
        "stressIn": ["work_pressure"],
        "breaksFirstIn": ["overthink"]
      },
      "disqualifiers": null,
      "rootCause": "The pressure makes you focus on the downside of every move. Too much caution slows you down.",
      "nextDirection": "Loom will simplify work into one result and a short path. That makes decisions feel lighter in the moment.",
      "rationale": "Fits work pressure combined with analysis delay."
    },
    {
      "id": "RC020",
      "layer": "core",
      "archetype": "Pressed Worker",
      "subarchetype": "Deadline Residue",
      "intensity": "high",
      "tags": ["work-pressure", "finish-weakness", "carryover", "spillover"],
      "triggerConditions": {
        "stressIn": ["work_pressure"],
        "breaksFirstIn": ["dont_finish"]
      },
      "disqualifiers": null,
      "rootCause": "Work keeps carrying over without a clean ending. Each unfinished piece makes the next one harder.",
      "nextDirection": "Loom will define one work result and a short finish path for today. That creates a clearer ending instead of endless carryover.",
      "rationale": "Fits work-pressure users who repeatedly carry open work forward."
    },
    {
      "id": "RC021",
      "layer": "core",
      "archetype": "Strained Provider",
      "subarchetype": "Cautious Stall",
      "intensity": "high",
      "tags": ["money-pressure", "start-friction", "risk-avoidance", "high-cost-beginning"],
      "triggerConditions": {
        "stressIn": ["money_pressure"],
        "breaksFirstIn": ["dont_start"]
      },
      "disqualifiers": null,
      "rootCause": "Money pressure makes each move feel like it has to be right. That pressure can stop action before it starts.",
      "nextDirection": "Loom will reduce the day to one clear result and a short order. That makes the next step feel smaller and safer.",
      "rationale": "Fits money stress where the user freezes under perceived cost of mistakes."
    },
    {
      "id": "RC022",
      "layer": "core",
      "archetype": "Strained Provider",
      "subarchetype": "Stress Drain",
      "intensity": "high",
      "tags": ["money-pressure", "momentum-loss", "energy-leak", "strain-drag"],
      "triggerConditions": {
        "stressIn": ["money_pressure"],
        "breaksFirstIn": ["lose_momentum"]
      },
      "disqualifiers": null,
      "rootCause": "Worry keeps taking energy away from steady effort. Even when you start, the strain keeps slowing you down.",
      "nextDirection": "Loom will hold one main result in place and shorten the action path. That helps your effort stay on one track longer.",
      "rationale": "Fits money-driven mental strain that erodes sustained effort."
    },
    {
      "id": "RC023",
      "layer": "core",
      "archetype": "Strained Provider",
      "subarchetype": "Vigilance Drift",
      "intensity": "high",
      "tags": ["money-pressure", "distraction", "threat-scanning", "attention-split"],
      "triggerConditions": {
        "stressIn": ["money_pressure"],
        "breaksFirstIn": ["get_distracted"]
      },
      "disqualifiers": null,
      "rootCause": "Your mind keeps scanning for what could go wrong. That keeps your attention on danger instead of follow-through.",
      "nextDirection": "Loom will center the day on one result and remove extra choices. That gives your mind fewer places to split.",
      "rationale": "Fits financial vigilance that pulls attention into scanning rather than doing."
    },
    {
      "id": "RC024",
      "layer": "core",
      "archetype": "Strained Provider",
      "subarchetype": "Fear Loop",
      "intensity": "high",
      "tags": ["money-pressure", "overthinking", "safety-loop", "future-checking"],
      "triggerConditions": {
        "stressIn": ["money_pressure"],
        "breaksFirstIn": ["overthink"]
      },
      "disqualifiers": null,
      "rootCause": "You keep trying to think far enough ahead to feel safe. Trying to cover every angle slows action right now.",
      "nextDirection": "Loom will move the day from broad worry to one defined result. That makes progress less dependent on feeling fully certain.",
      "rationale": "Fits money pressure expressed as future-checking and slowed action."
    },
    {
      "id": "RC025",
      "layer": "core",
      "archetype": "Strained Provider",
      "subarchetype": "Repeated Partials",
      "intensity": "medium",
      "tags": ["money-pressure", "finish-weakness", "protective-fragmentation", "partial-progress"],
      "triggerConditions": {
        "stressIn": ["money_pressure"],
        "breaksFirstIn": ["dont_finish"]
      },
      "disqualifiers": null,
      "rootCause": "You keep making small starts without finishing. The strain pushes you to protect yourself instead of complete the work.",
      "nextDirection": "Loom will narrow work to one result and a short finish path. That makes finishing more likely than scattered checking.",
      "rationale": "Fits money pressure that leads to partial, defensive movement rather than closure."
    },
    {
      "id": "RC026",
      "layer": "core",
      "archetype": "Drained Body",
      "subarchetype": "Low-Start Capacity",
      "intensity": "high",
      "tags": ["low-energy", "start-friction", "capacity-mismatch", "load-too-heavy"],
      "triggerConditions": {
        "stressIn": ["low_energy"],
        "breaksFirstIn": ["dont_start"]
      },
      "disqualifiers": null,
      "rootCause": "The day asks for more than your energy can give right away. Starting feels heavy because the workload and your energy do not match.",
      "nextDirection": "Loom will narrow the day to one result with an easier first step. That lowers the effort needed to begin.",
      "rationale": "Fits health or energy strain where beginning fails because the first lift is too large."
    },
    {
      "id": "RC027",
      "layer": "core",
      "archetype": "Drained Body",
      "subarchetype": "Energy Fade",
      "intensity": "high",
      "tags": ["low-energy", "momentum-loss", "capacity-drop", "short-burst-pattern"],
      "triggerConditions": {
        "stressIn": ["low_energy"],
        "breaksFirstIn": ["lose_momentum"]
      },
      "disqualifiers": null,
      "rootCause": "You can get going, but your energy drops before the work settles. The day keeps asking for more than your energy can handle.",
      "nextDirection": "Loom will shorten the work path around one result. That helps progress happen before your energy drops off.",
      "rationale": "Fits users whose effort starts but fades because energy cannot support longer paths."
    },
    {
      "id": "RC028",
      "layer": "core",
      "archetype": "Drained Body",
      "subarchetype": "Low-Signal Drift",
      "intensity": "medium",
      "tags": ["low-energy", "distraction", "thin-attention", "easy-capture"],
      "triggerConditions": {
        "stressIn": ["low_energy"],
        "breaksFirstIn": ["get_distracted"]
      },
      "disqualifiers": null,
      "rootCause": "When your energy is low, your attention is easier to pull off course. Small things can take over the day.",
      "nextDirection": "Loom will give the day one clear center and fewer active choices. That protects your focus when energy is low.",
      "rationale": "Fits low-energy attention fragility rather than classic external distraction."
    },
    {
      "id": "RC029",
      "layer": "core",
      "archetype": "Drained Body",
      "subarchetype": "Recovery Loop",
      "intensity": "medium",
      "tags": ["low-energy", "overthinking", "readiness-checking", "energy-monitoring"],
      "triggerConditions": {
        "stressIn": ["low_energy"],
        "breaksFirstIn": ["overthink"]
      },
      "disqualifiers": null,
      "rootCause": "You keep checking how you feel before each step. Trying to manage your energy can turn into delay.",
      "nextDirection": "Loom will simplify the day into one result and a short order. That makes action less dependent on feeling perfectly ready.",
      "rationale": "Fits low-energy users who get stuck in readiness checking."
    },
    {
      "id": "RC030",
      "layer": "core",
      "archetype": "Drained Body",
      "subarchetype": "Depleted Finish",
      "intensity": "medium",
      "tags": ["low-energy", "finish-weakness", "last-stretch-failure", "capacity-drop"],
      "triggerConditions": {
        "stressIn": ["low_energy"],
        "breaksFirstIn": ["dont_finish"]
      },
      "disqualifiers": null,
      "rootCause": "The final stretch asks for control you no longer have. The work stays unfinished because your energy runs out near the end.",
      "nextDirection": "Loom will make the day smaller and clearer around one result. That gives you a better chance to finish before you run out of energy.",
      "rationale": "Fits capacity-based finish failure."
    },
    {
      "id": "RC031",
      "layer": "core",
      "archetype": "Frayed Bond",
      "subarchetype": "Emotional Stall",
      "intensity": "high",
      "tags": ["relationship-tension", "start-friction", "occupied-mind", "emotional-load"],
      "triggerConditions": {
        "stressIn": ["relationship_tension"],
        "breaksFirstIn": ["dont_start"]
      },
      "disqualifiers": null,
      "rootCause": "The tension keeps part of your mind stuck somewhere else. Starting other work feels hard because your attention is not fully free.",
      "nextDirection": "Loom will narrow the day to one clear result and a short order. That gives the rest of the day a simpler path.",
      "rationale": "Fits emotionally occupied start failure."
    },
    {
      "id": "RC032",
      "layer": "core",
      "archetype": "Frayed Bond",
      "subarchetype": "Mood Carryover",
      "intensity": "high",
      "tags": ["relationship-tension", "momentum-loss", "carryover", "emotional-spill"],
      "triggerConditions": {
        "stressIn": ["relationship_tension"],
        "breaksFirstIn": ["lose_momentum"]
      },
      "disqualifiers": null,
      "rootCause": "The tension follows you into the rest of the day and slows you down. The work loses structure after you begin.",
      "nextDirection": "Loom will hold one main result steady and simplify what comes after it. That makes it easier to regain direction after an emotional hit.",
      "rationale": "Fits emotional spillover that weakens continuity."
    },
    {
      "id": "RC033",
      "layer": "core",
      "archetype": "Frayed Bond",
      "subarchetype": "Attention Split",
      "intensity": "high",
      "tags": ["relationship-tension", "distraction", "split-attention", "mental-division"],
      "triggerConditions": {
        "stressIn": ["relationship_tension"],
        "breaksFirstIn": ["get_distracted"]
      },
      "disqualifiers": null,
      "rootCause": "Part of your attention stays on the tension, so other things quickly lose focus. The day keeps feeling split in two.",
      "nextDirection": "Loom will center the day on one result and reduce extra choices. That gives your attention fewer places to split.",
      "rationale": "Fits distraction caused by ongoing emotional division."
    },
    {
      "id": "RC034",
      "layer": "core",
      "archetype": "Frayed Bond",
      "subarchetype": "Replay Loop",
      "intensity": "high",
      "tags": ["relationship-tension", "overthinking", "replay", "future-social-checking"],
      "triggerConditions": {
        "stressIn": ["relationship_tension"],
        "breaksFirstIn": ["overthink"]
      },
      "disqualifiers": null,
      "rootCause": "Your mind keeps replaying what happened or what might happen next. The replay becomes the main thing taking up space in your head.",
      "nextDirection": "Loom will move the day toward one defined result and a short action path. That gives your thoughts less room to spiral.",
      "rationale": "Fits relationship strain expressed as mental replay."
    },
    {
      "id": "RC035",
      "layer": "core",
      "archetype": "Frayed Bond",
      "subarchetype": "Unresolved Spillover",
      "intensity": "medium",
      "tags": ["relationship-tension", "finish-weakness", "spillover", "non-closure"],
      "triggerConditions": {
        "stressIn": ["relationship_tension"],
        "breaksFirstIn": ["dont_finish"]
      },
      "disqualifiers": null,
      "rootCause": "Unresolved tension keeps turning small tasks into half-starts. Finishing slips because part of your mind is somewhere else.",
      "nextDirection": "Loom will shrink today around one result and a short finish path. That makes finishing easier even on a noisy day.",
      "rationale": "Fits weak closure caused by emotional occupation."
    },
    {
      "id": "RC036",
      "layer": "core",
      "archetype": "Unclear Fog",
      "subarchetype": "Vague Stall",
      "intensity": "medium",
      "tags": ["unclear-stress", "start-friction", "ambiguity", "low-shape"],
      "triggerConditions": {
        "stressIn": ["not_sure"],
        "breaksFirstIn": ["dont_start"]
      },
      "disqualifiers": null,
      "rootCause": "The stress feels real, but it still has no clear shape. When the problem feels blurry, starting can feel random.",
      "nextDirection": "Loom will narrow the day to one result and a short order. That gives the day structure before you have all the answers.",
      "rationale": "Fits ambiguous stress where lack of shape blocks starting."
    },
    {
      "id": "RC037",
      "layer": "core",
      "archetype": "Unclear Fog",
      "subarchetype": "Shape-Shifting Day",
      "intensity": "medium",
      "tags": ["unclear-stress", "momentum-loss", "moving-ground", "weak-rhythm"],
      "triggerConditions": {
        "stressIn": ["not_sure"],
        "breaksFirstIn": ["lose_momentum"]
      },
      "disqualifiers": null,
      "rootCause": "The source keeps changing, so your day keeps changing too. It is hard to build rhythm when the ground keeps moving.",
      "nextDirection": "Loom will hold one main result steady across the day. That gives you a fixed point even when things feel mixed.",
      "rationale": "Fits ambiguous stress with low continuity because the felt problem keeps shifting."
    },
    {
      "id": "RC038",
      "layer": "core",
      "archetype": "Unclear Fog",
      "subarchetype": "Scattered Sensing",
      "intensity": "medium",
      "tags": ["unclear-stress", "distraction", "checking-many-signals", "low-depth"],
      "triggerConditions": {
        "stressIn": ["not_sure"],
        "breaksFirstIn": ["get_distracted"]
      },
      "disqualifiers": null,
      "rootCause": "When the problem is unclear, your attention keeps checking too many signals at once. That makes deep focus hard to keep.",
      "nextDirection": "Loom will reduce the day to one result and fewer active choices. That helps you focus before the full picture is clear.",
      "rationale": "Fits ambiguity plus attentional scanning."
    },
    {
      "id": "RC039",
      "layer": "core",
      "archetype": "Unclear Fog",
      "subarchetype": "Meaning Loop",
      "intensity": "medium",
      "tags": ["unclear-stress", "overthinking", "need-for-meaning", "clarity-search"],
      "triggerConditions": {
        "stressIn": ["not_sure"],
        "breaksFirstIn": ["overthink"]
      },
      "disqualifiers": null,
      "rootCause": "You keep trying to understand the whole problem before you act. That search for clarity becomes its own delay.",
      "nextDirection": "Loom will create one small center for the day first. That lets action reveal more than endless thinking does.",
      "rationale": "Fits ambiguity plus analysis delay where clarity is chased before action."
    },
    {
      "id": "RC040",
      "layer": "core",
      "archetype": "Unclear Fog",
      "subarchetype": "Loose Finish",
      "intensity": "medium",
      "tags": ["unclear-stress", "finish-weakness", "weak-end-state", "drift"],
      "triggerConditions": {
        "stressIn": ["not_sure"],
        "breaksFirstIn": ["dont_finish"]
      },
      "disqualifiers": null,
      "rootCause": "Without a clear sense of what matters most, work gets started and stays unfinished. The day moves, but it does not really land.",
      "nextDirection": "Loom will set one result and a short finish path for today. That gives the day a clearer ending.",
      "rationale": "Fits weak closure caused by unclear priority and weak end-state."
    },
    {
      "id": "CORE_LC_05",
      "layer": "core",
      "archetype": "load_conflict",
      "subarchetype": "crowded_scatter",
      "intensity": "high",
      "tags": ["overload", "distraction", "fragmentation", "broad_load"],
      "triggerConditions": {
        "stressIn": ["competing_priorities"],
        "breaksFirstIn": ["get_distracted"],
        "planningStyleIn": ["react_urgent", "simple_todo", "depends_day"],
        "areasCountMin": 5,
        "firstChangeIn": ["feel_control", "follow_through"]
      },
      "disqualifiers": null,
      "rootCause": "Too many things stay active at the same time, so your attention keeps splitting. The next pull shows up before the first one has enough weight.",
      "nextDirection": "Loom will let one result lead and push the rest back. That gives your attention one lane instead of several weak lanes.",
      "rationale": "Fills the missing overload plus distraction pattern."
    },
    {
      "id": "CORE_LC_06",
      "layer": "core",
      "archetype": "load_conflict",
      "subarchetype": "mid_load_freeze",
      "intensity": "medium",
      "tags": ["overload", "start_friction", "mid_breadth", "priority_blur"],
      "triggerConditions": {
        "stressIn": ["competing_priorities"],
        "breaksFirstIn": ["dont_start"],
        "planningStyleIn": ["plan_offtrack", "depends_day"],
        "areasCountMin": 4,
        "areasCountMax": 5,
        "firstChangeIn": ["know_what_matters", "feel_control"]
      },
      "disqualifiers": {
        "planningStyleIn": ["plan_follow_through"]
      },
      "rootCause": "The load is not endless, but it is still too mixed at the start. Nothing feels clear enough to begin cleanly.",
      "nextDirection": "Loom will choose one result to lead before the day spreads out. That makes the first step easier to trust.",
      "rationale": "Adds a moderate overload variant instead of only broad extreme-load versions."
    },
    {
      "id": "CORE_LS_05",
      "layer": "core",
      "archetype": "low_structure",
      "subarchetype": "messy_scatter",
      "intensity": "high",
      "tags": ["behind_disorganized", "distraction", "loose_edges", "weak_order"],
      "triggerConditions": {
        "stressIn": ["behind_disorganized"],
        "breaksFirstIn": ["get_distracted"],
        "planningStyleIn": ["react_urgent", "simple_todo"],
        "firstChangeIn": ["feel_control", "follow_through"]
      },
      "disqualifiers": null,
      "rootCause": "Loose and unfinished things keep pulling your attention in different directions. The mess keeps demanding attention before one task can settle.",
      "nextDirection": "Loom will pull the day into one result and a short Action Plan. That gives the mess less power to steer you.",
      "rationale": "Fills the missing disorganized plus distraction case."
    },
    {
      "id": "CORE_LS_06",
      "layer": "core",
      "archetype": "low_structure",
      "subarchetype": "urgent_backlog_start",
      "intensity": "high",
      "tags": ["behind_disorganized", "start_friction", "urgency", "backlog_pressure"],
      "triggerConditions": {
        "stressIn": ["behind_disorganized"],
        "breaksFirstIn": ["dont_start"],
        "planningStyleIn": ["react_urgent"],
        "firstChangeIn": ["feel_control", "faster_progress"]
      },
      "disqualifiers": null,
      "rootCause": "The backlog feels messy and urgent at the same time. Starting one thing feels pointless because ten other things still seem to demand attention.",
      "nextDirection": "Loom will stop the whole pile from feeling active at once. It will let one result come first so the day can actually begin.",
      "rationale": "Adds a stronger backlog-plus-urgency start-failure variant."
    },
    {
      "id": "CORE_LS_07",
      "layer": "core",
      "archetype": "low_structure",
      "subarchetype": "organized_but_cluttered",
      "intensity": "medium",
      "tags": ["behind_disorganized", "stable_planner", "mental_clutter", "rebuild_cost"],
      "triggerConditions": {
        "stressIn": ["behind_disorganized"],
        "breaksFirstIn": ["overthink", "dont_finish"],
        "planningStyleIn": ["plan_follow_through"],
        "firstChangeIn": ["feel_control", "know_what_matters"]
      },
      "disqualifiers": null,
      "rootCause": "You may already use structure, but too much clutter still comes with it. Your mind keeps trying to clean up the work while also doing it.",
      "nextDirection": "Loom will reduce how much is active inside the plan at one time. That makes your structure feel cleaner, not just more full.",
      "rationale": "Adds a high-functioning disorganization case."
    },
    {
      "id": "CORE_AF_04",
      "layer": "core",
      "archetype": "attention_drift",
      "subarchetype": "thought_hook_focus",
      "intensity": "medium",
      "tags": ["distractions", "overthink", "side_loops", "attention_leak"],
      "triggerConditions": {
        "stressIn": ["distractions"],
        "breaksFirstIn": ["overthink"],
        "planningStyleIn": ["simple_todo", "depends_day"],
        "firstChangeIn": ["know_what_matters", "follow_through"]
      },
      "disqualifiers": null,
      "rootCause": "Focus keeps breaking because small side questions keep opening in your head. The work loses depth before it gets enough hold on your attention.",
      "nextDirection": "Loom will make the path shorter and clearer under one result. That leaves less room for side thoughts to take over.",
      "rationale": "Adds distraction expressed as internal looping, not just external pulls."
    },
    {
      "id": "CORE_AF_05",
      "layer": "core",
      "archetype": "attention_drift",
      "subarchetype": "pre_start_pull",
      "intensity": "medium",
      "tags": ["distractions", "start_friction", "weak_entry", "open_attention"],
      "triggerConditions": {
        "stressIn": ["distractions"],
        "breaksFirstIn": ["dont_start"],
        "planningStyleIn": ["react_urgent", "depends_day"],
        "firstChangeIn": ["feel_control", "know_what_matters"]
      },
      "disqualifiers": null,
      "rootCause": "Your attention gets pulled away before the real work begins. The day starts too open, so nearby distractions win too easily.",
      "nextDirection": "Loom will set one clear result before the day fills up. That gives your attention a stronger place to land first.",
      "rationale": "Fills missing distraction plus no-start coverage."
    },
    {
      "id": "CORE_PT_05",
      "layer": "core",
      "archetype": "pressure_tunnel",
      "subarchetype": "work_freeze",
      "intensity": "high",
      "tags": ["work_pressure", "start_friction", "risk_weight", "high_stakes"],
      "triggerConditions": {
        "stressIn": ["work_pressure"],
        "breaksFirstIn": ["dont_start"],
        "planningStyleIn": ["react_urgent", "depends_day", "simple_todo"],
        "firstChangeIn": ["feel_control", "faster_progress"]
      },
      "disqualifiers": null,
      "rootCause": "Work pressure makes the next move feel heavier than it should. Starting gets delayed because making the wrong move feels costly.",
      "nextDirection": "Loom will make one result lead and shrink the first step. That makes getting started feel lighter.",
      "rationale": "Fills the missing work-pressure plus no-start case."
    },
    {
      "id": "CORE_PT_06",
      "layer": "core",
      "archetype": "pressure_tunnel",
      "subarchetype": "work_open_loops",
      "intensity": "high",
      "tags": ["work_pressure", "finish_weakness", "carryover", "deadline_drag"],
      "triggerConditions": {
        "stressIn": ["work_pressure"],
        "breaksFirstIn": ["dont_finish"],
        "planningStyleIn": ["react_urgent", "plan_offtrack"],
        "firstChangeIn": ["follow_through", "feel_control"]
      },
      "disqualifiers": null,
      "rootCause": "Pressure keeps adding new tasks before old ones are closed. That leaves too much work half-finished and hard to end cleanly.",
      "nextDirection": "Loom will narrow the active workload and give one result a clearer ending. That helps work finish instead of just carry over.",
      "rationale": "Fills the missing work-pressure plus finish weakness case."
    },
    {
      "id": "CORE_PT_07",
      "layer": "core",
      "archetype": "pressure_tunnel",
      "subarchetype": "work_pressure_stable_system",
      "intensity": "medium",
      "tags": ["work_pressure", "stable_planner", "pressure_overrides_system"],
      "triggerConditions": {
        "stressIn": ["work_pressure"],
        "breaksFirstIn": ["lose_momentum", "dont_finish"],
        "planningStyleIn": ["plan_follow_through"],
        "firstChangeIn": ["faster_progress", "feel_control"]
      },
      "disqualifiers": null,
      "rootCause": "You may already have a system, but pressure keeps changing the day after it starts. The problem is not a lack of structure. It is that the pressure keeps overriding it.",
      "nextDirection": "Loom will hold one result steady even when pressure rises. That keeps your structure from getting pushed around so easily.",
      "rationale": "High-functioning work-pressure case."
    },
    {
      "id": "CORE_PT_08",
      "layer": "core",
      "archetype": "pressure_tunnel",
      "subarchetype": "money_fade",
      "intensity": "medium",
      "tags": ["money_pressure", "momentum_loss", "worry_drag", "energy_split"],
      "triggerConditions": {
        "stressIn": ["money_pressure"],
        "breaksFirstIn": ["lose_momentum"],
        "planningStyleIn": ["depends_day", "plan_offtrack"],
        "firstChangeIn": ["feel_control", "follow_through"]
      },
      "disqualifiers": null,
      "rootCause": "Worry keeps taking energy away after you begin. The work starts, but the pressure drains too much focus to keep it going.",
      "nextDirection": "Loom will put more of the day behind one result and fewer active choices. That helps effort stay on one track longer.",
      "rationale": "Fills missing money-pressure plus momentum-loss coverage."
    },
    {
      "id": "CORE_PT_09",
      "layer": "core",
      "archetype": "pressure_tunnel",
      "subarchetype": "money_scatter",
      "intensity": "medium",
      "tags": ["money_pressure", "distraction", "threat_scanning", "split_focus"],
      "triggerConditions": {
        "stressIn": ["money_pressure"],
        "breaksFirstIn": ["get_distracted"],
        "planningStyleIn": ["react_urgent", "depends_day"],
        "firstChangeIn": ["feel_control", "know_what_matters"]
      },
      "disqualifiers": null,
      "rootCause": "Part of your attention keeps scanning for what could go wrong next. That makes your focus easier to break, even during simple work.",
      "nextDirection": "Loom will reduce the number of things pulling on you at once. That gives your attention less room to keep splitting.",
      "rationale": "Fills missing money-pressure plus distraction case."
    },
    {
      "id": "CORE_PT_10",
      "layer": "core",
      "archetype": "pressure_tunnel",
      "subarchetype": "money_open_loops",
      "intensity": "medium",
      "tags": ["money_pressure", "finish_weakness", "protective_switching"],
      "triggerConditions": {
        "stressIn": ["money_pressure"],
        "breaksFirstIn": ["dont_finish"],
        "planningStyleIn": ["simple_todo", "depends_day"],
        "firstChangeIn": ["follow_through", "feel_control"]
      },
      "disqualifiers": null,
      "rootCause": "When pressure feels risky, switching tasks can feel safer than finishing. That leaves too many things partly done and mentally draining.",
      "nextDirection": "Loom will narrow the work and make one finish path clearer. That helps finishing feel safer than endless partial progress.",
      "rationale": "Fills missing money-pressure plus no-finish case."
    },
    {
      "id": "CORE_PT_11",
      "layer": "core",
      "archetype": "pressure_tunnel",
      "subarchetype": "money_pressure_stable_system",
      "intensity": "medium",
      "tags": ["money_pressure", "stable_planner", "security_weight"],
      "triggerConditions": {
        "stressIn": ["money_pressure"],
        "breaksFirstIn": ["overthink", "lose_momentum"],
        "planningStyleIn": ["plan_follow_through"],
        "firstChangeIn": ["feel_control", "faster_progress"]
      },
      "disqualifiers": null,
      "rootCause": "Your system may work, but security pressure still adds extra weight to each step. The plan slows down because the stakes feel personal.",
      "nextDirection": "Loom will keep the day centered on one result with fewer side choices. That helps good structure move with less drag.",
      "rationale": "High-functioning money-pressure case."
    },
    {
      "id": "CORE_ED_04",
      "layer": "core",
      "archetype": "energy_drag",
      "subarchetype": "low_battery_scatter",
      "intensity": "medium",
      "tags": ["low_energy", "distraction", "thin_attention", "capacity_gap"],
      "triggerConditions": {
        "stressIn": ["low_energy"],
        "breaksFirstIn": ["get_distracted"],
        "planningStyleIn": ["depends_day", "react_urgent"],
        "firstChangeIn": ["feel_control", "feel_balanced"]
      },
      "disqualifiers": null,
      "rootCause": "When your energy runs low, your attention gets easier to pull off course. Small things can take over more of the day than they should.",
      "nextDirection": "Loom will make the day smaller and more centered around one result. That helps weak attention stay in one place longer.",
      "rationale": "Fills low-energy plus distraction gap."
    },
    {
      "id": "CORE_ED_05",
      "layer": "core",
      "archetype": "energy_drag",
      "subarchetype": "low_battery_loop",
      "intensity": "medium",
      "tags": ["low_energy", "overthink", "readiness_checking", "hesitation"],
      "triggerConditions": {
        "stressIn": ["low_energy"],
        "breaksFirstIn": ["overthink"],
        "planningStyleIn": ["depends_day", "simple_todo"],
        "firstChangeIn": ["feel_control", "follow_through"]
      },
      "disqualifiers": null,
      "rootCause": "You keep checking whether you have enough energy before acting. That turns low energy into extra delay on top of the work itself.",
      "nextDirection": "Loom will lower the effort needed to start and make the next path shorter. That helps action happen without waiting to feel perfectly ready.",
      "rationale": "Fills low-energy plus overthinking gap."
    },
    {
      "id": "CORE_ED_06",
      "layer": "core",
      "archetype": "energy_drag",
      "subarchetype": "low_battery_stable_system",
      "intensity": "medium",
      "tags": ["low_energy", "stable_planner", "capacity_mismatch"],
      "triggerConditions": {
        "stressIn": ["low_energy"],
        "breaksFirstIn": ["lose_momentum", "dont_finish"],
        "planningStyleIn": ["plan_follow_through"],
        "firstChangeIn": ["feel_balanced", "follow_through"]
      },
      "disqualifiers": null,
      "rootCause": "The plan may be fine, but your energy does not match what the plan expects right now. That makes a good structure feel too heavy to carry.",
      "nextDirection": "Loom will tighten the day around one result and a smaller action path. That helps your structure fit the energy you actually have.",
      "rationale": "High-functioning low-energy case."
    },
    {
      "id": "CORE_SN_03",
      "layer": "core",
      "archetype": "social_noise",
      "subarchetype": "relational_start_block",
      "intensity": "medium",
      "tags": ["relationship_tension", "start_friction", "mental_occupation"],
      "triggerConditions": {
        "stressIn": ["relationship_tension"],
        "breaksFirstIn": ["dont_start"],
        "planningStyleIn": ["depends_day", "simple_todo"],
        "firstChangeIn": ["feel_control", "feel_balanced"]
      },
      "disqualifiers": null,
      "rootCause": "Part of your mind stays tied up somewhere else, so starting other work feels harder than it should. The day never feels fully open.",
      "nextDirection": "Loom will narrow the day to one clear result first. That gives the rest of your attention one simple place to go.",
      "rationale": "Fills relationship-tension plus start-friction gap."
    },
    {
      "id": "CORE_SN_04",
      "layer": "core",
      "archetype": "social_noise",
      "subarchetype": "relational_open_loops",
      "intensity": "medium",
      "tags": ["relationship_tension", "finish_weakness", "spillover"],
      "triggerConditions": {
        "stressIn": ["relationship_tension"],
        "breaksFirstIn": ["dont_finish"],
        "planningStyleIn": ["depends_day", "react_urgent"],
        "firstChangeIn": ["feel_balanced", "follow_through"]
      },
      "disqualifiers": null,
      "rootCause": "The tension keeps pulling energy out of the final stretch of the work. Too many things stay partly open because your mind is already split.",
      "nextDirection": "Loom will shorten the active path and make finishing more defined. That helps the day land even when inner noise is present.",
      "rationale": "Fills relationship-tension plus no-finish gap."
    },
    {
      "id": "CORE_SN_05",
      "layer": "core",
      "archetype": "social_noise",
      "subarchetype": "relational_noise_stable_system",
      "intensity": "medium",
      "tags": ["relationship_tension", "stable_planner", "emotional_spill"],
      "triggerConditions": {
        "stressIn": ["relationship_tension"],
        "breaksFirstIn": ["get_distracted", "lose_momentum"],
        "planningStyleIn": ["plan_follow_through"],
        "firstChangeIn": ["feel_balanced", "follow_through"]
      },
      "disqualifiers": null,
      "rootCause": "The issue may not be your planning skill. Emotional noise keeps interrupting a system that usually works.",
      "nextDirection": "Loom will hold one result more clearly in front of you. That gives you a steady line when the rest of the day feels noisy.",
      "rationale": "High-functioning relationship-tension case."
    },
    {
      "id": "CORE_UN_03",
      "layer": "core",
      "archetype": "diffuse_uncertainty",
      "subarchetype": "foggy_start",
      "intensity": "medium",
      "tags": ["not_sure", "start_friction", "blurred_entry"],
      "triggerConditions": {
        "stressIn": ["not_sure"],
        "breaksFirstIn": ["dont_start"],
        "planningStyleIn": ["depends_day", "simple_todo"],
        "firstChangeIn": ["know_what_matters", "feel_control"]
      },
      "disqualifiers": null,
      "rootCause": "The day is hard to start because the real first step is still unclear. When the problem has no shape, starting feels random.",
      "nextDirection": "Loom will make one result stand out before the day spreads out. That gives you a clearer place to begin even while things stay unclear.",
      "rationale": "Specific uncertain-start variant."
    },
    {
      "id": "CORE_UN_04",
      "layer": "core",
      "archetype": "diffuse_uncertainty",
      "subarchetype": "foggy_fade",
      "intensity": "medium",
      "tags": ["not_sure", "momentum_loss", "moving_target"],
      "triggerConditions": {
        "stressIn": ["not_sure"],
        "breaksFirstIn": ["lose_momentum"],
        "planningStyleIn": ["depends_day", "plan_offtrack"],
        "firstChangeIn": ["follow_through", "feel_control"]
      },
      "disqualifiers": null,
      "rootCause": "You can start, but the goal keeps changing shape while you work. That makes momentum hard to keep for long.",
      "nextDirection": "Loom will give the day one fixed result even when the bigger picture feels mixed. That helps your effort stay on track longer.",
      "rationale": "Specific uncertain-momentum variant."
    },
    {
      "id": "CORE_UN_05",
      "layer": "core",
      "archetype": "diffuse_uncertainty",
      "subarchetype": "foggy_scatter",
      "intensity": "medium",
      "tags": ["not_sure", "distraction", "signal_scanning"],
      "triggerConditions": {
        "stressIn": ["not_sure"],
        "breaksFirstIn": ["get_distracted"],
        "planningStyleIn": ["react_urgent", "depends_day"],
        "firstChangeIn": ["know_what_matters", "feel_control"]
      },
      "disqualifiers": null,
      "rootCause": "When the real issue is still unclear, your attention keeps checking too many signals at once. That makes focus easy to lose.",
      "nextDirection": "Loom will reduce the day to one result and fewer active choices. That helps attention stop scanning so widely.",
      "rationale": "Specific uncertain-distraction variant."
    },
    {
      "id": "CORE_UN_06",
      "layer": "core",
      "archetype": "diffuse_uncertainty",
      "subarchetype": "foggy_loop",
      "intensity": "medium",
      "tags": ["not_sure", "overthink", "clarity_chasing"],
      "triggerConditions": {
        "stressIn": ["not_sure"],
        "breaksFirstIn": ["overthink"],
        "planningStyleIn": ["simple_todo", "depends_day"],
        "firstChangeIn": ["know_what_matters", "feel_control"]
      },
      "disqualifiers": null,
      "rootCause": "You keep trying to understand the whole pattern before acting. The search for clarity becomes the very thing that slows the day down.",
      "nextDirection": "Loom will create a smaller center for the day first. That lets action bring clarity instead of waiting for full certainty.",
      "rationale": "Specific uncertain-overthinking variant."
    },
    {
      "id": "CORE_UN_07",
      "layer": "core",
      "archetype": "diffuse_uncertainty",
      "subarchetype": "foggy_open_loops",
      "intensity": "medium",
      "tags": ["not_sure", "finish_weakness", "weak_end_state"],
      "triggerConditions": {
        "stressIn": ["not_sure"],
        "breaksFirstIn": ["dont_finish"],
        "planningStyleIn": ["depends_day", "simple_todo"],
        "firstChangeIn": ["follow_through", "feel_control"]
      },
      "disqualifiers": null,
      "rootCause": "When the day never gets a clear shape, work also ends without one. Too much stays partly open because the finish line stays unclear.",
      "nextDirection": "Loom will define one result and a shorter path to done. That makes finishing easier to see and reach.",
      "rationale": "Specific uncertain-finish variant."
    },
    {
      "id": "CORE_SP_03",
      "layer": "core",
      "archetype": "stable_but_spread_thin",
      "subarchetype": "stable_system_attention_leak",
      "intensity": "medium",
      "tags": ["stable_planner", "competing_priorities", "distraction", "spread_load"],
      "triggerConditions": {
        "stressIn": ["competing_priorities"],
        "breaksFirstIn": ["get_distracted"],
        "planningStyleIn": ["plan_follow_through"],
        "areasCountMin": 5,
        "firstChangeIn": ["follow_through", "feel_balanced"]
      },
      "disqualifiers": null,
      "rootCause": "You may already plan well, but too much is competing for your attention. That makes even a good system easier to drift away from.",
      "nextDirection": "Loom will tighten what stays active right now and let one result lead. That gives your focus fewer places to split.",
      "rationale": "High-functioning overload plus distraction case."
    },
    {
      "id": "CORE_SP_04",
      "layer": "core",
      "archetype": "stable_but_spread_thin",
      "subarchetype": "stable_system_clutter_loop",
      "intensity": "medium",
      "tags": ["stable_planner", "behind_disorganized", "overthink", "clutter_drag"],
      "triggerConditions": {
        "stressIn": ["behind_disorganized"],
        "breaksFirstIn": ["overthink"],
        "planningStyleIn": ["plan_follow_through"],
        "firstChangeIn": ["feel_control", "know_what_matters"]
      },
      "disqualifiers": null,
      "rootCause": "Your structure may work, but too much clutter still lives inside it. Your mind keeps cleaning up the plan instead of following it.",
      "nextDirection": "Loom will reduce how much sits inside the active plan at one time. That makes your structure feel clearer, not just more full.",
      "rationale": "High-functioning clutter-plus-loop case."
    },
    {
      "id": "CORE_SP_05",
      "layer": "core",
      "archetype": "stable_but_spread_thin",
      "subarchetype": "stable_system_low_fuel",
      "intensity": "medium",
      "tags": ["stable_planner", "low_energy", "momentum_loss", "capacity_gap"],
      "triggerConditions": {
        "stressIn": ["low_energy"],
        "breaksFirstIn": ["lose_momentum"],
        "planningStyleIn": ["plan_follow_through"],
        "firstChangeIn": ["follow_through", "feel_balanced"]
      },
      "disqualifiers": null,
      "rootCause": "The plan may be solid, but your energy cannot carry it at the pace it demands. Good structure still fades when your energy is too low.",
      "nextDirection": "Loom will tighten the work around one result and a shorter path. That helps your system fit your real energy better.",
      "rationale": "High-functioning low-energy momentum case."
    },
    {
      "id": "CORE_SP_06",
      "layer": "core",
      "archetype": "stable_but_spread_thin",
      "subarchetype": "stable_system_pressure_carryover",
      "intensity": "medium",
      "tags": ["stable_planner", "work_pressure", "finish_weakness", "carryover"],
      "triggerConditions": {
        "stressIn": ["work_pressure"],
        "breaksFirstIn": ["dont_finish"],
        "planningStyleIn": ["plan_follow_through"],
        "firstChangeIn": ["faster_progress", "feel_control"]
      },
      "disqualifiers": null,
      "rootCause": "Pressure is making the system run too wide to finish cleanly. You stay active, but too much work keeps carrying over unfinished.",
      "nextDirection": "Loom will make fewer results active at the same time and define clearer endings. That helps strong planning create cleaner closure.",
      "rationale": "High-functioning work-pressure finish case."
    },
    {
      "id": "CORE_SP_07",
      "layer": "core",
      "archetype": "stable_but_spread_thin",
      "subarchetype": "stable_system_social_scatter",
      "intensity": "medium",
      "tags": ["stable_planner", "relationship_tension", "distraction", "noise_intrusion"],
      "triggerConditions": {
        "stressIn": ["relationship_tension"],
        "breaksFirstIn": ["get_distracted"],
        "planningStyleIn": ["plan_follow_through"],
        "firstChangeIn": ["feel_balanced", "follow_through"]
      },
      "disqualifiers": null,
      "rootCause": "The system may not be the weak part. Emotional noise keeps slipping into your attention and pulling you away from the work.",
      "nextDirection": "Loom will hold one result more clearly in front of you and reduce extra pulls. That helps the day stay steadier when life feels noisy.",
      "rationale": "High-functioning relationship-tension distraction case."
    },
    {
      "id": "CORE_AF_06",
      "layer": "core",
      "archetype": "attention_drift",
      "subarchetype": "interrupted_momentum",
      "intensity": "medium",
      "tags": ["distractions", "lose_momentum", "attention_reset", "weak_reentry"],
      "triggerConditions": {
        "stressIn": ["distractions"],
        "breaksFirstIn": ["lose_momentum"],
        "planningStyleIn": ["react_urgent", "plan_offtrack", "depends_day"],
        "firstChangeIn": ["follow_through", "faster_progress"],
        "areaSpreadIn": ["mixed_wide", "outer_weighted", "balanced_mix"]
      },
      "disqualifiers": {
        "planningStyleIn": ["plan_follow_through"]
      },
      "rootCause": "The work loses its hold each time your attention gets pulled away. Too much of your energy goes into getting back on track.",
      "nextDirection": "Loom will keep one result and one short Action Plan in front of you. That makes restarting easier when your attention slips.",
      "rationale": "Directly fits distraction-led momentum loss rather than generic distraction or generic inconsistency."
    },
    {
      "id": "CORE_AF_07",
      "layer": "core",
      "archetype": "attention_drift",
      "subarchetype": "interrupted_finish",
      "intensity": "medium",
      "tags": ["distractions", "dont_finish", "closure_leak", "open_loops"],
      "triggerConditions": {
        "stressIn": ["distractions"],
        "breaksFirstIn": ["dont_finish"],
        "planningStyleIn": ["react_urgent", "simple_todo", "depends_day"],
        "firstChangeIn": ["follow_through", "feel_control"]
      },
      "disqualifiers": {
        "planningStyleIn": ["plan_follow_through"]
      },
      "rootCause": "Each break in focus weakens the final stretch of the work. Things stay unfinished because finishing keeps getting interrupted.",
      "nextDirection": "Loom will make the active path shorter and more limited. That gives finishing a clearer path before your focus breaks again.",
      "rationale": "Directly fills distraction plus don't-finish coverage."
    },
    {
      "id": "CORE_AF_08",
      "layer": "core",
      "archetype": "stable_but_spread_thin",
      "subarchetype": "stable_override_noise_momentum",
      "intensity": "medium",
      "tags": ["distractions", "lose_momentum", "plan_follow_through", "stable_override"],
      "triggerConditions": {
        "stressIn": ["distractions"],
        "breaksFirstIn": ["lose_momentum"],
        "planningStyleIn": ["plan_follow_through"],
        "firstChangeIn": ["follow_through", "faster_progress"]
      },
      "disqualifiers": null,
      "rootCause": "You may already know how to plan, but noise keeps pulling you off the work after you begin. The problem is not knowing what to do. It is staying with it.",
      "nextDirection": "Loom will keep one result more fixed in front of you and shorten the path under it. That helps your system hold longer when life gets noisy.",
      "rationale": "High-functioning distraction plus momentum case."
    },
    {
      "id": "CORE_AF_09",
      "layer": "core",
      "archetype": "stable_but_spread_thin",
      "subarchetype": "stable_override_noise_finish",
      "intensity": "medium",
      "tags": ["distractions", "dont_finish", "plan_follow_through", "stable_override"],
      "triggerConditions": {
        "stressIn": ["distractions"],
        "breaksFirstIn": ["dont_finish"],
        "planningStyleIn": ["plan_follow_through"],
        "firstChangeIn": ["follow_through", "feel_control"]
      },
      "disqualifiers": null,
      "rootCause": "The issue is not that you cannot organize the work. Repeated noise keeps weakening the push to finish.",
      "nextDirection": "Loom will reduce how much stays active and make finishing more defined. That helps a good system land the work more cleanly.",
      "rationale": "High-functioning distraction plus finish case."
    },
    {
      "id": "CORE_UN_08",
      "layer": "core",
      "archetype": "stable_but_spread_thin",
      "subarchetype": "stable_override_fog_loop",
      "intensity": "medium",
      "tags": ["not_sure", "overthink", "plan_follow_through", "stable_override", "clarity_gap"],
      "triggerConditions": {
        "stressIn": ["not_sure"],
        "breaksFirstIn": ["overthink"],
        "planningStyleIn": ["plan_follow_through"],
        "firstChangeIn": ["know_what_matters", "feel_control"]
      },
      "disqualifiers": null,
      "rootCause": "You may already have structure, but the real pressure still feels hard to name. Your mind keeps trying to solve the fog before acting.",
      "nextDirection": "Loom will force one result to lead even before the full picture is clear. That gives your structure something more solid to aim at.",
      "rationale": "High-functioning uncertainty plus overthinking case."
    },
    {
      "id": "CORE_UN_09",
      "layer": "core",
      "archetype": "stable_but_spread_thin",
      "subarchetype": "stable_override_fog_scatter",
      "intensity": "medium",
      "tags": ["not_sure", "get_distracted", "plan_follow_through", "stable_override", "signal_scanning"],
      "triggerConditions": {
        "stressIn": ["not_sure"],
        "breaksFirstIn": ["get_distracted", "not_sure"],
        "planningStyleIn": ["plan_follow_through"],
        "firstChangeIn": ["feel_control", "know_what_matters"]
      },
      "disqualifiers": null,
      "rootCause": "Your system may work, but unclear pressure keeps your attention checking too many signals. That makes your focus less steady than usual.",
      "nextDirection": "Loom will cut down the number of active pulls and hold one result more clearly. That gives your attention less to keep scanning.",
      "rationale": "High-functioning uncertainty plus distraction or hidden break case."
    },
    {
      "id": "CORE_PT_12",
      "layer": "core",
      "archetype": "stable_but_spread_thin",
      "subarchetype": "stable_override_money_start",
      "intensity": "medium",
      "tags": ["money_pressure", "dont_start", "plan_follow_through", "stable_override", "risk_weight"],
      "triggerConditions": {
        "stressIn": ["money_pressure"],
        "breaksFirstIn": ["dont_start"],
        "planningStyleIn": ["plan_follow_through"],
        "firstChangeIn": ["feel_control", "faster_progress"]
      },
      "disqualifiers": null,
      "rootCause": "The issue is not that you cannot plan. Pressure is making the first step feel heavier than normal, even inside a system that usually works.",
      "nextDirection": "Loom will lower the load at the start and keep one result in front. That helps your structure start moving sooner under pressure.",
      "rationale": "High-functioning money-pressure start case."
    },
    {
      "id": "CORE_LC_07",
      "layer": "core",
      "archetype": "stable_but_spread_thin",
      "subarchetype": "stable_override_overload_loop",
      "intensity": "medium",
      "tags": ["competing_priorities", "overthink", "plan_follow_through", "stable_override", "too_many_fronts"],
      "triggerConditions": {
        "stressIn": ["competing_priorities"],
        "breaksFirstIn": ["overthink"],
        "planningStyleIn": ["plan_follow_through"],
        "areasCountMin": 5,
        "firstChangeIn": ["know_what_matters", "faster_progress"]
      },
      "disqualifiers": null,
      "rootCause": "You may already have discipline, but too many fronts are trying to move at once. Your mind keeps sorting because the field stays too wide.",
      "nextDirection": "Loom will stop the day from giving equal weight to every open front. One result will lead so your system can move with less sorting.",
      "rationale": "High-functioning overload plus overthinking case."
    },
    {
      "id": "CORE_HB_01",
      "layer": "core",
      "archetype": "hidden_breakpoint",
      "subarchetype": "known_pressure_hidden_break",
      "intensity": "medium",
      "tags": ["known_stress", "breaks_not_sure", "hidden_mechanism"],
      "triggerConditions": {
        "stressIn": ["competing_priorities", "behind_disorganized", "distractions", "work_pressure", "money_pressure", "low_energy", "relationship_tension"],
        "breaksFirstIn": ["not_sure"],
        "planningStyleIn": ["react_urgent", "simple_todo", "plan_offtrack", "depends_day"]
      },
      "disqualifiers": {
        "stressIn": ["not_sure"]
      },
      "rootCause": "You can feel the pressure clearly, but the exact weak spot is still hard to find. That makes the day harder to fix because the problem stays slippery.",
      "nextDirection": "Loom will make the day simpler and more ordered first. That helps the real breaking point show up sooner.",
      "rationale": "Base hidden-break entry for all known stress sources when the failure point is unclear."
    }
  ],
  "modifierCandidates": [
    {
      "id": "RM041",
      "layer": "modifier",
      "archetype": "Reactive Day Runner",
      "subarchetype": "Urgency-Led Day",
      "intensity": "high",
      "tags": ["reactive-planning", "urgency", "low-structure", "control-seeking"],
      "triggerConditions": {
        "planningStyleIn": ["react_urgent"]
      },
      "disqualifiers": null,
      "rootCause": "Your day gets shaped by the next loud thing, not by a clear order. That makes different parts of life run into each other.",
      "nextDirection": "Loom will set one clear result before the day fills up. That gives you a steadier path to follow.",
      "rationale": "Strong cross-cutting modifier for urgency-led planning regardless of stress source."
    },
    {
      "id": "RM042",
      "layer": "modifier",
      "archetype": "Flat-List Planner",
      "subarchetype": "Unweighted List",
      "intensity": "medium",
      "tags": ["simple-list", "flat-priority", "low-weighting", "direction-seeking"],
      "triggerConditions": {
        "planningStyleIn": ["simple_todo"]
      },
      "disqualifiers": null,
      "rootCause": "A short list can hold tasks, but not their true order or importance. Different parts of life stay mixed together in one flat list.",
      "nextDirection": "Loom will put one result at the top and only a short ordered block under it. That gives the day more structure than a flat list can hold.",
      "rationale": "Captures users with basic capture structure but weak prioritization."
    },
    {
      "id": "RM043",
      "layer": "modifier",
      "archetype": "Slippery Planner",
      "subarchetype": "Plan Without Grip",
      "intensity": "medium",
      "tags": ["plan-off-track", "weak-plan-authority", "consistency-seeking"],
      "triggerConditions": {
        "planningStyleIn": ["plan_offtrack"]
      },
      "disqualifiers": null,
      "rootCause": "You can see what matters early, but the day does not stay connected to it. Once you drift, the plan stops leading.",
      "nextDirection": "Loom will keep one result at the center and make the day smaller around it. That helps the plan stay strong longer once the day gets moving.",
      "rationale": "Captures users with some structure but weak adherence."
    },
    {
      "id": "RM044",
      "layer": "modifier",
      "archetype": "Uneven Stabilizer",
      "subarchetype": "Structure Under Strain",
      "intensity": "medium",
      "tags": ["consistent-planning", "current-load-too-wide", "spillover", "balance-seeking"],
      "triggerConditions": {
        "planningStyleIn": ["plan_follow_through"]
      },
      "disqualifiers": {
        "stressIn": ["not_sure"],
        "breaksFirstIn": ["not_sure"]
      },
      "rootCause": "You already have structure, but the current workload is wider than your usual system can handle. The strain comes from spillover, not from a lack of discipline.",
      "nextDirection": "Loom will tighten your focus to one main result and clearer stopping points. That reduces spillover even when a lot is happening.",
      "rationale": "Important modifier so strong planners do not get mismatched to weak-structure language."
    },
    {
      "id": "RM045",
      "layer": "modifier",
      "archetype": "Variable Day Shifter",
      "subarchetype": "Moving Structure",
      "intensity": "medium",
      "tags": ["depends-on-day", "variable-structure", "low-stability", "balance-seeking"],
      "triggerConditions": {
        "planningStyleIn": ["depends_day"]
      },
      "disqualifiers": null,
      "rootCause": "Your structure changes with your energy, pressure, or noise around you. That makes good days clear and hard days messy.",
      "nextDirection": "Loom will give the day one fixed center even when the rest changes. That creates more steadiness across uneven days.",
      "rationale": "Captures variable structure without assuming no planning exists."
    },
    {
      "id": "RM046",
      "layer": "modifier",
      "archetype": "Control Seeker",
      "subarchetype": "Open-Choice Strain",
      "intensity": "medium",
      "tags": ["firstChange-control", "stress-relief", "choice-load", "settling"],
      "triggerConditions": {
        "firstChangeIn": ["feel_control"]
      },
      "disqualifiers": null,
      "rootCause": "Stress stays high because too many active choices keep pulling at you. It is hard to feel steady when everything still feels open in your mind.",
      "nextDirection": "Loom will reduce the number of active choices by putting one result first. That makes the day feel more settled.",
      "rationale": "Useful overlay when the user’s relief target is steadiness more than speed."
    },
    {
      "id": "RM047",
      "layer": "modifier",
      "archetype": "Direction Seeker",
      "subarchetype": "Blurred Importance",
      "intensity": "medium",
      "tags": ["firstChange-direction", "clarity", "priority-blur", "self-direction"],
      "triggerConditions": {
        "firstChangeIn": ["know_what_matters"]
      },
      "disqualifiers": null,
      "rootCause": "The issue is not just effort. What matters most keeps getting blurry before you can settle into action.",
      "nextDirection": "Loom will give you one result that sets the order for what comes next. That makes direction easier to feel.",
      "rationale": "Useful overlay when the user is asking for clearer priority, not just more discipline."
    },
    {
      "id": "RM048",
      "layer": "modifier",
      "archetype": "Consistency Seeker",
      "subarchetype": "Daily Rebuild",
      "intensity": "medium",
      "tags": ["firstChange-consistency", "repeatability", "reset-cost", "habitless-structure"],
      "triggerConditions": {
        "firstChangeIn": ["follow_through"]
      },
      "disqualifiers": null,
      "rootCause": "The pattern breaks because each day gets rebuilt from the beginning. Starting over costs more energy than it seems.",
      "nextDirection": "Loom will create one repeatable order around a main result. That makes follow-through less dependent on how you feel that day.",
      "rationale": "Useful overlay when the user values repeatability over relief or speed."
    },
    {
      "id": "RM049",
      "layer": "modifier",
      "archetype": "Momentum Seeker",
      "subarchetype": "Spread-Thin Progress",
      "intensity": "medium",
      "tags": ["firstChange-progress", "goal-progress", "spread-thin", "visible-gain"],
      "triggerConditions": {
        "firstChangeIn": ["faster_progress"]
      },
      "disqualifiers": null,
      "rootCause": "Your effort gets spread across too many open tracks, so the gains look smaller than the work you put in. Things move, but results do not show up fast.",
      "nextDirection": "Loom will push your effort into one result first. That makes progress easier to see.",
      "rationale": "Useful overlay when the user wants more visible movement on big outcomes."
    },
    {
      "id": "RM050",
      "layer": "modifier",
      "archetype": "Balance Seeker",
      "subarchetype": "Swinging Week",
      "intensity": "medium",
      "tags": ["firstChange-balance", "swing", "lopsided-load", "week-order"],
      "triggerConditions": {
        "firstChangeIn": ["feel_balanced"]
      },
      "disqualifiers": null,
      "rootCause": "One part of life keeps taking over, then other parts push back later. That back-and-forth swing creates stress.",
      "nextDirection": "Loom will use one clear result at a time inside a bigger plan. That makes the week feel less lopsided.",
      "rationale": "Useful overlay when the user’s desired relief is less swing between life domains."
    },
    {
      "id": "RM051",
      "layer": "modifier",
      "archetype": "Wide-Load Carrier",
      "subarchetype": "Broad Life Spread",
      "intensity": "high",
      "tags": ["area-breadth-wide", "fragmentation", "load-spread", "high-competition"],
      "triggerConditions": {
        "areasCountMin": 6
      },
      "disqualifiers": null,
      "rootCause": "Your attention is stretched across many parts of life at the same time. Even important things can blur when everything stays wide.",
      "nextDirection": "Loom will narrow what is active right now and hold the rest outside the moment. That makes focusing easier.",
      "rationale": "Strong breadth modifier for users carrying a wide field of long-term concerns."
    },
    {
      "id": "RM052",
      "layer": "modifier",
      "archetype": "Tight-Load Carrier",
      "subarchetype": "Narrow but Unordered",
      "intensity": "low",
      "tags": ["area-breadth-narrow", "order-problem", "few-areas-still-heavy"],
      "triggerConditions": {
        "areasCountExact": 3
      },
      "disqualifiers": null,
      "rootCause": "A smaller set of pressures can still feel heavy when there is no clear order inside it. Fewer areas do not help if the next step still feels unclear.",
      "nextDirection": "Loom will set one result as the main signal. That gives the day a clearer path.",
      "rationale": "Prevents later matching from over-attributing every problem to breadth."
    },
    {
      "id": "MOD_BR_03",
      "layer": "modifier",
      "archetype": "breadth_load",
      "subarchetype": "moderate_span",
      "intensity": "low",
      "tags": ["areas_4", "moderate_breadth", "early_fragmentation"],
      "triggerConditions": {
        "areasCountExact": 4
      },
      "disqualifiers": null,
      "rootCause": "The load is not tiny, but it is also not everywhere. That means the main problem may be order more than the amount itself.",
      "nextDirection": "Loom will help one result rise above the rest instead of treating all four pulls as equal. That makes the day easier to shape.",
      "rationale": "Adds a 4-area modifier missing from the earlier set."
    },
    {
      "id": "MOD_BR_04",
      "layer": "modifier",
      "archetype": "breadth_load",
      "subarchetype": "heavy_span",
      "intensity": "medium",
      "tags": ["areas_5", "broad_but_not_extreme", "split_load"],
      "triggerConditions": {
        "areasCountExact": 5
      },
      "disqualifiers": null,
      "rootCause": "A lot of different parts of life are already active in the background. That makes the day easier to feel divided before it even starts.",
      "nextDirection": "Loom will keep all five from demanding equal weight on the same day. One result will lead while the rest wait their turn.",
      "rationale": "Adds a 5-area modifier between narrow and very broad load."
    },
    {
      "id": "MOD_BR_05",
      "layer": "modifier",
      "archetype": "breadth_load",
      "subarchetype": "wide_span_balance_seek",
      "intensity": "high",
      "tags": ["areas_6_7", "feel_balanced", "cross_life_swing"],
      "triggerConditions": {
        "areasCountMin": 6,
        "firstChangeIn": ["feel_balanced"]
      },
      "disqualifiers": null,
      "rootCause": "A wide life spread can make balance feel hard because too many parts keep trying to move at once. That creates more swinging than steadiness.",
      "nextDirection": "Loom will stop the week from treating every part as equally active every day. That makes things feel calmer over time.",
      "rationale": "More specific broad-load modifier for balance-seeking users."
    },
    {
      "id": "MOD_RG_06",
      "layer": "modifier",
      "archetype": "relief_goal",
      "subarchetype": "control_under_urgency",
      "intensity": "medium",
      "tags": ["feel_control", "react_urgent", "containment_need"],
      "triggerConditions": {
        "firstChangeIn": ["feel_control"],
        "planningStyleIn": ["react_urgent"]
      },
      "disqualifiers": null,
      "rootCause": "The day gets pushed around too easily by outside demands. That makes it hard to feel calm because nothing stays steady long enough.",
      "nextDirection": "Loom will choose what leads before urgency does. That gives the day more control and less drifting.",
      "rationale": "Deepens control-seeking beyond the generic version."
    },
    {
      "id": "MOD_RG_07",
      "layer": "modifier",
      "archetype": "relief_goal",
      "subarchetype": "direction_under_fog",
      "intensity": "medium",
      "tags": ["know_what_matters", "not_sure", "clarity_need"],
      "triggerConditions": {
        "firstChangeIn": ["know_what_matters"],
        "stressIn": ["not_sure"]
      },
      "disqualifiers": null,
      "rootCause": "The biggest need is not just relief. It is a clearer signal for what should come first while the bigger picture still feels blurry.",
      "nextDirection": "Loom will make one result clearer than the rest before asking for more. That helps direction show up sooner than total certainty.",
      "rationale": "Specific direction-seeking modifier for uncertainty."
    },
    {
      "id": "MOD_RG_08",
      "layer": "modifier",
      "archetype": "relief_goal",
      "subarchetype": "consistency_under_slip",
      "intensity": "medium",
      "tags": ["follow_through", "plan_offtrack", "hold_need"],
      "triggerConditions": {
        "firstChangeIn": ["follow_through"],
        "planningStyleIn": ["plan_offtrack", "depends_day"]
      },
      "disqualifiers": null,
      "rootCause": "The issue is not only getting started. It is that the path does not stay steady enough after the day changes.",
      "nextDirection": "Loom will make the path shorter and more fixed around one result. That helps progress happen more reliably across days.",
      "rationale": "Sharper consistency modifier for unstable planners."
    },
    {
      "id": "MOD_RG_09",
      "layer": "modifier",
      "archetype": "relief_goal",
      "subarchetype": "progress_under_overload",
      "intensity": "medium",
      "tags": ["faster_progress", "competing_priorities", "throughput_loss"],
      "triggerConditions": {
        "firstChangeIn": ["faster_progress"],
        "stressIn": ["competing_priorities", "behind_disorganized"]
      },
      "disqualifiers": null,
      "rootCause": "The main problem is not effort alone. It is how much progress gets watered down by sorting, switching, and carrying too many open tasks.",
      "nextDirection": "Loom will push more of the day behind one result at a time. That makes progress show up faster in the work that matters most.",
      "rationale": "More specific speed-seeking modifier under overload."
    },
    {
      "id": "MOD_RG_10",
      "layer": "modifier",
      "archetype": "relief_goal",
      "subarchetype": "balance_under_pressure",
      "intensity": "medium",
      "tags": ["feel_balanced", "work_pressure", "money_pressure", "spillover"],
      "triggerConditions": {
        "firstChangeIn": ["feel_balanced"],
        "stressIn": ["work_pressure", "money_pressure"]
      },
      "disqualifiers": null,
      "rootCause": "Pressure in one part of life is starting to spill into everything else. That is why balance feels harder than usual right now.",
      "nextDirection": "Loom will keep one pressure point from taking over the whole week. That helps the rest of your life keep some structure too.",
      "rationale": "More specific balance-seeking modifier under pressure stress."
    },
    {
      "id": "MOD_PS_05",
      "layer": "modifier",
      "archetype": "planning_shape",
      "subarchetype": "stable_but_too_wide",
      "intensity": "medium",
      "tags": ["plan_follow_through", "areas_5_7", "spread_system"],
      "triggerConditions": {
        "planningStyleIn": ["plan_follow_through"],
        "areasCountMin": 5
      },
      "disqualifiers": null,
      "rootCause": "Even a working system can get stretched too wide. The issue may be too much spread, not a lack of discipline.",
      "nextDirection": "Loom will narrow how much your system carries at one time. That lets your structure work with more focus and less spreading.",
      "rationale": "Adds a broad-load planning modifier for strong planners."
    },
    {
      "id": "MOD_PS_06",
      "layer": "modifier",
      "archetype": "planning_shape",
      "subarchetype": "flat_list_under_breadth",
      "intensity": "medium",
      "tags": ["simple_todo", "areas_6_7", "flat_priority", "wide_menu"],
      "triggerConditions": {
        "planningStyleIn": ["simple_todo"],
        "areasCountMin": 6
      },
      "disqualifiers": null,
      "rootCause": "A flat list gets weaker when too many parts of life are inside it. The list gets wider, but the order stays weak.",
      "nextDirection": "Loom will stop the list from acting like one flat pile. It will give one result and one Action Plan more weight first.",
      "rationale": "Specific list modifier for broad area spread."
    },
    {
      "id": "MOD_PS_07",
      "layer": "modifier",
      "archetype": "planning_shape",
      "subarchetype": "urgency_plus_security",
      "intensity": "medium",
      "tags": ["react_urgent", "money_pressure", "outside_pull"],
      "triggerConditions": {
        "planningStyleIn": ["react_urgent"],
        "stressIn": ["money_pressure"]
      },
      "disqualifiers": null,
      "rootCause": "Urgency feels even louder when security already feels under pressure. That makes the day easier to hand over to whatever feels most urgent.",
      "nextDirection": "Loom will decide the order earlier and make fewer things feel active at once. That helps urgency stop running the whole day.",
      "rationale": "Specific urgency modifier under money pressure."
    },
    {
      "id": "MOD_UN_02",
      "layer": "modifier",
      "archetype": "uncertainty_softener",
      "subarchetype": "fog_with_speed_need",
      "intensity": "low",
      "tags": ["not_sure", "faster_progress", "mixed_signals"],
      "triggerConditions": {
        "stressIn": ["not_sure"],
        "firstChangeIn": ["faster_progress"]
      },
      "disqualifiers": null,
      "rootCause": "The pattern may still be blurry, but the cost is already showing up as slower progress. Mixed signals can still create real drag.",
      "nextDirection": "Loom will reduce side choices first so progress can start building sooner. That helps even before every cause has a clear name.",
      "rationale": "Adds uncertainty modifier for speed-seeking users."
    },
    {
      "id": "MOD_UN_03",
      "layer": "modifier",
      "archetype": "uncertainty_softener",
      "subarchetype": "fog_with_balance_need",
      "intensity": "low",
      "tags": ["not_sure", "feel_balanced", "mixed_direction"],
      "triggerConditions": {
        "stressIn": ["not_sure"],
        "firstChangeIn": ["feel_balanced"]
      },
      "disqualifiers": null,
      "rootCause": "You may not fully know the source yet, but you can still feel the week getting out of shape. The imbalance is clear even if the cause is not.",
      "nextDirection": "Loom will create a steadier order across the week before trying to solve every pattern. That brings structure before full certainty.",
      "rationale": "Adds uncertainty modifier for balance-seeking users."
    },
    {
      "id": "MOD_ID_02",
      "layer": "modifier",
      "archetype": "identity_spread",
      "subarchetype": "custom_plus_wide",
      "intensity": "medium",
      "tags": ["custom_area", "areas_5_7", "identity_variance", "mapping_gap"],
      "triggerConditions": {
        "requiresCustomArea": true,
        "areasCountMin": 5
      },
      "disqualifiers": null,
      "rootCause": "Part of your load may not fit the usual map, and the full picture is already wide. That can make direction weaker because the map still feels incomplete.",
      "nextDirection": "Loom will still force one result to lead even if the full map is not clear yet. That keeps progress from waiting on perfect labels.",
      "rationale": "Stronger custom-area modifier when breadth is also high."
    },
    {
      "id": "MOD_SP_01",
      "layer": "modifier",
      "archetype": "spread_meaning",
      "subarchetype": "inner_weighted",
      "intensity": "medium",
      "tags": ["area_spread_inner", "self_rebuild_load", "internal_pressure"],
      "triggerConditions": {
        "areaSpreadIn": ["inner_weighted"]
      },
      "disqualifiers": null,
      "rootCause": "A lot of the pressure is happening inside you, not just around you. That can make the day feel heavy even when the outside looks manageable.",
      "nextDirection": "Loom will reduce how many inner demands feel active at once. That makes it easier for one clear result to stand out.",
      "rationale": "Captures inward, self-regulation-heavy spread."
    },
    {
      "id": "MOD_SP_02",
      "layer": "modifier",
      "archetype": "spread_meaning",
      "subarchetype": "outer_weighted",
      "intensity": "medium",
      "tags": ["area_spread_outer", "external_demand", "performance_load"],
      "triggerConditions": {
        "areaSpreadIn": ["outer_weighted"]
      },
      "disqualifiers": null,
      "rootCause": "More of the pressure is coming from outside demands and visible responsibilities. That can make the day feel more forced than chosen.",
      "nextDirection": "Loom will give one result the lead before outside demands spread too wide. That helps the day feel less driven by outside pressure.",
      "rationale": "Captures outward, performance-heavy spread."
    },
    {
      "id": "MOD_SP_03",
      "layer": "modifier",
      "archetype": "spread_meaning",
      "subarchetype": "home_relational_weighted",
      "intensity": "medium",
      "tags": ["area_spread_relational", "spillover", "personal_life_noise"],
      "triggerConditions": {
        "areaSpreadIn": ["home_relational_weighted"]
      },
      "disqualifiers": null,
      "rootCause": "More of the pressure is tied to personal life and close relationships. That can make the rest of the day easier to knock off track.",
      "nextDirection": "Loom will keep one result more clearly in front of you even when personal-life noise is present. That helps the day stay steadier.",
      "rationale": "Captures relational and home-heavy spread."
    },
    {
      "id": "MOD_SP_04",
      "layer": "modifier",
      "archetype": "spread_meaning",
      "subarchetype": "growth_weighted",
      "intensity": "low",
      "tags": ["area_spread_growth", "future_building", "aspiration_load"],
      "triggerConditions": {
        "areaSpreadIn": ["growth_weighted"]
      },
      "disqualifiers": null,
      "rootCause": "A lot of the pressure is about building, improving, or becoming something over time. That can make the day feel full of future demands all at once.",
      "nextDirection": "Loom will stop the future from demanding action all at once. It will help one result carry the focus first.",
      "rationale": "Captures growth-heavy spread without sounding motivational."
    },
    {
      "id": "MOD_SP_05",
      "layer": "modifier",
      "archetype": "spread_meaning",
      "subarchetype": "mixed_wide",
      "intensity": "high",
      "tags": ["area_spread_mixed", "broad_competition", "cross_life_fragmentation"],
      "triggerConditions": {
        "areaSpreadIn": ["mixed_wide"]
      },
      "disqualifiers": null,
      "rootCause": "The pressure is spread across very different parts of life, not just one area. That makes it harder for the day to feel centered.",
      "nextDirection": "Loom will stop a wide life spread from feeling equally active at the same time. One result will lead while the rest wait.",
      "rationale": "Captures truly broad mixed spread."
    },
    {
      "id": "MOD_RG_11",
      "layer": "modifier",
      "archetype": "relief_goal",
      "subarchetype": "control_under_hidden_break",
      "intensity": "medium",
      "tags": ["feel_control", "breaks_not_sure", "containment_need"],
      "triggerConditions": {
        "firstChangeIn": ["feel_control"],
        "breaksFirstIn": ["not_sure"]
      },
      "disqualifiers": null,
      "rootCause": "Part of the stress is that the problem feels hard to pin down. When the weak spot stays vague, the day feels harder to hold together.",
      "nextDirection": "Loom will make the day feel steadier before every cause is fully clear. That helps you feel more settled sooner.",
      "rationale": "Specific control-seeking modifier for hidden-break cases."
    },
    {
      "id": "MOD_RG_12",
      "layer": "modifier",
      "archetype": "relief_goal",
      "subarchetype": "direction_under_hidden_break",
      "intensity": "medium",
      "tags": ["know_what_matters", "breaks_not_sure", "priority_need"],
      "triggerConditions": {
        "firstChangeIn": ["know_what_matters"],
        "breaksFirstIn": ["not_sure"]
      },
      "disqualifiers": null,
      "rootCause": "The day may be breaking down in ways that are still hard to name. That makes it harder for one priority to stand out clearly.",
      "nextDirection": "Loom will make one result lead before the full pattern is obvious. That brings direction sooner than a full explanation.",
      "rationale": "Specific direction-seeking modifier for hidden-break cases."
    },
    {
      "id": "MOD_PS_08",
      "layer": "modifier",
      "archetype": "planning_shape",
      "subarchetype": "stable_system_under_fog",
      "intensity": "low",
      "tags": ["plan_follow_through", "not_sure", "clarity_gap", "stable_override"],
      "triggerConditions": {
        "planningStyleIn": ["plan_follow_through"],
        "stressIn": ["not_sure"]
      },
      "disqualifiers": null,
      "rootCause": "You may have structure, but the current pattern still feels hard to read. That makes even a good system feel less steady than usual.",
      "nextDirection": "Loom will give your system one clearer target even while the bigger pattern stays mixed. That keeps the structure usable in the fog.",
      "rationale": "Planning modifier for stable users under ambiguity."
    }
  ],
  "bridgeCandidates": [
    {
      "id": "BRIDGE_01",
      "layer": "bridge",
      "archetype": "load_conflict",
      "subarchetype": "urgency_masked_overload",
      "intensity": "high",
      "tags": ["competing_priorities", "react_urgent", "start_friction"],
      "triggerConditions": {
        "stressIn": ["competing_priorities"],
        "breaksFirstIn": ["dont_start", "overthink"],
        "planningStyleIn": ["react_urgent"]
      },
      "disqualifiers": null,
      "rootCause": "It looks like urgency is the problem, but the deeper issue is that too many things are being treated as urgent at the same time. That blocks a clean start.",
      "nextDirection": "Loom will decide what comes first before the noise does. That turns the day from many urgent feelings into one real direction.",
      "rationale": "Blended case where overload and urgency reinforce each other."
    },
    {
      "id": "BRIDGE_02",
      "layer": "bridge",
      "archetype": "low_structure",
      "subarchetype": "list_without_filter",
      "intensity": "medium",
      "tags": ["simple_todo", "overthink", "behind_disorganized"],
      "triggerConditions": {
        "stressIn": ["behind_disorganized", "not_sure"],
        "breaksFirstIn": ["overthink"],
        "planningStyleIn": ["simple_todo"]
      },
      "disqualifiers": null,
      "rootCause": "Writing things down has helped you keep track of the load, but not sort it well enough. So the list exists, but your mind still has to do too much sorting.",
      "nextDirection": "Loom will turn stored items into a real order with one result at the top. That lowers the mental load the list still leaves behind.",
      "rationale": "Common case where the list is useful but not sufficient."
    },
    {
      "id": "BRIDGE_03",
      "layer": "bridge",
      "archetype": "pressure_tunnel",
      "subarchetype": "pressure_turns_into_thinking",
      "intensity": "high",
      "tags": ["work_pressure", "money_pressure", "overthink", "freeze"],
      "triggerConditions": {
        "stressIn": ["work_pressure", "money_pressure"],
        "breaksFirstIn": ["overthink", "dont_start"],
        "planningStyleIn": ["depends_day", "simple_todo", "react_urgent"]
      },
      "disqualifiers": null,
      "rootCause": "Pressure is making each move feel heavier than normal. When choices feel costly, your mind tries to protect you by delaying action.",
      "nextDirection": "Loom will shrink the field and make the next step easier to trust. That helps the day move without solving every risk first.",
      "rationale": "Better fit than pure pressure or pure thinking-loop entries alone."
    },
    {
      "id": "BRIDGE_04",
      "layer": "bridge",
      "archetype": "energy_drag",
      "subarchetype": "wide_load_low_battery",
      "intensity": "high",
      "tags": ["low_energy", "areas_6_7", "momentum_loss"],
      "triggerConditions": {
        "stressIn": ["low_energy"],
        "breaksFirstIn": ["lose_momentum", "dont_finish"],
        "areasCountMin": 6
      },
      "disqualifiers": null,
      "rootCause": "Your system is carrying a wide load with limited energy. That makes even good effort fade early because too much is drawing from the same source.",
      "nextDirection": "Loom will stop spreading effort so widely in the same day. It will give one result your energy first and let the rest wait.",
      "rationale": "Important blended case of capacity strain plus broad life spread."
    },
    {
      "id": "BRIDGE_05",
      "layer": "bridge",
      "archetype": "social_noise",
      "subarchetype": "strain_makes_day_variable",
      "intensity": "medium",
      "tags": ["relationship_tension", "depends_day", "follow_through_need"],
      "triggerConditions": {
        "stressIn": ["relationship_tension"],
        "planningStyleIn": ["depends_day"],
        "firstChangeIn": ["follow_through", "feel_balanced"]
      },
      "disqualifiers": null,
      "rootCause": "The day is not changing just by chance. It is changing because inner noise keeps shifting how much attention you can hold.",
      "nextDirection": "Loom will give the week a steadier path so the day does not depend as much on the moment. That helps progress feel less fragile.",
      "rationale": "More precise than either variable-day or social-noise alone."
    },
    {
      "id": "BRIDGE_06",
      "layer": "bridge",
      "archetype": "stable_but_spread_thin",
      "subarchetype": "good_planner_many_fronts",
      "intensity": "medium",
      "tags": ["plan_follow_through", "areas_6_7", "faster_progress"],
      "triggerConditions": {
        "planningStyleIn": ["plan_follow_through"],
        "areasCountMin": 6,
        "firstChangeIn": ["faster_progress", "feel_balanced"]
      },
      "disqualifiers": null,
      "rootCause": "The main issue may not be discipline at all. It may be that too many fronts are trying to move at the same time, so progress gets watered down.",
      "nextDirection": "Loom will stop asking every front to move together. It will give one result the lead first, so your effort can build instead of split.",
      "rationale": "Important high-functioning edge case."
    },
    {
      "id": "BRIDGE_07",
      "layer": "bridge",
      "archetype": "load_conflict",
      "subarchetype": "flat_list_overload_scatter",
      "intensity": "high",
      "tags": ["competing_priorities", "simple_todo", "get_distracted"],
      "triggerConditions": {
        "stressIn": ["competing_priorities"],
        "breaksFirstIn": ["get_distracted"],
        "planningStyleIn": ["simple_todo"]
      },
      "disqualifiers": null,
      "rootCause": "Too much is competing, and the flat list is not strong enough to sort it. That makes your attention easy to pull sideways.",
      "nextDirection": "Loom will turn the pile into one leading result and a short Action Plan. That gives your focus a stronger center than a flat list can.",
      "rationale": "Common blended case: overload plus list-based weak filtering."
    },
    {
      "id": "BRIDGE_08",
      "layer": "bridge",
      "archetype": "load_conflict",
      "subarchetype": "overload_loop_balance_seek",
      "intensity": "medium",
      "tags": ["competing_priorities", "overthink", "feel_balanced"],
      "triggerConditions": {
        "stressIn": ["competing_priorities"],
        "breaksFirstIn": ["overthink"],
        "firstChangeIn": ["feel_balanced"]
      },
      "disqualifiers": null,
      "rootCause": "You keep thinking about how to give every part of life a fair place, so the next step gets delayed. Balance turns into extra sorting.",
      "nextDirection": "Loom will let one result lead right now without asking the whole week to move at once. That lowers the pressure to balance everything in one moment.",
      "rationale": "Captures overload plus balance-seeking as a distinct loop."
    },
    {
      "id": "BRIDGE_09",
      "layer": "bridge",
      "archetype": "low_structure",
      "subarchetype": "urgent_mess_cycle",
      "intensity": "high",
      "tags": ["behind_disorganized", "react_urgent", "get_distracted"],
      "triggerConditions": {
        "stressIn": ["behind_disorganized"],
        "breaksFirstIn": ["get_distracted", "lose_momentum"],
        "planningStyleIn": ["react_urgent"]
      },
      "disqualifiers": null,
      "rootCause": "The backlog and urgency keep feeding each other. Loose tasks stay visible, and the loudest one keeps stealing your attention next.",
      "nextDirection": "Loom will stop the mess from deciding the order on its own. One result will lead before the loose ends do.",
      "rationale": "Specific disorganized-plus-urgency loop."
    },
    {
      "id": "BRIDGE_10",
      "layer": "bridge",
      "archetype": "low_structure",
      "subarchetype": "broad_backlog_open_loops",
      "intensity": "high",
      "tags": ["behind_disorganized", "dont_finish", "areas_6_7"],
      "triggerConditions": {
        "stressIn": ["behind_disorganized"],
        "breaksFirstIn": ["dont_finish"],
        "areasCountMin": 6
      },
      "disqualifiers": null,
      "rootCause": "Too many parts of life are carrying unfinished work at the same time. That makes finishing feel rare because the open loops keep multiplying.",
      "nextDirection": "Loom will stop the week from carrying so many open fronts at the same time. That gives finishing more room to happen.",
      "rationale": "Distinct backlog-plus-breadth finish case."
    },
    {
      "id": "BRIDGE_11",
      "layer": "bridge",
      "archetype": "pressure_tunnel",
      "subarchetype": "work_pressure_stable_start_block",
      "intensity": "medium",
      "tags": ["work_pressure", "dont_start", "plan_follow_through"],
      "triggerConditions": {
        "stressIn": ["work_pressure"],
        "breaksFirstIn": ["dont_start"],
        "planningStyleIn": ["plan_follow_through"]
      },
      "disqualifiers": null,
      "rootCause": "The issue is not that you lack a system. Pressure is making the first move feel too heavy, even inside a system that usually works.",
      "nextDirection": "Loom will lower the load at the start and keep one result in front. That helps your structure start moving sooner under pressure.",
      "rationale": "Important high-functioning work-pressure start case."
    },
    {
      "id": "BRIDGE_12",
      "layer": "bridge",
      "archetype": "pressure_tunnel",
      "subarchetype": "money_pressure_reactive_scatter",
      "intensity": "medium",
      "tags": ["money_pressure", "get_distracted", "react_urgent"],
      "triggerConditions": {
        "stressIn": ["money_pressure"],
        "breaksFirstIn": ["get_distracted"],
        "planningStyleIn": ["react_urgent"]
      },
      "disqualifiers": null,
      "rootCause": "Security pressure keeps making new demands feel more urgent than they really are. That makes your attention easier to hand over to the next intense signal.",
      "nextDirection": "Loom will set the order before urgency gets the first say. That gives your focus a steadier path under pressure.",
      "rationale": "Specific money-pressure plus urgency-reactive distraction case."
    },
    {
      "id": "BRIDGE_13",
      "layer": "bridge",
      "archetype": "energy_drag",
      "subarchetype": "low_energy_balance_loop",
      "intensity": "medium",
      "tags": ["low_energy", "overthink", "feel_balanced"],
      "triggerConditions": {
        "stressIn": ["low_energy"],
        "breaksFirstIn": ["overthink"],
        "firstChangeIn": ["feel_balanced"]
      },
      "disqualifiers": null,
      "rootCause": "Low energy makes every tradeoff feel more intense, so you keep thinking about where the day should go instead of using the energy you still have.",
      "nextDirection": "Loom will simplify the week so one result can lead without forcing every part of life to move equally. That lowers the mental load on tired days.",
      "rationale": "Distinct low-energy plus balance-seeking overthinking case."
    },
    {
      "id": "BRIDGE_14",
      "layer": "bridge",
      "archetype": "social_noise",
      "subarchetype": "relational_noise_variable_start",
      "intensity": "medium",
      "tags": ["relationship_tension", "dont_start", "depends_day"],
      "triggerConditions": {
        "stressIn": ["relationship_tension"],
        "breaksFirstIn": ["dont_start"],
        "planningStyleIn": ["depends_day"]
      },
      "disqualifiers": null,
      "rootCause": "The day is hard to start because inner noise keeps changing how available your attention feels. Some days the doorway just feels blocked.",
      "nextDirection": "Loom will give the day one simpler starting point even when the rest feels uneven. That makes starting less dependent on how the day feels.",
      "rationale": "Specific relationship-tension plus variable-day start case."
    },
    {
      "id": "BRIDGE_15",
      "layer": "bridge",
      "archetype": "diffuse_uncertainty",
      "subarchetype": "foggy_loop_direction_seek",
      "intensity": "medium",
      "tags": ["not_sure", "overthink", "know_what_matters"],
      "triggerConditions": {
        "stressIn": ["not_sure"],
        "breaksFirstIn": ["overthink"],
        "firstChangeIn": ["know_what_matters"]
      },
      "disqualifiers": null,
      "rootCause": "You keep trying to think your way into a clear direction before acting. The search for the right path is becoming the thing that slows the day.",
      "nextDirection": "Loom will choose one result to make the day clearer sooner. That helps direction show up before the whole problem is solved.",
      "rationale": "Distinct uncertain-overthinking plus direction-seeking case."
    },
    {
      "id": "BRIDGE_16",
      "layer": "bridge",
      "archetype": "diffuse_uncertainty",
      "subarchetype": "foggy_freeze_control_seek",
      "intensity": "medium",
      "tags": ["not_sure", "dont_start", "feel_control"],
      "triggerConditions": {
        "stressIn": ["not_sure"],
        "breaksFirstIn": ["dont_start"],
        "firstChangeIn": ["feel_control"]
      },
      "disqualifiers": null,
      "rootCause": "You may be waiting for the day to feel clearer before you start. That makes starting hard because your mind wants certainty before action.",
      "nextDirection": "Loom will give the day one clear starting point first. That creates more steadiness before every answer is known.",
      "rationale": "Distinct uncertain-start plus control-seeking case."
    },
    {
      "id": "BRIDGE_HB_01",
      "layer": "bridge",
      "archetype": "hidden_breakpoint",
      "subarchetype": "overload_hidden_break",
      "intensity": "medium",
      "tags": ["competing_priorities", "breaks_not_sure", "hidden_break", "broad_load"],
      "triggerConditions": {
        "stressIn": ["competing_priorities"],
        "breaksFirstIn": ["not_sure"]
      },
      "disqualifiers": null,
      "rootCause": "You can feel too much competing at once, even if the exact problem is still hard to name. The day gets crowded before one thing can take hold.",
      "nextDirection": "Loom will reduce how much is active at the same time and let one result lead. That helps the hidden problem show up more clearly.",
      "rationale": "Stress-specific hidden-break entry for overload."
    },
    {
      "id": "BRIDGE_HB_02",
      "layer": "bridge",
      "archetype": "hidden_breakpoint",
      "subarchetype": "disorganization_hidden_break",
      "intensity": "medium",
      "tags": ["behind_disorganized", "breaks_not_sure", "hidden_break", "shape_gap"],
      "triggerConditions": {
        "stressIn": ["behind_disorganized"],
        "breaksFirstIn": ["not_sure"]
      },
      "disqualifiers": null,
      "rootCause": "You can tell the day feels messy, even if the exact weak spot is still unclear. The work has too little structure for the pattern to show itself clearly.",
      "nextDirection": "Loom will give the day one result and one clearer order first. That makes the hidden problem easier to notice.",
      "rationale": "Stress-specific hidden-break entry for backlog/disorganization."
    },
    {
      "id": "BRIDGE_HB_03",
      "layer": "bridge",
      "archetype": "hidden_breakpoint",
      "subarchetype": "distraction_hidden_break",
      "intensity": "medium",
      "tags": ["distractions", "breaks_not_sure", "hidden_break", "attention_noise"],
      "triggerConditions": {
        "stressIn": ["distractions"],
        "breaksFirstIn": ["not_sure"]
      },
      "disqualifiers": null,
      "rootCause": "You can feel your focus getting pulled away, even if the exact point of failure is hard to name. The day loses structure through small attention leaks.",
      "nextDirection": "Loom will narrow the active load and hold one result more clearly in front of you. That makes attention leaks easier to spot and reduce.",
      "rationale": "Stress-specific hidden-break entry for distraction load."
    },
    {
      "id": "BRIDGE_HB_04",
      "layer": "bridge",
      "archetype": "hidden_breakpoint",
      "subarchetype": "work_hidden_break",
      "intensity": "medium",
      "tags": ["work_pressure", "breaks_not_sure", "hidden_break", "pressure_load"],
      "triggerConditions": {
        "stressIn": ["work_pressure"],
        "breaksFirstIn": ["not_sure"]
      },
      "disqualifiers": null,
      "rootCause": "You can feel the work pressure clearly, even if the exact breaking point is still unclear. The day is carrying more weight than your system can handle cleanly.",
      "nextDirection": "Loom will simplify the day around one result first. That helps the real weak spot stand out under pressure.",
      "rationale": "Stress-specific hidden-break entry for work pressure."
    },
    {
      "id": "BRIDGE_HB_05",
      "layer": "bridge",
      "archetype": "hidden_breakpoint",
      "subarchetype": "money_hidden_break",
      "intensity": "medium",
      "tags": ["money_pressure", "breaks_not_sure", "hidden_break", "security_weight"],
      "triggerConditions": {
        "stressIn": ["money_pressure"],
        "breaksFirstIn": ["not_sure"]
      },
      "disqualifiers": null,
      "rootCause": "The pressure is clear, but the exact weak spot may still be hard to pin down. Security stress can hide inside many small choices across the day.",
      "nextDirection": "Loom will reduce how many choices stay active at once. That helps the real breaking point show up with less noise around it.",
      "rationale": "Stress-specific hidden-break entry for money pressure."
    },
    {
      "id": "BRIDGE_HB_06",
      "layer": "bridge",
      "archetype": "hidden_breakpoint",
      "subarchetype": "energy_hidden_break",
      "intensity": "medium",
      "tags": ["low_energy", "breaks_not_sure", "hidden_break", "capacity_shift"],
      "triggerConditions": {
        "stressIn": ["low_energy"],
        "breaksFirstIn": ["not_sure"]
      },
      "disqualifiers": null,
      "rootCause": "You can feel the energy strain, even if the exact breaking point is hard to name. Low energy can blur whether the problem is starting, staying with it, or finishing.",
      "nextDirection": "Loom will make the day smaller and more ordered first. That helps the real energy limit show itself more clearly.",
      "rationale": "Stress-specific hidden-break entry for low energy."
    },
    {
      "id": "BRIDGE_HB_07",
      "layer": "bridge",
      "archetype": "hidden_breakpoint",
      "subarchetype": "relationship_hidden_break",
      "intensity": "medium",
      "tags": ["relationship_tension", "breaks_not_sure", "hidden_break", "spillover_noise"],
      "triggerConditions": {
        "stressIn": ["relationship_tension"],
        "breaksFirstIn": ["not_sure"]
      },
      "disqualifiers": null,
      "rootCause": "You can feel the strain, even if the exact way it disrupts the day is still blurry. Spillover can hide in your attention, pace, or ability to finish.",
      "nextDirection": "Loom will keep the day more centered around one result first. That makes the real problem easier to see through the noise.",
      "rationale": "Stress-specific hidden-break entry for relationship tension."
    },
    {
      "id": "BRIDGE_ST_01",
      "layer": "bridge",
      "archetype": "stable_system_override",
      "subarchetype": "stable_overload_direction_seek",
      "intensity": "medium",
      "tags": ["plan_follow_through", "competing_priorities", "know_what_matters", "overthink"],
      "triggerConditions": {
        "planningStyleIn": ["plan_follow_through"],
        "stressIn": ["competing_priorities"],
        "firstChangeIn": ["know_what_matters"],
        "breaksFirstIn": ["overthink", "not_sure"]
      },
      "disqualifiers": null,
      "rootCause": "You may already know how to use a system, but too many fronts are still competing to come first. That keeps clear direction from settling quickly enough.",
      "nextDirection": "Loom will stop the day from asking every front to lead at once. One result will come first so direction feels clearer sooner.",
      "rationale": "High-functioning overload plus direction-seeking bridge."
    },
    {
      "id": "BRIDGE_ST_02",
      "layer": "bridge",
      "archetype": "stable_system_override",
      "subarchetype": "stable_uncertainty_control_seek",
      "intensity": "medium",
      "tags": ["plan_follow_through", "not_sure", "feel_control", "hidden_break"],
      "triggerConditions": {
        "planningStyleIn": ["plan_follow_through"],
        "stressIn": ["not_sure"],
        "firstChangeIn": ["feel_control"],
        "breaksFirstIn": ["not_sure", "get_distracted"]
      },
      "disqualifiers": null,
      "rootCause": "The issue may not be structure. It may be that the current pattern feels too unclear to follow with confidence, even inside a working system.",
      "nextDirection": "Loom will simplify the day around one result before the full pattern is solved. That brings steadiness back faster.",
      "rationale": "High-functioning uncertainty plus control-seeking bridge."
    }
  ],
  "fallbackCandidates": [
    {
      "id": "RF053",
      "layer": "fallback",
      "archetype": "Unclear Break",
      "subarchetype": "Hidden Failure Point",
      "intensity": "low",
      "tags": ["break-unclear", "known-stress", "low-confidence-safe"],
      "triggerConditions": {
        "breaksFirstIn": ["not_sure"],
        "stressIn": ["competing_priorities", "behind_disorganized", "distractions", "work_pressure", "money_pressure", "low_energy", "relationship_tension"]
      },
      "disqualifiers": null,
      "rootCause": "The problem shows up, but the weak spot is still hard to name. That makes it harder to fix because the problem stays in the background.",
      "nextDirection": "Loom will simplify the day around one result and a short order. That makes the weak spot easier to see.",
      "rationale": "Safe response when stress is known but the failure point is unclear."
    },
    {
      "id": "RF054",
      "layer": "fallback",
      "archetype": "Double Ambiguity",
      "subarchetype": "Blurred Pressure and Break",
      "intensity": "low",
      "tags": ["stress-unclear", "break-unclear", "ambiguity", "low-confidence-safe"],
      "triggerConditions": {
        "stressIn": ["not_sure"],
        "breaksFirstIn": ["not_sure"]
      },
      "disqualifiers": null,
      "rootCause": "Both the pressure and the weak spot are still blurry. When the shape is unclear, the day can drift or tense up randomly.",
      "nextDirection": "Loom will give the day one small center first. That creates clarity without needing the full answer right away.",
      "rationale": "Safest response for the lowest-clarity combination."
    },
    {
      "id": "RF055",
      "layer": "fallback",
      "archetype": "Moving Puzzle",
      "subarchetype": "Variable Mixed Pattern",
      "intensity": "low",
      "tags": ["mixed-signals", "depends-on-day", "break-unclear", "stability-need"],
      "triggerConditions": {
        "planningStyleIn": ["depends_day"],
        "breaksFirstIn": ["not_sure"]
      },
      "disqualifiers": null,
      "rootCause": "Your days change faster than your system can adjust. Without a steady center, each day feels like a new puzzle.",
      "nextDirection": "Loom will hold one result steady and make the day smaller around it. That gives you one thing that stays stable.",
      "rationale": "Useful for variable-day users when signals are mixed and unstable."
    }
  ]
}
"""
