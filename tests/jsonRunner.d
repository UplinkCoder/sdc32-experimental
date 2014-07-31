import std.process;
import std.file;
import std.string;
import std.stdio;
import std.json;
import d.source;
import sdc.sdc;
import std.conv;
//import jsonx;
void main() {
import util.stringsource;
import jsonx;
import sdc.conf;

	write("Reading 'tests.json' ...");
	JSONValue[string] testsJson = readText("tests.json").parseJSON.object;
	writeln(" Done.");
	writeln("Runnig tests now.");
	immutable uint len = cast(immutable uint) testsJson["len"].integer;

	JSONValue[] tests = testsJson["tests"].array;

	auto conf = buildConf();

	foreach (i,test;tests) {


		auto _sdc = new SDC("sdc",conf,0,32);

		foreach (uint j,JSONValue dep;test["deps"].array) {
			 _sdc.compile(new StringSource(dep.str,format("test%04d_import%d",i,j+1)),[]);
		}
		_sdc.compile(new StringSource(test["code"].str,format("test%04d",i)),[]);

		_sdc.buildMain();
		_sdc.codeGen(format("test%04d.o",i),format("test%04d.exe",i));

		long retval = spawnProcess(format("test%04d.exe",i),stdin,stdout,stderr).wait;

		if (retval == test["retval"].integer) writeln("test "~to!string(i)~": GOOD");
		else writeln("test "~to!string(i)~": BAD");
	}


}
