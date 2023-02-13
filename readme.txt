AfterCast - Perform action after a cast
---------------------------------------------------------------------------
This is a fairly simple addon for performing actions based on the success
or failure of a cast. Usage is as follows:

/aftercast /smile
/aftercast +fail /cry
/cast Frostbolt(Rank 2)

For this example, if the spell succeeds then you'll smile, if it
fails, then you'll cry. If it is interrupted then nothing will happen.

If the +start event is given, +done must be stated explicitly:

/aftercast +start /p Casting Resurrection...
/aftercast +done /p Resurrection Done!
/cast Resurrection

Events you can use are:

+done	     At the end of successful casting (Default if no event given)
+fail        If the spell fails
+interrupt   If the spell is interrupted
+start       When spell starts casting (Fires before done for instant spells)

Aftercasts apply to the next spell which occurs, and then is reset, you can
set up one of each event before each cast.

Note 1: If a channelled spell is interrupted or fails while being casted,
it will not trigger the "fail" or "interrupt" event, it will always be
"done". This is not a restriction of the AddOn, it's how the API works.

Note 2: The start and end (done/fail/interrupt) events will work properly
only when one spell is casted after the previous spell is finished (cast bar
is empty). Starting a cast while another cast is still running will most
likely produce unwanted result. Also, if a spell is interrupted by the player
shortly before it is finished (e.g. jumping after mounting up), the "fail"
event might trigger even though the spell was actually successful. Higher
latency will increase this effect.

---------------------------------------------------------------------------
These functions can also be gotten at via lua functions
(NOTE: I left them in there, but didn't test them. They do not work in
Macros using /run; they might be used by other AddOns...)

AfterCast(doneAction, failAction);
   Shortcut to set up the 2 most common actions, either can be nil.

AfterCastOn(event, action)
   Set up a specific action (use without the +, so "done", "fail", etc)

AfterCastReason([clearFlag])
   Return the stop reason ("done"/"interrupt"/"fail") for the last cast
   (nil if none have stopped since the last clear).. if clearFlag is
   present and true then resets status after return.

---------------------------------------------------------------------------
REVISIONS

Version 2.02 - 2023-02-13
   * Udpated for WoW 3.3 by Runi

--- Revision by Nutbrittle below ---

Version 2.01 - 2009-08-12
   * Development taken over by Nutbrittle
   * Udpated for WoW 3.2
   
--- Original Revision by Iriel below ---

Version 1.1 - 2006-11-28
   * Updated for WoW 2.0 and Lua 5.1

Version 1.0 - 2006-08-29
   * Added trap for outstanding interrupt-during-cast event transition

Version 0.6 - 2006-06-19
   * Added spellcast failure tests for normal casting states to handle
     target-death-during-cast scenarios.

Version 0.5.1 - 2006-04-10
   * Removed accidental debugging line.

Version 0.5 - 2006-04-09
   * Updated for version 1.10 (Completely rewritten event engine)

Version 0.4 - 2005-09-12
   * Added AfterCastReason([clearFlag]) function

Version 0.3 - 2005-02-18
   * Fixed interrupt event issue 

Version 0.2 - 2005-01-30
   * Fixed issue with /p and other chat functions failing to work
   * Added a 'fake' start event for instant cast spells.