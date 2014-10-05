module d.llvm.symbol;

import d.llvm.codegen;

import d.ir.dscope;
import d.ir.symbol;
import d.ir.type;

import util.visitor;

import llvm.c.analysis;
import llvm.c.core;

import std.algorithm;
import std.array;
import std.range;
import std.string;

final class SymbolGen {
	private CodeGenPass pass;
	alias pass this;
	
	private LLVMValueRef[ValueSymbol] globals;
	private LLVMValueRef[ValueSymbol] locals;
	
	struct Closure {
		uint[Variable] indices;
		LLVMValueRef context;
		LLVMTypeRef type;
	}
	
	Closure[] contexts;
	
	private Closure[][TypeSymbol] embededContexts;
	
	this(CodeGenPass pass) {
		this.pass = pass;
	}
	
	void visit(Symbol s) {
		if(auto t = cast(TypeSymbol) s) {
			visit(t);
		} else if(auto v = cast(Variable) s) {
			genCached(v);
		} else if(auto f = cast(Function) s) {
			genCached(f);
		}
	}
	
	LLVMValueRef genCached(S)(S s) {
		import d.ast.base;
		final switch(s.storage) with(Storage) {
			case Enum:
			case Static:
				return globals.get(s, visit(s));
			
			case Local:
			case Capture:
				return locals.get(s, visit(s));
		}
	}
	
	void register(ValueSymbol s, LLVMValueRef v) {
		import d.ast.base;
		final switch(s.storage) with(Storage) {
			case Enum:
			case Static:
				globals[s] = v;
				return;
			
			case Local:
			case Capture:
				locals[s] = v;
				return;
		}
	}
	
	LLVMValueRef visit(Function f) {
		auto name = f.mangle.toStringz();
		auto fun = LLVMGetNamedFunction(dmodule, name);
		assert(!fun, f.mangle ~ " is already defined.");
		
		auto type = pass.visit(f.type);
		
		// Type generation can have generated the signeture (it is required to generate virtual table).
		fun = LLVMGetNamedFunction(dmodule, name);
		if (!fun) {
			fun = LLVMAddFunction(dmodule, name, LLVMGetElementType(type));
		}
		
		// Register the function.
		register(f, fun);
		if(f.fbody) {
			genFunctionBody(f, fun);
		}
		
		return fun;
	}
	
