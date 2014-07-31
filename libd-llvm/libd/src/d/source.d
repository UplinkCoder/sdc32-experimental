module d.source;

public import d.location;
import util.utf8;

abstract class Source {
	string content;
	
	this(string content) {
		this.content = content;
	}
	
	abstract string format(const Location location) const;
	
	@property
	abstract string filename() const;
}

final class FileSource : Source {
	string _filename;
	
	this(string filename) {
		_filename = filename;
		
		import std.file;
		auto data = cast(const(ubyte)[]) read(filename);
		super(convertToUTF8(data) ~ '\0');
	}
	
	override string format(const Location location) const {
		import std.conv;
		return _filename ~ ':' ~ to!string(location.line);
	}
	
	@property
	override string filename() const {
		return _filename;
	}
}

final class MixinSource : Source {
	Location location;
	
	this(Location location, string content) {
		this.location = location;
		super(content);
	}
	
	override string format(const Location dummy) const {
		return location.toString();
	}
	
	@property
	override string filename() const {
		return location.source.filename;
	}
}
