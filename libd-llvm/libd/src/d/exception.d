/**
 * This file is part of libd.
 * See LICENCE for more details.
 */
module d.exception;

import std.algorithm;
import std.stdio;
import std.string;

import d.location;

class  CompileException : Exception {
	Location location;
	
	CompileException next; // Optional
	string fixHint; // Optional
	
	this(Location loc, string message) {
		super(format("%s: error: %s", loc.toString(), message));
		location = loc;
	}
	
	this(Location loc, string message, CompileException next) {
		this.next = next;
		this(loc, message);
	}
}

