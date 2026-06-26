
# future design considerations

- the concepts and ideas in this document capture ideas about what i like and don't like about the game for future implementation
- some of these will be narrow refinements, some will take the form of design guardrails

## the text on screen is hard to read

- when designing the ui, i want the ui elements to be relatively large for readability
- i am 49 and my visiion isn't great
- i generally prefer setting my devices to use 150% text size

## format considerations

- in portrait mode, it is easy to lean into a vertical design, but sometimes you need to fit data and labels on a single row to make better use of real estate
- buttons should be relatively large to make it easy to click

## clock in button

- the text should be 2x bigger
- the background of the button should give a visual indication of progress towards next level
-- 


I want to take a step back from development and think about the direction of this entire project.

# New Dev Roadmap

i spent a few days on vacation, where i was able to stop developing my game and spend time using it instead.  i have developed a number of ideas that I want to work on.  some are duplicative of the existing plan and should be called out, some are changes that should be discussed, and some are brand new concepts that we need to flesh out.

## UI sizing

- I need the UI to be a little chunkier for visibility, with larger text
- most panels should be a bit larger, and the exact size and arrangement of buttons and labels should be examined to find improvements

## minigames

- i like the idea of having multiple minigames to add some energy to transitions
- one idea i had was that a minigame would be used to determine the total amount of legacy that a user received on prestige
- minigame ideas i like
-- match-3 games, the more crystals they match, teh more legacy they keep (percentage of whole, not multiplier)
-- physics/balance game, the longer they go the more of the legacy they keep

## gameplay and layout
- the buy and hire buttons should each get half of the width of the property panel
- each property cycle should be considerably longer than the last
-- in adventure capitalist, by the time you had 5 units the highest income also has a really long wait
-- how do the income cycle times in my game compare to adventure capitalist, and how can i make it feel better

# what's next

please read through all of this information, determine all of the ways the gdd needs to be changed and all of the open questions or discussions that remain. i think there is a lot to talk about