	private void genFunctionBody(Function f, LLVMValueRef fun) {
		assert(LLVMCountBasicBlocks(fun) == 0, f.mangle ~ " body is already defined.");
		
		// Function can be defined in several modules, so the optimizer can do its work.
		LLVMSetLinkage(fun, LLVMLinkage.WeakODR);
		
		// Alloca and instruction block.
		auto allocaBB = LLVMAppendBasicBlockInContext(llvmCtx, fun, "");
		auto bodyBB = LLVMAppendBasicBlockInContext(llvmCtx, fun, "body");
		
		// Ensure we are rentrant.
		auto backupCurrentBB = LLVMGetInsertBlock(builder);
		auto oldLocals = locals;
		auto oldThisPtr = thisPtr;
		auto oldContexts = contexts;
		auto oldLpContext = lpContext;
		auto oldCatchClauses = catchClauses;
		auto oldUnwindBlocks = unwindBlocks;
		
		scope(exit) {
			if(backupCurrentBB) {
				LLVMPositionBuilderAtEnd(builder, backupCurrentBB);
			} else {
				LLVMClearInsertionPosition(builder);
			}
			
			locals = oldLocals;
			thisPtr = oldThisPtr;
			contexts = oldContexts;
			lpContext = oldLpContext;
			catchClauses = oldCatchClauses;
			unwindBlocks = oldUnwindBlocks;
		}
		
		// XXX: what is the way to flush an AA ?
		locals = null;
		lpContext = null;
		catchClauses = [];
		unwindBlocks = [];
		
		// Handle parameters in the alloca block.
		LLVMPositionBuilderAtEnd(builder, allocaBB);
		
		auto funType = LLVMGetElementType(LLVMTypeOf(fun));
		
		LLVMValueRef[] params;
		LLVMTypeRef[] paramTypes;
		params.length = paramTypes.length = LLVMCountParamTypes(funType);
		LLVMGetParams(fun, params.ptr);
		LLVMGetParamTypes(funType, paramTypes.ptr);
		
		auto parameters = f.params;
		
		thisPtr = null;
		if(f.hasThis) {
			// TODO: if this have a context, expand variables !
			auto thisType = f.type.paramTypes[0];
			auto value = params[0];
			
			if(thisType.isRef || thisType.isFinal) {
				LLVMSetValueName(value, "this");
				thisPtr = value;
			} else {
				auto alloca = LLVMBuildAlloca(builder, paramTypes[0], "this");
				LLVMSetValueName(value, "arg.this");
				
				LLVMBuildStore(builder, value, alloca);
				thisPtr = alloca;
			}
			
			buildEmbededCaptures(thisPtr, thisType.type);
			
			params = params[1 .. $];
			paramTypes = paramTypes[1 .. $];
		}
		
		if (f.hasContext) {
			auto ctxType = f.type.paramTypes[f.hasThis];
			auto parentCtx = params[f.hasThis];
			
			assert(ctxType.isRef || ctxType.isFinal);
			LLVMSetValueName(parentCtx, "__ctx");
			
			auto ctxTypeGen = pass.visit(ctxType.type);
			contexts = contexts[0 .. $ - retro(contexts).countUntil!(c => c.type is ctxTypeGen)()];
			
			auto s = cast(ClosureScope) f.dscope;
			assert(s, "Function has context but do not have a closure scope");
			
			buildCapturedVariables(parentCtx, contexts, s.capture);
			
			params = params[1 .. $];
			paramTypes = paramTypes[1 .. $];
			
			// Chain closures.
			auto closure = Closure();
			closure.type = buildContextType(f);
			closure.context = LLVMBuildAlloca(builder, closure.type, "");
			
			auto parentType = LLVMTypeOf(parentCtx);
			closure.context = LLVMBuildPointerCast(
				builder,
				closure.context,
				LLVMPointerType(LLVMStructTypeInContext(llvmCtx, &parentType, 1, false), 0),
				"",
			);
			
			LLVMBuildStore(builder, parentCtx, LLVMBuildStructGEP(builder, closure.context, 0, ""));
			contexts ~= closure;
		} else {
			// Build closure for this function.
			auto closure = Closure();
			closure.type = buildContextType(f);
			contexts = [closure];
		}
		
		foreach(i, p; parameters) {
			auto type = p.type;
			auto value = params[i];
			
			if(type.isRef || type.isFinal) {
				LLVMSetValueName(value, p.mangle.toStringz());
				locals[p] = value;
			} else {
				auto name = p.name.toString(context);
				auto alloca = LLVMBuildAlloca(builder, paramTypes[i], name.toStringz());
				LLVMSetValueName(value, ("arg." ~ name).toStringz());
				
				LLVMBuildStore(builder, value, alloca);
				locals[p] = alloca;
			}
		}
		
		// Generate function's body.
		LLVMPositionBuilderAtEnd(builder, bodyBB);
		
		import d.llvm.statement;
		auto sg = StatementGen(pass);
		sg.visit(f.fbody);
		
		// If the current block isn't concluded, it means that it is unreachable.
		if(!LLVMGetBasicBlockTerminator(LLVMGetInsertBlock(builder))) {
			// FIXME: provide the right AST in case of void function.
			if(LLVMGetTypeKind(LLVMGetReturnType(funType)) == LLVMTypeKind.Void) {
				LLVMBuildRetVoid(builder);
			} else {
				LLVMBuildUnreachable(builder);
			}
		}
		
		// Branch from alloca block to function body.
		LLVMPositionBuilderAtEnd(builder, allocaBB);
		LLVMBuildBr(builder, bodyBB);
		
		// If we have a context, let's make it the right size.
		if (auto context = contexts[$ - 1].context) {
			auto ctxType = LLVMGetElementType(LLVMTypeOf(context));
			
			auto count = LLVMCountStructElementTypes(ctxType);
			LLVMTypeRef[] types;
			types.length = count;
			LLVMGetStructElementTypes(ctxType, types.ptr);
			
			ctxType = contexts[$ - 1].type;
			LLVMStructSetBody(ctxType, types.ptr, count, false);
			
			while(LLVMGetInstructionOpcode(context) != LLVMOpcode.Alloca) {
				assert(LLVMGetInstructionOpcode(context) == LLVMOpcode.BitCast);
				context = LLVMGetOperand(context, 0);
			}
			
			LLVMPositionBuilderBefore(builder, context);
			
			import d.llvm.expression;
			auto eg = ExpressionGen(pass);
			
			LLVMValueRef size = LLVMConstTrunc(LLVMSizeOf(ctxType),getPtrTypeInContext(llvmCtx));
			auto alloc = eg.buildCall(druntimeGen.getAllocMemory(), [size]);
			LLVMAddInstrAttribute(alloc, 0, LLVMAttribute.NoAlias);
			
			LLVMReplaceAllUsesWith(context, LLVMBuildPointerCast(builder, alloc, LLVMPointerType(ctxType, 0), ""));
		}
	}
	
