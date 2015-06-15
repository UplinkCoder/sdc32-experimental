/**
 * Copyright 2010 Jakob Ovrum.
 * This file is part of SDC.
 * See LICENCE or sdc.d for more details.
 */ 
module sdc.terminal;

import std.stdio;

import d.context.sourcemanager;

version(Windows) {
	import std.c.windows.windows;
}

void outputCaretDiagnostics(FullLocation loc, string fixHint) {
	uint offset = loc.getStartOffset();
	uint start = offset;
	auto content = loc.getContent();

	// This is unexpected end of input.
	if (start == content.length) {
		// Find first non white char.
		import std.ascii;
		while(start > 0 && isWhite(content[--start])) {}
	}
	
	// XXX: We could probably use infos from source manager here.
	FindStart: while(start > 0) {
		switch(content[start]) {
			case '\n':
			case '\r':
				start++;
				break FindStart;
			
			default:
				start--;
		}
	}
	
	uint length = loc.length;
	uint end = offset + loc.length;
	
	// This is unexpected end of input.
	if (end > content.length) {
		end = cast(uint) content.length;
	}
	
	FindEnd: while(end < content.length) {
		switch(content[end]) {
			case '\n':
			case '\r':
				break FindEnd;
			
			default:
				end++;
		}
	}
	
	auto line = content[start .. end];
	uint index = offset - start;

	// Multi line location
	if (index < line.length && index + length > line.length) {
		length = cast(uint) line.length - index;
	}
	
	char[] underline;
	underline.length = index + length;
	foreach(i; 0 .. index) {
		underline[i] = (line[i] == '\t') ? '\t' : ' ';
	}
	
	underline[index] = '^';
	foreach(i; index + 1 .. index + length) {
		underline[i] = '~';
	}

	stderr.write(loc.isMixin() ? "mixin" : loc.getFileName(), ":", loc.getStartLineNumber(), ":", index, ":");
	stderr.writeColouredText(ConsoleColour.Red, " error: ");
	stderr.writeColouredText(ConsoleColour.White, fixHint, "\n");
	
	stderr.writeln(line);
	stderr.writeColouredText(ConsoleColour.Green, underline, "\n");
	
	if (loc.isMixin()) {
		outputCaretDiagnostics(loc.getImportLocation(), "mixed in at");
	}
}

/*
 * ANSI colour codes per ECMA-48 (minus 30).
 * e.g., Yellow = 3 + 30 = 33.
 */
enum ConsoleColour {
	Black	= 0,
	Red		= 1,
	Green	= 2,
	Yellow	= 3,
	Blue	= 4,
	Magenta	= 5,
	Cyan	= 6,
	White	= 7,
}

void writeColouredText(T...)(File pipe, ConsoleColour colour, T t) {
	bool coloursEnabled = true;  // XXX: Fix me!

	if (!coloursEnabled) {
		pipe.write(t);
	}

	char[5] ansiSequence = [0x1b, '[', '3', '0', 'm'];
	ansiSequence[3] = cast(char)(colour + '0');

	// XXX: use \e]11;?\a to get the color to restore
	pipe.write(ansiSequence, t, "\x1b[0m");
}
