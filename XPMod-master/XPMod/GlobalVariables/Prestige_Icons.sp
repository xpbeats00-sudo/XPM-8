// Custom Private Use Area icons for XPMod prestige ranks.
//
// These codepoints have no assigned glyph in normal fonts - they render as unique
// icons only within the L4D2 client itself (font 'tarty', see the guide this list came
// from: https://fsymbols.com/generators/tarty/). Everywhere else - this file, chat logs,
// a text editor - they show as invisible/blank or a tofu box, by design.
//
// Assigned to prestige ranks in the order originally provided (rank 1 = first entry).
// This ordering is arbitrary - nobody involved in writing this code could preview what
// these actually look like in-game, so it is NOT guaranteed to read as an escalating
// bronze-to-diamond style progression. Reorder the entries below (or trim the list) to
// match your intended rank progression once you have previewed them in-game.
//
// UPDATE: ranks 1-10 were switched from the original PUA codepoints (still used for
// ranks 11-45 below) to plain "P<n>" text + an escalating emoji instead - guaranteed
// readable everywhere regardless of whether the custom "tarty" font addon is loaded
// client-side, at the cost of not being a custom-drawn icon. Same rendering caveat as
// the Customize menu's emoji tags applies here too: standard Unicode, not guaranteed to
// have a glyph in L4D2's own HUD font - please test live.
char PRESTIGE_ICONS[][] = {
	"P1⭐",	// rank 1
	"P2🌟",	// rank 2
	"P3✨",	// rank 3
	"P4🔥",	// rank 4
	"P5⚡",	// rank 5
	"P6💥",	// rank 6
	"P7💎",	// rank 7
	"P8🏆",	// rank 8
	"P9💀",	// rank 9
	"P10👑",	// rank 10
	"",	// rank 11 - U+E0F0
	"",	// rank 12 - U+E100
	"",	// rank 13 - U+E110
	"",	// rank 14 - U+E120
	"",	// rank 15 - U+E130
	"",	// rank 16 - U+E140
	"",	// rank 17 - U+E150
	"",	// rank 18 - U+E160
	"",	// rank 19 - U+E170
	"",	// rank 20 - U+E180
	"",	// rank 21 - U+E190
	"",	// rank 22 - U+E1A0
	"",	// rank 23 - U+E1B0
	"",	// rank 24 - U+E1C0
	"",	// rank 25 - U+E1D0
	"",	// rank 26 - U+E1E0
	"",	// rank 27 - U+E1F0
	"",	// rank 28 - U+E200
	"",	// rank 29 - U+E210
	"",	// rank 30 - U+E220
	"",	// rank 31 - U+E230
	"",	// rank 32 - U+E240
	"",	// rank 33 - U+E250
	"",	// rank 34 - U+E260
	"",	// rank 35 - U+E270
	"",	// rank 36 - U+E280
	"",	// rank 37 - U+E290
	"",	// rank 38 - U+E2A0
	"",	// rank 39 - U+E2B0
	"",	// rank 40 - U+E2C0
	"",	// rank 41 - U+E2D0
	"",	// rank 42 - U+E2E0
	"",	// rank 43 - U+E2F0
	"",	// rank 44 - U+F000
	""	// rank 45 - U+F010
};

// Returns the icon for the given prestige rank (1-based). Empty string for rank 0 (not
// prestiged). Cycles back through the list if the player has prestiged more times than
// there are icons defined above.
void GetPrestigeSymbol(int iPrestigeCount, char[] strSymbol, int maxlen)
{
	if (iPrestigeCount <= 0)
	{
		strSymbol[0] = '\0';
		return;
	}

	int iIndex = (iPrestigeCount - 1) % sizeof(PRESTIGE_ICONS);
	strcopy(strSymbol, maxlen, PRESTIGE_ICONS[iIndex]);
}

// Decorator shown for players who haven't prestiged yet (prestige count 0, "new" tier),
// prepended to their level instead of a prestige count - see RenamePlayerWithLevelTags.
char NEW_PLAYER_SYMBOL[] = "🔰";