# why would this command require approval to proceed from me
Bash(cd "D:/Claude/American Tycoon" && git checkout main && git merge release --ff-only && echo "=== merged, pushing ===" && git push origin main && echo
      "=== new ma…)
# why would this command require approval to proceed from me

cd "D:/Claude/American Tycoon" && git checkout main && git merge --no-ff feature/source-control-rework -m "Merge feature/source-control-rework into
   main" && git push origin main && echo "=== delete merged feature branches (local+remote) ===" && git branch -d feature/source-control-rework && git
   push origin --delete feature/source-control-rework && git branch -d feature/minigame-library && git push origin --delete feature/minigame-library &&
   echo "=== final branches ===" && git branch -a
# same for this command






Text below clock in button 50% bigger

Rush seems over powered. There should be legacy upgrades for increasing rush bonus. 

Legacy balance is WAY off. Ended first run at 20T and had 16k legacy. 

Holding down legacy upgrade buttons should keep auto buying until release, but slow enough for the user to gauge when to stop. Same for buy buttons. 

When legacy upgrade cycle time, the progress bar doesn't totally fill up let to right any more. It should fill up, just faster

Legacy upgrade to income doesn't reflect on label on property.

Upon first contact, flavor text is underwhelming, should feel like event

Staff upgrade costs in second epoch are WAY too low. If you already have trillions, you can basically afford every upgrade right away. Costs should be low relative to that epoch's economy, you should not be able to afford any staff upgrades at the very beginning of an epoch unless there were missed upgrades from the previous epoch. 

Clock in button label does not reflect increased amount after legacy upgrade


When unclaimed legacy amount has been earned in current run, the estate planning tab should have a small red dot badge in the top right corner to indicate there is something to do. the dot goes away once the user has clicked on that tab.


Hire button should replace the text Hire with a small headshot icon. 

Once it has been purchased, the staff image background changes to the color of that property, and a large headshot symbol in dark gray is centered.

Remove the start button and use the staff image as that button instead. When the staff is not yet purchased, it will show a standard restart icon with a silver background. The player can click it once to activate the property, or hold it down to stay in rush mode. During rush mode, the icon changes from the restart icon to an infinity icon.  If the property has been automated then rush mode is no longer an option for that property except for the highest level property owned. 




===================

# button resizing
- there will be a standard ui button height used across the game
- that height will be equal to 160% of the average size of the current buttons
- the following buttons should be included
-- turbo and buy mode buttons on game screen
-- plan the estate button on the estate planning screen
-- dev - balance tuning button on the settings screen



====================

minigame v2

the following changes should be made to the minigame screen that will affect how this screen appears from the minigame tuning screen as well as during prestige and other times

# all minigames
- a consistent visual theme will be applied to each minigame
- the entire minigame will sit inside of a panel centered on the screen that is 70% the height of the screen and 95% the width of the screen
-- the panel will have an outline of a moderately thick black line
- the top section of the screen will display different objects depending on context
- when the minigame screen is opened from the minigame tuner, then the top section of the screen will have a left-aligned Back button
- when the minigame screen is opened from anywhere else, then the top section of the screen will have a centered text block that describes the purpose of the minigame ("Grow the inheritance", "Fight for alien bonus", etc)
- the file "D:\Claude\American Tycoon\art concepts\minigame_example_layout.png" is a rough layout template of how the "Timing Bar" minigame should be laid out specifically, but also serves as a template for how all minigame screens should be laid out
- every minigame should have a progress bar that only indicates a spectrum of possibilities that range from only keeping 50% to keeping 125% of the legacy points (not units relative to that minigame only)

# match 3
- update to match layout template
- currently, if a single move results in a combo chain of mutiple sequential matches, all of the points for all of the matches are assigned as soon as the player makes the initial move, but instead they should be earned as the action occurs on the screen
- i want to introduce a challenging mechanic
-- each time the game starts it chooses one or more of the gem types at random and assigns quotas that must be met to retain full bonus, and extra gems of the same types can earn stretch goal
-- the required gem types are displayed above the game grid, where each gem symbol is displayed next to the quotas
-- if the player makes a match that is not one of the required types, they lose half as many points as they make for matching the required types

# timing bar
- the "target zone" that is currently a gold bar should move positions every time the user achieves a lock, and it should slowly and linearly lose up to half of it's width as additional locks are achieved
- if the user clicks and misses the lock window, then they should lose a lock

# catch the money
- each money symbol should start 50% larger than it is now
- each time the user clicks on a money symbol, the size of all future money symbols will spawn 5% smaller than the last

# balance the books
- the progress bar should start empty, and only increase while the marker is in the gold zone
- the gold zone / target zone should move back and forth randomly, not too jerky, to keep teh player engaged to following

# 20260624
# estate planning 
- on the estate planning tab, there is a "plan the estate" button at the top of the tab panel.  the wording of this button is confusing.  I want to change the text portion of the button label to say "PASS THE TORCH (+x Legacy)"
- Each estate planning category should have a unique color theme associated with it, and each button and section should be themed with that color
- each estate planning category is collapsible, and all sections are collapsed by default
-- on the same row as the tab title "estate planning", two new buttons should be added that will collapse all and expand all categories on the screen

# estate planning tab badge
- on the estate planning tab, there is a small red dot that displays to notify  the user that there is something new for them to seems
- that dot should be 50% larger, and farther away from teh top left corner is it overlaps with the tab button outline


# match 3 minigame
i want to change the rules of the game to make it more interesting
- there won't be any way for the user to lose progress
- each round one or two gem types are selected as bonus types
- the player earns points for any match
- the more gems in a given match grant higher rewards
- multiple consecutive matches for a single gem switch will gain additional combo bonuses
- when any game switch move happens, if the match contains any of the bonus gem types, then all rewards for the initial matches as well as combo matches are granted 10x points
- the balance for how many points a non-bonus type match earns and how many points a bonus type match earns should be defined by these guidelines
-- if the user spent the entire game time regularly making non-bonus type matches, they should get a reward equal to 100%
-- if the user regularly makes bonus type matches, they will be able to make it to the maximum possible score

# minigame behavior
- at the end of each minigame, the screen should pause with a clear display of the results of the minigame and a large button to continue

# estate planning tab
- on each collapsed category row, add right-aligned text like "+x" where x is the number of upgrade options that the player has enough legacy points to purchased
- that available upgrades count will only display when there are one or more upgrades not yet maxed out





# income per second display
currently, the income per second display changes in ways that are too fast and too random to perceive any rational pattern
Instead of measuring how much cash actually entered the player's wallet over the last few frames, calculate the theoretical income per second mathematically based on the player's current assets.

read this image for information about how the income per second should be calculated

the income per second panel should update once every 100ms to avoid being distracting

# clock in
- the amount of income that can be earned by the clock in button should scale faster
- rather than relying on predetermined title from a random list, the level of the clock in button should be a simple number
-- the text below the clock in button "<job title> - top of the ladder (for now)" should be completely removed
-- on the same row as the clock in button, using 15% of the row width, will be a label that displays "<current level> / <next upgrade tier>"
-- the current pattern of requiring 10 clicks per level, then 20, then 30, should continue, and the level will be equal to the number of times the user has completed the required number of clicks to level up



# properties owned tiers
- the game displays the number of a given property that is owned, as well as how many are needed to reach the next level
- it is not apparent what bonus is rewarded by each level, if there is any
- when the number of properties owned reaches each threshold, a standard game bonus should apply to those properties, consistent with industry standards


# match 3
- only a single bonus gem type should be selected for each round
- matches that do not include a bonus gem type should have their rewards increased 15%
- matches that do include a bonus gem type should have their rewards reduced by 10%
- the progress bar should not have a vertical line in it, the color changes should be enough
- each of the four gem types should use svg images instead of drawing the images on screen, so that i can have more creative control
- the bonus gem type icon above the game board should be 50% larger, pinned to the top of the game board with a small margin, and surrounded by a thick gold outline on a rounded panel with a dark gold background
- the game board should be outlined by a thick dark gold rounded outline

# timing bar
- when the player clicks/presses, the line and target zone should freeze for 0.5 seconds while a quick visual burst of color indicates success or failure
-- on success, the line should become thicker and be white with gold glow
-- on failure, the line should become thicker and be gray with a dark shadow around it

# new minigame idea
- micro basketball
-- a round basket appears and slowly moves around the game board
-- basketballs randomly spawn around the board, and the player can grab a ball and throw it with a swipe motion before letting go to "throw" the basketball at the hoop
-- play gets points for every basket made
-- basketball and basket are both svg images

# all minigames
each minigame should generally shoot for a 20 second game, and scoring should take that into account