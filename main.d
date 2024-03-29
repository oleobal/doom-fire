import std.stdio;
import std.conv;
import std.typecons;
import std.process;
import std.math;
import std.random;
Random rnd;
import std.container : DList;
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


/**
 * take a queue of events (from earliest to latest)
 * and returns the average number of such events per second
 */
long avgEventsPerSecond(DList!MonoTime times)
{
	auto nt = times.dup();
    MonoTime start = nt.front();
    nt.removeFront();

    Duration total = dur!("seconds")(0);
    long elements = 0;

    while (!nt.empty())
    {
        total = total + (nt.front() - start) ;
        nt.removeFront();
        elements++;
    }

    return dur!("seconds")(1)/(total/elements);
}


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
		decayMod=to!int(round(area.lines*(-0.15)+6.5));
		bugMsg("updateCanvas/autoDecayCalc ", area.lines, " -> ", decayMod);
	}
	
	auto decays = [0, 0, 1, 2];
	if (decayMod < 0)
		decays.length = decays.length+abs(decayMod); // add zeroes
	else if (decayMod > 0)
	{
		auto oldLength = decays.length;
		decays.length+=decayMod;
		for (ulong i =oldLength; i < decays.length; i++)
			decays[i]=1+(i%3);
		//alternate adding 1 and 2 and 3
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
			auto direction = [-1, 0, 0, 0, 0, 0, 0, 0, 1].choice(rnd);
			canvas[l][c] = to!ubyte(clamp(
					canvas[l+1][clamp(c+direction, 0, canvas[l].length-1)]
					
					//- uniform(max(0+decayMod, 0), max(3+decayMod, 2), rnd),
					- decays.choice(rnd),
					
					0, temperatures.length-1
				));
		}
	}
	
}


void renderCanvas(Canvas canvas, Dimensions area, string topLeft="")
{
	
	int offset = max(0, to!int(canvas.length)-to!int(area.lines));
	bugMsg("renderCanvas ",canvas.length, " ", area.lines, " ", offset, " | ",topLeft);
	
	string result = "";
	
	for (int l=0 ;l+offset<canvas.length;l++)
	{
		result~=Keys.cursorAt(to!short(l),to!short(0));
		for (int c=0 ; c<canvas[l+offset].length && c<area.cols;c++)
		{
			if (l==0)
			{
				if (c<topLeft.length)
				{
					result~=Keys.colorBG[temperatures[canvas[l+offset][c]]]~Keys.colorFG[2]~topLeft[c]~Keys.terminator;
					continue;
				}
			}
			result~=Keys.colorBG[temperatures[canvas[l+offset][c]]]~" "~Keys.terminator;
		}
	}
	write(result);
}


int main(string[] args)
{
	short timeslice = 66; // in ms
	short decayMod = 0;
	bool autoDecayMod = true;
	shared uint switchSourceEvery = 0;
	bool displayFPScounter = false;
	// argument parsing
	for (int i=0; i<args.length; i++)
	{
		if (args[i] == "--help" || args[i] == "-h")
		{
			writeln(`POSIX console 'Doom fire' as described by Fabien Sanglard.
Read here: http://fabiensanglard.net/doom_fire_psx/
Options:
  --speed, -s <n> : Set target simulation speed (default: 15 ticks/s)
  --decay, -d <n> : Adjust decay rate of temperature (can be negative)
                    By default, dynamic value depending on window size
  --flip,  -f <n> : Flip the source on and off every <n> seconds

Switches:
  --fps-counter : Displays a frames per second counter in the top left
  --debug       : Output debug info (while running) to stderr
  --help,  -h   : Display this help and exit`);
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
		if (args[i] == "--flip" || args[i] == "-f")
		{
			switchSourceEvery = abs(to!int(args[i+1]));
			i++;
		}
		
		if (args[i] == "--debug")
			bugMode = true;
		if (args[i] == "--fps-counter")
			displayFPScounter = true;
	}
	
	
	
	// you might also wonder, why not catch SIGWINCH ?
	// take a wild guess as to how much attention signal handling got
	// in the stdlib :)
	
	
	signal(SIGINT, &handleSigint);
	try
	{
		Keys.discover();
	}
	catch (Exception e)
	{
		stderr.writeln(e.msg);
		return 1;
	}
	
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

	
	shared bool keepSourceGoing = true;
	if (switchSourceEvery > 0)
	{
		auto switchSourceThread = new Thread({
			while(!gotSigint) {
				Thread.sleep(dur!"seconds"(switchSourceEvery));
				atomicOp!"^="(keepSourceGoing, true);
			}
		}).start();
	}
	
	// avoid getWindowSize() on the main thread
	auto windowSizeThread = new Thread({
		while(!gotSigint) {
			try
			{
				Dimensions d = getWindowSize();
			
				if (d != dims)
					//atomicStore(dims, d); // my code is radioactive
					/+
					 + OK so the above doesn't work.
					 + maybe cause Tuple is a pointer type ? Idk.
					 + https://www.mail-archive.com/digitalmars-d-bugs@puremagic.com/msg75050.html
					 +
					 + it's not really a problem though;
					 + I don't need atomic operations, simply because
					 + this thread is the only one writing on 'dims'.
					 +/
					atomicStore(dims.lines, d.lines);
					atomicStore(dims.cols, d.cols);
			}
			catch (ConvException e)
			{ /+ silence the exception +/ break; }
		}
	}).start();
	

	/// keeps the window size consistent within a loop
	Dimensions area;
	
	auto times = DList!MonoTime(
			MonoTime.currTime, MonoTime.currTime,
			MonoTime.currTime, MonoTime.currTime,
			MonoTime.currTime, MonoTime.currTime,
			MonoTime.currTime, MonoTime.currTime,
			MonoTime.currTime, MonoTime.currTime,
			MonoTime.currTime, MonoTime.currTime,
			MonoTime.currTime, MonoTime.currTime,
			MonoTime.currTime, MonoTime.currTime,
			MonoTime.currTime, MonoTime.currTime,
			MonoTime.currTime, MonoTime.currTime);
	auto nextUpdate = MonoTime.currTime;
	while (!gotSigint)
	{
		area.lines = dims.lines;
		area.cols = dims.cols;
		if (MonoTime.currTime >= nextUpdate)
		{
			nextUpdate+=dur!("msecs")(timeslice);
			updateCanvas(canvas, area, keepSourceGoing, decayMod, autoDecayMod);
		}
		
		if (displayFPScounter)
		{
			times.insertBack(MonoTime.currTime);
			times.removeFront();
			renderCanvas(canvas, area, to!string(avgEventsPerSecond(times)));
		}
		else
			renderCanvas(canvas, area);

	}
	
	write(Keys.terminator,Keys.cursorAt(0,0), Keys.cursorNormal, Keys.alternateScreenOff);
	return 0;
}
