module d.location;

import d.source;
import std.string;

/**
 * Struct representing a location in a source file.
 */
struct Location {
	Source source;
	
	uint line = 1;
	uint index = 1;
	uint length = 0;
	
	string toString() const {
		return source.format(this);
	}
	
	void spanTo(ref const Location end) in {
		assert(source is end.source, "locations must have the same source !");
		
		assert(line <= end.line);
		assert(index <= end.index);
		assert(index + length <= end.index + end.length);
	} body {
		length = end.index - index + end.length;
	}
}