	private void buildEmbededCaptures(LLVMValueRef thisPtr, Type t) {
		if (auto st = cast(StructType) t) {
			auto s = st.dstruct;
			if (!s.hasContext) {
				return;
			}
			
			auto vs = cast(VoldemortScope) s.dscope;
			assert(vs, "Struct has context but no VoldemortScope");
			
			buildEmbededCaptures(thisPtr, 0, embededContexts[s], vs);
		} else if (auto ct = cast(ClassType) t) {
			auto c = ct.dclass;
			if (!c.hasContext) {
				return;
			}
			
			auto vs = cast(VoldemortScope) c.dscope;
			assert(vs, "Class has context but no VoldemortScope");
			
			import d.context;
			auto f = retro(c.members).filter!(m => m.name == BuiltinName!"__ctx").map!(m => cast(Field) m).front;
			
			buildEmbededCaptures(thisPtr, f.index, embededContexts[c], vs);
		} else {
			assert(0, typeid(t).toString() ~ " is not supported.");
		}
	}
	
	private void buildEmbededCaptures(LLVMValueRef thisPtr, uint i, Closure[] contexts, VoldemortScope s) {
		buildCapturedVariables(LLVMBuildLoad(builder, LLVMBuildStructGEP(builder, thisPtr, i, ""), ""), contexts, s.capture);
	}
	
	private void buildCapturedVariables(LLVMValueRef root, Closure[] contexts, bool[Variable] capture) {
		auto closureCount = capture.length;
		
		// Try to find out if we have the variable in a closure.
		ClosureLoop: foreach_reverse(closure; contexts) {
			root = LLVMBuildPointerCast(builder, root, LLVMTypeOf(closure.context), "");
			
			// Create enclosed variables.
			foreach(v; capture.byKey()) {
				if (auto indexPtr = v in closure.indices) {
					// Register the variable.
					locals[v] = LLVMBuildStructGEP(builder, root, *indexPtr, v.mangle.toStringz());
					
					closureCount--;
					if (!closureCount) {
						break ClosureLoop;
					}
				}
			}
			
			root = LLVMBuildLoad(builder, LLVMBuildStructGEP(builder, root, 0, ""), "");
		}
		
		assert(closureCount == 0);
	}
	
	LLVMValueRef getContext(Function f) {
		auto type = pass.buildContextType(f);
		auto value = contexts[$ - 1].context;
		foreach_reverse(i, c; contexts) {
			value = LLVMBuildPointerCast(builder, value, LLVMTypeOf(c.context), "");
			
			if (c.type is type) {
				return LLVMBuildPointerCast(builder, value, LLVMPointerType(type, 0), "");
			}
			
			value = LLVMBuildLoad(builder, LLVMBuildStructGEP(builder, value, 0, ""), "");
		}
		
		assert(0, "No context available.");
	}
	
