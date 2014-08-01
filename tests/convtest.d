module convtest;
import std.string;
import std.stdio;
import std.file;
import std.conv;
import std.json;
import jsonx;

struct Test {
	public:
	uint number;
	bool compiles;
	bool has_passed;
	int retval;
	string[] deps;
	string code;
}

bool yn2bool (string yn) {
	if (yn == "yes"|| yn == "true") return true;
	else if (yn == "no"|| yn ==  "false") return false;
	else assert(0,"Malformed Input "~yn~" has to be yes or no");
}
string f(uint testNumber) {
	return format("test%04s.d",testNumber);
} 
void main () {
	static int testNumber = 0;
	string filename;
	Test[] tests;
	do {
		filename = f(testNumber);
		Test t;
		t.number = testNumber;
		auto f = File(filename, "r");
		scope (exit) f.close();
	    foreach (line; f.byLine) {
	        if (line.length < 3 || line[0 .. 3] != "//T") {
	            t.code~=to!string(line)~"\n";
	            continue;
	        }
	        auto words = split(line);
	        if (words.length != 2) {
	            stderr.writefln("%s: malformed test.", filename);
	        }
	        auto set = split(words[1], ":");
	        if (set.length < 2) {
	            stderr.writefln("%s: malformed test.", filename);
	            return;
	        }
	        auto var = set[0].idup;
	        auto val = set[1].idup;
	        
	        switch (var) {
			case "compiles":
				t.compiles=yn2bool(val);
			break;

			case "retval":
				t.retval = parse!int(val); 
			break;

	        	case "dependency":
				auto df = File(val,"r");
				string dep;
				foreach(l;df.byLine) {
					dep~=to!string(l)~"\n";
				}
				t.deps ~= dep;
			break;

			case "has-passed":
				t.has_passed = yn2bool(val);
			break;

	        	default:
				stderr.writefln("%s: unkown command (%s). ", filename,var);
			return;
			}
		}
		tests ~= t;
	} while (exists(f(++testNumber)));
 
	File testsJson = File ("tests.json","w");
	testsJson.write(tests.jsonEncode);	
}

