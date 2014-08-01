import std.process;
import std.file;
import std.string;
import std.stdio;
import std.json;
import d.source;
import sdc.sdc;
import std.conv;

void main(string[] args) {

import sdc.conf;

	write("Reading 'tests.json' ...");
	JSONValue[string] testsJson = readText("tests.json").parseJSON.object;
	writeln(" Done. \n Running tests ...");
	immutable uint len = cast(immutable uint) testsJson["len"].integer;

	JSONValue[] tests = testsJson["tests"].array;

	auto conf = buildConf();

	foreach (i,test;tests) {
		if (test["compiles"].type == JSON_TYPE.FALSE 
		    || test["has_passed"].type == JSON_TYPE.FALSE ) {
			writefln("test %d: DOES NOT COMPILE",i);
			continue;
		}
		auto _sdc = new SDC(args[0],conf,0,32);
		
		foreach (uint j,JSONValue dep;test["deps"].array) {
			 _sdc.compile(new StringSource(dep.str,format("test%04d_import%d",i,j+1)));
		}
		_sdc.compile(new StringSource(test["code"].str,format("test%04d",i)));

		_sdc.buildMain();
		_sdc.codeGen(format("test%04d.o",i),format("test%04d.exe",i));

		long retval = spawnProcess(format("./test%04d.exe",i),stdin,stdout,stderr).wait;

		if (retval == test["retval"].integer) writefln("test %04d : SUCCEEDED",i);
		else writefln("test %04d : FAILED",i);
	}
}
