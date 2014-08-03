module d.source;

public import d.location;

abstract class Source {
	string content;
	size_t pos;

	void popFront() {
		pos++;
	}

	char front() {
		return content[pos];
	}

	Source save(T)() {
		Source ret = new T;	
		ret.pos(pos);
		return this;
	}

	this(string content) {
		this.content = content;
	}
	
	abstract string format(const Location location) const;
	
	@property
	abstract string filename() const;

	@property
	abstract string[] packages() const;

	final string[] packages_from_filename() const {
		import std.string:split; 

		if (filename[$-2 .. $] == ".d") {
			return filename[0 .. $-2].split("/");
		} else {
			return filename.split("/");
		}
	}
	//@property 
	//abstract  getstr(Location begin,Location end) const;

}

final class FileSource : Source {
	import util.utf8;

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
	
	@property
	override string[] packages() const {
		return packages_from_filename();
        }
}

final class MixinSource : Source {
	Source source;
	Location location;

	this(Source source,Location location, string content) {
		this.source = source;
		this.location = location;
		super(content);
	}


	this(Location location, string content) {
		this.location = location;
		super(content);
	}
	
	override string format(const Location dummy) const {
		return location.toString();
	}
	
	@property
	override string filename() const {
		if (source is null) {
			return location.source.filename;
		} else {
			return source.filename;
		}
	}
	
	@property
        override string[] packages() const {
                return location.source.packages;
        }
}

/** 
 * This class is mostly ment for Unittests and such but could also be used by REPL and stuff. 
 */
final class StringSource : Source {
        string _name;

        this(in string content,in string name) {
                _name = name;
                super(content ~ '\0');
        }

        override string format(const Location location) const {
                import std.conv;
                return _name ~ ':' ~ to!string(location.line);
        }

        @property
        override string filename() const {
                return _name;
        }
	
	@property 
	override string[] packages() const {
		return packages_from_filename();
	}
}

