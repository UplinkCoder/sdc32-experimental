module d.ir.dscope;

import d.ir.symbol;

import d.ast.conditional;

import d.context.location;
import d.context.name;

// XXX: move this to a more apropriate place ?
final class OverloadSet : Symbol {
	Symbol[] set;
	bool isPoisoned;
	
	this(Location location, Name name, Symbol[] set) {
		super(location, name);
		this.set = set;
	}
}

struct ConditionalBranch {
// XXX: Can't be private because mixin templates are a glorious hack.
// private:
	// XXX: Because mixin if such a fucking broken way to go:
	static import d.ast.declaration;
	alias Declaration = d.ast.declaration.Declaration;
	
	import std.bitmanip;
	mixin(taggedClassRef!(
		StaticIfDeclaration, "sif",
		bool, "branch", 1,
	));
	
public:
	this(StaticIfDeclaration sif, bool branch) {
		// XXX: Need to set the branch first because of
		// https://issues.dlang.org/show_bug.cgi?id=15305
		this.branch = branch;
		this.sif = sif;
	}
}

/**
 * Tools to make symbols Scopes.
 */
interface Scope {
	Module getModule();
	Symbol getSymbol();
	Scope getParentScope();
	
	Module[] getImports();
	void addImport(Module m);

	///search for a symbol in this scope
	Symbol search(Location location, Name name);
	///reslove transitivly searches in the parent
	Symbol resolve(Location location, Name name);
	
	void addSymbol(Symbol s);
	void addOverloadableSymbol(Symbol s);
	void addConditionalSymbol(Symbol s, ConditionalBranch[] cdBranches);
	
	void setPoisoningMode();
	void clearPoisoningMode();
}

enum ScopeType {
	Module,
	WithParent,
}

