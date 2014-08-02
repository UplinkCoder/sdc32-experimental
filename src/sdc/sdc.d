/**
 * Entry point for the new multi-pass experiment.
 */
module sdc.sdc;

import d.ir.symbol;

import d.llvm.backend;

import d.semantic.semantic;

import d.context;
import d.location;
import d.source;

import util.json;

import std.algorithm;
import std.array;
import std.file;

final class SDC {
	Context context;
	uint bitWidth;

	SemanticPass semantic;
	LLVMBackend backend;

	string[] includePaths;

	Module[] modules;

	this(string name, JSON conf, uint optLevel,uint bitWidth) {
		includePaths = conf["includePath"].array.map!(path => cast(string) path).array();

		context = new Context();
		this.bitWidth=bitWidth;

		backend	= new LLVMBackend(context, name, optLevel, conf["libPath"].array.map!(path => " -L" ~ (cast(string) path)).join(),bitWidth);
		semantic = new SemanticPass(context, backend.getEvaluator(), &getFileSource, bitWidth);

		// Review thet way this whole thing is built.
		backend.getPass().object = semantic.object;
	}
	
	void compile (Source s) {
		auto packages = s.packages.map!(p =>  context.getName(p)).array();
		modules ~= semantic.add(s,packages);
	}

	void compileFile(string filename) {
		compile(new FileSource(filename)); 
	}

	void compile(Name[] packages) {
		modules ~= semantic.add(getFileSource(packages), packages);
	}

	void buildMain() {
		semantic.terminate();

		backend.visit(semantic.buildMain(modules));
	}

	void codeGen(string objFile) {
		semantic.terminate();

		backend.emitObject(modules, objFile);
	}

	void codeGen(string objFile, string executable) {
		codeGen(objFile);

		backend.link(objFile, executable);
	}
	/*
	Source getSource  (string fqn) {
		string[] parts = split(fqn,".");

	}
*/
	FileSource getFileSource(Name[] packages) {
		auto filename = "/" ~ packages.map!(p => p.toString(context)).join("/") ~ ".d";
		foreach(path; includePaths) {
			auto fullpath = path ~ filename;
			if(exists(fullpath)) {
				return new FileSource(fullpath);
			}
		}

		assert(0, "File not found: " ~ filename);
	}
}

