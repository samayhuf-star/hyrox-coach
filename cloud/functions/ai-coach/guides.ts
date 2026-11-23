// Short English reference notes the Coach may quote from.
//
// Training approach condensed and translated from the MIT-licensed "hyrox-training-skill"
// (c) 2026 HYROX备赛指南, https://github.com/samayhuf-star/hyrox-training-skill (see NOTICE.md).
// Every race fact below (order, distances, weights, target heights, penalties, team formats) was
// checked against the official HYROX 2026/27 Singles, Doubles and Relay rulebooks, not taken from
// the skill. Benchmark finishing times and medical or supplement advice were left out on purpose.
// Hybrid Training is not affiliated with HYROX.

export type Guide = { id: string; title: string; keywords: string[]; text: string };

export const SEASON = '2026/27';

export const guides: Guide[] = [
  {
    id: 'race-format',
    title: 'Race format and official station standards',
    keywords: ['hyrox', 'format', 'station', 'stations', 'order', 'distance', 'weight', 'weights', 'kg', 'division', 'open', 'pro', 'how far', 'how heavy', 'how long', 'course', 'wall ball height', 'target'],
    text: `A race is 8 x 1 km runs, each followed by one station, always in this order: 1) SkiErg 1000 m, 2) Sled Push 50 m (4 x 12.5 m), 3) Sled Pull 50 m (4 x 12.5 m), 4) Burpee Broad Jumps 80 m, 5) Rowing 1000 m, 6) Farmers Carry 200 m, 7) Sandbag Lunges 100 m, 8) Wall Balls 100 reps.
Weights by division (Women Open / Men Open and Women Pro / Men Pro): Sled Push 102 / 152 / 202 kg including sled; Sled Pull 78 / 103 / 153 kg including sled; Farmers Carry 2 x 16 / 2 x 24 / 2 x 32 kg; Lunges sandbag 10 / 20 / 30 kg; Wall Ball 4 / 6 / 9 kg. Wall ball target height: 2.70 m for women's divisions, 3.00 m for men's. Running distance is the same in every division.
Total running is 8 km, so most of the race is running: a comfortable, repeatable run pace matters more than any single station.`
  },
  {
    id: 'rules-penalties',
    title: 'Common penalties',
    keywords: ['rule', 'rules', 'penalty', 'penalties', 'disqualified', 'dq', 'no rep', 'chalk', 'judge', 'allowed', 'legal', 'illegal', 'infringement'],
    text: `Penalties people most often pick up (${SEASON} Singles rulebook): lunge with the trailing knee not touching the ground or not standing tall: 15 seconds each time; taking the sandbag off the shoulders: 15 seconds each time; burpee broad jump faults: 15 seconds each; touching the SkiErg or rower handle before feet are set on the base or footplates: 15 seconds; kettlebells returned incorrectly: 30 seconds; outside assistance: 2 minutes; wrong station entry or exit: 2 minutes; doing stations out of order: 3 minutes the first time, then disqualification; skipping a run or station, leaving the SkiErg, rower or wall balls before the full amount, missing a sled lane or a carry lap, or using the wrong weight on carry or lunges: disqualification.
Chalk is allowed only at Sled Pull and Farmers Carry and only the chalk the event provides; anywhere else, or your own chalk, is 2 minutes. Wall balls have no warnings: a throw is either a rep or a no-rep. Rules change between seasons, so check the current official rulebook before race day.`
  },
  {
    id: 'pacing',
    title: 'Pacing and race-day strategy',
    keywords: ['pace', 'pacing', 'strategy', 'tactic', 'race day', 'split', 'splits', 'blow up', 'too fast', 'heart rate', 'plan my race', 'go out'],
    text: `Fatigue builds across the race, so the plan is to arrive at the last three stations with something left.
Opening (SkiErg, first runs, Sled Push): start below the effort that feels right. Hold one steady rhythm on the SkiErg and never sprint the first 200 m. The sled push is the first big spike in effort; short steps, steady pressure.
Middle (Sled Pull, Burpee Broad Jumps, Row): treat these as controlled work. Keep burpee jumps small and even; rhythm beats distance per jump. Use the row to bring breathing back under control.
Closing (Farmers Carry, Lunges, Wall Balls): grip is the limit on the carry, so plan set-downs before you are forced into them. On lunges, stability beats speed. Break wall balls into planned sets from the first rep rather than going to failure.
Runs: aim for even 1 km splits; the run right after the sleds and after lunges will feel worst, and that is normal. A useful effort guide is 7 out of 10 for most of the race, saving 9 for the final station and run.`
  },
  {
    id: 'stations-cardio',
    title: 'Technique: SkiErg, Row, Burpee Broad Jump',
    keywords: ['ski', 'skierg', 'row', 'rowing', 'rower', 'burpee', 'burpees', 'broad jump', 'jump', 'technique', 'form', 'how do i'],
    text: `SkiErg: drive with legs and hips, not just arms. Hinge and pull the handles down past the hips with elbows back, then return tall. Keep shoulders down. Hold an even stroke rate; when tired, slow the rate rather than shortening the pull.
Row: order is legs, then lean back slightly, then arms; return arms first, then body, then knees. Push hard with the legs and keep the back neutral. Settle on a split you could hold while breathing steadily.
Burpee Broad Jump: hands down, chest to the floor, stand, then take off and land with both feet together. Stepping back and stepping up is fine and often steadier than hopping. Choose a jump length you can repeat for the whole distance; small steady jumps cost less than big ones followed by standing rests.
Practice idea: alternate short pieces with easy running, for example 500 m SkiErg, 400 m run, 500 m SkiErg, at an effort you could repeat.`
  },
  {
    id: 'stations-strength',
    title: 'Technique: Sled Push, Sled Pull, Farmers Carry, Lunges, Wall Balls',
    keywords: ['sled', 'push', 'pull', 'rope', 'farmer', 'farmers', 'carry', 'kettlebell', 'grip', 'lunge', 'lunges', 'sandbag', 'wall ball', 'wallball', 'wall balls', 'technique', 'form'],
    text: `Sled Push: arms long or bent but fixed, body leaning from the ankles, short quick steps. Keep moving; restarting a stopped sled costs the most.
Sled Pull: sit the hips back with a neutral back and pull hand over hand, or walk backwards with straight arms if that is steadier. Keep the rope clear of your feet.
Farmers Carry: stand tall, shoulders relaxed, quick short steps. Decide where you will set the weights down before grip fails.
Sandbag Lunges: bag secure across the shoulders, trailing knee touches the ground, then stand fully tall on every step. Even steps and an upright torso matter more than speed.
Wall Balls: squat to depth, drive up and release in one motion, catch softly and go straight into the next rep. Plan sets with short fixed rests from the start.
In training, use loads well below race weight until the movement is consistent, and build gradually. If a movement is new, ask a coach to check the setup.`
  },
  {
    id: 'plans',
    title: 'Building a training plan by level and weeks available',
    keywords: ['plan', 'program', 'programme', 'schedule', 'weeks', 'week', 'training plan', 'how many days', 'days a week', 'prepare', 'preparation', 'first race', 'beginner', 'taper', 'build up'],
    text: `Pick the level honestly: newer athletes 3 to 4 sessions a week, experienced 4 to 5, competitive 5 to 6. Every week needs easy running, station practice, strength, and at least one full rest day.
6 weeks or less: weeks 1-2 learn each station at light load plus easy aerobic work; weeks 3-4 run plus 1 to 2 stations in one session; weeks 5-6 a practice of 3 stations, work on the weakest station, then reduce volume.
7 to 12 weeks: weeks 1-2 baseline and easy base; 3-4 technique plus two-station chains; 5-6 longer runs and three-station chains; 7-8 intervals and a longer race-style practice; 9-10 focus on weak stations; 11-12 taper: shorter, easier sessions and rest before race day.
For a first race, running volume of roughly 8 to 10 km a week at an easy effort and training loads around 60 to 70 percent of race weight are sensible starting points. Aim to finish feeling you could do a little more. Adjust for how you feel rather than following any plan mechanically.`
  },
  {
    id: 'chain-training',
    title: 'Run-station-run chain training',
    keywords: ['chain', 'fatigue', 'compromised', 'brick', 'simulation', 'simulate', 'rehearsal', 'legs feel', 'heavy legs', 'after the sled', 'transition', 'transitions', 'run after'],
    text: `The hard part of this sport is not one station; it is running well straight after a station, again and again. Train the change of gear directly.
Short chain (2 to 3 stations, about 15 minutes): run, one station, run. Good early in a build-up and for learning how each station changes your running.
Medium chain (4 to 5 stations, 25 to 30 minutes): for example SkiErg, run, Sled Push, run, Sled Pull; or Row, run, Carry, run, Lunges.
Long chain (6 to 8 stations): a near-full rehearsal, used sparingly, mainly in the last third of a build-up and not in the final week.
Progress from short to long over the weeks. Keep the first chains at an effort where technique stays clean; stop a set when form breaks down. In the app, the "Run-station chain" and "Race rehearsal" sessions follow this pattern and scale distances to your level.`
  },
  {
    id: 'adjusting',
    title: 'Adjusting training load and recovery',
    keywords: ['tired', 'fatigue', 'sore', 'soreness', 'recovery', 'recover', 'rest day', 'overtraining', 'too much', 'sleep', 'adjust', 'rpe', 'deload', 'missed', 'skip'],
    text: `Use a 1 to 10 effort scale: 3-4 easy aerobic, 5-6 steady, 7 hard but repeatable, 8-9 very hard, 10 all out. Most weekly training should sit at 3 to 6, with one or two sessions reaching 7 to 8.
Reduce the next session (lower effort, less volume, or swap to easy movement) when: you feel unusually tired for several days, soreness is still strong the next day, sleep has been poor, or you cannot reach normal efforts. Ordinary muscle soreness 1 to 3 days after a new session is expected; keep moving at a lower intensity.
Missed a session? Skip it rather than doubling up. Returning after a break? Restart a step lower than where you left off.
Stop a session if technique falls apart, or if you have sharp joint pain, dizziness, chest pain or trouble breathing; those need appropriate qualified care, not a training change.`
  },
  {
    id: 'doubles-relay',
    title: 'Doubles and Relay formats',
    keywords: ['doubles', 'double', 'partner', 'pairs', 'relay', 'team', 'teammate', 'teammates', 'four', 'split the work', 'who should', 'assign', 'handover', 'transition zone'],
    text: `Doubles (${SEASON}): both partners run every 1 km together; if one runs ahead there is a 1-minute penalty, and more than 3 such penalties puts the team out of competition. Both must enter each station together and leave together. The station work is shared however the team likes, with one person working at a time. Total work is the same as a singles race, so agree splits and hand-over points for each station in training.
Relay: a team of four. Each member runs 2 x 1 km and does 2 stations; which ones is up to the team, and a member may do theirs back to back or separately. The team must start with all four present.
Assigning stations fairly: start from anything a teammate cannot do, then preferences, then strengths. Avoid giving one person consecutive legs unless they ask; a gap of one or two legs helps recovery. Do not assume an injured or newer teammate should get the two easiest stations: ask what they are willing to take on, and test doubtful assignments in training.`
  },
  {
    id: 'race-day',
    title: 'Race-day preparation and reviewing afterwards',
    keywords: ['race day', 'morning', 'warm up', 'warm-up', 'warmup', 'what to bring', 'checklist', 'nervous', 'after the race', 'review', 'debrief', 'next race', 'improve', 'went wrong', 'cramp'],
    text: `Before: keep the final week light; nothing new on race day (shoes, food, kit). Arrive early, walk the course layout, find the entry and exit of each station, and warm up with easy running plus a few light efforts of the first movements.
During: follow your own plan, not the people around you. If something goes wrong, slow down, breathe, and restart with a smaller target (the next 10 reps, the next lane). If you feel faint, have chest pain, or cannot catch your breath, stop and get help from event staff.
After: write a short review within a day or two while it is fresh. Useful questions: Which station felt best and worst? Were the run splits even, or faster early and slower late? Where did you first feel in trouble? Did sleep, food or warm-up play a part? What is the one thing to change for next time, and how many hours a week can you give it? Turn the answer into the focus of the next training block.`
  }
];

const words = (text: string) => ` ${text.toLowerCase().replace(/[^a-z0-9]+/g, ' ')} `;

/** Picks the notes that best match the question. Returns at most `limit`, best first; none if nothing matches. */
export function pickGuides(question: string, context = '', limit = 2): Guide[] {
  const q = words(question);
  const c = words(context);
  return guides
    .map(guide => {
      let score = 0;
      for (const keyword of guide.keywords) {
        const needle = ` ${keyword} `;
        if (q.includes(needle)) score += keyword.includes(' ') ? 3 : 2;
        else if (c.includes(needle)) score += 1;
      }
      return { guide, score };
    })
    .filter(entry => entry.score >= 2)
    .sort((a, b) => b.score - a.score)
    .slice(0, limit)
    .map(entry => entry.guide);
}

export function referenceBlock(question: string, context = ''): string {
  const picked = pickGuides(question, context);
  if (picked.length === 0) return '';
  return `\n\nReference notes (${SEASON} season; general information, not personal advice):\n` +
    picked.map(guide => `## ${guide.title}\n${guide.text}`).join('\n\n');
}
