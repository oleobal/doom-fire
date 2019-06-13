import std.process;
import core.thread;


void main(string[] args)
{
	
	auto cpid = pipeShell("tput cols", Redirect.stdout);
	auto lpid = pipeShell("tput lines", Redirect.stdout);
	wait(cpid); wait(lpid);

	
	

	wait(spawnShell("tput smcup"));
	println(	
	Thread.sleep(dur!("seconds")(2));
	wait(spawnShell("tput rmcup"));
}