	LLVMValueRef visit(Variable v) {
		import d.llvm.expression;
		auto eg = ExpressionGen(pass);
		auto value = eg.visit(v.value);
		
		import d.ast.base;
		if(v.storage == Storage.Enum) {
			return globals[v] = value;
		}
		
		auto type = pass.visit(v.type);
		if(v.storage == Storage.Static) {
			auto globalVar = LLVMAddGlobal(dmodule, type, v.mangle.toStringz());
			LLVMSetThreadLocal(globalVar, true);
			
			// Store the initial value into the global variable.
			LLVMSetInitializer(globalVar, value);
			
			// Register the variable.
			return globals[v] = globalVar;
		}
		
		// Backup current block
		auto backupCurrentBlock = LLVMGetInsertBlock(builder);
		LLVMPositionBuilderAtEnd(builder, LLVMGetFirstBasicBlock(LLVMGetBasicBlockParent(backupCurrentBlock)));
		
		// Sanity check
		scope(success) assert(LLVMGetInsertBlock(builder) is backupCurrentBlock);
		
		LLVMValueRef addr;
		if(v.storage == Storage.Capture) {
			auto closure = &contexts[$ - 1];
			
			uint index = 0;
			
			// If we don't have a closure, make one.
			if (!closure.context) {
				auto alloca = LLVMBuildAlloca(builder, closure.type, "");
				closure.context = LLVMBuildPointerCast(
					builder,
					alloca,
					LLVMPointerType(LLVMStructTypeInContext(llvmCtx, &type, 1, false), 0),
					"",
				);
			} else {
				auto context = closure.context;
				auto contextType = LLVMGetElementType(LLVMTypeOf(context));
				index = LLVMCountStructElementTypes(contextType);
				
				LLVMTypeRef[] types;
				types.length = index + 1;
				LLVMGetStructElementTypes(contextType, types.ptr);
				types[$ - 1] = type;
				
				closure.context = LLVMBuildPointerCast(
					builder,
					context,
					LLVMPointerType(LLVMStructTypeInContext(llvmCtx, types.ptr, index + 1, false), 0),
					"",
				);
			}
			
			closure.indices[v] = index;
			addr = LLVMBuildStructGEP(builder, closure.context, index, v.mangle.toStringz());
		} else {
			addr = LLVMBuildAlloca(builder, type, v.mangle.toStringz());
		}
		
		// Store the initial value into the alloca.
		LLVMPositionBuilderAtEnd(builder, backupCurrentBlock);
		LLVMBuildStore(builder, value, addr);
		
		import d.context;
		if(v.name == BuiltinName!"this") {
			thisPtr = addr;
		}
		
		// Register the variable.
		return locals[v] = addr;
	}
	
	LLVMValueRef visit(Parameter p) {
		return locals[p];
	}
	
	LLVMTypeRef visit(TypeSymbol s) {
		if (s.hasContext) {
			embededContexts[s] = contexts;
		}
		
		return this.dispatch(s);
	}
	
	LLVMTypeRef visit(TypeAlias a) {
		return pass.visit(a.type);
	}
	
	LLVMTypeRef visit(Struct s) {
		auto ret = pass.buildStructType(s);
		
		foreach(member; s.members) {
			if(typeid(member) !is typeid(Field)) {
				visit(member);
			}
		}
		
		return ret;
	}
	
	LLVMTypeRef visit(Class c) {
		auto ret = pass.buildClassType(c);
		
		foreach(member; c.members) {
			if (auto m = cast(Method) member) {
				auto fun = genCached(m);
				if (LLVMCountBasicBlocks(fun) == 0) {
					genFunctionBody(m, fun);
				}
			}
		}
		
		return ret;
	}
	
	LLVMTypeRef visit(Enum e) {
		auto type = pass.visit(new EnumType(e));
		/+
		foreach(entry; e.entries) {
			visit(entry);
		}
		+/
		return type;
	}
}

