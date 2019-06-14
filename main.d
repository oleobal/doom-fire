import std.stdio;
import std.conv;
import std.typecons;
import std.process;
import core.thread;

alias Canvas= ubyte[][];
alias Dimensions=Tuple!(int, "cols", int, "lines");

// (handpicked) terminal colors, from coldest to warmest
ubyte[16] colors = [ 0, 52, 88, 124, 196, 202, 215, 220, 222, 226, 227, 228, 229, 230, 195, 231 ];

void updateCanvas(Canvas previousState)
{

}

void renderCanvas(Canvas state)
{

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

void main(string[] args)
{
	
	//set-up
	//wait(spawnShell("tput smcup"));

	// http://fabiensanglard.net/timer_and_framerate/

	// you might also wonder, why not catch SIGWINCH ?
	// take a wild guess as to how much attention signal handling got
	// in the stdlib :)
	auto oldDims = getWindowSize();
	Canvas canvas;

	canvas.length = oldDims.lines;
	for (int l=0 ; l<oldDims.lines;l++)
	{
		canvas[l].length = oldDims.cols;
		for (int c=0 ; c<oldDims.cols;c++)
			canvas[l][c] = 0;
	}
	for (int c=0 ; c<oldDims.cols;c++)
		canvas[canvas.length-1][c]=colors.length;


	writeln(canvas.length, " ", canvas[0].length, " ", canvas[canvas.length-1][0]);

	//Thread.sleep(dur!("seconds")(2));


	// clean-up
	//wait(spawnShell("tput rmcup"));
}
