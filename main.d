import std.stdio;
import std.conv;
import std.typecons;
import std.process;
import std.random;
Random rnd;
import std.algorithm.comparison;
import std.concurrency;
import core.thread;
import core.atomic;


import core.stdc.signal;
__gshared bool gotSigint = false;
extern(C) void handleSigint(int sig) nothrow @nogc @system
{
    gotSigint = true;
}

bool bugMode = false;


void bugMsg(T...)(T args)
{
	if (bugMode)
		stderr.writeln(args);
}


import escapes;

alias Canvas= ubyte[][];
alias Dimensions=Tuple!(int, "cols", int, "lines");

// (handpicked) terminal colors, from coldest to warmest
ubyte[16] temperatures = [ 0, 52, 88, 124, 196, 202, 215, 220, 222, 226, 227, 228, 229, 230, 195, 231 ];


Dimensions getWindowSize()
{
	// getting size should take a bit less than 10ms on most machines
	auto cpid = pipeShell("tput cols", Redirect.stdout);
	auto lpid = pipeShell("tput lines", Redirect.stdout);
	wait(cpid.pid); wait(lpid.pid);
	
	// the fact there isn't a readAll method is a failure of stdlib
	// or the fact that I can't find it is a failure of documentation
	// either way, I'm disappointed
	Dimensions d;
	d.cols = to!int(cpid.stdout.byLine().front);
	d.lines = to!int(lpid.stdout.byLine().front);

	cpid.stdout.close(); lpid.stdout.close();
	return d;
}



/**
 * decayMod may be null, in which case the decay modifier is
 * adjusted depending on area.lines
 */
void updateCanvas(ref Canvas canvas, Dimensions area, bool keepSourceGoing, int decayMod, bool autoDecayMod)
{
	bugMsg("updateCanvas ", canvas.length, " ", canvas[0].length, "-", canvas[canvas.length-1].length, " ", area);
	
	// enlarge canvas (never reduce)
	if (canvas.length < area.lines)
	{
		canvas.length = area.lines;
	}
	for (int l=0;l<canvas.length;l++)
	{
		if (canvas[l].length < max(canvas[0].length, area.cols))
			canvas[l].length = max(canvas[0].length, area.cols);
	}
	
	
	// calculate decayMod
	if (autoDecayMod)
	{
		if (area.lines > 45)
			decayMod = -1;
		else if (area.lines < 20 && area.lines >= 10)
			decayMod = 1;
		else if (area.lines < 10)
			decayMod = 2;
	}

	// last line is white
	if (keepSourceGoing)
		canvas[canvas.length-1][] = temperatures.length-1;
	else
		canvas[canvas.length-1][] = 0;
	
	// calculate new state
	for (int l=0 ; l<canvas.length-1;l++)
	{
		for (int c=0 ; c<canvas[l].length;c++)
		{
			canvas[l][c] = to!ubyte(clamp(
				canvas[l+1][c]
				- uniform(max(0+decayMod, 0), max(3+decayMod, 2), rnd),
			0, temperatures.length-1));
		}
	}
	
}


void renderCanvas(Canvas canvas, Dimensions area)
{
	
	int offset = max(0, to!int(canvas.length)-to!int(area.lines));
	bugMsg("renderCanvas ",canvas.length, " ", area.lines, " ", offset);
	
	for (int l=0 ;l+offset<canvas.length;l++)
	{
		write(Keys.cursorAt(to!short(l),to!short(0)));
		for (int c=0 ; c<canvas[l+offset].length && c<area.cols;c++)
		{
			write(Keys.colorBG[temperatures[canvas[l+offset][c]]]~" "~Keys.terminator);
		}
	}
}


int main(string[] args)
{
	short timeslice = 66; // in ms
	short decayMod = 0;
	bool autoDecayMod = true;
	// argument parsing
	for (int i=0; i<args.length; i++)
	{
		if (args[i] == "--help" || args[i] == "-h")
		{
			writeln(`POSIX console 'Doom fire' as described by Fabien Sanglard.
Read here: http://fabiensanglard.net/doom_fire_psx/
Options:
  --speed, -s :  Set target simulation speed (default: 15 ticks/s)
  --decay, -d :  Adjust decay rate of temperature (can be negative)
                 By default, dynamic value depending on window size
Switches:
  --debug     :  Output debug info to stderr
  --help,  -h :  Display this help`);
			return 0;
		}
		if (args[i] == "--speed" || args[i] == "-s")
		{
			timeslice = 1000/to!short(args[i+1]);
			i++;
		}
		if (args[i] == "--decay" || args[i] == "-d")
		{
			autoDecayMod = false;
			decayMod = to!short(args[i+1]);
			i++;
		}
		
		if (args[i] == "--debug")
			bugMode = true;
	}
	
	
	
	// you might also wonder, why not catch SIGWINCH ?
	// take a wild guess as to how much attention signal handling got
	// in the stdlib :)
	
	Keys.discover();
	signal(SIGINT, &handleSigint);
	
	rnd = Random(unpredictableSeed);
	
	
	//set-up
	write(Keys.cursorInvisible, Keys.alternateScreenOn);
	

	// initialize canvas
	shared Dimensions dims = getWindowSize();
	
	Canvas canvas;
	canvas.length = dims.lines;
	for (int l=0 ; l<dims.lines;l++)
	{
		canvas[l].length = dims.cols;
		for (int c=0 ; c<dims.cols;c++)
			canvas[l][c] = 0;
	}
	for (int c=0 ; c<dims.cols;c++)
		canvas[canvas.length-1][c]=temperatures.length-1;

	
	
	// avoid getWindowSize() on the main thread
	auto windowSizeThread = new Thread({
		while(!gotSigint) {
			Dimensions d = getWindowSize();
			if (d != dims)
				//atomicStore(dims, d); // my code is radioactive
				// OK so the above doesn't work.
				// Why ?
				// No. Fucking. Clue.
				// maybe cause Tuple is a pointer type ? Idk.
				// https://www.mail-archive.com/digitalmars-d-bugs@puremagic.com/msg75050.html
				
				// it's not really a problem though, I don't need atomic
				// operations, simply because this thread is the only
				// one writing on this piece of data.
				atomicStore(dims.lines, d.lines);
				atomicStore(dims.cols, d.cols);
		}
	}).start();
	
	// http://fabiensanglard.net/timer_and_framerate/
	
	
	
	auto nextUpdate = MonoTime.currTime;
	/// keeps the window size consistent within a loop
	Dimensions area;
	while (!gotSigint)
	{
		area = dims;
		if (MonoTime.currTime >= nextUpdate)
		{
			nextUpdate+=dur!("msecs")(timeslice);
			updateCanvas(canvas, area, true, decayMod, autoDecayMod);
		}
		renderCanvas(canvas, area);
	}
	
	write(Keys.terminator,Keys.cursorAt(0,0), Keys.cursorNormal, Keys.alternateScreenOff);
	return 0;
}
