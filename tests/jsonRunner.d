import std.file;
import std.string;
import std.stdio;
import std.json;
import d.location;
//import jsonx;
void main() {
	write("Reading 'tests.json' ...");
	JSONValue[string] testsJson = readText("tests.json").parseJSON.object;
	writeln(" Done.");
	writeln("Runnig tests now.");
	immutable uint len = cast(immutable uint) testsJson["len"].integer;

	JSONValue[] tests = testsJson["tests"].array;
	foreach (i,test;tests) {
		writeln(test["code"].str);
		StringSource[] ds;
		foreach (uint j,JSONValue dep;test["deps"].array) {
			ds~= new StringSource(dep.str,format("test%04d_import%d",i,j+1));
		}

		auto s = new StringSource(test["code"].str,format("test%04d",i));

		//auto pid = spwanProcess(command,codeFile,stdout,stderr);

	}
}
