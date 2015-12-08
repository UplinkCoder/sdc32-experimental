/**
 * This module crawl the AST to resolve identifiers and process types.
 */
module d.semantic.dmodule;

import d.semantic.scheduler;
import d.semantic.semantic;

import d.ast.declaration;

import d.ir.symbol;

import d.context.name;

alias AstModule = d.ast.declaration.Module;
alias Module = d.ir.symbol.Module;

alias PackageNames = Name[];

final class ModuleVisitor {
private:
	SemanticPass pass;
	alias pass this;
	
	string[] includePaths;

	Module[string] cachedModules;

public:
	this(SemanticPass pass, string[] includePaths) {
		this.pass = pass;
		this.includePaths = includePaths;
	}
	
	Module importModule(PackageNames packages) {
		import std.algorithm, std.range;
		auto name = packages.map!(p => p.toString(pass.context)).join(".");
		
		return cachedModules.get(name, {
			import std.algorithm, std.array, std.path;
			auto basename = packages
				.map!(p => p.toString(pass.context))
				.buildPath();
			
			auto filename = basename ~ ".d";
			auto dir = getIncludeDir(filename, includePaths);
			
			auto astm = parse(filename, dir);
			auto mod = modulize(astm);
			
			pass.scheduler.schedule(astm, mod);
			return cachedModules[name] = mod;
		}());
	}

	Module add(const char* code, size_t codeLength, const char* filename, size_t filenameLength) {
		auto astm = this.parse(code, codeLength, filename, filenameLength);
		auto mod = modulize(astm);
		cachedModules[getModuleName(mod)] = mod;
		
		scheduler.schedule(astm, mod);
		return mod;
	}

	Module add(string filename) {
		import std.conv, std.path;
		filename = expandTilde(filename)
			.asAbsolutePath
			.asNormalizedPath
			.to!string();
		
		// Try to find the module in include path.
		string dir;
		foreach(path; includePaths) {
			if (path.length < dir.length) {
				continue;
			}
			
			import std.algorithm;
			if (filename.startsWith(path)) {
				dir = path;
			}
		}
		
		// XXX: this.parse, because dmd is insane and want to use std.conv :(
		auto astm = this.parse(relativePath(filename, dir), dir);
		auto mod = modulize(astm);
		cachedModules[getModuleName(mod)] = mod;
		
		scheduler.schedule(astm, mod);
		return mod;
	}

	AstModule parse(const char* pcontent, size_t contentLength, const char* pfilename, size_t filenameLength) {
		string filename  = cast(immutable) pfilename[0 .. filenameLength];
		string content = cast(immutable) pcontent[0 .. contentLength];

		auto base = context.registerBuffer(content, filename);

		return parse(base, filename);
	}

	AstModule parse(string filename, string directory) in {
		assert(filename[$ - 2 .. $] == ".d");
	} body {
		import d.context.location;
		auto base = context.registerFile(Location.init, filename, directory);

		return parse(base, filename);
	}

	import d.context.location:Position;
	AstModule parse(Position base, string filename) {
		import d.lexer;
		auto l = lex(base, context);
		
		import d.parser.dmodule;
		auto m = l.parseModule();
		
		import std.algorithm, std.array, std.path;
		auto packages = filename[0 .. $ - 2]
			.pathSplitter()
			.map!(p => pass.context.getName(p))
			.array();
		
		auto name = packages[$ - 1];
		packages = packages[0 .. $ - 1];
		
		// If we have no module declaration, we infer it from the file.
		if (m.name == BuiltinName!"") {
			m.name = name;
			m.packages = packages;
		} else {
			// XXX: Do proper error checking. Consider doing fixup.
			assert(m.name == name, "Wrong module name");
			assert(m.packages == packages, "Wrong module package");
		}
		
		return m;
	}
	
	Module modulize(AstModule astm) {
		auto loc = astm.location;
		
		auto m = new Module(loc, astm.name, null);
		m.addSymbol(m);
		
		Package p;
		foreach(n; astm.packages) {
			p = new Package(loc, n, p);
		}
		
		m.parent = p;
		p = m;
		while (p.parent !is null) {
			p.parent.addSymbol(p);
			p = p.parent;
		}
		
		return m;
	}
	
	private auto getModuleName(Module m) {
		auto name = m.name.toString(context);
		if (m.parent) {
			auto dpackage = m.parent;
			while(dpackage) {
				name = dpackage.name.toString(context) ~ "." ~ name;
				dpackage = dpackage.parent;
			}
		}
	
		return name;
	}
}

private:
string getIncludeDir(string filename, string[] includePaths) {
	foreach(path; includePaths) {
		import std.path;
		auto fullpath = buildPath(path, filename);
		
		import std.file;
		if (exists(fullpath)) {
			return path;
		}
	}
	
	// XXX: handle properly ? Now it will fail down the road.
	return "";
}
