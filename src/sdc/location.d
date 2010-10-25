/**
 * Copyright 2010 Bernard Helyer.
 * Copyright 2010 Jakob Ovrum.
 * This file is part of SDC. SDC is licensed under the GPL.
 * See LICENCE or sdc.d for more details.
 */
module sdc.location;

import std.string;
import std.stdio;


// This was pretty much stolen wholesale from Daniel Keep. <3
struct Location
{
    string filename;
    uint line = 1;
    uint column = 1;
    uint length = 0;
    
    string toString()
    {
        return format("%s(%s:%s)", filename, line, column);
    }
    
    // Difference between two locations
    // end - begin == begin .. end
    Location opBinary(string op)(Location begin) if (op == "-")
    {        
        assert(begin.filename == filename);
        assert(begin.line <= line);
        
        Location loc;
        loc.filename = filename;
        loc.line = begin.line;
        loc.column = begin.column;
        
        if (line != begin.line) {
            loc.length = -1; // End of line
        } else {
            assert(begin.column <= column);
            loc.length = column + length - begin.column;
        }
        
        return loc;
    }
    
    // When the column is 0, the whole line is assumed to be the location
    immutable uint wholeLine = 0;
}

char[] readErrorLine(Location loc)
{            
    auto f = File(loc.filename);
    
    foreach(ulong n, char[] line; lines(f)) {
        if(n == loc.line - 1) {
            while(line[$-1] == '\n' || line[$-1] == '\r'){ 
                line = line[0 .. $ - 1];
            }
            return line;
        }
    }
    
    return null;
}