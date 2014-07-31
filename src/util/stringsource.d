module util.stringsource;

import d.location;
import d.source;
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
}

