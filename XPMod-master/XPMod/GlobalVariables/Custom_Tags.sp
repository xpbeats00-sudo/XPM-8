// Player-selectable custom name tags for XPMod, chosen via the "Customize" menu
// (Extras -> Customize, unlocked at level 30 same as Prestige).
//
// PLACEHOLDER CONTENT: the 7 entries below (TAG1..TAG7) are stand-ins only, the same
// way the Prestige icon list started as bare codepoints before real content was chosen.
// Replace these strings with whatever real tags you want players to pick from - plain
// text (e.g. "VIP", "OG") or Private Use Area icons like the Prestige ones, if you want
// them to render as custom symbols instead. Keep entries short: each tag is displayed
// inside its own bracket next to the player's name (see RenamePlayerWithLevelTags), and
// L4D2 names are capped at 31 characters total.
char CUSTOM_TAGS[][] = {
	"TAG1",
	"TAG2",
	"TAG3",
	"TAG4",
	"TAG5",
	"TAG6",
	"TAG7"
};

// Returns the tag text for the given 1-based tag ID. Empty string for ID 0 (no tag
// selected) or anything out of range.
void GetCustomTagText(int iTagId, char[] strTag, int maxlen)
{
	if (iTagId <= 0 || iTagId > sizeof(CUSTOM_TAGS))
	{
		strTag[0] = '\0';
		return;
	}

	strcopy(strTag, maxlen, CUSTOM_TAGS[iTagId - 1]);
}