mixin template ScopeSymbol(
	ScopeType ST = ScopeType.WithParent,
	ParentScope = Scope,
) {
private:
	import d.ir.symbol;
	Module dmodule;
	static if (ST) {
		Symbol symbol;
		ParentScope parentScope;
	}
	
	import d.context.name;
	Symbol[Name] symbols;
	
	static if (ST) {
		// XXX: Use a proper set :D
		bool[Variable] captures;
	}
	
	Module[] imports;
	
	bool isPoisoning;
	bool isPoisoned;
	bool hasConditional;
	
final:
	static if (ST) {
		void fillParentScope(ParentScope parentScope) {
			this.dmodule = parentScope.getModule();
			this.parentScope = parentScope;
		}
	}
	
public:
	Module getModule() {
		assert(dmodule !is null, "No module");
		return dmodule;
	}
	
	Scope getParentScope() {
		static if (ST) {
			assert(parentScope !is null);
			return parentScope;
		} else {
			return null;
		}
	}
	
	static if (ST) {
		bool[Variable] getCaptures() {
			return captures;
		}
		Symbol getSymbol() {
			return symbol;
		}
	} else {
		Symbol getSymbol() {
			//maybe assert here ?
			return null;
		}
	}
	
	Module[] getImports() {
		return imports;
	}
	
	void addImport(Module m) {
		imports ~= m;
	}
	
	Symbol search(Location location, Name name) {
		if (auto s = resolve(location, name)) {
			return s;
		}
		
		Symbol s = null;
		static if (ST) {
			s = parentScope.search(location, name);
		}
		
		static if (!is(typeof(hasContext))) {
			enum hasContext = false;
		}
		
		if (s is null || !hasContext) {
			return s;
		}
		
		static if (ST) {
			if (auto v = cast(Variable) s) {
				import d.common.qualifier;
				if (v.storage.isLocal) {
					captures[v] = true;
					v.storage = Storage.Capture;
				}
			}
		}
		
		return s;
	}
	
	Symbol resolve(Location location, Name name) {
		if (auto sPtr = name in symbols) {
			auto s = *sPtr;
			
			// If we are poisoning, we need to make sure we poison.
			// If not, we can return directly.
			if (!isPoisoning) {
				return s;
			}
			
			// If we have an overloadset, make it poisoned.
			if (auto os = cast(OverloadSet) s) {
				os.isPoisoned = true;
				return s;
			}
			
			// If we have a poison, then pretend there is nothing.
			if (cast(Poison) s) {
				return null;
			}
			
			// If we have no conditionals, no need to check for them.
			if (!hasConditional) {
				return s;
			}
			
			// If we have a conditional, poison it.
			if (auto cs = cast(ConditionalSet) s) {
				cs.isPoisoned = true;
				return cs.selected;
			}
			
			return s;
		}
		
		if (isPoisoning) {
			symbols[name] = new Poison(location, name);
			isPoisoned = true;
		}
		
		return null;
	}
	
	void addSymbol(Symbol s) {
		assert(!s.name.isEmpty, "Symbol can't be added to scope as it has no name.");
		
		if (auto sPtr = s.name in symbols) {
			if (auto p = cast(Poison) *sPtr) {
				import d.exception;
				throw new CompileException(s.location, "Poisoned");
			}
			
			import d.exception;
			throw new CompileException(s.location, "Already defined");
		}
		
		symbols[s.name] = s;
	}
	
	void addOverloadableSymbol(Symbol s) {
		if (auto sPtr = s.name in symbols) {
			if (auto os = cast(OverloadSet) *sPtr) {
				if (os.isPoisoned) {
					import d.exception;
					throw new CompileException(s.location, "Poisoned");
				}
				
				os.set ~= s;
				return;
			}
		}
		
		addSymbol(new OverloadSet(s.location, s.name, [s]));
	}
	
	void addConditionalSymbol(Symbol s, ConditionalBranch[] cdBranches) in {
		assert(cdBranches.length > 0, "No conditional branches supplied");
	} body {
		auto entry = ConditionalEntry(s, cdBranches);
		if (auto csPtr = s.name in symbols) {
			if (auto cs = cast(ConditionalSet) *csPtr) {
				cs.set ~= entry;
				return;
			}
			
			import d.exception;
			throw new CompileException(s.location, "Already defined");
		}
		
		symbols[s.name] = new ConditionalSet(s.location, s.name, [entry]);
		hasConditional = true;
	}
	
	void setPoisoningMode() in {
		assert(isPoisoning == false, "poisoning mode is already on.");
	} body {
		isPoisoning = true;
	}
	
	void clearPoisoningMode() in {
		assert(isPoisoning == true, "poisoning mode is not on.");
	} body {
		// XXX: Consider not removing tags on OverloadSet.
		// That would allow to not pass over the AA most of the time.
		foreach(n; symbols.keys) {
			auto s = symbols[n];
			
			// Mark overload set as non poisoned.
			// XXX: Why ?!??
			if (auto os = cast(OverloadSet) s) {
				os.isPoisoned = false;
				continue;
			}
			
			// Remove poisons.
			// XXX: Why ?!!??!
			if (isPoisoned && cast(Poison) s) {
				symbols.remove(n);
				continue;
			}
			
			// If we have no conditionals, no need to check for them.
			if (!hasConditional) {
				continue;
			}
			
			// Replace conditional entrie by whatever they resolve to.
			if (auto cs = cast(ConditionalSet) s) {
				if (cs.set.length) {
					import d.exception;
					throw new CompileException(cs.set[0].entry.location, "Not resolved");
				}
				
				assert(
					cs.set.length == 0,
					"Conditional symbols remains when clearing poisoning mode."
				);
				if (cs.selected) {
					symbols[n] = cs.selected;
				} else {
					symbols.remove(n);
				}
			}
		}
		
		isPoisoning = false;
		isPoisoned = false;
		hasConditional = false;
	}
	
	// XXX: Use of smarter data structure can probably improve things here :D
	import d.ast.conditional : StaticIfDeclaration;
	void resolveConditional(StaticIfDeclaration sif, bool branch) in {
		assert(isPoisoning, "You must be in poisoning mode when resolving static ifs.");
	} body {
		foreach(s; symbols.values) {
			if (auto cs = cast(ConditionalSet) s) {
				ConditionalEntry[] newSet;
				foreach(ce; cs.set) {
					// This is not the symbol we are interested in, move on.
					if (ce.cdBranches[0].sif !is sif) {
						newSet ~= ce;
						continue;
					}
					
					// If this is not the right branch, forget.
					if (ce.cdBranches[0].branch != branch) {
						continue;
					}
					
					// The top level static if is resolved, drop.
					ce.cdBranches = ce.cdBranches[1 .. $];
					
					// There are nested static ifs, put back in the set.
					if (ce.cdBranches.length) {
						newSet ~= ce;
						continue;
					}
					
					// FIXME: Check if it is an overloadable symbol.
					assert(cs.selected is null, "overload ? bug ?");
					
					// We have a new symbol, select it.
					if (cs.isPoisoned) {
						import d.exception;
						throw new CompileException(s.location, "Poisoned");
					}
					
					cs.selected = ce.entry;
				}
				
				cs.set = newSet;
			}
		}
	}
}

final:

/**
 * A scope associate identifier with declarations.
 */
class NestedScope : Scope {
	mixin ScopeSymbol;
	
	this(S)(S parentScope) if (is(S : Scope)) {
		this.dmodule = parentScope.getModule();
		this.parentScope = parentScope;
	}
	
	this()(Module dmodule, Scope parentScope) in {
		assert(dmodule is parentScope.getModule());
	} body {
		this.dmodule = dmodule;
		this.parentScope = parentScope;
	}
}

// XXX: Can't be private because mixin templates are a glorious hack.
// private:
class Poison : Symbol {
	this(Location location, Name name) {
		super(location, name);
	}
}

struct ConditionalEntry {
	Symbol entry;
	ConditionalBranch[] cdBranches;
}

class ConditionalSet : Symbol {
	ConditionalEntry[] set;
	
	Symbol selected;
	bool isPoisoned;
	
	this(Location location, Name name, ConditionalEntry[] set) {
		super(location, name);
		this.set = set;
	}
}
