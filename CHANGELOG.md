# XIVTarget

## 0.5.0

### Class
- New text word **class**: a player's class, in its class colour (the colour can be turned off on the Text page). For monsters and NPCs it shows their creature type instead (Beast, Undead, Demon...), handy for spells that only work on some types. It works in any text: above the bar, your target's target, and the new power text.
- **Class icons**: switch on "Class (players)" on the Icons page to show a player's class icon first in the icon row beside the name. It also shows before your target's target's name (can be turned off), and has its own size setting. Off by default.

### Power
- New text words for the target's mana, rage or energy: **power**, **powermax**, **powerpercent** (**powerpercent.1** for a decimal) and **powertype** (its name, such as "Mana" or "Rage"). They work in any text, including your target's target's.
- A **power bar**, on the new Power page: a slimmer FFXIV gauge under the health bar, in the game's colours for mana, rage and energy. Set its height, its length (as a share of the bar), whether it lines up under the left end, the middle or the right end, the gap below the bar and a left / right nudge. Off by default, so your layout stays as it is.
- The power bar has its own text, under its right end (the power's value by default; any words work, and value, max and percent mean the power there). Empty hides it.
- It hides for targets with no power at all, and while it's empty (an enemy warrior that hasn't built any rage), coming back as soon as there's some. After it empties it waits a few seconds before going. Can be turned off.
- Status effects move down to make room for the power bar when it's on.
- While unlocked, the power bar, its text and the class icon show samples like the rest.

### Options
- Shift-click a setting's + or - to change it ten steps at a time.

### Cast bar
- Casts whose spell the game hides from add-ons now show on the cast bar instead of causing an error.
- While unlocked, the sample cast shows with a target too (not only with nothing targeted), so the cast bar can always be placed.

### Blizzard's target frame
- **Hide Blizzard's target frame** now holds through combat and Edit Mode: it goes at once, even mid-fight, instead of waiting for the fight to end, and stays gone when the game lays it out again. It also works alongside other add-ons that hide it.

### Fixes
- Text with more than six words now keeps updating.
- A level of 0 shows as "??", as the game's own frame shows it.

### Colours
- "Reaction" colours now grey out enemies someone else has tapped and show players in their class colour, as FrogTarget's do.

### Under the hood
- Text, colours, icons and the click buttons are FrogLib's, shared with FrogTarget and FrogFrames.

## 0.4.3

### Under the hood
- Shares its options page and its texture and font lists with the other Frog Wizard add-ons (one copy of the code, so a fix reaches them all at once). Nothing changes in how it looks or works.

## 0.4.2

### Fixes
- Names include the surname on Forever, as the game's own frames show them (it showed only the first name).

### Options
- Listed with the rest of Frog Wizard's add-ons: under a "Frog Wizard" heading in the AddOn list, and in its own "Frog Wizard" section of Options > AddOns, whose page lists them all with a button to each one's settings.

## 0.4.1

### Fixes
- Fixed a "file not found" font error after EllesmereUI is turned off or removed while its font (Expressway) is chosen. The game's standard font is used until you pick another.
- Hiding Blizzard's target frame now works alongside other add-ons that hide it the same way, instead of the two undoing each other.

## 0.4.0

### Blizzard's target frame
- New **Hide Blizzard's target frame** setting (Bar page), off by default. Its target-of-target and cast bar go with it; XIVTarget shows both. Combo points are drawn on Blizzard's target frame, so they stay where they were. Turned on or off in combat, it takes effect once combat ends.

## 0.3.2

- No changes in the game. From this version, releases are published automatically to CurseForge and GitHub.

## 0.3.1

### Options
- Now listed in the game's Options > AddOns, with a button that opens its settings and a list of its slash commands.

### Fixes
- Fixed a "forbidden object" error that could appear when status-effect text updated in restricted content (for example in combat).
