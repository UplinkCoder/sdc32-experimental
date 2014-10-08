/**
 * Entry point for the new multi-pass experiment.
 */
module sdc.main;

import d.ast.dmodule;

import d.exception;

import sdc.conf;
import sdc.sdc;
import sdc.terminal;

import std.array;
import std.getopt;
import std.path;

int main(string[] args) {
	version(DigitalMars) {
		version(linux) {
			import etc.linux.memoryerror;
			// druntime not containe the necessary symbol.
			// registerMemoryErrorHandler();
		}
	}
	
	auto conf = buildConf();
	
	string[] includePath;
	string[] versions;
	uint optLevel;
	bool dontLink;
	uint bitWidth;
	bool outputSrc;
	bool outputBc; 
	string outputFile;
	getopt(
		args, std.getopt.config.caseSensitive,
		"I", &includePath,
		"O", &optLevel,
		"c", &dontLink,
		"m",&bitWidth,
		"s",&outputSrc,
		"version",&versions,
		"output-bc",&outputBc,
		"o", &outputFile,
		"help|h", delegate() {
			import std.stdio;
			writeln("HELP !");
		}
	);
	
	foreach(path; includePath) {
		conf["includePath"] ~= path;
	}

	switch (bitWidth) {
		case 0 : version (D_LP64) 
			versions ~= "D_LP64";
		 break;
		case 32 : 
			break;
		case 64 : versions ~= "D_LP64";
			break;
		default :
			assert(0,"Unspported arguemt to -m");
	}

	auto files = args[1 .. $];
	
	auto executable = files[0].idup.baseName(".d");
	auto objFile = executable~".o";
	if(outputFile.length) {
		if(dontLink) {
			objFile = outputFile;
		} else {
			executable = outputFile;
		}
	}
	
	auto sdc = new SDC(files[0], conf, optLevel,versions);
	try {
		foreach(file; files) {
			sdc.compile(file);
		}
		
		if(dontLink) {
			sdc.codeGen(objFile);
		} else {
			sdc.buildMain();
			sdc.codeGen(objFile, executable);
		}
		
		return 0;
	} catch(CompileException e) {
		outputCaretDiagnostics(e.location, e.msg);
		
		// Rethrow in debug, so we have the stack trace.
		debug {
			throw e;
		} else {
			return 1;
		}
	}
}

