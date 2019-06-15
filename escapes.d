module escapes;

import std.conv;
import std.process;
import std.typecons;
import std.string;

struct Keys
{
	static:
		string alternateScreenOn;
		string alternateScreenOff;
		
		string[256] colorFG;
		string[256] colorBG;
		string terminator; 
	
		/// undoes cursorInvisible
		string cursorNormal;
		string cursorInvisible;
		
		string cursorR;
		string cursorL;
		string cursorU;
		string cursorD;
		
		

		/// also returns cursor to home
		string eraseDisplay;
		string eraseLine;
		
		
		private string[int][int] cursorAtCache;
		string cursorAt(short l, short c)
		{
			return cursorAtCache.require(l).require(c, callTput("cup "~to!string(l)~" "~to!string(c)));
		}
	
		/**
		 * interrogates terminfo to discover escape codes
		 *
		 * go read man 5 terminfo
		 *
		 * from what I can gather, it is possible to initialize static
		 * members with functions, but only at compile time (so if the
		 * function can go through CTFE). Well, it's only a theory;
		 * either that or DMD has one more bug.
		 */
		void discover()
		{
			alternateScreenOn = callTput("smcup");
			alternateScreenOff = callTput("rmcup");
			
			colorFG = getColorEscapes(0,colorFG.length, "f");
			colorBG = getColorEscapes(0,colorBG.length, "b");
			
			
			terminator = callTput("sgr0");
			cursorNormal = callTput("cnorm");
			cursorInvisible = callTput("civis");
			
			cursorR = callTput("cuf1");
			cursorL = callTput("cub1");
			cursorU = callTput("cuu1");
			cursorD = callTput("cud1");
			
			eraseDisplay = callTput("clear");
			eraseLine = callTput("dl1");
		}
}

string callTput(string args)
{
	string command = "tput ";
	command~=args;
	auto sh = pipeShell(command, Redirect.stdout);
	wait(sh.pid);
	auto result = to!string(sh.stdout.byLine().front);
	sh.stdout.close();
	return strip(result);
}

/**
 * calls tput setab on each number to find out the escape code
 * bORf : background or foreground, as one letter
 */
string[] getColorEscapes(int min, int max, string bORf)
{

	string[] result;
	result.length = max;

	for (int i=min ; i<max; i++)
	{
		string command = "tput seta"~bORf~" "~to!string(i);
		auto sh = pipeShell(command, Redirect.stdout);
		wait(sh.pid);
		result[i] = to!string(sh.stdout.byLine().front);
		sh.stdout.close();
	}
	return result;
}