/**
 * Entry point for the new multi-pass experiment.
 */
module sdc.sdc;

import d.ir.symbol;

import d.llvm.backend;
import d.llvm.codegen;
import d.llvm.evaluator;

import d.semantic.semantic;

import d.context;
import d.location;

import util.json;

import std.algorithm;
import std.array;
import std.file;

final class SDC {
	Context context;

	CodeGenPass codegen;
	SemanticPass semantic;
	LLVMBackend backend;
	
	string[] includePath;
	
	Module[] modules;
	
	this(string name, JSON conf, string linkerParams,string[] versions) {
		includePath = conf["includePath"].array.map!(path => cast(string) path).array();
		linkerParams = conf["libPath"].array.map!(path => " -L" ~ (cast(string) path)).join();

		context = new Context();
		versions ~= ["SDC"]; 
	
		backend	= new LLVMBackend(context, name, 0, linkerParams);
		semantic = new SemanticPass(context, backend.getEvaluator, &getFileSource);
		
		// Review thet way this whole thing is built.
		backend.getPass().object = semantic.object;
	}

	void compile (Source s, Name[] packages = []) {
		modules ~= semantic.add(s,packages);
	}

	void compile(string filename) {
		auto packages = filename[0 .. $ - 2].split("/").map!(p => context.getName(p)).array();
		modules ~= semantic.add(new FileSource(filename), packages);
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
	
	FileSource getFileSource(Name[] packages) {
		auto filename = "/" ~ packages.map!(p => p.toString(context)).join("/") ~ ".d";
		foreach(path; includePath) {
			auto fullpath = path ~ filename;
			if(exists(fullpath)) {
				return new FileSource(fullpath);
			}
		}
		
		assert(0, "filenotfoundmalheur ! " ~ filename);
	}
}

