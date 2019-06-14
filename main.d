import std.stdio;
import std.conv;
import std.typecons;
import std.process;
import std.random;
import core.thread;


import core.sys.posix.signal;
bool gotSignal = false;
extern(C) void handler(int num) nothrow @nogc @system
{
    gotSignal = true;
}


import escapes;

alias Canvas= ubyte[][];
alias Dimensions=Tuple!(int, "cols", int, "lines");

// (handpicked) terminal colors, from coldest to warmest
ubyte[16] colors = [ 0, 52, 88, 124, 196, 202, 215, 220, 222, 226, 227, 228, 229, 230, 195, 231 ];


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




void updateCanvas(Canvas previousState, int decayFactor)
{

}


void renderCanvas(Canvas state)
{
	write(Keys.eraseDisplay);
	for (int l=0 ; l<state.length;l++)
	{
		write(Keys.cursorAt(to!short(l),to!short(0)));
		for (int c=0 ; c<state[l].length;c++)
		{
			if (state[l][c] != 0)
			{
				//write("0");
				write(Keys.colorBG[colors[state[l][c]]]~"a"~Keys.terminator);
			}
			else
				write(Keys.cursorR);
		}
	}
	stdout.flush();

}


void main(string[] args)
{
	// you might also wonder, why not catch SIGWINCH ?
	// take a wild guess as to how much attention signal handling got
	// in the stdlib :)
	auto oldDims = getWindowSize();
	
	Keys.discover();
	
	auto rnd = Random(unpredictableSeed);
	
	
	//set-up
	write(Keys.cursorInvisible, Keys.alternateScreenOn);




	
	// initialize canvas
	Canvas canvas;
	canvas.length = oldDims.lines;
	for (int l=0 ; l<oldDims.lines;l++)
	{
		canvas[l].length = oldDims.cols;
		for (int c=0 ; c<oldDims.cols;c++)
			canvas[l][c] = 0;
	}
	for (int c=0 ; c<oldDims.cols;c++)
		canvas[canvas.length-1][c]=colors.length-1;

	

	
	// http://fabiensanglard.net/timer_and_framerate/
	
	auto nextUpdate = MonoTime.currTime;
	while (true)
	{
		if (gotSignal)
			break;
		
		if (MonoTime.currTime <= nextUpdate)
		{
			nextUpdate+=dur!("msecs")(100); // 16 FPS
			updateCanvas(canvas, 1);
		}
		renderCanvas(canvas);
	}


	// clean-up
	write(Keys.cursorNormal, Keys.alternateScreenOff);
}
