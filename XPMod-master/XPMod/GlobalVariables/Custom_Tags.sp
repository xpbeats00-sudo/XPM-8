// Player-selectable custom name tags for XPMod, chosen via the "Customize" menu
// (Extras -> Customize, unlocked at level 30 same as Prestige).
//
// These are standard Unicode (not the Private Use Area font trick Prestige_Icons.sp
// uses), so - unlike the prestige icons - there is no guarantee L4D2's built-in HUD font
// actually has glyphs for the emoji entries. The box-drawing/emoji here render fine in
// this file, a terminal, or Discord, but the game's font is a different, much more
// limited character set. Please test in-game; anything that doesn't render will just
// show as a blank/tofu box in the name, same graceful-failure behavior as everywhere
// else tags are used here, nothing will break - just tell me which ones to swap out.
//
// OWNER/ADMIN are plain readable text rather than the multi-line block-art banners
// requested, because a player's in-game name is a single-line string - there's no way
// to fit a 2-line banner into it. They're also restricted to actual admins (see
// CUSTOM_TAG_ADMIN_ONLY below) so a regular player can't tag themselves as staff.
char CUSTOM_TAGS[][] = {
	"👑",
	"🎮",
	"🎰",
	"🎲",
	"🎯",
	"💀",
	"OWNER",
	"ADMIN"
};

// Parallel array - true means only players with SourceMod admin access can select/see
// this tag in the Customize menu. Keep this the same length/order as CUSTOM_TAGS above.
bool CUSTOM_TAG_ADMIN_ONLY[] = {
	false,	// 👑
	false,	// 🎮
	false,	// 🎰
	false,	// 🎲
	false,	// 🎯
	false,	// 💀
	true,	// OWNER
	true	// ADMIN
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
